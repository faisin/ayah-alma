// AYAH ALMA SSH payload bridge.
// Supports raw HTTP Injector payloads (GET/CGI/CONNECT) and RFC 6455 WebSocket
// framing when Sec-WebSocket-Key is supplied by a standards-compliant client.
package main

import (
	"bufio"
	"bytes"
	"crypto/sha1"
	"encoding/base64"
	"encoding/binary"
	"errors"
	"io"
	"log"
	"net"
	"strings"
	"sync"
	"time"
)

const (
	listenAddr = "127.0.0.1:2096"
	targetAddr = "127.0.0.1:143"
	maxHeader  = 64 * 1024
	maxFrame   = 16 * 1024 * 1024
)

func main() {
	ln, err := net.Listen("tcp", listenAddr)
	if err != nil {
		log.Fatalf("listen %s: %v", listenAddr, err)
	}
	log.Printf("SSH payload bridge listening %s -> %s", listenAddr, targetAddr)
	for {
		c, err := ln.Accept()
		if err != nil {
			log.Printf("accept: %v", err)
			continue
		}
		go handle(c)
	}
}

func handle(client net.Conn) {
	defer client.Close()
	_ = client.SetReadDeadline(time.Now().Add(15 * time.Second))
	br := bufio.NewReaderSize(client, 4096)
	var header strings.Builder
	for header.Len() < maxHeader {
		line, err := br.ReadString('\n')
		if err != nil {
			return
		}
		header.WriteString(line)
		v := header.String()
		if strings.HasSuffix(v, "\r\n\r\n") || strings.HasSuffix(v, "\n\n") {
			break
		}
	}
	if header.Len() >= maxHeader {
		_, _ = io.WriteString(client, "HTTP/1.1 431 Request Header Fields Too Large\r\nConnection: close\r\n\r\n")
		return
	}

	// HTTP Injector may concatenate more than one request around [split].
	// Collect up to four complete request headers before opening the SSH stream.
	fullHeader, pending := collectPayloadHeaders(client, br, header.String())
	lines := strings.Split(strings.ReplaceAll(fullHeader, "\r\n", "\n"), "\n")
	if len(lines) == 0 {
		return
	}
	parts := strings.Fields(lines[0])
	if len(parts) < 3 || !strings.HasPrefix(parts[2], "HTTP/1.") {
		_, _ = io.WriteString(client, "HTTP/1.1 400 Bad Request\r\nConnection: close\r\n\r\n")
		return
	}
	method := strings.ToUpper(parts[0])
	if !validMethod(method) {
		_, _ = io.WriteString(client, "HTTP/1.1 405 Method Not Allowed\r\nConnection: close\r\n\r\n")
		return
	}
	// The last request line determines whether this is a CONNECT payload.
	for _, line := range lines[1:] {
		fields := strings.Fields(line)
		if len(fields) >= 3 && strings.HasPrefix(fields[2], "HTTP/1.") {
			method = strings.ToUpper(fields[0])
		}
	}

	key := ""
	for _, line := range lines[1:] {
		if i := strings.IndexByte(line, ':'); i > 0 && strings.EqualFold(strings.TrimSpace(line[:i]), "Sec-WebSocket-Key") {
			key = strings.TrimSpace(line[i+1:])
			break
		}
	}
	websocketMode := key != "" && method != "CONNECT"
	accept := ""
	if websocketMode {
		decoded, err := base64.StdEncoding.DecodeString(key)
		if err != nil || len(decoded) != 16 {
			_, _ = io.WriteString(client, "HTTP/1.1 400 Invalid WebSocket Key\r\nConnection: close\r\n\r\n")
			return
		}
		sum := sha1.Sum([]byte(key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))
		accept = base64.StdEncoding.EncodeToString(sum[:])
	}

	target, err := net.DialTimeout("tcp", targetAddr, 10*time.Second)
	if err != nil {
		_, _ = io.WriteString(client, "HTTP/1.1 502 Bad Gateway\r\nConnection: close\r\n\r\n")
		return
	}
	defer target.Close()

	response := ""
	if method == "CONNECT" {
		response = "HTTP/1.1 200 Connection established\r\nProxy-Agent: AYAH-ALMA\r\n\r\n"
	} else {
		response = "HTTP/1.1 101 Switching Protocols\r\nConnection: Upgrade\r\nUpgrade: websocket\r\n"
		if websocketMode {
			response += "Sec-WebSocket-Accept: " + accept + "\r\n"
		}
		response += "\r\n"
	}
	if _, err = io.WriteString(client, response); err != nil {
		return
	}
	_ = client.SetDeadline(time.Time{})

	if websocketMode {
		bridgeWebSocket(client, br, target)
		return
	}

	// Raw-payload mode: preserve partial bytes and SSH data following all HTTP headers.
	rawClient := io.Reader(br)
	if len(pending) > 0 {
		rawClient = io.MultiReader(bytes.NewReader(pending), br)
	}
	done := make(chan struct{}, 1)
	go func() {
		_, _ = io.Copy(target, rawClient)
		if t, ok := target.(*net.TCPConn); ok {
			_ = t.CloseWrite()
		}
		done <- struct{}{}
	}()
	_, _ = io.Copy(client, target)
	_ = client.SetDeadline(time.Now().Add(time.Second))
	select {
	case <-done:
	case <-time.After(time.Second):
	}
}

func validMethod(method string) bool {
	if method == "" {
		return false
	}
	for _, r := range method {
		if !(r >= 'A' && r <= 'Z') && !(r >= '0' && r <= '9') && !strings.ContainsRune("!#$%&'*+-.^_`|~", r) {
			return false
		}
	}
	return true
}

func isHTTPRequestLine(line string) bool {
	fields := strings.Fields(line)
	return len(fields) >= 3 && validMethod(strings.ToUpper(fields[0])) &&
		(strings.HasPrefix(fields[2], "HTTP/1.0") || strings.HasPrefix(fields[2], "HTTP/1.1"))
}

func collectPayloadHeaders(client net.Conn, br *bufio.Reader, first string) (string, []byte) {
	full := first
	var pending []byte
	if strings.Contains(strings.ToLower(first), "sec-websocket-key:") {
		return full, nil
	}
	for request := 0; request < 4 && len(full) < maxHeader; request++ {
		_ = client.SetReadDeadline(time.Now().Add(450 * time.Millisecond))
		line, err := br.ReadString('\n')
		if err != nil {
			pending = append(pending, []byte(line)...)
			break
		}
		if !isHTTPRequestLine(line) {
			pending = append(pending, []byte(line)...)
			break
		}
		full += line
		for {
			line, err = br.ReadString('\n')
			if err != nil {
				pending = append(pending, []byte(line)...)
				_ = client.SetReadDeadline(time.Time{})
				return full, pending
			}
			full += line
			if strings.HasSuffix(full, "\r\n\r\n") || strings.HasSuffix(full, "\n\n") {
				break
			}
			if len(full) >= maxHeader {
				break
			}
		}
	}
	_ = client.SetReadDeadline(time.Time{})
	return full, pending
}

func bridgeWebSocket(client net.Conn, br *bufio.Reader, target net.Conn) {
	var writeMu sync.Mutex
	done := make(chan struct{}, 2)

	go func() {
		defer func() { done <- struct{}{} }()
		for {
			payload, opcode, err := readClientFrame(br)
			if err != nil {
				return
			}
			switch opcode {
			case 0x0, 0x1, 0x2: // continuation, text, binary
				if len(payload) > 0 {
					if _, err := target.Write(payload); err != nil {
						return
					}
				}
			case 0x8: // close
				writeMu.Lock()
				_ = writeServerFrame(client, 0x8, payload)
				writeMu.Unlock()
				return
			case 0x9: // ping
				writeMu.Lock()
				err = writeServerFrame(client, 0xA, payload)
				writeMu.Unlock()
				if err != nil {
					return
				}
			case 0xA: // pong
			default:
				return
			}
		}
	}()

	go func() {
		defer func() { done <- struct{}{} }()
		buf := make([]byte, 32*1024)
		for {
			n, err := target.Read(buf)
			if n > 0 {
				writeMu.Lock()
				writeErr := writeServerFrame(client, 0x2, buf[:n])
				writeMu.Unlock()
				if writeErr != nil {
					return
				}
			}
			if err != nil {
				return
			}
		}
	}()
	<-done
	_ = client.SetDeadline(time.Now().Add(time.Second))
	_ = target.Close()
}

func readClientFrame(r *bufio.Reader) ([]byte, byte, error) {
	var h [2]byte
	if _, err := io.ReadFull(r, h[:]); err != nil {
		return nil, 0, err
	}
	if h[0]&0x70 != 0 {
		return nil, 0, errors.New("unsupported websocket RSV bits")
	}
	opcode := h[0] & 0x0f
	masked := h[1]&0x80 != 0
	if !masked {
		return nil, 0, errors.New("client websocket frame is not masked")
	}
	length := uint64(h[1] & 0x7f)
	if length == 126 {
		var b [2]byte
		if _, err := io.ReadFull(r, b[:]); err != nil {
			return nil, 0, err
		}
		length = uint64(binary.BigEndian.Uint16(b[:]))
	} else if length == 127 {
		var b [8]byte
		if _, err := io.ReadFull(r, b[:]); err != nil {
			return nil, 0, err
		}
		length = binary.BigEndian.Uint64(b[:])
	}
	if length > maxFrame {
		return nil, 0, errors.New("websocket frame too large")
	}
	var mask [4]byte
	if _, err := io.ReadFull(r, mask[:]); err != nil {
		return nil, 0, err
	}
	payload := make([]byte, int(length))
	if _, err := io.ReadFull(r, payload); err != nil {
		return nil, 0, err
	}
	for i := range payload {
		payload[i] ^= mask[i%4]
	}
	return payload, opcode, nil
}

func writeServerFrame(w io.Writer, opcode byte, payload []byte) error {
	var h [10]byte
	h[0] = 0x80 | (opcode & 0x0f)
	n := len(payload)
	var header []byte
	switch {
	case n < 126:
		h[1] = byte(n)
		header = h[:2]
	case n <= 65535:
		h[1] = 126
		binary.BigEndian.PutUint16(h[2:4], uint16(n))
		header = h[:4]
	default:
		h[1] = 127
		binary.BigEndian.PutUint64(h[2:10], uint64(n))
		header = h[:10]
	}
	if _, err := w.Write(header); err != nil {
		return err
	}
	_, err := w.Write(payload)
	return err
}

// SSH WebSocket tunnel proxy.
// Accepts RFC 6455 WebSocket connections and forwards binary payloads to Dropbear.
package main

import (
	"bufio"
	"crypto/sha1"
	"encoding/base64"
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"strings"
	"sync"
	"time"
)

const (
	ListenAddr = "127.0.0.1:2096"
	TargetAddr = "127.0.0.1:109"
	wsGUID     = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
	maxFrame   = 1 << 20 // 1 MiB per WebSocket frame
)

func main() {
	ln, err := net.Listen("tcp", ListenAddr)
	if err != nil {
		log.Fatalf("listen error: %v", err)
	}
	log.Printf("SSH WSS backend (TLS terminated by HAProxy) listening on %s -> %s", ListenAddr, TargetAddr)
	for {
		conn, err := ln.Accept()
		if err != nil {
			log.Printf("accept error: %v", err)
			continue
		}
		go handle(conn)
	}
}

func handle(client net.Conn) {
	defer client.Close()
	_ = client.SetDeadline(time.Now().Add(15 * time.Second))
	reader := bufio.NewReader(client)

	req, err := http.ReadRequest(reader)
	if err != nil {
		log.Printf("invalid websocket request from %s: %v", client.RemoteAddr(), err)
		return
	}
	if req.Method != http.MethodGet ||
		!headerHasToken(req.Header, "Connection", "upgrade") ||
		!strings.EqualFold(req.Header.Get("Upgrade"), "websocket") ||
		req.Header.Get("Sec-WebSocket-Version") != "13" {
		writeHTTPError(client, http.StatusBadRequest, "valid WebSocket upgrade required")
		return
	}
	key := strings.TrimSpace(req.Header.Get("Sec-WebSocket-Key"))
	decoded, err := base64.StdEncoding.DecodeString(key)
	if err != nil || len(decoded) != 16 {
		writeHTTPError(client, http.StatusBadRequest, "invalid Sec-WebSocket-Key")
		return
	}

	target, err := net.DialTimeout("tcp", TargetAddr, 5*time.Second)
	if err != nil {
		writeHTTPError(client, http.StatusBadGateway, "SSH backend unavailable")
		log.Printf("target connect error: %v", err)
		return
	}
	defer target.Close()

	sum := sha1.Sum([]byte(key + wsGUID))
	accept := base64.StdEncoding.EncodeToString(sum[:])
	response := "HTTP/1.1 101 Switching Protocols\r\n" +
		"Upgrade: websocket\r\n" +
		"Connection: Upgrade\r\n" +
		"Sec-WebSocket-Accept: " + accept + "\r\n\r\n"
	if _, err = io.WriteString(client, response); err != nil {
		log.Printf("handshake response error: %v", err)
		return
	}
	_ = client.SetDeadline(time.Time{})
	log.Printf("websocket connected: %s", client.RemoteAddr())

	var writeMu sync.Mutex
	writeFrame := func(opcode byte, payload []byte) error {
		writeMu.Lock()
		defer writeMu.Unlock()
		return writeServerFrame(client, opcode, payload)
	}

	// Client frames are masked as required by RFC 6455; unmask and forward
	// application data to the raw SSH socket.
	clientDone := make(chan error, 1)
	go func() {
		var fragmentOpcode byte
		for {
			op, fin, payload, err := readClientFrame(reader)
			if err != nil {
				clientDone <- err
				return
			}
			switch op {
			case 0x8: // close
				_ = writeFrame(0x8, payload)
				clientDone <- io.EOF
				return
			case 0x9: // ping
				if err := writeFrame(0xA, payload); err != nil {
					clientDone <- err
					return
				}
			case 0xA: // pong
				continue
			case 0x1, 0x2: // text or binary data
				if fragmentOpcode != 0 {
					clientDone <- errors.New("new data frame before fragmented message completed")
					return
				}
				if err := writeAll(target, payload); err != nil {
					clientDone <- err
					return
				}
				if !fin {
					fragmentOpcode = op
				}
			case 0x0: // continuation
				if fragmentOpcode == 0 {
					clientDone <- errors.New("unexpected continuation frame")
					return
				}
				if err := writeAll(target, payload); err != nil {
					clientDone <- err
					return
				}
				if fin {
					fragmentOpcode = 0
				}
			default:
				clientDone <- fmt.Errorf("unsupported websocket opcode: %d", op)
				return
			}
		}
	}()

	// Wrap raw SSH bytes in unmasked server-to-client binary WebSocket frames.
	buf := make([]byte, 32*1024)
	for {
		n, readErr := target.Read(buf)
		if n > 0 {
			if err := writeFrame(0x2, buf[:n]); err != nil {
				log.Printf("websocket write error: %v", err)
				return
			}
		}
		if readErr != nil {
			if readErr != io.EOF {
				log.Printf("SSH backend read error: %v", readErr)
			}
			_ = writeFrame(0x8, nil)
			return
		}
		select {
		case err := <-clientDone:
			if err != nil && err != io.EOF {
				log.Printf("websocket client ended: %v", err)
			}
			return
		default:
		}
	}
}

func headerHasToken(h http.Header, name, token string) bool {
	for _, value := range h.Values(name) {
		for _, part := range strings.Split(value, ",") {
			if strings.EqualFold(strings.TrimSpace(part), token) {
				return true
			}
		}
	}
	return false
}

func writeHTTPError(w io.Writer, code int, message string) {
	status := http.StatusText(code)
	_, _ = fmt.Fprintf(w, "HTTP/1.1 %d %s\r\nConnection: close\r\nContent-Type: text/plain\r\nContent-Length: %d\r\n\r\n%s",
		code, status, len(message), message)
}

func readClientFrame(r io.Reader) (byte, bool, []byte, error) {
	var head [2]byte
	if _, err := io.ReadFull(r, head[:]); err != nil {
		return 0, false, nil, err
	}
	fin := head[0]&0x80 != 0
	opcode := head[0] & 0x0f
	if head[0]&0x70 != 0 {
		return 0, false, nil, errors.New("websocket RSV bits are not supported")
	}
	masked := head[1]&0x80 != 0
	if !masked {
		return 0, false, nil, errors.New("client websocket frame is not masked")
	}
	length := uint64(head[1] & 0x7f)
	switch length {
	case 126:
		var ext [2]byte
		if _, err := io.ReadFull(r, ext[:]); err != nil {
			return 0, false, nil, err
		}
		length = uint64(binary.BigEndian.Uint16(ext[:]))
	case 127:
		var ext [8]byte
		if _, err := io.ReadFull(r, ext[:]); err != nil {
			return 0, false, nil, err
		}
		length = binary.BigEndian.Uint64(ext[:])
		if length>>63 != 0 {
			return 0, false, nil, errors.New("invalid websocket frame length")
		}
	}
	if length > maxFrame {
		return 0, false, nil, errors.New("websocket frame exceeds 1 MiB limit")
	}
	if opcode >= 0x8 && (!fin || length > 125) {
		return 0, false, nil, errors.New("invalid websocket control frame")
	}
	var mask [4]byte
	if _, err := io.ReadFull(r, mask[:]); err != nil {
		return 0, false, nil, err
	}
	payload := make([]byte, int(length))
	if _, err := io.ReadFull(r, payload); err != nil {
		return 0, false, nil, err
	}
	for i := range payload {
		payload[i] ^= mask[i&3]
	}
	return opcode, fin, payload, nil
}

func writeServerFrame(w io.Writer, opcode byte, payload []byte) error {
	var header []byte
	n := len(payload)
	switch {
	case n < 126:
		header = []byte{0x80 | opcode, byte(n)}
	case uint64(n) <= 65535:
		header = make([]byte, 4)
		header[0], header[1] = 0x80|opcode, 126
		binary.BigEndian.PutUint16(header[2:], uint16(n))
	default:
		header = make([]byte, 10)
		header[0], header[1] = 0x80|opcode, 127
		binary.BigEndian.PutUint64(header[2:], uint64(n))
	}
	if err := writeAll(w, header); err != nil {
		return err
	}
	return writeAll(w, payload)
}

func writeAll(w io.Writer, p []byte) error {
	for len(p) > 0 {
		n, err := w.Write(p)
		if err != nil {
			return err
		}
		if n == 0 {
			return io.ErrShortWrite
		}
		p = p[n:]
	}
	return nil
}

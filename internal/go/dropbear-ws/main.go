// ==========================================
// SSH WebSocket Proxy (Golang) - by Ayah Alma
// ==========================================
package main

import (
	"bufio"
	"crypto/sha1"
	"encoding/base64"
	"fmt"
	"io"
	"log"
	"net"
	"strings"
	"time"
)

const (
	ListenAddr = "127.0.0.1:2082"
	// Dropbear tetap berada di loopback; port 109/143 publik diteruskan
	// oleh HAProxy sesuai konfigurasi yang sudah ada.
	TargetAddr = "127.0.0.1:1109"
	BufLen     = 32 * 1024
)

const websocketGUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

func main() {
	ln, err := net.Listen("tcp", ListenAddr)
	if err != nil {
		log.Fatalf("listen error: %v", err)
	}
	log.Printf("SSH WS listening on %s -> %s", ListenAddr, TargetAddr)

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

	reader := bufio.NewReaderSize(client, BufLen)
	requestLine, err := reader.ReadString('\n')
	if err != nil {
		log.Printf("request line error: %v", err)
		return
	}
	if !strings.HasPrefix(requestLine, "GET ") {
		log.Printf("unsupported SSH WS request: %q", strings.TrimSpace(requestLine))
		_, _ = io.WriteString(client, "HTTP/1.1 400 Bad Request\r\nConnection: close\r\nContent-Length: 0\r\n\r\n")
		return
	}

	var websocketKey string
	headerBytes := len(requestLine)
	for {
		line, readErr := reader.ReadString('\n')
		if readErr != nil {
			log.Printf("header read error: %v", readErr)
			return
		}
		headerBytes += len(line)
		if headerBytes > BufLen {
			_, _ = io.WriteString(client, "HTTP/1.1 431 Request Header Fields Too Large\r\nConnection: close\r\nContent-Length: 0\r\n\r\n")
			return
		}
		if line == "\r\n" || line == "\n" {
			break
		}
		name, value, ok := strings.Cut(line, ":")
		if ok && strings.EqualFold(strings.TrimSpace(name), "Sec-WebSocket-Key") {
			websocketKey = strings.TrimSpace(value)
		}
	}

	target, err := net.DialTimeout("tcp", TargetAddr, 10*time.Second)
	if err != nil {
		log.Printf("target connect error: %v", err)
		return
	}
	defer target.Close()

	if websocketKey == "" {
		// HTTP Custom/raw SSH-WS clients that do not send an RFC6455 key
		// retain the legacy tunnel handshake, but with valid Upgrade headers.
		_, err = io.WriteString(client, "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n")
	} else {
		sum := sha1.Sum([]byte(websocketKey + websocketGUID))
		accept := base64.StdEncoding.EncodeToString(sum[:])
		_, err = fmt.Fprintf(client,
			"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: %s\r\n\r\n",
			accept)
	}
	if err != nil {
		log.Printf("handshake write error: %v", err)
		return
	}



	_ = client.SetDeadline(time.Time{})
	_ = target.SetDeadline(time.Time{})

	errCh := make(chan error, 1)
	go func() {
		// Preserve any bytes already buffered after the HTTP header.
		if reader.Buffered() > 0 {
			if _, copyErr := io.CopyN(target, reader, int64(reader.Buffered())); copyErr != nil {
				errCh <- copyErr
				return
			}
		}
		_, copyErr := io.Copy(target, client)
		if tcp, ok := target.(*net.TCPConn); ok {
			_ = tcp.CloseWrite()
		}
		errCh <- copyErr
	}()

	_, copyErr := io.Copy(client, target)
	if copyErr != nil && copyErr != io.EOF {
		log.Printf("target->client error: %v", copyErr)
	}
	if err := <-errCh; err != nil && err != io.EOF {
		log.Printf("client->target error: %v", err)
	}
	log.Printf("connection closed: %s", client.RemoteAddr())
}

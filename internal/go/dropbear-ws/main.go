// ==========================================
// SSH WebSocket Proxy (Golang) - by Ayah Alma
// Legacy HTTP Custom-compatible raw SSH tunnel.
// ==========================================
package main

import (
	"bufio"
	"io"
	"log"
	"net"
	"strings"
	"time"
)

const (
	ListenAddr = "127.0.0.1:2082"
	TargetAddr = "127.0.0.1:1109"
	MaxHeader  = 32 * 1024
)

// Keep the legacy Ayah Alma handshake used by the successful TCP experiment.
// HAProxy must pass this response as raw TCP; do not put this backend in mode http.
const response = "HTTP/1.1 101 Ayah Alma Server Connected\r\n" +
	"Content-Length: 104857600000\r\n\r\n"

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
	_ = client.SetReadDeadline(time.Now().Add(15 * time.Second))

	reader := bufio.NewReaderSize(client, 4096)
	requestLine, err := reader.ReadString('\n')
	if err != nil {
		log.Printf("request line error from %s: %v", client.RemoteAddr(), err)
		return
	}
	if !strings.HasPrefix(requestLine, "GET ") {
		log.Printf("unsupported request from %s: %q", client.RemoteAddr(), strings.TrimSpace(requestLine))
		_, _ = io.WriteString(client, "HTTP/1.1 400 Bad Request\r\nConnection: close\r\nContent-Length: 0\r\n\r\n")
		return
	}

	headerSize := len(requestLine)
	for {
		line, readErr := reader.ReadString('\n')
		if readErr != nil {
			log.Printf("header read error from %s: %v", client.RemoteAddr(), readErr)
			return
		}
		headerSize += len(line)
		if headerSize > MaxHeader {
			_, _ = io.WriteString(client, "HTTP/1.1 431 Request Header Fields Too Large\r\nConnection: close\r\nContent-Length: 0\r\n\r\n")
			return
		}
		if line == "\r\n" || line == "\n" {
			break
		}
	}

	target, err := net.DialTimeout("tcp", TargetAddr, 10*time.Second)
	if err != nil {
		log.Printf("target connect error %s -> %s: %v", client.RemoteAddr(), TargetAddr, err)
		return
	}
	defer target.Close()

	if _, err = io.WriteString(client, response); err != nil {
		log.Printf("handshake write error: %v", err)
		return
	}

	_ = client.SetDeadline(time.Time{})
	_ = target.SetDeadline(time.Time{})

	copyDone := make(chan error, 1)
	go func() {
		_, copyErr := io.Copy(target, reader)
		if tcp, ok := target.(*net.TCPConn); ok {
			_ = tcp.CloseWrite()
		}
		copyDone <- copyErr
	}()

	_, reverseErr := io.Copy(client, target)
	if reverseErr != nil && reverseErr != io.EOF {
		log.Printf("target-to-client copy error: %v", reverseErr)
	}
	if forwardErr := <-copyDone; forwardErr != nil && forwardErr != io.EOF {
		log.Printf("client-to-target copy error: %v", forwardErr)
	}
	log.Printf("connection closed: %s", client.RemoteAddr())
}

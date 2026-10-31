# AYAH ALMA — Peta Port dan Alur Koneksi

## Prinsip utama

- HAProxy adalah satu-satunya pintu masuk publik untuk TCP 80 dan 443.
- TLS HTTPS diterminasi di HAProxy. Backend WSS menerima HTTP biasa di loopback.
- Nginx hanya melayani website pada `127.0.0.1:8080`.
- Semua inbound Xray hanya mendengarkan `127.0.0.1`; HAProxy meneruskan path ke inbound yang sesuai.
- OpenSSH tetap langsung pada TCP 22.
- Dropbear langsung pada TCP 109 dan 143. HAProxy tidak bind kedua port ini.

## Port

| Layanan | Akses | Tujuan |
|---|---|---|
| OpenSSH | TCP 22 publik | sshd |
| Dropbear | TCP 109 publik | Dropbear |
| Dropbear | TCP 143 publik | Dropbear |
| HTTP | TCP 80 publik | HAProxy |
| HTTPS | TCP 443 publik | HAProxy TLS termination |
| SSH WS | HAProxy `:80 /ssh-ws` | `127.0.0.1:2082` → Dropbear `127.0.0.1:109` |
| SSH WSS | HAProxy `:443 /ssh-wss` | `127.0.0.1:2096` → Dropbear `127.0.0.1:143` |
| Nginx | loopback only | `127.0.0.1:8080` |
| Xray VMess WS | loopback only | `23456` TLS path `/vmess`; `23457` HTTP path `/vmess` |
| Xray VLESS WS | loopback only | `14016` TLS path `/vless`; `14017` HTTP path `/vless` |
| Xray Trojan WS | loopback only | `25432` TLS path `/trojan-ws`; `25433` HTTP path `/trojan-ws` |
| Xray Shadowsocks WS | loopback only | `30300` TLS path `/ss-ws`; `30301` HTTP path `/ss-ws` |
| Xray gRPC | loopback only | `31234`, `24456`, `33456`, `30310` |
| Xray HTTPUpgrade | loopback only | `14018`, `14019`, `14020` |

## SSH payload routing

HAProxy mengenali:

- `/ssh-ws` dan `/ssh-wss`
- `/cdn-cgi/trace` (HTTP: SSH WS; HTTPS: SSH WSS)
- WebSocket `Upgrade`
- `Connection: Upgrade`
- `X-Online-Host`
- `X-Real-Host`
- metode `CONNECT`
- variasi HTTP/1.0 dan HTTP/1.1 dengan header lengkap; header diproses sampai `CRLF CRLF`

Bridge Go membaca header HTTP sampai delimiter akhir, menerima variasi GET/CGI dan CONNECT, lalu meneruskan stream ke Dropbear. Data yang ikut terkirim setelah akhir header tetap diteruskan, tidak dibuang.

## Sertifikat

Let's Encrypt HTTP-01 memakai webroot `/var/www/ayah-alma`. Selama bootstrap, HAProxy tetap pemilik port 80 dan meneruskan challenge ke Nginx privat. HAProxy tidak perlu dihentikan dan Nginx tidak pernah bind port publik 80/443.

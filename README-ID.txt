AYAH ALMA — ARSITEKTUR SSH / WEBSOCKET / HAPROXY

- HAProxy satu-satunya pemilik port publik TCP 80 dan 443.
- OpenSSH tetap pada TCP 22.
- Dropbear langsung pada TCP 109 dan 143; bukan melalui HAProxy.
- SSH WS: HAProxy port 80, path /ssh-ws -> 127.0.0.1:2082 -> Dropbear 109.
- SSH WSS: HAProxy port 443, path /ssh-wss -> 127.0.0.1:2096 -> Dropbear 143.
- Nginx hanya listen 127.0.0.1:8080.
- Semua inbound Xray hanya listen 127.0.0.1 dan dipilih melalui routing path HAProxy.
- Tidak ada listener SSH SSL-only port 444, stunnel, atau raw TCP TLS 10011-10013.

Sertifikat:
- Let's Encrypt HTTP-01 memakai webroot /var/www/ayah-alma.
- HAProxy tetap memegang port 80 dan meneruskan challenge ke Nginx privat.
- HAProxy tidak dihentikan untuk penerbitan atau pembaruan sertifikat.

Payload SSH:
- GET /ssh-ws dan GET /ssh-wss
- GET /cdn-cgi/trace
- GET HTTP/1.0 dan HTTP/1.1
- CONNECT
- X-Online-Host dan X-Real-Host
- Upgrade dan Connection: Upgrade
- Header payload multi-bagian [split]

Lihat PORT-MAP.md dan AUDIT-CHANGES.md untuk alur lengkap.
Jangan unggah private key, sertifikat runtime, token, atau kredensial produksi ke GitHub.

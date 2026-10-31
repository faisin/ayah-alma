# AYAH ALMA — Audit dan Perubahan Arsitektur SSH / HAProxy

## Perubahan

1. HAProxy menjadi satu-satunya pemilik listener publik TCP 80 dan 443. Semua listener HAProxy lama pada 109, 143, 444, dan 10011–10013 dihapus.
2. OpenSSH tetap di TCP 22. Dropbear langsung menggunakan TCP 109 dan 143; konfigurasi lama 1109/1143 dihapus. Installer memeriksa port agar tidak merebut port yang sedang digunakan daemon lain.
3. SSH WS menggunakan bridge Go pada `127.0.0.1:2082` menuju Dropbear `127.0.0.1:109`. SSH WSS menggunakan bridge Go pada `127.0.0.1:2096` menuju Dropbear `127.0.0.1:143`; TLS diterminasi oleh HAProxy.
4. Bridge menerima GET, GET CGI (`/cdn-cgi/trace`), HTTP/1.0 dan HTTP/1.1, CONNECT, `X-Online-Host`, `X-Real-Host`, dan variasi Upgrade. Header dibaca sampai delimiter lengkap dan data setelah header tidak dibuang.
5. Bridge mendukung raw HTTP Injector payload dan RFC 6455 WebSocket framing saat `Sec-WebSocket-Key` tersedia.
6. Nginx hanya menjadi backend website pada `127.0.0.1:8080`. Routing Xray duplikat di Nginx dihapus.
7. Semua inbound Xray template hanya bind ke `127.0.0.1`; inbound raw TLS yang tidak bisa dimultiplex oleh HAProxy HTTP frontend dihapus. Routing WS, HTTPUpgrade, dan gRPC tetap melalui HAProxy.
8. Penerbitan sertifikat beralih ke HTTP-01 webroot melalui HAProxy → Nginx. HAProxy tidak perlu dihentikan dan Nginx tidak mengambil port publik 80/443.
9. Service dan menu WSS diganti menjadi `dropbear-wss`; layanan stunnel dan SSH SSL-only port 444 tidak lagi dipasang.
10. `setup.sh` mendapat pemeriksaan akhir listener publik, backend Nginx, Dropbear, WS/WSS, dan alamat bind Xray.

## Validasi yang dijalankan pada arsip hasil

- Semua file `*.sh` lolos `bash -n`.
- `config/xray.json` lolos parsing JSON; seluruh 15 inbound menggunakan `127.0.0.1` dan tidak ada port inbound duplikat.
- Kedua program Go lolos `gofmt`, `go test ./...`, dan build.
- Smoke test bridge lolos untuk GET CGI dengan X-Online-Host, pemeliharaan data setelah header, dan frame WebSocket RFC 6455.
- Audit template HAProxy menemukan listener publik hanya pada port 80 dan 443; Nginx hanya bind `127.0.0.1:8080`.

## Batas validasi

Konfigurasi HAProxy belum dapat diuji dengan `haproxy -c` di lingkungan build ini karena binary HAProxy tidak tersedia. Installer tetap menjalankan `haproxy -c -f` sebelum mengaktifkan konfigurasi final pada VPS.
11. Menu SSH, pemeriksaan service, restart service, dan laporan audit VPS diselaraskan ke nama unit `dropbear-ws` dan `dropbear-wss`. Installer juga menghentikan unit legacy dari versi lama sebelum memeriksa port.
12. Payload contoh akun diperbarui dengan GET CGI, X-Online-Host, X-Real-Host, dan contoh multi-request `[split]` yang membawa header penanda agar HAProxy dapat memilih backend SSH.

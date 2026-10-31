# AYAH ALMA — Laporan audit konfigurasi SSH dan reverse proxy

## Arsitektur yang diterapkan

- HAProxy satu-satunya pemilik listener publik TCP 80 dan 443.
- OpenSSH langsung pada TCP 22.
- Dropbear langsung pada TCP 109 dan 143.
- SSH WS loopback `127.0.0.1:2082` menuju Dropbear 109.
- SSH WSS loopback `127.0.0.1:2096` menuju Dropbear 143; TLS diterminasi di HAProxy.
- Nginx website fallback hanya pada `127.0.0.1:8080`.
- Semua inbound Xray bind ke `127.0.0.1`; HAProxy merutekan WS, HTTPUpgrade, dan gRPC berdasarkan path.
- Sertifikat HTTP-01 menggunakan webroot melalui HAProxy ke Nginx; HAProxy tidak dihentikan saat challenge.

## Temuan lama yang diperbaiki

- Listener HAProxy lama pada 109/143, 444, dan 10011–10013 dihapus.
- Dropbear 1109/1143 diganti menjadi 109/143.
- Dua bridge Go diperbaiki untuk membaca header HTTP lengkap, mendukung GET/CGI, CONNECT, X-Online-Host, X-Real-Host, multi-request payload, raw tunnel, dan framing RFC 6455.
- Nginx tidak lagi memiliki routing Xray duplikat.
- Inbound raw TLS Xray yang tidak bisa dipetakan oleh frontend HTTP HAProxy dihapus.
- Service stunnel dan SSH SSL-only port 444 tidak lagi dipasang.
- Menu dan uninstall diperbarui untuk service `dropbear-wss`.
- `setup.sh` menambahkan pemeriksaan port dan alamat bind setelah instalasi.

## Pemeriksaan yang dilakukan pada paket hasil

- Semua file `*.sh` lolos `bash -n`.
- `config/xray.json` valid; 15 inbound menggunakan `127.0.0.1` dan tidak ada port duplikat.
- Kedua program Go lolos `gofmt`, `go test ./...`, dan build.
- Smoke test lolos untuk GET CGI/X-Online-Host, payload multi-request `[split]`, raw data preservation, dan WebSocket frame RFC 6455.
- Pemeriksaan statis HAProxy menunjukkan bind publik hanya pada port 80 dan 443.

## Batas pemeriksaan

Binary HAProxy tidak tersedia pada lingkungan build ini, sehingga `haproxy -c` belum dijalankan di sini. Installer akan menjalankan validasi `haproxy -c -f /etc/haproxy/haproxy.cfg` pada VPS sebelum mengaktifkan konfigurasi final. Checkout sumber tidak memiliki folder `bin/amd64`; installer mengandalkan Release ZIP untuk binary arsitektur tersebut dan keberadaan Release harus dipastikan sebelum instalasi. Belum dilakukan instalasi end-to-end pada VPS target atau tes koneksi dari jaringan eksternal.

Jalankan installer hanya setelah backup/snapshot VPS tersedia dan akses SSH pemulihan tetap dapat digunakan.

# Ayah Alma — SSH, WebSocket, Xray & reverse proxy

Installer Ubuntu/Debian. Routing HTTP/HTTPS dipusatkan pada HAProxy agar tidak ada konflik antara SSH WebSocket, website Nginx, dan Xray.

## Prinsip arsitektur

- HAProxy adalah satu-satunya listener publik untuk TCP **80 dan 443**.
- TLS HTTPS diterminasi di HAProxy; backend WSS menerima koneksi HTTP lokal.
- Nginx hanya melayani website pada `127.0.0.1:8080`.
- Semua inbound Xray hanya bind ke `127.0.0.1`; HAProxy memilih backend berdasarkan path.
- OpenSSH tetap langsung pada TCP **22**.
- Dropbear langsung pada TCP **109 dan 143**. HAProxy tidak mengambil kedua port ini.
- SSH WS: HAProxy `:80 /ssh-ws` → `127.0.0.1:2082` → Dropbear `127.0.0.1:109`.
- SSH WSS: HAProxy `:443 /ssh-wss` → `127.0.0.1:2096` → Dropbear `127.0.0.1:143`.
- Tidak ada lagi SSH SSL-only port 444, stunnel, atau listener raw TLS publik 10011–10013.
- WireGuard dan ZiVPN tetap menggunakan listener UDP tersendiri karena HAProxy HTTP/TCP tidak merutekan UDP.

## Payload SSH yang didukung

Bridge SSH menerima HTTP/1.0 dan HTTP/1.1, GET, GET CGI (`/cdn-cgi/trace`), CONNECT, header `X-Online-Host`, `X-Real-Host`, `Upgrade`, `Connection: Upgrade`, serta beberapa request header berurutan untuk payload multi-bagian `[split]`. Data sesudah header tidak dibuang. Bridge juga menangani framing RFC 6455 ketika klien mengirim `Sec-WebSocket-Key`; payload HTTP Injector tanpa key memakai mode raw tunnel.

## Peta port

Lihat [`PORT-MAP.md`](PORT-MAP.md) untuk daftar backend Xray lengkap, alur request, dan routing sertifikat.

| Publik | Pemilik | Tujuan |
|---|---|---|
| 22/TCP | OpenSSH | Administrasi SSH |
| 80/TCP | HAProxy | HTTP, SSH WS, Xray WS/HTTPUpgrade/gRPC, website fallback |
| 443/TCP | HAProxy | HTTPS/TLS termination, SSH WSS, Xray WS/HTTPUpgrade/gRPC, website fallback |
| 109/TCP | Dropbear | SSH langsung |
| 143/TCP | Dropbear | SSH langsung |
| 51820/UDP | WireGuard | VPN UDP |
| 5667/UDP | ZiVPN | VPN UDP |

## Sertifikat

Let's Encrypt HTTP-01 menggunakan webroot `/var/www/ayah-alma`. Saat bootstrap, HAProxy tetap memegang port 80 dan meneruskan challenge ke Nginx privat. Nginx tidak pernah bind port publik 80/443.

## Sebelum push ke GitHub

1. Periksa URL `faisin/ayah-alma` di `setup.sh` dan `internal/go/go.mod`; ubah jika repository tujuan berbeda.
2. Tinjau `config/license.conf`. Pastikan IP VPS memang diizinkan oleh pemilik repository.
3. Jangan commit private key, token OCI, `.env`, sertifikat runtime, atau database pengguna produksi.
4. Pastikan URL raw GitHub mengarah ke repository Anda.

## Instalasi

Jalankan `setup.sh` sebagai root pada Ubuntu/Debian yang didukung. DNS domain harus mengarah ke VPS dan TCP 80/443 harus dapat dijangkau dari internet. Installer memvalidasi port dan konfigurasi layanan sebelum menyatakan berhasil.

## Validasi lokal sebelum push

```bash
find . -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n
python3 -c 'import json; json.load(open("config/xray.json")); json.load(open("config/udp-custom.json"))'
(cd internal/go && go test ./...)
```

Validasi lokal bukan pengganti `haproxy -c`, `xray -test`, `nginx -t`, dan pengujian koneksi nyata di VPS.

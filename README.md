# Ayah Alma — tunneling & reverse proxy

Installer satu perintah untuk Ubuntu/Debian (amd64 dan arm64). Audit ini memusatkan routing **TCP** pada HAProxy supaya port publik dan layanan tunneling dikelola dari satu konfigurasi.

## Arsitektur reverse proxy

- **HAProxy** adalah pintu masuk publik untuk HTTP/WebSocket, HTTPUpgrade, gRPC, dan TCP passthrough.
- **TCP 80**: route berdasarkan path WebSocket/HTTPUpgrade/gRPC yang didaftarkan; path tidak dikenal mengembalikan HTTP 404.
- **TCP 443**: TLS diakhiri di HAProxy, lalu route berdasarkan path ke backend lokal. Sertifikat dipasang di `/etc/haproxy/certs/ayah-alma.pem`.
- **TCP 109 dan 143**: HAProxy meneruskan koneksi ke Dropbear yang hanya mendengarkan di `127.0.0.1`.
- **TCP 444**: HAProxy meneruskan koneksi SSH SSL-only ke `127.0.0.1:2222`.
- **TCP 10011–10013**: HAProxy meneruskan koneksi ke backend VMess/VLESS/Trojan TLS di loopback.
- **SSH administrasi TCP 22** sengaja tetap langsung ke `sshd` agar akses pemulihan VPS tidak bergantung pada HAProxy.
- **UDP WireGuard 51820 dan ZiVPN 5667** tidak dapat dimasukkan ke router HTTP/TCP HAProxy yang dipakai proyek ini; keduanya tetap menjadi listener UDP tersendiri. Ini batas protokol, bukan jalur yang dilewatkan diam-diam melalui HAProxy.
- Nginx tidak diperlukan untuk tunneling dan dinonaktifkan oleh installer jika ada.

### Diagram

```text
Client TCP 80/443, 109/143, 444, 10011-10013
                    |
                 HAProxy
          +---------+----------+
          |         |          |
       HTTP(S)    TCP SSH    TCP TLS
          |         |          |
       Xray WS/   Dropbear   Xray raw TLS
       Upgrade/   loopback   loopback
       gRPC       :109/:143  :10001-10003

Client UDP 51820 ----------------> WireGuard
Client UDP 5667 -----------------> ZiVPN
Client TCP 22 -------------------> sshd (administrasi)
```

## Port & routing

| Publik | Protokol | Tujuan lokal | Pengelola |
|---|---|---|---|
| 80/TCP | HTTP WS/HTTPUpgrade/gRPC | Xray/SSH WS sesuai path | HAProxy |
| 443/TCP | HTTPS WS/HTTPUpgrade/gRPC | Xray/SSH WS sesuai path | HAProxy |
| 109/TCP | SSH Dropbear | `127.0.0.1:109` | HAProxy TCP |
| 143/TCP | SSH Dropbear | `127.0.0.1:143` | HAProxy TCP |
| 444/TCP | SSH SSL-only | `127.0.0.1:2222` | HAProxy TCP |
| 10011/TCP | VMess TLS | `127.0.0.1:10001` | HAProxy TCP |
| 10012/TCP | VLESS TLS | `127.0.0.1:10002` | HAProxy TCP |
| 10013/TCP | Trojan TLS | `127.0.0.1:10003` | HAProxy TCP |
| 22/TCP | SSH administrasi | sshd | Langsung, untuk pemulihan |
| 51820/UDP | WireGuard | WireGuard | Listener UDP tersendiri |
| 5667/UDP | ZiVPN | ZiVPN | Listener UDP tersendiri |

## Sebelum push ke GitHub

1. Periksa semua URL `faisin/ayah-alma` di `setup.sh` dan `internal/go/go.mod`. Jika repository tujuan berbeda, ubah ke `OWNER/REPO` milik Anda. URL dalam `setup.sh` menentukan dari repository mana source, Release ZIP, dan `config/license.conf` diambil saat instalasi.
2. Tinjau `config/license.conf`. Installer memakai allowlist IP publik; IP VPS baru harus memang diizinkan oleh pemilik repository. Jangan hapus mekanisme lisensi tanpa keputusan pemiliknya.
3. Jangan commit private key, token OCI, file `.env`, sertifikat runtime, atau database pengguna produksi. Secret OCI disimpan di GitHub **Settings → Secrets and variables → Actions**. Workflow memerlukan `OCI_USER_OCID`, `OCI_TENANCY_OCID`, `OCI_REGION`, `OCI_SUBNET_ID`, `OCI_FINGERPRINT`, `OCI_KEY_FILE`, dan `OCI_SSH_PUBLIC_KEY`.
4. Workflow OCI sekarang mencari image Ubuntu 22.04 agar sejalan dengan `setup.sh`; periksa ketersediaan image di region dan tenancy sebelum mengaktifkan jadwal.
5. Jika menggunakan satu baris installer, pastikan URL raw GitHub mengarah ke repository Anda, bukan upstream.

## Instalasi

Setelah URL repository dan allowlist lisensi sudah benar, jalankan `setup.sh` sebagai root di VPS Ubuntu/Debian yang didukung. Domain harus mengarah ke IP VPS dan TCP port 80 harus dapat diakses dari internet saat penerbitan sertifikat Let's Encrypt HTTP-01.

## Validasi lokal sebelum push

```bash
# Bash syntax
find . -type f \( -name '*.sh' -o -name 'menu' -o -name 'm-*' -o -name 'clearcache' \) -print0 | while IFS= read -r -d '' f; do bash -n "$f" || exit 1; done

# JSON / Python / Go
python3 -c 'import json; json.load(open("config/xray.json")); json.load(open("config/udp-custom.json"))'
python3 -c 'compile(open("main.py", encoding="utf-8").read(), "main.py", "exec")'
(cd internal/go && go test ./...)
```

Pemeriksaan statis bukan pengganti uji `haproxy -c`, `xray -test`, dan pengujian koneksi nyata di VPS.

## Audit sebelum push

Workflow **Repository Audit** memeriksa sintaks skrip, JSON, Python, build Go, dan sintaks konfigurasi HAProxy. Lihat [`TESTING.md`](TESTING.md) untuk urutan push yang disarankan dan batas pengujian.

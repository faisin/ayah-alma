AYAH ALMA - PERBAIKAN SERTIFIKAT WILDCARD DNS-01

File dalam paket:
- setup.sh: installer utama, prompt domain diperjelas.
- install/nginx.sh: bootstrap Nginx (tidak lagi digunakan untuk validasi HTTP).
- install/xray.sh: meminta Cloudflare API Token secara tersembunyi, menerbitkan sertifikat DNS-01 untuk domain utama + wildcard, memasang ke /etc/xray/private.key dan /etc/xray/cert.crt, serta menyiapkan reload saat renewal.

PENTING:
1. Masukkan domain utama, contoh adyersasak.my.id, bukan subdomain dan bukan *.domain.
2. Token Cloudflare harus memiliki Zone:DNS:Edit dan Zone:Zone:Read untuk zona domain.
3. Jangan unggah token, /root/.acme.sh/account.conf, sertifikat privat, atau private.key ke GitHub.
4. Uji di VPS baru/staging sebelum mengganti installer produksi.
5. Paket ini hanya mengubah tiga file yang disediakan; file konfigurasi lain seperti config/xray.conf dan config/xray.json tidak disertakan.

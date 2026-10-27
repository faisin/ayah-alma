# Pengujian Ayah Alma langsung di VPS

GitHub dipakai sebagai **penyimpanan kode saja**. Paket ini tidak berisi workflow GitHub Actions; push ke GitHub tidak akan menjalankan audit atau membuat instance cloud.

## Sebelum instalasi

1. Masuk ke VPS Ubuntu/Debian yang memang akan digunakan.
2. Ekstrak source ZIP di VPS, lalu masuk ke direktori `ayah-alma-main`.
3. Jalankan audit statis yang tidak mengubah layanan atau firewall:

```bash
bash tools/vps-audit.sh --static
```

4. Baca semua baris `[GAGAL]` dan `[PERINGATAN]`. Peringatan binary berarti file mungkin diperoleh oleh installer dari Release yang dikonfigurasi; pastikan sumber Release tersebut tersedia dan sesuai arsitektur VPS.
5. Jangan jalankan installer pada server produksi yang menyimpan layanan penting tanpa backup snapshot dan rencana pemulihan. Installer mengubah firewall, paket, sertifikat, service, serta konfigurasi sistem.

## Instalasi

Jalankan perintah installer sesuai README proyek dan hanya setelah audit awal selesai. Pastikan domain A/AAAA mengarah ke VPS, TCP port 80 dapat dijangkau untuk ACME HTTP-01, dan port yang dibutuhkan diizinkan pada firewall VPS **serta** firewall/security list provider cloud. HAProxy menangani listener publik; Nginx hanya menjadi fallback web pada `127.0.0.1:8080` untuk request HTTP/HTTPS yang tidak cocok dengan path tunneling.

## Setelah instalasi

Jalankan:

```bash
sudo bash tools/vps-audit.sh --post-install
```

Mode ini memeriksa konfigurasi HAProxy terpasang, status service yang diharapkan, konfigurasi Xray, dan menampilkan listener port. Skrip ini bersifat diagnostik: tidak mengubah firewall, tidak restart service, dan tidak memperbaiki konfigurasi otomatis.

Untuk menelusuri kegagalan service, gunakan contoh berikut:

```bash
systemctl status haproxy --no-pager -l
journalctl -u haproxy -n 100 --no-pager
nginx -t
systemctl status nginx --no-pager -l
journalctl -u nginx -n 100 --no-pager
systemctl status xray --no-pager -l
journalctl -u xray -n 100 --no-pager
ss -lntup
ss -lnup
```

Uji juga dari perangkat klien: SSH port 22, port TCP tunneling yang memang dikonfigurasi, HTTPS/domain, WireGuard UDP 51820, ZiVPN UDP 5667, dan UDP Custom sesuai konfigurasi. Tes listener lokal saja tidak membuktikan jalur jaringan dari internet berhasil.

## Penyimpanan di GitHub

Paket ZIP ini tidak membawa folder `.github/workflows`. Namun, jika workflow lama masih ada di repository GitHub, mengekstrak ZIP di atas salinan repository **tidak otomatis menghapus** file lama. Untuk benar-benar menghentikan otomatisasi, hapus workflow lama dan push penghapusan itu:

```bash
git rm -r .github/workflows
git add -A
git commit -m "Remove GitHub Actions; test directly on VPS"
git push origin main
```

Jalankan perintah dari clone repository yang benar. Jika menggunakan GitHub web, hapus file workflow di `.github/workflows/` secara manual lalu commit. Setelah itu pastikan folder Actions tidak lagi menampilkan workflow aktif dari file-file tersebut.

GitHub hanya digunakan sebagai penyimpanan source. Jangan commit private key, token, password, file sertifikat, atau konfigurasi runtime berisi kredensial.

## Batas audit saat ini

Audit sintaks lokal dapat dilakukan dari paket ini, tetapi hasil instalasi nyata belum bisa dinyatakan berhasil sampai `--post-install` dan pengujian koneksi klien dijalankan pada VPS target. `menu1.sh` merupakan backup lama dan tidak termasuk pemeriksaan sintaks rutin.

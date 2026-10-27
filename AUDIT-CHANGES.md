# Audit & perubahan Ayah Alma

- HAProxy menjadi pusat listener TCP layanan sesuai konfigurasi proyek; WireGuard dan ZiVPN tetap memakai UDP langsung, sementara SSH administrasi port 22 menjadi jalur pemulihan. Untuk request HTTP/HTTPS yang tidak cocok dengan path tunneling, HAProxy memakai Nginx fallback di 127.0.0.1:8080. Nginx tidak membuka port publik sendiri.
- Password awal UDP Custom dan ZiVPN dibuat acak saat instalasi pertama, dengan salinan root-only dan tidak ditulis ke log instalasi.
- Ditambahkan `tools/vps-audit.sh` untuk pemeriksaan langsung di VPS sebelum dan sesudah instalasi.
- GitHub Actions dikeluarkan dari paket ini karena repository dimaksudkan hanya sebagai penyimpanan source. Workflow audit dan workflow OCI terjadwal tidak akan ikut aktif setelah paket ini di-push.
- `menu1.sh` tetap dipertahankan sebagai backup lama dan tidak diperiksa dalam pemeriksaan sintaks rutin.

Perubahan ini belum membuktikan instalasi end-to-end. Ikuti `TESTING.md`, tinjau output audit di VPS, dan uji koneksi dari klien eksternal sebelum menyatakan semua layanan berjalan.

# Laporan audit Ayah Alma — alur pengujian langsung di VPS

## Tujuan dan alur

Arsitektur web: HAProxy menguasai port publik TCP 80/443 dan merutekan path tunneling yang dikenal ke backend masing-masing. Request web yang tidak cocok diarahkan ke Nginx pada `127.0.0.1:8080`. Nginx tidak bind port publik. Listener TCP lainnya tetap ditangani HAProxy; WireGuard dan ZiVPN tetap memakai UDP langsung.

GitHub hanya menjadi tempat penyimpanan source. Semua pengujian dilakukan di VPS target. Seluruh file workflow GitHub Actions telah dikeluarkan dari paket ini. Agar workflow yang sudah ada di remote benar-benar berhenti, penghapusan `.github/workflows/` juga harus di-commit dan di-push; mengekstrak ZIP saja tidak menghapus file remote.

Alur yang benar:

1. Ekstrak source pada VPS target.
2. Jalankan `bash tools/vps-audit.sh --static`.
3. Tinjau kegagalan/peringatan dan perbaiki sebelum instalasi.
4. Jalankan installer sesuai README proyek pada VPS yang sudah dicadangkan.
5. Jalankan `sudo bash tools/vps-audit.sh --post-install`.
6. Periksa log untuk service yang gagal dan lakukan pengujian koneksi dari klien eksternal.
7. Simpan source dan catatan hasil uji di GitHub setelah tes VPS.

## Pemeriksaan yang sudah dijalankan pada paket di lingkungan audit

- 51 file berekstensi `.sh` selain `menu1.sh` lolos `bash -n`.
- 4 file Python lolos parsing AST.
- 2 file JSON di `config/` valid.
- `go test ./...` pada `internal/go` berhasil; kedua paket melaporkan tidak ada test case.
- `menu1.sh` masih memiliki kesalahan sintaks lama (EOF saat mencari tanda kurung tutup) dan sengaja dipertahankan sebagai backup, bukan skrip aktif.

## Perbaikan untuk alur VPS

- Menghapus `.github/workflows/audit.yml` agar push tidak menjalankan tes di GitHub.
- Menghapus `.github/workflows/main.yml` agar workflow `Oracle Auto Retry` yang dijadwalkan setiap 15 menit tidak berjalan dari repository ini.
- Menambahkan `tools/vps-audit.sh` untuk pemeriksaan statis dan diagnostik pasca-instalasi langsung di VPS. Skrip ini tidak mengubah firewall atau me-restart service.
- Memasang Nginx sebagai fallback web loopback di `127.0.0.1:8080`, menambahkan backend default di HAProxy untuk request yang tidak cocok dengan rute tunneling, serta menambahkan health check `/__health`.
- Menambahkan pemeriksaan file Nginx fallback sebagai file wajib pada preflight installer.
- Mengganti instruksi `TESTING.md` agar alur berpusat pada VPS, bukan GitHub Actions.

## Belum boleh dianggap lulus

- HAProxy belum dapat divalidasi di lingkungan audit ini karena binary HAProxy tidak tersedia. Skrip audit VPS akan memvalidasi konfigurasi jika HAProxy terpasang. Template Nginx juga belum dapat diuji dengan `nginx -t` pada lingkungan audit ini; installer dan mode pasca-instalasi akan menjalankannya pada VPS.
- Belum ada instalasi end-to-end pada VPS target.
- DNS, penerbitan sertifikat ACME, firewall provider, koneksi klien, IPv6, WireGuard, ZiVPN, UDP Custom, serta alur upgrade belum diuji dari jaringan nyata.
- `go test` hanya menunjukkan paket dapat diuji/build; output menunjukkan tidak ada test case.
- `menu1.sh` sengaja tidak diperbaiki karena file cadangan lama; jangan menjalankannya sebagai entrypoint.

## Catatan sumber binary

Source checkout ini menyertakan binary ARM64 untuk sebagian layanan, sementara installer juga mengandalkan Release/runtime sesuai arsitektur. Sebelum instalasi, jalankan audit dan pastikan installer memperoleh seluruh binary wajib dari sumber Release yang dikonfigurasi. Jangan menganggap paket siap untuk semua arsitektur hanya karena pemeriksaan sintaks lolos.

## Risiko operasional

Installer utama mengubah firewall, paket, sertifikat, konfigurasi HAProxy/Xray/WireGuard, dan unit systemd. Jalankan hanya pada OS/arsitektur yang didukung, dengan snapshot/backup dan akses console atau jalur SSH pemulihan. Firewall di panel provider harus disetel terpisah dari firewall di dalam VPS.

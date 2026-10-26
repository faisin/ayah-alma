AYAH ALMA - METODE SERTIFIKAT HTTP-01 STANDALONE

Metode sertifikat:
- install/xray.sh menerbitkan sertifikat Let's Encrypt untuk domain layanan yang dipilih.
- Validasi menggunakan HTTP-01 Standalone pada TCP port 80.
- Nginx dihentikan sementara saat validasi, lalu dijalankan kembali.
- Sertifikat dipasang ke /etc/xray/cert.crt dan kunci privat ke /etc/xray/private.key.
- Metode ini menerbitkan sertifikat untuk satu domain yang dimasukkan, bukan wildcard.

Persyaratan:
1. DNS A domain harus mengarah ke IP publik VPS.
2. TCP port 80 harus dapat diakses dari internet selama validasi.
3. Pastikan tidak ada layanan lain yang menggunakan TCP port 80 ketika penerbitan berlangsung.
4. Jangan mengunggah kunci privat atau kredensial ACME ke GitHub.

File dokumentasi tidak menjadi syarat wajib untuk menjalankan installer.

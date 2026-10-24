# UDP dan game online — AYAH ALMA

## Xray (VMess / VLESS / Trojan)

Xray menggunakan outbound `freedom`, yang dapat meneruskan trafik UDP. UDP untuk game berjalan **di dalam koneksi proxy Xray**; tidak perlu membuka port UDP publik baru untuk setiap akun Xray. Agar game mengirim trafiknya ke Xray, aplikasi klien harus mendukung UDP dan menjalankan mode VPN/TUN (atau mode transparan yang setara). Mode proxy HTTP/SOCKS biasa tidak otomatis menangkap semua trafik game.

- Aktifkan UDP pada klien Xray jika tersedia.
- Gunakan mode VPN/TUN dan izinkan aplikasi game melewati VPN.
- VMess/VLESS/Trojan WS atau gRPC tetap memakai transport TCP; UDP game dibungkus di koneksi tersebut. Ini kompatibel untuk banyak aplikasi, tetapi bukan UDP native end-to-end dan bisa menambah latensi.
- Hasil akhir bergantung pada klien, jaringan/operator, firewall, dan game. Tidak menjamin semua game atau NAT traversal akan berfungsi.

## ZiVPN / UDP gateway

Installer membuka UDP port `5667` untuk ZiVPN. Rentang UDP `6000:19999` diarahkan ke gateway oleh `install/zivpn.sh`. Fitur ini terpisah dari UDP yang dibawa melalui koneksi Xray. Pastikan juga aturan firewall/security-list dari penyedia VPS mengizinkan port tersebut bila ZiVPN digunakan.

## Penting

Jangan menambahkan inbound Xray UDP mentah tanpa rancangan autentikasi dan klien yang cocok. VMess/VLESS/Trojan bukan server game UDP publik; fitur ini mem-proxy trafik UDP dari klien yang mendukungnya.

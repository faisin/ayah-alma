#!/bin/bash
# Tambah akun WireGuard - by Ayah Alma (Optimized)

# 1. Validasi keberadaan file config utama
[[ -f /etc/wireguard/wg0.conf ]] || {
    echo "Error: WireGuard is not installed or wg0.conf is missing!"
    exit 1
}

# 2. Input dan validasi nama user
read -p "Masukkan nama user: " user

[[ "$user" =~ ^[a-zA-Z0-9_-]+$ ]] || {
    echo "Error: Invalid username! Gunakan huruf, angka, underscore, atau strip."
    exit 1
}

# Cek apakah user sudah ada di file config
grep -q "^# $user$" /etc/wireguard/wg0.conf && {
    echo "Error: User '$user' already exists!"
    exit 1
}

# 3. Generate Kunci Kriptografi WireGuard
priv_key=$(wg genkey)
pub_key=$(echo "$priv_key" | wg pubkey)
psk=$(wg genpsk)

# 4. Deteksi IP klien terakhir secara aman
last_ip=$(grep -oE "10\.66\.66\.[0-9]+" /etc/wireguard/wg0.conf 2>/dev/null | tail -n1 | cut -d'.' -f4)

if [[ -z "$last_ip" ]]; then
    next_ip=2
else
    next_ip=$((last_ip + 1))
fi

if (( next_ip > 254 )); then
    echo "Error: IP pool exhausted! (Maksimal 254 klien)"
    exit 1
fi

client_ip="10.66.66.${next_ip}/32"

# 5. Buat direktori penyimpanan klien jika belum ada
mkdir -p /etc/wireguard/clients
client_config="/etc/wireguard/clients/$user.conf"

# 6. Ambil info Endpoint Server (Prioritas Domain, fallback IP publik)
if [ -f /etc/xray/domain ]; then
    server_ip=$(cat /etc/xray/domain)
elif [ -f /root/domain ]; then
    server_ip=$(cat /root/domain)
else
    server_ip=$(curl -s --max-time 5 ifconfig.me)
fi

[[ -z "$server_ip" ]] && {
    echo "Error: Failed to get server IP/Domain!"
    exit 1
}

server_port=$(grep -i "ListenPort" /etc/wireguard/wg0.conf | awk '{print $3}' | head -n1)
[[ -z "$server_port" ]] && server_port=51820

server_pubkey=$(wg show wg0 public-key 2>/dev/null)
if [[ -z "$server_pubkey" ]]; then
    # Fallback ambil pubkey dari file atau config jika interface belum up
    server_pubkey=$(grep -oP 'PrivateKey = \K.*' /etc/wireguard/wg0.conf | xargs -I {} wg pubkey <<< "{}")
fi

# 7. Tambahkan konfigurasi Peer baru ke server wg0.conf secara bersih
echo "" >> /etc/wireguard/wg0.conf
echo "# $user" >> /etc/wireguard/wg0.conf
echo "[Peer]" >> /etc/wireguard/wg0.conf
echo "PublicKey = $pub_key" >> /etc/wireguard/wg0.conf
echo "PresharedKey = $psk" >> /etc/wireguard/wg0.conf
echo "AllowedIPs = $client_ip" >> /etc/wireguard/wg0.conf

# 8. Buat file konfigurasi sisi klien (.conf)
cat > "$client_config" <<EOF
[Interface]
PrivateKey = $priv_key
Address = $client_ip
DNS = 1.1.1.1

[Peer]
PublicKey = $server_pubkey
PresharedKey = $psk
Endpoint = $server_ip:$server_port
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

# 9. Buat QR Code untuk klien
if command -v qrencode &> /dev/null; then
    qrencode -o "/etc/wireguard/clients/${user}.png" < "$client_config"
fi

# 10. Sinkronisasi service WireGuard secara dinamis tanpa menjatuhkan interface utama
if systemctl is-active --quiet wg-quick@wg0; then
    # Jika service aktif, gunakan wg syncconf agar aman tanpa restart total
    wg syncconf wg0 <(wg-quick strip wg0 2>/dev/null) || systemctl restart wg-quick@wg0
else
    # Jika mati, coba jalankan ulang service-nya
    systemctl restart wg-quick@wg0
fi

sleep 1

# 11. Verifikasi akhir status service WireGuard
if ! systemctl is-active --quiet wg-quick@wg0; then
    echo "Error: WireGuard failed to restart properly! Cek konfigurasi PostUp/PostDown interface eth0."
    exit 1
}

# 12. Tampilkan informasi hasil ke layar
echo -e "\n✅ Akun WireGuard '$user' berhasil dibuat!"
echo -e "📄 Detail Konfigurasi Klien:\n"
cat "$client_config"

if command -v qrencode &> /dev/null; then
    echo -e "\n📷 QR Code (Scan melalui aplikasi WireGuard):"
    qrencode -t ansiutf8 < "$client_config"
fi

echo ""
read -n 1 -s -r -p "Tekan tombol apa saja untuk kembali ke menu utama..."

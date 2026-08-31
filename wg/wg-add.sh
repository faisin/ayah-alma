#!/bin/bash
# Tambah akun WireGuard - by Ayah Alma

[[ -f /etc/wireguard/wg0.conf ]] || {
    echo "WireGuard is not installed!"
    exit 1
}

read -p "Masukkan nama user: " user

[[ "$user" =~ ^[a-zA-Z0-9_-]+$ ]] || {
    echo "Invalid username!"
    exit 1
}

grep -q "^# $user$" /etc/wireguard/wg0.conf && {
    echo "User already exists!"
    exit 1
}

priv_key=$(wg genkey)
pub_key=$(echo "$priv_key" | wg pubkey)
psk=$(wg genpsk)

last_ip=$(grep "^AllowedIPs = 10\.66\.66\." /etc/wireguard/wg0.conf \
    | tail -n1 \
    | awk '{print $3}' \
    | cut -d'.' -f4 \
    | cut -d'/' -f1)

if [[ -z "$last_ip" ]]; then
    last_ip=1
fi

next_ip=$((last_ip + 1))

if (( next_ip > 254 )); then
    echo "IP pool exhausted!"
    exit 1
fi

client_ip="10.66.66.${next_ip}/32"

# Buat folder klien
mkdir -p /etc/wireguard/clients
client_config="/etc/wireguard/clients/$user.conf"

# Ambil info server (Prioritas Domain/IP lokal, fallback ke ifconfig.me)
if [ -f /etc/xray/domain ]; then
    server_ip=$(cat /etc/xray/domain)
elif [ -f /root/domain ]; then
    server_ip=$(cat /root/domain)
else
    server_ip=$(curl -s --max-time 5 ifconfig.me)
fi

[[ -z "$server_ip" ]] && {
    echo "Failed to get server IP/Domain!"
    exit 1
}

server_port=$(grep ListenPort /etc/wireguard/wg0.conf | awk '{print $3}')
server_pubkey=$(wg show wg0 public-key)

# Tambah ke config server
echo -e "\n# $user\n[Peer]\nPublicKey = $pub_key\nPresharedKey = $psk\nAllowedIPs = $client_ip" >> /etc/wireguard/wg0.conf

# Buat config klien
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

qrencode -o "/etc/wireguard/clients/${user}.png" < "$client_config"

wg-quick strip wg0 >/dev/null 2>&1 || {
    echo "Invalid WireGuard configuration!"
    exit 1
}

# Apply config
systemctl restart wg-quick@wg0

sleep 2

systemctl is-active --quiet wg-quick@wg0 || {
    echo "WireGuard failed to restart!"
    exit 1
}

# Tampilkan config + QR
echo -e "\n✅ Akun WireGuard '$user' berhasil dibuat!"
echo -e "📄 Config:\n"
cat "$client_config"

echo -e "\n📷 QR Code (scan via WireGuard app):"
qrencode -t ansiutf8 < "$client_config"

echo ""
read -n 1 -s -r -p "Tekan apa saja untuk kembali ke menu utama..."
menu

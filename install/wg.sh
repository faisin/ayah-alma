#!/bin/bash
# Install WireGuard + konfigurasi awal
# By Ayah-Alma
# Converted for Ayah-Alma Project (Kernel Module Fixed)

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

clear

echo -e "${GREEN}▶️ Memulai instalasi WireGuard...${NC}"
sleep 1

# Install dependensi, resolvconf, dan pastikan modul kernel wireguard tersedia
apt update -y
DEBIAN_FRONTEND=noninteractive apt install -y \
    wireguard \
    wireguard-tools \
    qrencode \
    iptables \
    resolvconf

# Coba muat modul bila modular, lalu uji dukungan kernel sebenarnya.
# WireGuard yang dikompilasi built-in tidak muncul di output lsmod.
modprobe wireguard >/dev/null 2>&1 || true
if ! ip link add dev wg-aayah-test type wireguard >/dev/null 2>&1; then
    echo -e "${RED}[ERROR] Kernel VPS ini tidak mendukung interface WireGuard.${NC}"
    exit 1
fi
ip link delete dev wg-aayah-test >/dev/null 2>&1 || true

# Buat direktori config
mkdir -p /etc/wireguard
cd /etc/wireguard || exit

# Jangan menghapus identitas atau konfigurasi WireGuard yang sudah ada saat
# installer dijalankan ulang. Buat konfigurasi awal hanya pada instalasi baru.
if [[ ! -s wg0.conf ]]; then
    # Ambil interface default (eth0/fallback)
    interface=$(ip -4 route show default | awk 'NR == 1 {print $5}')
    if [[ -z "$interface" ]]; then
        echo -e "${RED}[ERROR] Failed to detect network interface!${NC}"
        exit 1
    fi

    privkey=$(wg genkey)
    pubkey=$(printf '%s' "$privkey" | wg pubkey)
    printf '%s\n' "$privkey" > private.key
    printf '%s\n' "$pubkey" > public.key
    chmod 600 private.key
    chmod 644 public.key

    cat > wg0.conf <<EOF
[Interface]
Address = 10.66.66.1/24
ListenPort = 51820
PrivateKey = $privkey
DNS = 1.1.1.1, 8.8.8.8
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $interface -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $interface -j MASQUERADE
SaveConfig = true
EOF
    chmod 600 wg0.conf
else
    echo -e "${GREEN}[INFO] Konfigurasi WireGuard yang ada dipertahankan.${NC}"
    chmod 600 wg0.conf
fi

# Aktifkan IP forwarding
cat > /etc/sysctl.d/30-wg.conf <<EOF
net.ipv4.ip_forward=1
EOF

sysctl --system >/dev/null 2>&1

# === TESTING CONFIG
wg-quick strip wg0 >/dev/null 2>&1 || {
    echo -e "${RED}[ERROR] Invalid WireGuard configuration!${NC}"
    exit 1
}

# Hentikan dulu jika service sempat tersangkut
systemctl stop wg-quick@wg0 >/dev/null 2>&1

# Enable dan start service
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0

sleep 2

if ! systemctl is-active --quiet wg-quick@wg0; then
    echo -e "${RED}[ERROR] WireGuard failed to start!${NC}"
    journalctl -u wg-quick@wg0 -n 20 --no-pager
    exit 1
fi

# Tambahkan ke /root/log-install.txt
touch /root/log-install.txt
grep -q "WireGuard" /root/log-install.txt || \
echo "WireGuard (Ayah-Alma) : 51820" >> /root/log-install.txt

echo -e "${GREEN}✅ WireGuard berhasil di-install & aktif di port 51820!${NC}"

#!/bin/bash
# Hapus akun SS WS - by znand-dev

# Warna
YELLOW='\e[1;33m'
CYAN='\e[1;36m'
GREEN='\e[1;32m'
RED='\e[1;31m'
NC='\e[0m'

clear
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}         🗑️ HAPUS AKUN SHADOWSOCKS WS         ${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

read -rp "Masukkan username yang ingin dihapus: " user

if [[ -z "$user" ]]; then
    echo -e "${RED}❌ Username tidak boleh kosong!${NC}"
    exit 1
fi

config="/etc/xray/config.json"
db_file="/etc/xray/ssws.db"

# Cek apakah user ada di database ssws.db
if ! grep -w "$user" "$db_file" >/dev/null 2>&1; then
    echo -e "${RED}❌ Akun '$user' tidak ditemukan di database!${NC}"
    exit 1
fi

# Validasi config lama
if ! jq empty "$config" >/dev/null 2>&1; then
    echo -e "${RED}❌ config.json invalid!${NC}"
    exit 1
fi

# Backup config
cp "$config" "${config}.bak"

# Temp file
tmpfile=$(mktemp)

# Hapus user dari config menggunakan jq untuk semua tag inbound ssws
if ! jq --arg user "$user" '
(.inbounds[] | select(.tag=="ssws-ws-tls").settings.clients) |= [ .[] | select(.email != $user) ] |
(.inbounds[] | select(.tag=="ssws-ws-nontls").settings.clients) |= [ .[] | select(.email != $user) ] |
(.inbounds[] | select(.tag=="ssws-grpc").settings.clients) |= [ .[] | select(.email != $user) ]
' "$config" > "$tmpfile"; then
    echo -e "${RED}❌ Gagal memproses konfigurasi!${NC}"
    rm -f "$tmpfile"
    exit 1
fi

# Validasi JSON hasil temporary
if ! jq empty "$tmpfile" >/dev/null 2>&1; then
    echo -e "${RED}❌ Hasil generate JSON tidak valid!${NC}"
    rm -f "$tmpfile"
    exit 1
fi

# Replace config
mv "$tmpfile" "$config"

# Test config xray
if ! xray -test -config "$config" >/dev/null 2>&1; then
    echo -e "${RED}❌ Uji konfigurasi Xray gagal! Memulihkan konfigurasi...${NC}"
    cp "${config}.bak" "$config"
    exit 1
fi

# Restart xray
systemctl restart xray

# Hapus baris dari database ssws.db
sed -i "/^${user} /d" "$db_file"

echo -e "${GREEN}✅ Akun '$user' berhasil dihapus dari Shadowsocks WS!${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
read -n 1 -s -r -p "Tekan tombol apa saja untuk kembali ke menu..."
menu


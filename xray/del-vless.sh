#!/bin/bash
# Hapus Akun VLESS - by Ayah Alma

clear

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

CONFIG="/etc/xray/config.json"
DB="/etc/xray/vless.db"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\E[44;1;39m            DELETE VLESS ACCOUNT             \E[0m"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [[ ! -f $DB ]]; then
    echo -e "${RED}❌ Database user VLESS tidak ditemukan!${NC}"
    exit 1
fi

if [[ ! -s $DB ]]; then
    echo -e "${RED}Tidak ada user VLESS terdaftar!${NC}"
    echo ""
    read -n 1 -s -r -p "Tekan apa saja untuk kembali ke menu..."
    menu
    exit
fi

echo -e "${CYAN}📋 List User VLESS:${NC}"
echo ""

num=1
while read -r line; do
    user=$(echo "$line" | awk '{print $1}')
    if [[ -n "$user" ]]; then
        printf "${GREEN}[%s]${NC} %s\n" "$num" "$user"
        ((num++))
    fi
done < "$DB"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
read -rp "👉 Masukkan username yang ingin dihapus: " user
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [[ -z "$user" ]]; then
    echo -e "${RED}❌ Username tidak boleh kosong!${NC}"
    exit 1
fi

if ! grep -w "$user" "$DB" >/dev/null 2>&1; then
    echo -e "${RED}❌ Akun '${user}' tidak ditemukan di database!${NC}"
    exit 1
fi

if ! jq empty "$CONFIG" >/dev/null 2>&1; then
    echo -e "${RED}❌ config.json invalid!${NC}"
    exit 1
fi

cp "$CONFIG" "${CONFIG}.bak"
tmpfile=$(mktemp)

# Membersihkan user dari semua tag inbound VLESS yang sesuai dengan config.json
if ! jq --arg user "$user" '
(.inbounds[] | select(.tag=="vless-ws-tls").settings.clients) |= [ .[] | select(.email != $user) ] |
(.inbounds[] | select(.tag=="vless-ws-nontls").settings.clients) |= [ .[] | select(.email != $user) ] |
(.inbounds[] | select(.tag=="vless-grpc").settings.clients) |= [ .[] | select(.email != $user) ]
' "$CONFIG" > "$tmpfile"; then
    echo -e "${RED}❌ Gagal memproses konfigurasi!${NC}"
    rm -f "$tmpfile"
    exit 1
fi

if ! jq empty "$tmpfile" >/dev/null 2>&1; then
    echo -e "${RED}❌ Hasil generate JSON tidak valid!${NC}"
    rm -f "$tmpfile"
    exit 1
fi

mv "$tmpfile" "$CONFIG"

if ! xray -test -config "$CONFIG" >/dev/null 2>&1; then
    echo -e "${RED}❌ Uji konfigurasi Xray gagal! Memulihkan konfigurasi...${NC}"
    cp "${CONFIG}.bak" "$CONFIG"
    exit 1
fi

systemctl restart xray

if ! systemctl is-active --quiet xray; then
    echo -e "${RED}❌ Xray gagal berjalan! Memulihkan konfigurasi...${NC}"
    cp "${CONFIG}.bak" "$CONFIG"
    systemctl restart xray
    exit 1
fi

# Hapus baris dari database vless.db
sed -i "/^${user} /d" "$DB"

echo ""
echo -e "${GREEN}✅ User VLESS '${user}' berhasil dihapus!${NC}"
echo ""

read -n 1 -s -r -p "Tekan apa saja untuk kembali ke menu..."

menu

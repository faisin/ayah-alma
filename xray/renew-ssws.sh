#!/bin/bash
# Perpanjang Akun Shadowsocks WS - by Ayah Alma

clear

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

DB="/etc/xray/ssws.db"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\E[44;1;39m         RENEW SHADOWSOCKS WS ACCOUNT        \E[0m"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [[ ! -f $DB ]]; then
    echo -e "${RED}❌ Database user Shadowsocks WS tidak ditemukan!${NC}"
    exit 1
fi

if [[ ! -s $DB ]]; then
    echo -e "${RED}Tidak ada user Shadowsocks WS terdaftar!${NC}"
    echo ""
    read -n 1 -s -r -p "Tekan apa saja untuk kembali ke menu..."
    menu
    exit
fi

echo -e "${CYAN}📋 List User Shadowsocks WS:${NC}"
echo ""

num=1
while read -r line; do
    user=$(echo "$line" | awk '{print $1}')
    exp=$(echo "$line" | awk '{print $2}')
    if [[ -n "$user" ]]; then
        printf "${GREEN}[%s]${NC} %s (Exp: %s)\n" "$num" "$user" "$exp"
        ((num++))
    fi
done < "$DB"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
read -rp "👉 Masukkan username yang ingin diperpanjang: " user

if [[ -z "$user" ]]; then
    echo -e "${RED}❌ Username tidak boleh kosong!${NC}"
    exit 1
fi

if ! grep -w "$user" "$DB" >/dev/null 2>&1; then
    echo -e "${RED}❌ Akun '${user}' tidak ditemukan di database!${NC}"
    exit 1
fi

read -rp "👉 Tambah masa aktif (hari): " tambah

if ! [[ "$tambah" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}❌ Masukkan angka hari yang valid!${NC}"
    exit 1
fi

current_exp=$(grep -w "$user" "$DB" | awk '{print $2}')
current_ts=$(date -d "$current_exp" +%s)
today_ts=$(date +%s)

if [ $current_ts -ge $today_ts ]; then
    new_exp_ts=$((current_ts + (tambah * 86400)))
else
    new_exp_ts=$((today_ts + (tambah * 86400)))
fi

new_exp=$(date -d "@$new_exp_ts" +"%Y-%m-%d")
shadowsocks_pass=$(grep -w "$user" "$DB" | awk '{print $3}')

# Perbarui database
sed -i "/^${user} /c\\${user} ${new_exp} ${shadowsocks_pass}" "$DB"

echo ""
echo -e "${GREEN}✅ Masa aktif akun '${user}' berhasil diperpanjang hingga ${new_exp}!${NC}"
echo ""

read -n 1 -s -r -p "Tekan apa saja untuk kembali ke menu..."
menu

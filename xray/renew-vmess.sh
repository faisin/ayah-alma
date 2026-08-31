#!/bin/bash
# Perpanjang Akun VMess - by Ayah Alma

clear

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

DB="/etc/xray/vmess.db"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\E[44;1;39m            PERPANJANG AKUN VMESS            \E[0m"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [[ ! -f $DB ]]; then
    echo -e "${RED}❌ Database user VMess tidak ditemukan!${NC}"
    exit 1
fi

if [[ ! -s $DB ]]; then
    echo -e "${RED}Tidak ada user VMess terdaftar!${NC}"
    echo ""
    read -n 1 -s -r -p "Tekan apa saja untuk kembali ke menu..."
    menu
    exit
fi

echo -e "${CYAN}📋 Daftar User VMess:${NC}"
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
read -rp "Masukkan username yang ingin diperpanjang: " user

if [[ -z "$user" ]]; then
    echo -e "${RED}❌ Username tidak boleh kosong!${NC}"
    exit 1
fi

if ! grep -w "$user" "$DB" >/dev/null 2>&1; then
    echo -e "${RED}❌ Akun '${user}' tidak ditemukan di database!${NC}"
    exit 1
fi

read -rp "Tambahkan masa aktif (hari): " masaaktif

if ! [[ "$masaaktif" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}❌ Masukkan angka hari yang valid!${NC}"
    exit 1
fi

current_exp=$(grep -w "$user" "$DB" | awk '{print $2}')
current_ts=$(date -d "$current_exp" +%s)
today_ts=$(date +%s)

if [ $current_ts -ge $today_ts ]; then
    new_exp_ts=$((current_ts + (masaaktif * 86400)))
else
    new_exp_ts=$((today_ts + (masaaktif * 86400)))
fi

exp=$(date -d "@$new_exp_ts" +"%Y-%m-%d")
vmess_uuid=$(grep -w "$user" "$DB" | awk '{print $3}')

# Perbarui database
sed -i "/^${user} /c\\${user} ${exp} ${vmess_uuid}" "$DB"

clear
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\E[44;1;39m            AKUN BERHASIL DIPERPANJANG       \E[0m"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "User      : ${GREEN}$user${NC}"
echo -e "Expired   : ${GREEN}$exp${NC}"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

read -n 1 -s -r -p "Tekan apa saja untuk kembali ke menu..."

menu

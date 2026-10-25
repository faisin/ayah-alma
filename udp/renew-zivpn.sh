#!/bin/bash
set -Eeuo pipefail

DB="/etc/zivpn/users.db"
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[1;36m'
NC='\033[0m'

clear
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}       RENEW ZIVPN USER${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [[ ! -s "$DB" ]]; then
    echo -e "${RED}Tidak ada pengguna ZiVPN.${NC}"
    read -r -n 1 -s -p "Tekan tombol apa saja untuk kembali..."
    exec /usr/bin/m-zivpn
fi

printf '%-20s %-15s %-12s\n' "USERNAME" "EXPIRED" "LIMIT DEVICE"
awk 'NF { printf "%-20s %-15s %-12s\n", $1, ($2=="" ? "-" : $2), ($3=="" ? "default" : $3) }' "$DB"
echo
read -r -p "Username yang diperpanjang: " user
[[ "$user" =~ ^[a-zA-Z0-9_.-]+$ ]] || { echo -e "${RED}Username tidak valid.${NC}"; exit 1; }

if ! awk -v u="$user" '$1==u {found=1} END {exit !found}' "$DB"; then
    echo -e "${RED}Pengguna tidak ditemukan.${NC}"
    read -r -n 1 -s -p "Tekan tombol apa saja untuk kembali..."
    exec /usr/bin/m-zivpn
fi

read -r -p "Tambah masa aktif (hari): " days
[[ "$days" =~ ^[0-9]+$ ]] && (( days > 0 )) || { echo -e "${RED}Jumlah hari harus angka lebih dari 0.${NC}"; exit 1; }

current_exp="$(awk -v u="$user" '$1==u {print $2; exit}' "$DB")"
today="$(date +%F)"
if [[ "$current_exp" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && [[ "$current_exp" > "$today" ]]; then
    base_date="$current_exp"
else
    base_date="$today"
fi
new_exp="$(date -d "$base_date + $days days" +%F)"

tmp="$(mktemp)"
awk -v u="$user" -v exp="$new_exp" 'BEGIN{OFS=" "} $1==u {$2=exp; found=1} {print} END{if(!found) exit 1}' "$DB" > "$tmp"
install -m 600 "$tmp" "$DB"
rm -f "$tmp"

if [[ -x /etc/ayah-alma/udp/rebuild-config.sh ]]; then
    /etc/ayah-alma/udp/rebuild-config.sh
fi

echo -e "${GREEN}Pengguna $user diperpanjang sampai $new_exp.${NC}"
read -r -n 1 -s -p "Tekan tombol apa saja untuk kembali..."
exec /usr/bin/m-zivpn

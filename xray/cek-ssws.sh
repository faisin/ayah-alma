#!/bin/bash
# Cek login SS WS - by znand-dev

# Warna
YELLOW='\e[1;33m'
CYAN='\e[1;36m'
GREEN='\e[1;32m'
RED='\e[1;31m'
NC='\e[0m'

clear
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}         🔍 CEK LOGIN SHADOWSOCKS WS          ${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

log_file="/var/log/xray/access.log"
db_file="/etc/xray/ssws.db"

if [[ ! -f $log_file ]]; then
    echo -e "${RED}❌ Log file tidak ditemukan!${NC}"
    exit 1
fi

if [[ ! -f $db_file ]]; then
    echo -e "${RED}❌ Database user SS WS tidak ditemukan!${NC}"
    exit 1
fi

echo -e " Username         | Status / IP Terhubung"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

while read -r line; do
    user=$(echo "$line" | awk '{print $1}')
    if [[ -n "$user" ]]; then
        # Cek apakah user tercatat aktif di log xray
        is_active=$(grep -w "$user" "$log_file" | tail -n 1)
        if [[ -n "$is_active" ]]; then
            ip_client=$(grep -w "$user" "$log_file" | tail -n 1 | awk '{print $6}' | cut -d: -f1)
            echo -e " ${GREEN}$user${NC}        | Terhubung (IP: ${ip_client})"
        else
            echo -e " ${RED}$user${NC}        | Tidak Aktif / Offline"
        fi
    fi
done < "$db_file"

echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
read -n 1 -s -r -p "Tekan tombol apa saja untuk kembali ke menu..."
menu


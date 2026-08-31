#!/bin/bash
# Cek login Trojan - by znand-dev

clear

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

LOG="/var/log/xray/access.log"
CONFIG="/etc/xray/config.json"
DB="/etc/xray/trojan.db"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\E[44;1;39m            CEK LOGIN TROJAN USER            \E[0m"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [[ ! -f $LOG ]]; then
    echo -e "${RED}❌ Log file tidak ditemukan!${NC}"
    exit 1
fi

if [[ ! -f $DB ]]; then
    echo -e "${RED}❌ Database user Trojan tidak ditemukan!${NC}"
    exit 1
fi

printf "%-15s %-18s\n" "USERNAME" "IP CLIENT / STATUS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

while read -r line; do
    user=$(echo "$line" | awk '{print $1}')
    if [[ -n "$user" ]]; then
        # Cek apakah user aktif di log berdasarkan email/username
        is_active=$(grep -w "$user" "$LOG" | tail -n 1)
        if [[ -n "$is_active" ]]; then
            ip_client=$(grep -w "$user" "$LOG" | tail -n 1 | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n 1)
            [[ -z "$ip_client" ]] && ip_client="Tersambung"
            printf "${GREEN}%-15s${NC} %-18s\n" "$user" "$ip_client"
        else
            printf "${RED}%-15s${NC} %-18s\n" "$user" "Offline / Tidak Aktif"
        fi
    fi
done < "$DB"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

read -n 1 -s -r -p "Tekan apa saja untuk kembali ke menu..."

menu


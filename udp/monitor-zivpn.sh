#!/bin/bash
# ==========================================
# MONITOR ONLINE ZIVPN USER - by Ayah Alma
# ==========================================

clear

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m'

LOG_FILE="/tmp/zivpn-monitor.log"

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}     ONLINE ZIVPN USER${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo ""

# ==============================
# CHECK SERVICE
# ==============================

if ! systemctl is-active --quiet zivpn; then
    echo -e "${RED}ZIVPN service is not running!${NC}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    read -n 1 -s -r -p "Press any key to back menu..."
    m-zivpn
fi

# ==============================
# GET CONNECTION
# ==============================

ss -unap 2>/dev/null | grep "zivpn" | \
awk '{print $5}' | \
cut -d':' -f1 | \
sort -u > $LOG_FILE

TOTAL=$(cat $LOG_FILE | wc -l)

# ==============================
# NO CONNECTION
# ==============================

if [[ $TOTAL -eq 0 ]]; then
    echo -e "${RED}No online ZIVPN users!${NC}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    rm -f $LOG_FILE
    echo ""
    read -n 1 -s -r -p "Press any key to back menu..."
    m-zivpn
fi

# ==============================
# HEADER
# ==============================

printf "${WHITE} %-4s %-25s${NC}\n" \
"NO" "IP ADDRESS"

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# ==============================
# SHOW ONLINE IP
# ==============================

NO=1

while read -r ip; do

    [[ -z "$ip" ]] && continue

    printf " %-4s %-25s\n" \
    "$NO" "$ip"

    ((NO++))

done < $LOG_FILE

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "${WHITE}Total Online${NC} : $TOTAL"

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

rm -f $LOG_FILE

echo ""
read -n 1 -s -r -p "Press any key to back menu..."
m-zivpn

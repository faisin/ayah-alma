#!/bin/bash
# ==========================================
# CHECK ZIVPN USER - by Ayah Alma
# ==========================================

DB="/etc/zivpn/users.db"

clear

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m'

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}        ZIVPN MEMBER${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo ""

# ==============================
# CHECK EMPTY DB
# ==============================

if [[ ! -s $DB ]]; then
    echo -e "${RED}No ZIVPN users found!${NC}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    read -n 1 -s -r -p "Press any key to back menu..."
    m-zivpn
fi

# ==============================
# HEADER
# ==============================

printf "${WHITE} %-4s %-18s %-15s %-10s${NC}\n" \
"NO" "USERNAME" "EXPIRED" "STATUS"

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# ==============================
# READ USER DB
# ==============================

NO=1

while read -r user exp; do

    # Skip empty line
    [[ -z "$user" ]] && continue

    # Expired check
    exp_ts=$(date -d "$exp" +%s 2>/dev/null)
    now_ts=$(date +%s)

    if [[ $now_ts -gt $exp_ts ]]; then
        STATUS="${RED}EXPIRED${NC}"
    else
        STATUS="${GREEN}ACTIVE${NC}"
    fi

    printf " %-4s %-18s %-15s %-10b\n" \
    "$NO" "$user" "$exp" "$STATUS"

    ((NO++))

done < "$DB"

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

TOTAL=$(grep -vc '^$' "$DB")

echo -e "${WHITE}Total Users${NC} : $TOTAL"

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo ""
read -n 1 -s -r -p "Press any key to back menu..."
m-zivpn

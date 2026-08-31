#!/bin/bash
# ==========================================
# DELETE ZIVPN USER - by Ayah Alma
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
echo -e "${GREEN}      DELETE ZIVPN USER${NC}"
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
# SHOW USER LIST
# ==============================

printf "${WHITE} %-4s %-18s %-15s${NC}\n" \
"NO" "USERNAME" "EXPIRED"

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

NO=1

while read -r user exp; do

    [[ -z "$user" ]] && continue

    printf " %-4s %-18s %-15s\n" \
    "$NO" "$user" "$exp"

    ((NO++))

done < "$DB"

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# ==============================
# INPUT USER
# ==============================

echo ""

read -rp "Input Username : " user

# ==============================
# CHECK USER
# ==============================

if ! grep -wq "^$user" $DB; then
    echo ""
    echo -e "${RED}User not found!${NC}"
    echo ""
    read -n 1 -s -r -p "Press any key to back menu..."
    m-zivpn
fi

# ==============================
# DELETE USER
# ==============================

sed -i "/^$user /d" $DB

# ==============================
# REBUILD CONFIG
# ==============================

if [[ -f /etc/ayah-alma/udp/rebuild-config.sh ]]; then
    bash /etc/ayah-alma/udp/rebuild-config.sh
fi

clear

# ==============================
# SUCCESS OUTPUT
# ==============================

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}      DELETE SUCCESS${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo ""
echo -e " ${WHITE}Username${NC} : $user"
echo -e " ${WHITE}Status${NC}   : Deleted Successfully"

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo ""
read -n 1 -s -r -p "Press any key to back menu..."
m-zivpn

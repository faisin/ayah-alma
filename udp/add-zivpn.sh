#!/bin/bash
# ==========================================
# ADD ZIVPN USER - by Ayah Alma
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
echo -e "${GREEN}       ADD ZIVPN USER${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# ==============================
# INPUT USER
# ==============================

read -rp "Username       : " user

# ==============================
# VALIDATION
# ==============================

if [[ -z "$user" ]]; then
    echo -e "${RED}Username cannot be empty!${NC}"
    exit 1
fi

# Check existing user
if grep -wq "^$user" $DB; then
    echo ""
    echo -e "${RED}User already exists!${NC}"
    exit 1
fi

read -rp "Expired (days) : " days

# ==============================
# GENERATE EXP DATE
# ==============================

exp=$(date -d "$days days" +"%Y-%m-%d")

# ==============================
# SAVE USER
# ==============================

echo "$user $exp" >> $DB

# ==============================
# REBUILD CONFIG
# ==============================

if [[ -f /etc/ayah-alma/udp/rebuild-config.sh ]]; then
    bash /etc/ayah-alma/udp/rebuild-config.sh
fi

# ==============================
# GET DOMAIN
# ==============================

DOMAIN=$(cat /etc/xray/domain 2>/dev/null)

if [[ -z "$DOMAIN" ]]; then
    DOMAIN=$(curl -s ipv4.icanhazip.com)
fi

clear

# ==============================
# OUTPUT
# ==============================

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}      ZIVPN ACCOUNT${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

printf " ${WHITE}Username${NC}    : %s\n" "$user"
printf " ${WHITE}Expired On${NC}  : %s\n" "$exp"
printf " ${WHITE}Host/IP${NC}     : %s\n" "$DOMAIN"
printf " ${WHITE}UDP Port${NC}    : 5667\n"
printf " ${WHITE}Password${NC}    : %s\n" "$user"
printf " ${WHITE}Protocol${NC}    : UDP\n"
printf " ${WHITE}OBFS${NC}        : zivpn\n"

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo ""
echo -e "${YELLOW}📱 ZIVPN CLIENT CONFIG${NC}"
echo ""
echo -e " Host      : ${DOMAIN}"
echo -e " Password  : ${user}"
echo -e " UDP Mode  : ON"
echo -e " TLS       : ON"
echo -e " OBFS      : zivpn"

echo ""
read -n 1 -s -r -p "Press any key to back menu..."
m-zivpn


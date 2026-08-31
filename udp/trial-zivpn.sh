#!/bin/bash
# ==========================================
# TRIAL ZIVPN USER - by Ayah Alma
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
echo -e "${GREEN}      TRIAL ZIVPN USER${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# ==============================
# GENERATE USER
# ==============================

USER="trial$(tr -dc a-z0-9 </dev/urandom | head -c4)"

# ==============================
# CHECK DUPLICATE
# ==============================

while grep -qw "^$USER" $DB; do
    USER="trial$(tr -dc a-z0-9 </dev/urandom | head -c4)"
done

# ==============================
# TRIAL EXPIRED
# ==============================

DAYS=1
EXP=$(date -d "$DAYS days" +"%Y-%m-%d")

# ==============================
# SAVE USER
# ==============================

echo "$USER $EXP" >> $DB

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
echo -e "${GREEN}      TRIAL ZIVPN ACCOUNT${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo ""
printf " ${WHITE}Username${NC}    : %s\n" "$USER"
printf " ${WHITE}Password${NC}    : %s\n" "$USER"
printf " ${WHITE}Host/IP${NC}     : %s\n" "$DOMAIN"
printf " ${WHITE}UDP Port${NC}    : 5667\n"
printf " ${WHITE}Protocol${NC}    : UDP\n"
printf " ${WHITE}OBFS${NC}        : zivpn\n"
printf " ${WHITE}Expired On${NC}  : %s\n" "$EXP"

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo ""
echo -e "${YELLOW}📱 ZIVPN CLIENT CONFIG${NC}"
echo ""
echo -e " Host      : ${DOMAIN}"
echo -e " Password  : ${USER}"
echo -e " UDP Mode  : ON"
echo -e " TLS       : ON"
echo -e " OBFS      : zivpn"

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo ""
read -n 1 -s -r -p "Press any key to back menu..."
m-zivpn

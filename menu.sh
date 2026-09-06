#!/bin/bash

# ================= IP VALIDATION =================
CURRENT_IP=$(curl -s ipv4.icanhazip.com)
ALLOWED_IPS="16.78.100.222" # Ganti atau tambahkan IP yang diizinkan di sini

VALID=false
for ip in $ALLOWED_IPS; do
    if [[ "$CURRENT_IP" == "$ip" ]]; then
        VALID=true
        break
    fi
done

if [[ "$VALID" == false ]]; then
    echo -e "\033[1;31m❌ Akses Ditolak! IP Anda ($CURRENT_IP) tidak terdaftar.\033[0m"
    exit 1
fi
# ==========================================

# ... (lanjutan kode panel seperti variabel, banner, dan menu di bawahnya)

# ==========================================
# AYAH-ALMA XRAY PANEL
# ==========================================

PANEL_VERSION="v2.1.1"

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m'

CONFIG="/etc/xray/config.json"
LOG="/var/log/xray/access.log"

# ================= ANIMATION =================

loading() {
local text="$1"

echo -ne "${CYAN}➜ ${text}${NC}"

for i in {1..3}; do
    echo -ne "."
    sleep 0.35
done

echo ""
}

type_text() {
    local delay="${2:-0.02}"

    while IFS= read -r -n1 char; do
        printf "%s" "$char"
        sleep "$delay"
    done

    echo
}

# ================= SYSTEM INFO =================

IP=$(curl -s ipv4.icanhazip.com)
DOMAIN=$(cat /etc/xray/domain 2>/dev/null || echo "N/A")

ISP=$(curl -s --max-time 3 ipinfo.io/org | cut -d " " -f2-)
[[ -z "$ISP" ]] && ISP="Unknown"

UPTIME=$(uptime -p | sed 's/up //')
TIME=$(date "+%d-%m-%Y %H:%M:%S")

OS=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')

CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2+$4"%"}')

RAM=$(free -m | awk 'NR==2{printf "%sMB / %sMB",$3,$2}')

DISK=$(df -h / | awk 'NR==2{print $3 "/" $2}')

# ================= NETWORK =================

IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}')
if [[ -z "$IFACE" ]]; then
    IFACE="eth0"
fi

MONTH_NAME=$(date +"%Y-%m")

if command -v vnstat &>/dev/null; then
    TODAY=$(vnstat -i "$IFACE" 2>/dev/null | awk '/today/ {print $8" "$9}')
    YESTERDAY=$(vnstat -i "$IFACE" 2>/dev/null | awk '/yesterday/ {print $8" "$9}')
    MONTH=$(vnstat -i "$IFACE" 2>/dev/null | awk -v m="$MONTH_NAME" '$1 ~ m {print $8" "$9}')
    TOTAL_BW=$(vnstat --oneline 2>/dev/null | cut -d; -f15)
else
    TODAY="N/A"
    YESTERDAY="N/A"
    MONTH="N/A"
    TOTAL_BW="N/A"
fi

[[ -z "$YESTERDAY" ]] && YESTERDAY="0 B"
[[ -z "$TOTAL_BW" ]] && TOTAL_BW="0 B"
[[ -z "$TODAY" ]] && TODAY="0 B"
[[ -z "$MONTH" ]] && MONTH="0 B"

# ================= STATUS =================

XRAY=$(systemctl is-active xray)

if [[ $XRAY == "active" ]]; then
XRAY="${GREEN}🟢 ONLINE${NC}"
else
XRAY="${RED}🔴 OFF${NC}"
fi

NGINX=$(systemctl is-active nginx)

if [[ $NGINX == "active" ]]; then
NGINX="${GREEN}🟢 ONLINE${NC}"
else
NGINX="${RED}🔴 OFF${NC}"
fi

WG=$(systemctl is-active wg-quick@wg0)

if [[ $WG == "active" ]]; then
WG="${GREEN}🟢 ONLINE${NC}"
else
WG="${RED}🔴 OFF${NC}"
fi

ZIVPN=$(systemctl is-active zivpn)

if [[ $ZIVPN == "active" ]]; then
ZIVPN="${GREEN}🟢 ONLINE${NC}"
else
ZIVPN="${RED}🔴 OFF${NC}"
fi

UDPCUSTOM=$(systemctl is-active udp-custom)

if [[ $UDPCUSTOM == "active" ]]; then
    UDPCUSTOM="${GREEN}🟢 ONLINE${NC}"
else
    UDPCUSTOM="${RED}🔴 OFF${NC}"
fi

DROPBEARWS=$(systemctl is-active ws-dropbear)

if [[ $DROPBEARWS == "active" ]]; then
DROPBEARWS="${GREEN}🟢 ONLINE${NC}"
else
DROPBEARWS="${RED}🔴 OFF${NC}"
fi

STUNNELWS=$(systemctl is-active stunnel-ws)

if [[ $STUNNELWS == "active" ]]; then
    STUNNELWS="${GREEN}🟢 ONLINE${NC}"
else
    STUNNELWS="${RED}🔴 OFF${NC}"
fi

DROPBEAR=$(systemctl is-active dropbear)

if [[ $DROPBEAR == "active" ]]; then
    DROPBEAR="${GREEN}🟢 ONLINE${NC}"
else
    DROPBEAR="${RED}🔴 OFF${NC}"
fi

# ================= USER COUNT =================

VMESS=$(jq '[.inbounds[] | select(.tag=="vmess-ws-tls").settings.clients[]] | length' $CONFIG 2>/dev/null || echo 0)

VLESS=$(jq '[.inbounds[] | select(.tag=="vless-ws-tls").settings.clients[]] | length' $CONFIG 2>/dev/null || echo 0)

TROJAN=$(jq '[.inbounds[] | select(.tag=="trojan-ws-tls").settings.clients[]] | length' $CONFIG 2>/dev/null || echo 0)

SSWS=$(jq '[.inbounds[] | select(.tag=="ssws-ws-tls").settings.clients[]] | length' $CONFIG 2>/dev/null || echo 0)

ZIVPN_USER=$(grep -vc '^$' /etc/zivpn/users.db 2>/dev/null || echo 0)

SSH_USER=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd 2>/dev/null | wc -l)

TOTAL=$((VMESS + VLESS + TROJAN + SSWS + ZIVPN_USER + SSH_USER))

ONLINE=$(tail -n 500 /var/log/xray/access.log 2>/dev/null | 
grep -Eo 'tcp:[0-9]+.[0-9]+.[0-9]+.[0-9]+' | 
cut -d':' -f2 | sort -u | wc -l)

# ===== INIT =====

clear

echo -ne "${YELLOW}"
printf "🚀🚀🚀 LOADING AYAH-ALMA PANEL VESION 🚀🚀🚀" | type_text
echo -e "${NC}"

loading "Loading System Modules"
loading "Checking Services"
loading "Reading Traffic Database"

echo ""
echo -e "${GREEN}✔ System Ready!${NC}"

sleep 1
clear

# ================= HEADER =================

echo -e "${CYAN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
echo -e "${CYAN}┃${GREEN}          ⚡ AYAH-ALMA XRAY PANEL ⚡         ${CYAN}┃${NC}"
echo -e "${CYAN}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"

# ================= SYSTEM INFO =================

echo -e "${YELLOW}┌──────────────── SYSTEM INFO ────────────────┐${NC}"

printf " ${GREEN}IP VPS      ${NC}: ${GREEN}%-25s${NC}\n" "$IP"
printf " ${GREEN}DOMAIN      ${NC}: ${GREEN}%-25s${NC}\n" "$DOMAIN"
printf " ${GREEN}ISP         ${NC}: ${GREEN}%-25s${NC}\n" "$ISP"
printf " ${GREEN}OS          ${NC}: ${GREEN}%-25s${NC}\n" "$OS"
printf " ${GREEN}UPTIME      ${NC}: ${GREEN}%-25s${NC}\n" "$UPTIME"
printf " ${GREEN}CPU USAGE   ${NC}: ${GREEN}%-25s${NC}\n" "$CPU"
printf " ${GREEN}RAM USAGE   ${NC}: ${GREEN}%-25s${NC}\n" "$RAM"
printf " ${GREEN}DISK USAGE  ${NC}: ${GREEN}%-25s${NC}\n" "$DISK"
printf " ${GREEN}SERVER TIME ${NC}: ${GREEN}%-25s${NC}\n" "$TIME"

echo -e "${YELLOW}└─────────────────────────────────────────────┘${NC}"

# ================= BANDWIDTH =================

echo -e "${CYAN}┌──────────────── BANDWIDTH ──────────────────┐${NC}"

printf " ${GREEN}TODAY${NC}   : ${GREEN}%-10s${NC}" "$TODAY"
printf " ${GREEN}YESTERDAY${NC}  : ${GREEN}%-10s${NC}\n" "$YESTERDAY"

printf " ${GREEN}MONTH${NC}   : ${GREEN}%-10s${NC}" "$MONTH"
printf " ${GREEN}TOTAL${NC}      : ${GREEN}%-10s${NC}\n" "$TOTAL_BW"

echo -e "${CYAN}└─────────────────────────────────────────────┘${NC}"

# ================= USER ==================

echo -e "${CYAN}┌──────────────── USER STATS ─────────────────┐${NC}"

echo -e " ${GREEN}VMESS${NC} : ${GREEN}$VMESS${NC}     ${GREEN}VLESS${NC} : ${GREEN}$VLESS${NC}     ${GREEN}TROJAN${NC} : ${GREEN}$TROJAN${NC}"

echo -e " ${GREEN}SSWS${NC}  : ${GREEN}$SSWS${NC}     ${GREEN}SSH${NC}   : ${GREEN}$SSH_USER${NC}     ${GREEN}ZIVPN${NC} : ${GREEN}$ZIVPN_USER${NC}"

echo -e " ${GREEN}TOTAL${NC} : ${GREEN}$TOTAL${NC}    ${GREEN}ONLINE${NC} : ${GREEN}$ONLINE${NC}"

echo -e "${CYAN}└─────────────────────────────────────────────┘${NC}"

# ================= SERVICE =================

echo -e "${BLUE}┌──────────────── SERVICE ────────────────────┐${NC}"

printf " ${GREEN}%-10s${NC} : %-15b  ${GREEN}%-10s${NC} : %-15b\n" "XRAY" "$XRAY" "NGINX" "$NGINX"
printf " ${GREEN}%-10s${NC} : %-15b  ${GREEN}%-10s${NC} : %-15b\n" "DROPBEAR" "$DROPBEAR" "WIREGUARD" "$WG"
printf " ${GREEN}%-10s${NC} : %-15b  ${GREEN}%-10s${NC} : %-15b\n" "UDP CUSTOM" "$UDPCUSTOM" "UDP ZIVPN" "$ZIVPN"
printf " ${GREEN}%-10s${NC} : %-15b  ${GREEN}%-10s${NC} : %-15b\n" "SSH WS" "$DROPBEARWS" "WSS" "$STUNNELWS"

echo -e "${BLUE}└─────────────────────────────────────────────┘${NC}"

# ================= MENU =================

echo -e "${RED}┌──────────────── MENU AYAH ALMA ─────────────────┐${NC}"

echo -e " ${CYAN}[1]${NC}  ${GREEN}SSH${NC}         ${CYAN}[8]${NC}  ${GREEN}TOOLS${NC}"
echo -e " ${CYAN}[2]${NC}  ${GREEN}VMESS${NC}       ${CYAN}[9]${NC}  ${GREEN}STATUS${NC}"
echo -e " ${CYAN}[3]${NC}  ${GREEN}VLESS${NC}       ${CYAN}[10]${NC} ${GREEN}CLEAR RAM${NC}"
echo -e " ${CYAN}[4]${NC}  ${GREEN}TROJAN${NC}      ${CYAN}[11]${NC} ${GREEN}REBOOT VPS${NC}"
echo -e " ${CYAN}[5]${NC}  ${GREEN}SSWS${NC}        ${CYAN}[12]${NC} ${GREEN}UNINSTALL${NC}"
echo -e " ${CYAN}[6]${NC}  ${GREEN}WIREGUARD${NC}   ${CYAN}[13]${NC} ${GREEN}UDP CUSTOM${NC}"
echo -e " ${CYAN}[7]${NC}  ${GREEN}UDP ZIVPN${NC}   ${CYAN}[x]${NC}  ${GREEN}EXIT${NC}"

echo -e "${RED}└─────────────────────────────────────────────┘${NC}"

# ================= LICENSE =================

echo -e "${RED}┌──────────────── LICENSE ────────────────────┐${NC}"
echo -e " ${GREEN}License${NC} : ${GREEN}AYAH-ALMA-ULTIMATE${NC}"
echo -e " ${GREEN}Type${NC}    : ${GREEN}Lifetime Premium${NC}"
echo -e "${RED}└─────────────────────────────────────────────┘${NC}"

read -rp "Select Menu : " menu

case $menu in
1) m-ssh ;;
2) m-vmess ;;
3) m-vless ;;
4) m-trojan ;;
5) m-ssws ;;
6) m-wg ;;
7) m-zivpn ;;
8) tools-menu ;;
9) running ;;
10) clearcache ;;
11) reboot ;;
12) bash /root/uninstall.sh ;;
13) systemctl status udp-custom ;;
x) exit ;;
*)
echo -e "${RED}❌ Invalid menu!${NC}"
sleep 1
exec "$0"
;;
esac

#!/bin/bash

# ==========================================
# AYA ALMA PANEL
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

IP=$(curl -s --max-time 3 ipv4.icanhazip.com)
[[ -z "$IP" ]] && IP="N/A"

DOMAIN=$(cat /etc/xray/domain 2>/dev/null || echo "N/A")

ISP=$(curl -s --max-time 3 ipinfo.io/org | cut -d " " -f2-)
[[ -z "$ISP" ]] && ISP="Unknown"

UPTIME=$(uptime -p 2>/dev/null | sed 's/up //')
TIME=$(date "+%d-%m-%Y %H:%M:%S")

OS=$(grep PRETTY_NAME /etc/os-release 2>/dev/null |
    cut -d= -f2 |
    tr -d '"')

CPU=$(top -bn1 2>/dev/null |
    grep "Cpu(s)" |
    awk '{print $2+$4"%"}')

[[ -z "$CPU" ]] && CPU="0%"

RAM=$(free -m 2>/dev/null |
    awk 'NR==2{printf "%sMB / %sMB",$3,$2}')

DISK=$(df -h / 2>/dev/null |
    awk 'NR==2{print $3 "/" $2}')


# ================= NETWORK =================

IFACE=$(ip route get 1.1.1.1 2>/dev/null |
    awk '{print $5; exit}')

[[ -z "$IFACE" ]] && IFACE="eth0"

MONTH_NAME=$(date +"%Y-%m")

if command -v vnstat >/dev/null 2>&1; then

    TODAY=$(vnstat -i "$IFACE" 2>/dev/null |
        awk '/today/ {print $8" "$9}')

    YESTERDAY=$(vnstat -i "$IFACE" 2>/dev/null |
        awk '/yesterday/ {print $8" "$9}')

    MONTH=$(vnstat -i "$IFACE" 2>/dev/null |
        awk -v m="$MONTH_NAME" '$1 ~ m {print $8" "$9}')

    TOTAL_BW=$(vnstat --oneline 2>/dev/null |
        cut -d';' -f15)

else

    TODAY="N/A"
    YESTERDAY="N/A"
    MONTH="N/A"
    TOTAL_BW="N/A"

fi

[[ -z "$TODAY" ]] && TODAY="0 B"
[[ -z "$YESTERDAY" ]] && YESTERDAY="0 B"
[[ -z "$MONTH" ]] && MONTH="0 B"
[[ -z "$TOTAL_BW" ]] && TOTAL_BW="0 B"


# ================= SERVICE STATUS =================

XRAY_RAW=$(systemctl is-active xray 2>/dev/null)

if [[ "$XRAY_RAW" == "active" ]]; then
    XRAY="${GREEN}🟢 ONLINE${NC}"
else
    XRAY="${RED}🔴 OFF${NC}"
fi


NGINX_RAW=$(systemctl is-active nginx 2>/dev/null)

if [[ "$NGINX_RAW" == "active" ]]; then
    NGINX="${GREEN}🟢 ONLINE${NC}"
else
    NGINX="${RED}🔴 OFF${NC}"
fi


WG_RAW=$(systemctl is-active wg-quick@wg0 

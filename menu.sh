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

OS=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')

CPU=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print $2+$4"%"}')
[[ -z "$CPU" ]] && CPU="0%"

RAM=$(free -m 2>/dev/null | awk 'NR==2{printf "%sMB / %sMB",$3,$2}')

DISK=$(df -h / 2>/dev/null | awk 'NR==2{print $3 "/" $2}')

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
    TOTAL_BW=$(vnstat --oneline 2>/dev/null | cut -d';' -f15)

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

# ================= SERVICE STATUS =================

XRAY=$(systemctl is-active xray 2>/dev/null)

if [[ "$XRAY" == "active" ]]; then
    XRAY="${GREEN}🟢 ONLINE${NC}"
else
    XRAY="${RED}🔴 OFF${NC}"
fi


NGINX=$(systemctl is-active nginx 2>/dev/null)

if [[ "$NGINX" == "active" ]]; then
    NGINX="${GREEN}🟢 ONLINE${NC}"
else
    NGINX="${RED}🔴 OFF${NC}"
fi


WG=$(systemctl is-active wg-quick@wg0 2>/dev/null)

if [[ "$WG" == "active" ]]; then
    WG="${GREEN}🟢 ONLINE${NC}"
else
    WG="${RED}🔴 OFF${NC}"
fi


ZIVPN=$(systemctl is-active zivpn 2>/dev/null)

if [[ "$ZIVPN" == "active" ]]; then
    ZIVPN="${GREEN}🟢 ONLINE${NC}"
else
    ZIVPN="${RED}🔴 OFF${NC}"
fi


UDPCUSTOM=$(systemctl is-active udp-custom 2>/dev/null)

if [[ "$UDPCUSTOM" == "active" ]]; then
    UDPCUSTOM="${GREEN}🟢 ONLINE${NC}"
else
    UDPCUSTOM="${RED}🔴 OFF${NC}"
fi


DROPBEARWS=$(systemctl is-active dropbear-ws 2>/dev/null)

if [[ "$DROPBEARWS" == "active" ]]; then
    DROPBEARWS="${GREEN}🟢 ONLINE${NC}"
else
    DROPBEARWS="${RED}🔴 OFF${NC}"
fi


STUNNELWS=$(systemctl is-active stunnel-ws 2>/dev/null)

if [[ "$STUNNELWS" == "active" ]]; then
    STUNNELWS="${GREEN}🟢 ONLINE${NC}"
else
    STUNNELWS="${RED}🔴 OFF${NC}"
fi


DROPBEAR=$(systemctl is-active dropbear 2>/dev/null)

if [[ "$DROPBEAR" == "active" ]]; then
    DROPBEAR="${GREEN}🟢 ONLINE${NC}"
else
    DROPBEAR="${RED}🔴 OFF${NC}"
fi


# ================= USER COUNT =================

VMESS=0
VLESS=0
TROJAN=0
SSWS=0

if command -v jq >/dev/null 2>&1 && [[ -f "$CONFIG" ]]; then

    VMESS=$(jq '
        [
            .inbounds[]?
            | select(.protocol=="vmess")
            | .settings.clients[]?
        ] | length
    ' "$CONFIG" 2>/dev/null)

    VLESS=$(jq '
        [
            .inbounds[]?
            | select(.protocol=="vless")
            | .settings.clients[]?
        ] | length
    ' "$CONFIG" 2>/dev/null)

    TROJAN=$(jq '
        [
            .inbounds[]?
            | select(.protocol=="trojan")
            | .settings.clients[]?
        ] | length
    ' "$CONFIG" 2>/dev/null)

    SSWS=$(jq '
        [
            .inbounds[]?
            | select(.protocol=="shadowsocks")
            | .settings.clients[]?
        ] | length
    ' "$CONFIG" 2>/dev/null)

fi

[[ "$VMESS" =~ ^[0-9]+$ ]] || VMESS=0
[[ "$VLESS" =~ ^[0-9]+$ ]] || VLESS=0
[[ "$TROJAN" =~ ^[0-9]+$ ]] || TROJAN=0
[[ "$SSWS" =~ ^[0-9]+$ ]] || SSWS=0


# ================= ZIVPN USERS =================

ZIVPN_USER=0

if [[ -f /etc/zivpn/users.db ]]; then

    ZIVPN_USER=$(awk '
        NF && $0 !~ /^[[:space:]]*#/ {
            count++
        }
        END {
            print count+0
        }
    ' /etc/zivpn/users.db 2>/dev/null)

fi

[[ "$ZIVPN_USER" =~ ^[0-9]+$ ]] || ZIVPN_USER=0


# ================= SSH USERS =================

SSH_USER=0

if [[ -f /etc/passwd ]]; then

    SSH_USER=$(awk -F: '
        $3 >= 1000 &&
        $1 != "nobody" &&
        $7 != "/usr/sbin/nologin" &&
        $7 != "/bin/false" &&
        $7 != "/sbin/nologin" {
            count++
        }
        END {
            print count+0
        }
    ' /etc/passwd 2>/dev/null)

fi

[[ "$SSH_USER" =~ ^[0-9]+$ ]] || SSH_USER=0


# ================= TOTAL USERS =================

TOTAL=$((VMESS + VLESS + TROJAN + SSWS + ZIVPN_USER + SSH_USER))


# ==================================================
# ================= ONLINE STATUS ==================
# ==================================================
#
# TIDAK menggunakan access.log.
#
# Kita mengambil koneksi TCP yang benar-benar ESTABLISHED
# pada port inbound Xray.
#
# /proc/net/tcp  -> koneksi IPv4
# /proc/net/tcp6 -> koneksi IPv6
#
# State 01 = ESTABLISHED
#
# ==================================================

ONLINE=0

if [[ "$XRAY" == *"ONLINE"* ]]; then

    XRAY_PORTS=$(jq -r '
        .inbounds[]?
        | .port?
        | select(type=="number")
    ' "$CONFIG" 2>/dev/null | sort -nu)

    if [[ -n "$XRAY_PORTS" ]]; then

        for PORT in $XRAY_PORTS; do

            HEX_PORT=$(printf '%04X' "$PORT")

            # IPv4
            if [[ -r /proc/net/tcp ]]; then

                COUNT4=$(awk -v p="$HEX_PORT" '
                    NR > 1 &&
                    $4 == "01" &&
                    toupper($2) ~ ":" p "$" {
                        count++
                    }
                    END {
                        print count+0
                    }
                ' /proc/net/tcp)

                ONLINE=$((ONLINE + COUNT4))

            fi


            # IPv6
            if [[ -r /proc/net/tcp6 ]]; then

                COUNT6=$(awk -v p="$HEX_PORT" '
                    NR > 1 &&
                    $4 == "01" &&
                    toupper($2) ~ ":" p "$" {
                        count++
                    }
                    END {
                        print count+0
                    }
                ' /proc/net/tcp6)

                ONLINE=$((ONLINE + COUNT6))

            fi

        done

    fi

fi

[[ "$ONLINE" =~ ^[0-9]+$ ]] || ONLINE=0


# ================= INIT =================

clear

echo -ne "${YELLOW}"
printf "🚀 WELCOM TO SCRIPT MENU AYAH ALMA 🚀" | type_text
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
echo -e "${CYAN}┃${GREEN}          ⚡ AYAH ALMA VPS PANEL ⚡         ${CYAN}┃${NC}"
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
printf " ${GREEN}YESTERDAY${NC} : ${GREEN}%-10s${NC}\n" "$YESTERDAY"

printf " ${GREEN}MONTH${NC}   : ${GREEN}%-10s${NC}" "$MONTH"
printf " ${GREEN}TOTAL${NC}     : ${GREEN}%-10s${NC}\n" "$TOTAL_BW"

echo -e "${CYAN}└─────────────────────────────────────────────┘${NC}"


# ================= USER STATS =================

echo -e "${CYAN}┌──────────────── USER STATS ─────────────────┐${NC}"

printf " ${GREEN}VMESS${NC} : %-5s    ${GREEN}VLESS${NC} : %-5s    ${GREEN}TROJAN${NC} : %-5s\n" \
    "$VMESS" "$VLESS" "$TROJAN"

printf " ${GREEN}SSWS${NC}  : %-5s    ${GREEN}SSH${NC}   : %-5s    ${GREEN}ZIVPN${NC}  : %-5s\n" \
    "$SSWS" "$SSH_USER" "$ZIVPN_USER"

printf " ${GREEN}TOTAL${NC} : %-5s    ${GREEN}ONLINE${NC} : %-5s\n" \
    "$TOTAL" "$ONLINE"

echo -e "${CYAN}└─────────────────────────────────────────────┘${NC}"


# ================= SERVICE =================

echo -e "${BLUE}┌──────────── SERVICE BY AYAH ALMA ────────────┐${NC}"

printf " ${GREEN}%-10s${NC} : %-15b  ${GREEN}%-10s${NC} : %-15b\n" \
    "XRAY" "$XRAY" "NGINX" "$NGINX"

printf " ${GREEN}%-10s${NC} : %-15b  ${GREEN}%-10s${NC} : %-15b\n" \
    "DROPBEAR" "$DROPBEAR" "WIREGUARD" "$WG"

printf " ${GREEN}%-10s${NC} : %-15b  ${GREEN}%-10s${NC} : %-15b\n" \
    "UDP CUSTOM" "$UDPCUSTOM" "UDP ZIVPN" "$ZIVPN"

printf " ${GREEN}%-10s${NC} : %-15b  ${GREEN}%-10s${NC} : %-15b\n" \
    "SSH WS" "$DROPBEARWS" "WSS" "$STUNNELWS"

echo -e "${BLUE}└─────────────────────────────────────────────┘${NC}"


# ================= MENU =================

echo -e "${RED}┌─────────────── AYAH ALMA MENU ────────────────┐${NC}"

echo -e " ${CYAN}[1]${NC}  ${GREEN}SSH${NC}         ${CYAN}[8]${NC}  ${GREEN}TOOLS${NC}"
echo -e " ${CYAN}[2]${NC}  ${GREEN}VMESS${NC}       ${CYAN}[9]${NC}  ${GREEN}STATUS${NC}"
echo -e " ${CYAN}[3]${NC}  ${GREEN}VLESS${NC}       ${CYAN}[10]${NC} ${GREEN}CLEAR RAM${NC}"
echo -e " ${CYAN}[4]${NC}  ${GREEN}TROJAN${NC}      ${CYAN}[11]${NC} ${GREEN}REBOOT VPS${NC}"
echo -e " ${CYAN}[5]${NC}  ${GREEN}SSWS${NC}        ${CYAN}[12]${NC} ${GREEN}UNINSTALL${NC}"
echo -e " ${CYAN}[6]${NC}  ${GREEN}WIREGUARD${NC}   ${CYAN}[13]${NC} ${GREEN}UDP CUSTOM${NC}"
echo -e " ${CYAN}[7]${NC}  ${GREEN}UDP ZIVPN${NC}   ${CYAN}[x]${NC}  ${GREEN}EXIT${NC}"

echo -e "${RED}└────────────────────────────────────────────────┘${NC}"


# ================= LICENSE =================

echo -e "${RED}┌──────────────── LICENSE ────────────────────┐${NC}"

echo -e " ${GREEN}License${NC} : ${GREEN}AYAH ALMA${NC}"
echo -e " ${GREEN}Pemilik${NC} : ${GREEN}SCRIPT BY AYAH ALMA${NC}"

echo -e "${RED}└─────────────────────────────────────────────┘${NC}"


# ================= MENU INPUT =================

read -rp "Select Menu : " menu

case "$menu" in

1)
    m-ssh
    ;;

2)
    m-vmess
    ;;

3)
    m-vless
    ;;

4)
    m-trojan
    ;;

5)
    m-ssws
    ;;

6)
    m-wg
    ;;

7)
    m-zivpn
    ;;

8)
    tools-menu
    ;;

9)
    status
    ;;

10)
    clearcache
    ;;

11)
    reboot
    ;;

12)
    bash /root/uninstall.sh
    ;;

13)
    systemctl status udp-custom
    ;;

x|X)
    exit 0
    ;;

*)
    echo -e "${RED}❌ Invalid menu!${NC}"
    sleep 1
    exec "$0"
    ;;

esac

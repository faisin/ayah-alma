#!/usr/bin/env bash
# AYA ALMA PANEL - menu.sh
# Audited replacement for the truncated v2.1.1 menu script.
# This script displays system/service information and delegates account actions
# to existing Ayah Alma commands. It does not edit Xray/Nginx configuration.

PANEL_VERSION="v2.1.1"
CONFIG="/etc/xray/config.json"
LOG="/var/log/xray/access.log"

RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'
BLUE='\033[1;34m'; CYAN='\033[1;36m'; WHITE='\033[1;37m'; NC='\033[0m'

color() { printf '%b' "$1"; }
line() { printf '%s\n' '============================================================'; }

service_state() {
    local service="$1" raw
    raw=$(systemctl is-active "$service" 2>/dev/null || true)
    if [[ "$raw" == active ]]; then
        printf '%b🟢 ONLINE%b' "$GREEN" "$NC"
    else
        printf '%b🔴 OFFLINE%b' "$RED" "$NC"
    fi
}

get_ip() {
    local ip=''
    if command -v curl >/dev/null 2>&1; then
        ip=$(curl -4 -fsS --max-time 3 https://ipv4.icanhazip.com 2>/dev/null || true)
    fi
    printf '%s' "${ip:-N/A}"
}

get_domain() {
    local domain='N/A'
    if [[ -r /etc/xray/domain ]]; then
        IFS= read -r domain < /etc/xray/domain || true
    fi
    printf '%s' "${domain:-N/A}"
}

get_cpu() {
    local cpu='0%'
    if command -v top >/dev/null 2>&1; then
        cpu=$(top -bn1 2>/dev/null | awk '/Cpu\(s\)/ {gsub(/,/,"",$2); gsub(/,/,"",$4); print $2+$4 "%"; exit}')
    fi
    printf '%s' "${cpu:-0%}"
}

get_ram() {
    free -m 2>/dev/null | awk 'NR==2 {printf "%sMB / %sMB", $3, $2}'
}

get_disk() {
    df -h / 2>/dev/null | awk 'NR==2 {print $3 "/" $2}'
}

get_iface() {
    local iface=''
    if command -v ip >/dev/null 2>&1; then
        iface=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')
    fi
    printf '%s' "${iface:-eth0}"
}

traffic_value() {
    local kind="$1" iface="$2" out=''
    command -v vnstat >/dev/null 2>&1 || { printf 'N/A'; return; }
    case "$kind" in
        today) out=$(vnstat -i "$iface" 2>/dev/null | awk '/today/ {print $8, $9; exit}') ;;
        yesterday) out=$(vnstat -i "$iface" 2>/dev/null | awk '/yesterday/ {print $8, $9; exit}') ;;
        month) out=$(vnstat -i "$iface" --oneline 2>/dev/null | awk -F';' '{print $11}') ;;
        total) out=$(vnstat -i "$iface" --oneline 2>/dev/null | awk -F';' '{print $15}') ;;
    esac
    printf '%s' "${out:-0 B}"
}

show_dashboard() {
    clear 2>/dev/null || true
    local ip domain uptime os cpu ram disk iface today yesterday month total
    ip=$(get_ip)
    domain=$(get_domain)
    uptime=$(uptime -p 2>/dev/null | sed 's/^up //' || true)
    os=$(sed -n 's/^PRETTY_NAME="\(.*\)"$/\1/p' /etc/os-release 2>/dev/null | head -n1)
    cpu=$(get_cpu); ram=$(get_ram); disk=$(get_disk); iface=$(get_iface)
    today=$(traffic_value today "$iface")
    yesterday=$(traffic_value yesterday "$iface")
    month=$(traffic_value month "$iface")
    total=$(traffic_value total "$iface")

    line
    printf '%b        AYA ALMA PANEL %s%b\n' "$CYAN" "$PANEL_VERSION" "$NC"
    line
    printf ' IP VPS       : %s\n' "$ip"
    printf ' Domain       : %s\n' "$domain"
    printf ' OS           : %s\n' "${os:-Unknown}"
    printf ' Uptime       : %s\n' "${uptime:-Unknown}"
    printf ' CPU          : %s\n' "$cpu"
    printf ' RAM          : %s\n' "${ram:-N/A}"
    printf ' Disk         : %s\n' "${disk:-N/A}"
    line
    printf ' SERVICE STATUS\n'
    printf ' Xray         : '; service_state xray; printf '\n'
    printf ' Nginx        : '; service_state nginx; printf '\n'
    printf ' WireGuard    : '; service_state wg-quick@wg0; printf '\n'
    printf ' Dropbear     : '; service_state dropbear; printf '\n'
    printf ' Dropbear WS  : '; service_state dropbear-ws; printf '\n'
    printf ' Stunnel WS   : '; service_state stunnel-ws; printf '\n'
    printf ' UDP Custom   : '; service_state udp-custom; printf '\n'
    printf ' ZIVPN        : '; service_state zivpn; printf '\n'
    line
    printf ' TRAFFIC (%s)\n' "$iface"
    printf ' Today        : %s\n' "$today"
    printf ' Yesterday    : %s\n' "$yesterday"
    printf ' This month   : %s\n' "$month"
    printf ' Total        : %s\n' "$total"
    line
}

run_existing() {
    local label="$1"; shift
    local candidate
    for candidate in "$@"; do
        if command -v "$candidate" >/dev/null 2>&1; then
            clear 2>/dev/null || true
            "$candidate"
            printf '\nTekan Enter untuk kembali ke menu...'
            read -r _ || true
            return 0
        fi
    done
    printf '\nPerintah %s tidak ditemukan di sistem ini.\n' "$label"
    sleep 1
    return 1
}

while true; do
    show_dashboard
    cat <<'MENU'
 PILIHAN MENU
 1. Kelola akun VMess
 2. Kelola akun VLESS
 3. Kelola akun Trojan
 4. Kelola akun Shadowsocks
 5. Kelola akun SSH / Dropbear
 6. Status layanan (running)
 7. Tools menu
 8. Restart Xray
 9. Restart Nginx
 0. Keluar
MENU
    printf ' Pilihan [0-9]: '
    read -r choice || exit 0
    case "$choice" in
        1) run_existing 'VMess' m-vmess /usr/bin/m-vmess ;;
        2) run_existing 'VLESS' m-vless /usr/bin/m-vless ;;
        3) run_existing 'Trojan' m-trojan /usr/bin/m-trojan ;;
        4) run_existing 'Shadowsocks' m-ss /usr/bin/m-ss m-shadowsocks /usr/bin/m-shadowsocks ;;
        5) run_existing 'SSH' m-ssh /usr/bin/m-ssh ;;
        6) run_existing 'running' running /usr/bin/running ;;
        7) run_existing 'tools-menu' tools-menu /usr/bin/tools-menu ;;
        8)
            if systemctl restart xray; then echo 'Xray berhasil direstart.'; else echo 'Gagal restart Xray; periksa journalctl -u xray.'; fi
            sleep 2
            ;;
        9)
            if systemctl restart nginx; then echo 'Nginx berhasil direstart.'; else echo 'Gagal restart Nginx; periksa journalctl -u nginx.'; fi
            sleep 2
            ;;
        0) exit 0 ;;
        *) echo 'Pilihan tidak valid.'; sleep 1 ;;
    esac
done

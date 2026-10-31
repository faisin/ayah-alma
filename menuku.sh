#!/usr/bin/env bash
# AYA ALMA PANEL - menu.sh
# Visual refresh: colored dashboard/menu. Existing account commands are preserved.
# This script does not edit Xray/HAProxy configuration.

PANEL_VERSION="v2.1.1"

# Enable ANSI colors only for interactive terminals.
if [[ -t 1 ]]; then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_DIM=$'\033[2m'
    C_RED=$'\033[1;31m'
    C_GREEN=$'\033[1;32m'
    C_YELLOW=$'\033[1;33m'
    C_BLUE=$'\033[1;34m'
    C_MAGENTA=$'\033[1;35m'
    C_CYAN=$'\033[1;36m'
    C_WHITE=$'\033[1;37m'
    C_GRAY=$'\033[0;37m'
else
    C_RESET=''; C_BOLD=''; C_DIM=''; C_RED=''; C_GREEN=''
    C_YELLOW=''; C_BLUE=''; C_MAGENTA=''; C_CYAN=''; C_WHITE=''; C_GRAY=''
fi

BAR='━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'

print_bar() { printf '%b%s%b\n' "$C_CYAN" "$BAR" "$C_RESET"; }
print_label() { printf ' %b%-13s%b : %s\n' "$C_CYAN" "$1" "$C_RESET" "$2"; }

# Animasi warna berulang pada satu baris; teks tidak bergerak horizontal.
print_lombok_marquee() {
    local text='LOMBOK | SELAMAT DATANG DI AYAH ALMA VPN'
    local color
    local colors=("$C_YELLOW$C_BOLD" "$C_CYAN$C_BOLD" "$C_MAGENTA$C_BOLD" "$C_GREEN$C_BOLD")
    if [[ ! -t 1 ]]; then
        printf '  %s\n' "$text"
        return
    fi
    # Ulangi animasi warna beberapa kali, lalu tampilkan warna akhir.
    for color in "${colors[@]}" "${colors[@]}" "${colors[@]}"; do
        printf '\r  %b%s%b\033[K' "$color" "$text" "$C_RESET"
        sleep 0.18
    done
    printf '\r  %b%s%b\033[K\n' "$C_YELLOW$C_BOLD" "$text" "$C_RESET"
}

service_state() {
    local service="$1" raw
    raw=$(systemctl is-active "$service" 2>/dev/null || true)
    if [[ "$raw" == active ]]; then
        printf '%b● ONLINE%b' "$C_GREEN" "$C_RESET"
    else
        printf '%b● OFFLINE%b' "$C_RED" "$C_RESET"
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

get_ram() { free -m 2>/dev/null | awk 'NR==2 {printf "%sMB / %sMB", $3, $2}'; }
get_disk() { df -h / 2>/dev/null | awk 'NR==2 {print $3 "/" $2}'; }

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
        today)     out=$(vnstat -i "$iface" 2>/dev/null | awk '/today/ {print $8, $9; exit}') ;;
        yesterday) out=$(vnstat -i "$iface" 2>/dev/null | awk '/yesterday/ {print $8, $9; exit}') ;;
        month)     out=$(vnstat -i "$iface" --oneline 2>/dev/null | awk -F';' '{print $11}') ;;
        total)     out=$(vnstat -i "$iface" --oneline 2>/dev/null | awk -F';' '{print $15}') ;;
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

    printf '  %bSYSTEM OVERVIEW%b\n' "$C_WHITE$C_BOLD" "$C_RESET"
    print_label 'Public IP' "$ip"
    print_label 'Domain' "$domain"
    print_label 'Operating OS' "${os:-Unknown}"
    print_label 'Uptime' "${uptime:-Unknown}"
    print_label 'CPU Usage' "$cpu"
    print_label 'RAM Usage' "${ram:-N/A}"
    print_label 'Disk Usage' "${disk:-N/A}"

    
    print_bar
    # Banner LOMBOK berwarna, memakai huruf outline agar tidak terlalu tebal.
    printf '%b' "$C_MAGENTA$C_BOLD"
    cat <<'LOMBOK_BANNER'
     _      ____  __  __ ____   ____  _  __
    | |    / __ \|  \/  | __ ) / __ \| |/ /
    | |   | |  | | |\/| |  _ \| |  | | ' /
    | |___| |__| | |  | | |_) | |__| | . \
    |_____\____/|_|  |_ |____/ \____/|_|\_\
LOMBOK_BANNER
    printf '%b' "$C_RESET"
    print_lombok_marquee
    printf '  %b◆ AYAH ALMA VPN%b  %b%s%b\n' "$C_MAGENTA$C_BOLD" "$C_RESET" "$C_YELLOW" "$PANEL_VERSION" "$C_RESET"
    printf '  %bSecure • Simple • Manageable VPN Server%b\n' "$C_DIM" "$C_RESET"
    print_bar

    
    print_bar
    printf '  %bSERVICE MONITOR%b\n' "$C_WHITE$C_BOLD" "$C_RESET"
    printf ' %b%-13s%b : ' "$C_CYAN" 'Xray Core' "$C_RESET"; service_state xray; printf '\n'
    printf ' %b%-13s%b : ' "$C_CYAN" 'HAProxy' "$C_RESET"; service_state haproxy; printf '\n'
    printf ' %b%-13s%b : ' "$C_CYAN" 'WireGuard' "$C_RESET"; service_state wg-quick@wg0; printf '\n'
    printf ' %b%-13s%b : ' "$C_CYAN" 'Dropbear' "$C_RESET"; service_state dropbear; printf '\n'
    printf ' %b%-13s%b : ' "$C_CYAN" 'Dropbear WS' "$C_RESET"; service_state dropbear-ws; printf '\n'
    printf ' %b%-13s%b : ' "$C_CYAN" 'SSH WSS' "$C_RESET"; service_state dropbear-wss; printf '\n'
    printf ' %b%-13s%b : ' "$C_CYAN" 'UDP Custom' "$C_RESET"; service_state udp-custom; printf '\n'
    printf ' %b%-13s%b : ' "$C_CYAN" 'ZIVPN' "$C_RESET"; service_state zivpn; printf '\n'

    print_bar
    printf '  %bNETWORK TRAFFIC%b  %b(interface: %s)%b\n' "$C_WHITE$C_BOLD" "$C_RESET" "$C_DIM" "$iface" "$C_RESET"
    print_label 'Today' "$today"
    print_label 'Yesterday' "$yesterday"
    print_label 'This Month' "$month"
    print_label 'All Time' "$total"
    print_bar
}

menu_item() {
    printf '  %b[%s]%b %s\n' "$C_YELLOW$C_BOLD" "$1" "$C_RESET" "$2"
}

run_existing() {
    local label="$1"; shift
    local candidate
    for candidate in "$@"; do
        if command -v "$candidate" >/dev/null 2>&1; then
            clear 2>/dev/null || true
            "$candidate"
            printf '\n%bTekan Enter untuk kembali ke menu...%b' "$C_DIM" "$C_RESET"
            read -r _ || true
            return 0
        fi
    done
    printf '\n%b[ERROR]%b Perintah %s tidak ditemukan di sistem ini.\n' "$C_RED" "$C_RESET" "$label"
    sleep 1
    return 1
}

while true; do
    show_dashboard
    printf '  %bMENU UTAMA%b\n' "$C_WHITE$C_BOLD" "$C_RESET"
    menu_item 1 'VMess'
    menu_item 2 'VLESS'
    menu_item 3 'Trojan'
    menu_item 4 'Shadowsocks'
    menu_item 5 'SSH / Dropbear'
    menu_item 6 'Status layanan (running)'
    menu_item 7 'Tools menu'
    menu_item 8 'Restart Xray'
    menu_item 9 'Restart HAProxy'
    menu_item 0 'Keluar'
    print_bar
    printf '  %bPilih menu [0-9]: %b' "$C_GREEN$C_BOLD" "$C_RESET"
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
            if systemctl restart xray; then
                printf '%bXray berhasil direstart.%b\n' "$C_GREEN" "$C_RESET"
            else
                printf '%bGagal restart Xray; periksa journalctl -u xray.%b\n' "$C_RED" "$C_RESET"
            fi
            sleep 2
            ;;
        9)
            if systemctl restart haproxy; then
                printf '%bHAProxy berhasil direstart.%b\n' "$C_GREEN" "$C_RESET"
            else
                printf '%bGagal restart HAProxy; periksa journalctl -u haproxy.%b\n' "$C_RED" "$C_RESET"
            fi
            sleep 2
            ;;
        0) exit 0 ;;
        *) printf '%bPilihan tidak valid.%b\n' "$C_RED" "$C_RESET"; sleep 1 ;;
    esac
done

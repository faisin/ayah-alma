#!/bin/bash
# Uninstall Script - by Ayah Alma

# ================= COLOR =================

RED='\033[1;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m'

BASE_DIR="/etc/ayah-alma"

# ================= CHECK ROOT =================

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[ERROR] Jalankan script sebagai root!${NC}"
    exit 1
fi

# ================= FUNCTION =================

confirm() {
    read -rp "❗ Yakin ingin menghapus semua layanan Ayah Alma VPS? [y/N]: " confirm

    [[ "$confirm" =~ ^[Yy]$ ]] || {
        echo -e "${YELLOW}Batal uninstall.${NC}"
        exit 1
    }
}

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

err() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ================= START =================

confirm

clear

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}🚮 UNINSTALL AYAH ALMA VPS${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# ================= STOP SERVICES =================

services=(
    nginx
    xray
    dropbear
    ws-dropbear
    ws-stunnel
    udp-custom
    udpgw
    stunnel4
    wg-quick@wg0
    zivpn
    dropbear-ws
    stunnel-ws
)

for svc in "${services[@]}"; do
    if systemctl list-unit-files | grep -q "^${svc}"; then
        info "Stopping service: $svc"
        systemctl stop "$svc" >/dev/null 2>&1 || true
        systemctl disable "$svc" >/dev/null 2>&1 || true
    fi
done

# ================= REMOVE SYSTEMD =================

info "Removing systemd services..."

rm -f /etc/systemd/system/xray.service
rm -f /etc/systemd/system/dropbear.service
rm -f /etc/systemd/system/ws-dropbear.service
rm -f /etc/systemd/system/ws-stunnel.service
rm -f /etc/systemd/system/udp-custom.service
rm -f /etc/systemd/system/udpgw.service
rm -f /etc/systemd/system/zivpn.service
rm -f /etc/systemd/system/dropbear-ws.service
rm -f /etc/systemd/system/stunnel-ws.service

rm -f /etc/systemd/system/acme*.service
rm -f /etc/systemd/system/acme*.timer

systemctl daemon-reload
systemctl daemon-reexec

sleep 3

# ================= REMOVE BINARIES =================

info "Removing binaries..."

rm -f /usr/local/bin/xray
rm -f /usr/local/bin/ws-dropbear
rm -f /usr/local/bin/ws-stunnel
rm -f /usr/local/bin/udp-custom
rm -f /usr/local/bin/badvpn-udpgw
rm -f /usr/local/bin/zivpn
rm -f /usr/local/bin/dropbearws
rm -f /usr/local/bin/stunnelws

# ================= REMOVE CONFIG =================

info "Removing configurations..."

rm -rf /etc/xray
rm -rf /etc/v2ray
rm -rf /etc/zivpn
rm -rf /etc/wireguard
rm -rf /etc/ayah-alma
rm -rf /etc/autoscriptvpn
rm -rf /etc/udp-custom

rm -f /etc/nginx/conf.d/xray.conf

rm -f /etc/default/dropbear
rm -f /etc/issue.net
rm -f /etc/profile.d/no-login.sh

rm -f /root/domain
rm -f /root/scdomain
rm -f /root/log-install.txt
rm -f /etc/log-create-ssh.log

rm -rf /root/accounts
rm -rf /root/backup-autoscript

# ================= REMOVE MENUS =================

info "Removing menu commands..."

binaries=(
    menu
    m-ssh
    m-vmess
    m-vless
    m-trojan
    m-ssws
    m-wg
    m-zivpn
    tools-menu
    m-zivpn
)

for bin in "${binaries[@]}"; do
    rm -f "/usr/bin/$bin"
done

# ================= REMOVE TRIAL USERS =================

info "Removing trial users..."

awk -F: '/^trial/ {print $1}' /etc/passwd | while read -r user; do
    userdel -f "$user" >/dev/null 2>&1 || true
done

# ================= REMOVE CRON =================

info "Cleaning cron jobs..."

rm -f /etc/cron.d/xray
rm -f /etc/cron.d/autoscript
rm -f /etc/cron.d/ayah-alma

# ================= REMOVE ACME =================

if [[ -d ~/.acme.sh ]]; then
    info "Removing acme.sh..."
    rm -rf ~/.acme.sh
fi

# ================= REMOVE PACKAGES =================

warn "Removing packages..."

apt remove -y \
    nginx \
    dropbear \
    stunnel4 \
    wireguard \
    wireguard-tools \
    qrencode || true

apt autoremove -y

# ================= CLEAN TEMP =================

warn "Cleaning temporary files..."

rm -rf /tmp/xray
rm -rf /tmp/badvpn
rm -f /tmp/xray.zip

# ================= REMOVE SOURCE =================

info "Removing source directory..."
rm -rf "$BASE_DIR"

# ================= FINISH =================

clear

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ AYAH ALMA VPS UNINSTALLED${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo ""
echo -e " NGINX       : REMOVED"
echo -e " XRAY        : REMOVED"
echo -e " SSH WS      : REMOVED"
echo -e " WireGuard   : REMOVED"
echo -e " UDP CUSTOM  : REMOVED"
echo -e " UDPGW       : REMOVED"
echo -e " UDP ZIVPN   : REMOVED"

echo ""
echo -e "${YELLOW}💡 Recommended reboot:${NC} reboot"
echo ""


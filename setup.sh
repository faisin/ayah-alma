#!/bin/bash
# ================================================================
# AYAH-ALMA AIO - ONE COMMAND INSTALLER
# wget -qO- https://raw.githubusercontent.com/faisin/ayah-alma/main/setup.sh | bash
# ================================================================
set -Eeuo pipefail
IFS=$'\n\t'

RELEASE_URL="https://github.com/faisin/ayah-alma/releases/latest/download/ayah-alma-release.zip"
INSTALL_ROOT="/etc/ayah-alma"
WORK_DIR=""
CLEAN_WORK=false
START_TIME=$(date +%s)
RED='\e[1;31m'; GREEN='\e[0;32m'; YELLOW='\e[1;33m'; BLUE='\e[1;34m'; CYAN='\e[1;36m'; NC='\e[0m'

info(){ echo -e "${GREEN}[INFO]${NC} $*"; }
warn(){ echo -e "${YELLOW}[WARNING]${NC} $*"; }
die(){ echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }
read_prompt(){
    local prompt="$1" var="$2"
    if [[ -r /dev/tty ]]; then
        read -rp "$prompt" "$var" </dev/tty
    else
        read -rp "$prompt" "$var"
    fi
}
on_error(){ local line=$1 code=$2; echo -e "${RED}[ERROR]${NC} setup.sh gagal pada baris ${line} (exit ${code})." >&2; echo "Log: /root/log-install.txt" >&2; }
trap 'on_error $LINENO $?' ERR
cleanup(){ [[ "$CLEAN_WORK" == true && -n "$WORK_DIR" ]] && rm -rf "$WORK_DIR"; }
trap cleanup EXIT

[[ $EUID -eq 0 ]] || die "Jalankan sebagai root."
command -v apt-get >/dev/null 2>&1 || die "Installer ini mendukung Ubuntu/Debian."
[[ -f /etc/os-release ]] || die "Tidak dapat membaca /etc/os-release."
. /etc/os-release
case "${ID:-}" in ubuntu|debian) ;; *) die "OS ${PRETTY_NAME:-unknown} belum didukung." ;; esac
ARCH=$(dpkg --print-architecture)
case "$ARCH" in amd64|arm64) ;; *) die "Arsitektur $ARCH belum didukung. Gunakan amd64 atau arm64." ;; esac
if command -v systemd-detect-virt >/dev/null 2>&1; then [[ "$(systemd-detect-virt || true)" != "openvz" ]] || die "OpenVZ tidak didukung."; fi

: > /root/log-install.txt
exec > >(tee -a /root/log-install.txt) 2>&1
info "AYAH-ALMA AIO installer dimulai."
info "OS: ${PRETTY_NAME:-$ID} | Arch: $ARCH"

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl wget jq tar gzip unzip git python3 python3-pip coreutils openssl iptables iptables-persistent netfilter-persistent vnstat screen golang-go file

SOURCE_FILE="${BASH_SOURCE[0]:-}"
if [[ -n "$SOURCE_FILE" && -f "$SOURCE_FILE" ]]; then
    SELF_DIR="$(cd -- "$(dirname -- "$SOURCE_FILE")" && pwd)"
else
    SELF_DIR="$PWD"
fi
LOCAL_READY=true
for rel in install/nginx.sh install/xray.sh install/ssh.sh install/wg.sh install/zivpn.sh "bin/$ARCH/xray" "bin/$ARCH/zivpn" "bin/$ARCH/badvpn-udpgw" "bin/$ARCH/udp-custom" config/nginx.conf config/xray.conf config/xray.json internal/go/dropbear-ws/main.go internal/go/stunnel-ws/main.go; do
    [[ -s "$SELF_DIR/$rel" ]] || { LOCAL_READY=false; break; }
done
if [[ "$LOCAL_READY" == true ]]; then
    BASE_DIR="$SELF_DIR"
    info "Release lokal lengkap ditemukan: $BASE_DIR"
else
    WORK_DIR=$(mktemp -d /tmp/ayah-alma.XXXXXX)
    CLEAN_WORK=true
    ARCHIVE="$WORK_DIR/ayah-alma-release.zip"
    info "Mengunduh release resmi Ayah Alma..."
    wget -q --show-progress --https-only -O "$ARCHIVE" "$RELEASE_URL" || die "Gagal mengunduh release Ayah Alma."
    unzip -tq "$ARCHIVE" >/dev/null || die "Release Ayah Alma rusak."
    mkdir -p "$WORK_DIR/release"
    unzip -q "$ARCHIVE" -d "$WORK_DIR/release"
    BASE_DIR="$WORK_DIR/release/ayah-alma-release/ayah-alma-main"
    [[ -d "$BASE_DIR" ]] || die "Struktur release Ayah Alma tidak valid."
fi

# ================= LICENSE CHECK =================
LICENSE_FILE="$BASE_DIR/config/license.conf"

[[ -f "$LICENSE_FILE" ]] || die "File license.conf tidak ditemukan."

source "$LICENSE_FILE"

declare -p ALLOWED_IPS >/dev/null 2>&1 || die "Konfigurasi lisensi tidak valid."

PUBLIC_IP=$(curl -4fsS --max-time 10 https://api.ipify.org 2>/dev/null || true)

[[ "$PUBLIC_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] \
    || die "Gagal mendapatkan IP VPS."

LICENSE_VALID=false

for allowed_ip in "${ALLOWED_IPS[@]}"; do
    if [[ "$PUBLIC_IP" == "$allowed_ip" ]]; then
        LICENSE_VALID=true
        break
    fi
don

[[ "$LICENSE_VALID" == true ]] || die "IP VPS tidak memiliki lisensi."

info "Lisensi valid: $PUBLIC_IP"

required=(install/nginx.sh install/xray.sh install/ssh.sh install/wg.sh install/zivpn.sh "bin/$ARCH/xray" "bin/$ARCH/zivpn" "bin/$ARCH/badvpn-udpgw" "bin/$ARCH/udp-custom" config/nginx.conf config/xray.conf config/xray.json config/license.conf license config/udp-custom config/udp-custom.json config/issue.net sshws/udpgw.service sshws/udp-custom.service internal/go/dropbear-ws/main.go internal/go/dropbear-ws.service internal/go/stunnel-ws/main.go internal/go/stunnel-ws.service menu.sh uninstall.sh clearcache)
for rel in "${required[@]}"; do [[ -f "$BASE_DIR/$rel" ]] || die "File wajib tidak ditemukan: $rel"; done
cd "$BASE_DIR"

# Fail early on accidentally corrupted source files.
while IFS= read -r -d '' f; do
    sed -i 's/\r$//' "$f"
    grep -qE '\[span_[0-9]+\]|start_span|end_span' "$f" && die "File rusak mengandung marker span: ${f#$BASE_DIR/}"
done < <(find "$BASE_DIR" -type f \( -name '*.sh' -o -name 'm-*' -o -name '*.service' -o -name '*.py' -o -name '*.go' \) -print0)

mkdir -p /etc/xray /etc/v2ray /var/lib /etc/ayah-alma
local_ip=$(hostname -I | awk '{print $1}'); hostname_now=$(hostname)
if [[ -n "$local_ip" && -n "$hostname_now" ]] && ! grep -Eq "^[[:space:]]*${local_ip//./\.}[[:space:]]+${hostname_now}([[:space:]]|$)" /etc/hosts; then echo "$local_ip $hostname_now" >> /etc/hosts; fi
ln -sf /usr/share/zoneinfo/Asia/Jakarta /etc/localtime

clear
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}         DOMAIN SETUP${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "1. Domain otomatis (IP.sslip.io)"
echo "2. Domain sendiri"
read_prompt "Pilih opsi (1/2): " pilihan
if [[ "$pilihan" == "1" ]]; then
    pub_ip=$(curl -4fsS --max-time 10 https://api.ipify.org 2>/dev/null || true)
    [[ -n "$pub_ip" ]] || pub_ip=$(hostname -I | awk '{print $1}')
    [[ "$pub_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "IP publik tidak berhasil dideteksi."
    domain="${pub_ip}.sslip.io"
elif [[ "$pilihan" == "2" ]]; then
    read_prompt "Masukkan domain kamu: " domain
    [[ "$domain" =~ ^[A-Za-z0-9.-]+$ ]] || die "Format domain tidak valid."
else die "Pilihan domain tidak valid."; fi

for f in /root/domain /root/scdomain /etc/xray/domain /etc/xray/scdomain /etc/v2ray/domain /etc/v2ray/scdomain; do printf '%s\n' "$domain" > "$f"; done
printf 'OS=%s\nIP=%s\n' "$PRETTY_NAME" "$domain" > /var/lib/ipvps.conf
info "Domain: $domain"

run_module(){ local rel="$1"; [[ -f "$BASE_DIR/$rel" ]] || die "Module tidak ditemukan: $rel"; info "Menjalankan $rel ..."; (cd "$BASE_DIR" && bash "$BASE_DIR/$rel"); }
run_module install/nginx.sh
run_module install/xray.sh
run_module install/ssh.sh
run_module install/wg.sh
run_module install/zivpn.sh

info "Memasang runtime Ayah Alma..."
mkdir -p "$INSTALL_ROOT"/{ssh,xray,wg,udp,tools,config,sshws,internal/go}
for dir in ssh xray wg udp tools config sshws; do cp -a "$BASE_DIR/$dir/." "$INSTALL_ROOT/$dir/"; done
cp -a "$BASE_DIR/internal/go/." "$INSTALL_ROOT/internal/go/"
for f in "$BASE_DIR"/ssh/* "$BASE_DIR"/xray/* "$BASE_DIR"/wg/* "$BASE_DIR"/udp/* "$BASE_DIR"/tools/*; do [[ -f "$f" ]] || continue; install -m 755 "$f" "/usr/bin/$(basename "$f")"; done
install -m 755 "$BASE_DIR/menu.sh" /usr/bin/menu
install -m 755 "$BASE_DIR/clearcache" /usr/bin/clearcache
install -m 755 "$BASE_DIR/uninstall.sh" /root/uninstall.sh

for f in /usr/local/bin/xray /usr/local/bin/dropbearws /usr/local/bin/stunnelws /usr/local/bin/badvpn-udpgw /usr/local/bin/udp-custom /usr/local/bin/zivpn; do [[ -x "$f" ]] || die "Binary wajib tidak executable: $f"; done
[[ -f /etc/xray/config.json ]] || die "Xray config tidak terpasang."
[[ -f /etc/nginx/conf.d/xray.conf ]] || die "Nginx Xray config tidak terpasang."
[[ -f /etc/wireguard/wg0.conf ]] || die "WireGuard config tidak terpasang."

systemctl daemon-reload
services=(xray nginx ssh dropbear dropbear-ws stunnel-ws udpgw udp-custom wg-quick@wg0 zivpn)
for svc in "${services[@]}"; do
    systemctl enable "$svc" >/dev/null 2>&1 || die "Gagal enable service $svc"
    systemctl restart "$svc" >/dev/null 2>&1 || { systemctl status "$svc" --no-pager || true; die "Service $svc gagal start."; }
done
for svc in "${services[@]}"; do systemctl is-active --quiet "$svc" || { systemctl status "$svc" --no-pager || true; die "Health check gagal: $svc"; }; done

cat > /root/.profile <<'EOF'
if [ "$BASH" ]; then
    if [ -f ~/.bashrc ]; then . ~/.bashrc; fi
fi
if [ -t 0 ] && [ -t 1 ] && command -v menu >/dev/null 2>&1; then
    clear
    menu
fi
EOF
chmod 644 /root/.profile
printf '\nAYAH-ALMA INSTALLATION SUCCESSFUL\n' >> /root/log-install.txt
elapsed=$(( $(date +%s) - START_TIME ))
clear
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}   AYAH-ALMA INSTALLATION DONE${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Domain      : $domain"
echo "Xray        : OK"
echo "Nginx       : OK"
echo "SSH/WS      : OK"
echo "WireGuard   : OK"
echo "UDP Custom  : OK"
echo "ZiVPN       : OK"
echo "Waktu       : $((elapsed/60)) menit $((elapsed%60)) detik"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
warn "Tidak otomatis reboot. Jalankan reboot jika diperlukan."

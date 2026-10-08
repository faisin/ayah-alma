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

RED='\e[1;31m'
GREEN='\e[0;32m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
CYAN='\e[1;36m'
NC='\e[0m'

info(){
    echo -e "${GREEN}[INFO]${NC} $*"
}

warn(){
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

die(){
    echo -e "${RED}[ERROR]${NC} $*" >&2
    exit 1
}

read_prompt(){
    local prompt="$1" var="$2"

    if [[ -r /dev/tty ]]; then
        read -rp "$prompt" "$var" </dev/tty
    else
        read -rp "$prompt" "$var"
    fi
}

on_error(){
    local line=$1
    local code=$2

    echo -e "${RED}[ERROR]${NC} setup.sh gagal pada baris ${line} (exit ${code})." >&2
    echo "Log: /root/log-install.txt" >&2
}

trap 'on_error $LINENO $?' ERR

cleanup(){
    [[ "$CLEAN_WORK" == true && -n "$WORK_DIR" ]] && rm -rf "$WORK_DIR"
}

trap cleanup EXIT

[[ $EUID -eq 0 ]] || die "Jalankan sebagai root."

command -v apt-get >/dev/null 2>&1 \
    || die "Installer ini mendukung Ubuntu/Debian."

[[ -f /etc/os-release ]] \
    || die "Tidak dapat membaca /etc/os-release."

. /etc/os-release

case "${ID:-}" in
    ubuntu|debian)
        ;;
    *)
        die "OS ${PRETTY_NAME:-unknown} belum didukung."
        ;;
esac

ARCH=$(dpkg --print-architecture)

case "$ARCH" in
    amd64|arm64)
        ;;
    *)
        die "Arsitektur $ARCH belum didukung. Gunakan amd64 atau arm64."
        ;;
esac

if command -v systemd-detect-virt >/dev/null 2>&1; then
    [[ "$(systemd-detect-virt || true)" != "openvz" ]] \
        || die "OpenVZ tidak didukung."
fi

: > /root/log-install.txt

exec > >(tee -a /root/log-install.txt) 2>&1

info "AYAH-ALMA AIO installer dimulai."
info "OS: ${PRETTY_NAME:-$ID} | Arch: $ARCH"

export DEBIAN_FRONTEND=noninteractive

apt-get update

apt-get install -y \
    ca-certificates \
    curl \
    wget \
    jq \
    tar \
    gzip \
    unzip \
    git \
    python3 \
    python3-pip \
    coreutils \
    openssl \
    iptables \
    iptables-persistent \
    netfilter-persistent \
    vnstat \
    screen \
    golang-go \
    file

# ================================================================
# FIREWALL
# ================================================================

# Buka HTTP/HTTPS pada firewall host sebelum ACME Webroot.
# Ini sengaja ditempatkan di depan rule REJECT yang mungkin sudah ada.

for port in 80 443; do

    iptables -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null \
        || iptables -I INPUT 1 -p tcp --dport "$port" -j ACCEPT

    if command -v ip6tables >/dev/null 2>&1; then

        ip6tables -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null \
            || ip6tables -I INPUT 1 -p tcp --dport "$port" -j ACCEPT

    fi

done

if command -v netfilter-persistent >/dev/null 2>&1; then
    netfilter-persistent save >/dev/null 2>&1 || true
fi

# ================================================================
# DETECT SOURCE
# ================================================================

SOURCE_FILE="${BASH_SOURCE[0]:-}"

if [[ -n "$SOURCE_FILE" && -f "$SOURCE_FILE" ]]; then
    SELF_DIR="$(cd -- "$(dirname -- "$SOURCE_FILE")" && pwd)"
else
    SELF_DIR="$PWD"
fi

# ================================================================
# MAIN GITHUB = SUMBER UTAMA
# RELEASE ZIP = FALLBACK
# ================================================================

WORK_DIR=$(mktemp -d /tmp/ayah-alma.XXXXXX)
CLEAN_WORK=true

MAIN_DIR="$WORK_DIR/main"
ZIP_DIR=""

mkdir -p "$MAIN_DIR"

MAIN_GIT_URL="https://github.com/faisin/ayah-alma.git"
MAIN_URL="https://raw.githubusercontent.com/faisin/ayah-alma/main"

info "Mengambil source dari branch main..."

git clone \
    --depth 1 \
    --filter=blob:none \
    --single-branch \
    --branch main \
    "$MAIN_GIT_URL" \
    "$MAIN_DIR" \
    || die "Gagal mengambil repository main."

# ================================================================
# FILE WAJIB
# ================================================================

required=(
    install/nginx.sh
    install/xray.sh
    install/ssh.sh
    install/wg.sh
    install/zivpn.sh
    "bin/$ARCH/xray"
    "bin/$ARCH/zivpn"
    "bin/$ARCH/badvpn-udpgw"
    "bin/$ARCH/udp-custom"
    config/nginx.conf
    config/xray.conf
    config/xray.json
    config/haproxy.cfg
    config/license.conf
    config/udp-custom
    config/udp-custom.json
    config/issue.net
    sshws/udpgw.service
    sshws/udp-custom.service
    internal/go/dropbear-ws/main.go
    internal/go/dropbear-ws.service
    internal/go/stunnel-ws/main.go
    internal/go/stunnel-ws.service
    menu.sh
    uninstall.sh
    clearcache
)

missing=()

for rel in "${required[@]}"; do

    [[ -s "$MAIN_DIR/$rel" ]] \
        || missing+=("$rel")

done

if (( ${#missing[@]} > 0 )); then

    info "MAIN memiliki ${#missing[@]} file wajib yang belum ada/kosong."
    info "Mengambil release ZIP sebagai fallback..."

    ARCHIVE="$WORK_DIR/ayah-alma-release.zip"

    wget -q --show-progress --https-only \
        -O "$ARCHIVE" \
        "$RELEASE_URL" \
        || die "Gagal mengunduh release Ayah Alma."

    unzip -tq "$ARCHIVE" >/dev/null \
        || die "Release Ayah Alma rusak."

    unzip -q "$ARCHIVE" -d "$WORK_DIR/release"

    ZIP_DIR="$WORK_DIR/release/ayah-alma-main"

    [[ -d "$ZIP_DIR" ]] \
        || die "Struktur release Ayah Alma tidak valid."

    for rel in "${missing[@]}"; do

        if [[ -s "$ZIP_DIR/$rel" ]]; then

            mkdir -p "$MAIN_DIR/$(dirname "$rel")"

            cp -a "$ZIP_DIR/$rel" "$MAIN_DIR/$rel"

            info "ZIP fallback: $rel"

        else

            die "File wajib tidak tersedia di MAIN maupun release ZIP: $rel"

        fi

    done

fi

BASE_DIR="$MAIN_DIR"

# ================================================================
# RUNTIME/SOURCE TAMBAHAN DARI ZIP
# HANYA UNTUK FILE YANG BELUM ADA DI MAIN
# ================================================================

if [[ -n "$ZIP_DIR" ]]; then

    for dir in ssh xray wg udp tools sshws internal/go; do

        if [[ -d "$ZIP_DIR/$dir" ]]; then

            mkdir -p "$BASE_DIR/$dir"

            cp -an "$ZIP_DIR/$dir/." "$BASE_DIR/$dir/"

        fi

    done

fi

info "Sumber final: MAIN prioritas; ZIP hanya fallback untuk file MAIN yang hilang/kosong."

# ================================================================
# LICENSE CHECK
# ================================================================

LICENSE_URL="https://raw.githubusercontent.com/faisin/ayah-alma/main/config/license.conf"
LICENSE_FILE="$BASE_DIR/config/license.conf"

info "Memastikan konfigurasi lisensi dari main..."

mkdir -p "$(dirname "$LICENSE_FILE")"

if [[ ! -s "$LICENSE_FILE" ]]; then

    wget -q --https-only \
        -O "$LICENSE_FILE" \
        "$LICENSE_URL" \
        || die "Gagal mengambil license.conf dari repository main."

fi

[[ -s "$LICENSE_FILE" ]] \
    || die "license.conf dari repository main kosong."

source "$LICENSE_FILE"

declare -p ALLOWED_IPS >/dev/null 2>&1 \
    || die "Konfigurasi lisensi tidak valid: ALLOWED_IPS tidak ditemukan."

PUBLIC_IP=$(curl -4fsS --max-time 10 https://api.ipify.org 2>/dev/null || true)

[[ "$PUBLIC_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] \
    || die "Gagal mendapatkan IP VPS."

LICENSE_VALID=false

for allowed_ip in "${ALLOWED_IPS[@]}"; do

    if [[ "$PUBLIC_IP" == "$allowed_ip" ]]; then

        LICENSE_VALID=true
        break

    fi

done

[[ "$LICENSE_VALID" == true ]] \
    || die "IP VPS tidak memiliki lisensi: $PUBLIC_IP"

info "Lisensi valid: $PUBLIC_IP"

for rel in "${required[@]}"; do

    [[ -s "$BASE_DIR/$rel" ]] \
        || die "File wajib tidak ditemukan/kosong: $rel"

done

cd "$BASE_DIR"

# ================================================================
# NORMALIZE SOURCE
# ================================================================

while IFS= read -r -d '' f; do

    sed -i 's/\r$//' "$f"

    # Jangan periksa installer ini sendiri.
    [[ "$(basename "$f")" == "setup.sh" ]] && continue

    if grep -qE 'span_[0-9]+|start_span|end_span' "$f"; then

        die "File rusak mengandung marker span: ${f#$BASE_DIR/}"

    fi

done < <(
    find "$BASE_DIR" -type f \
        \
            -name '*.sh' \
            -o -name 'm-*' \
            -o -name '*.service' \
            -o -name '*.py' \
            -o -name '*.go' \
        \
        -print0
)

# ================================================================
# BASIC DIRECTORY
# ================================================================

mkdir -p \
    /etc/xray \
    /etc/v2ray \
    /var/lib \
    /etc/ayah-alma

local_ip=$(hostname -I | awk '{print $1}')
hostname_now=$(hostname)

if [[ -n "$local_ip" && -n "$hostname_now" ]] \
    && ! grep -Eq \
        "^[[:space:]]*${local_ip//./\.}[[:space:]]+${hostname_now}([[:space:]]|$)" \
        /etc/hosts; then

    echo "$local_ip $hostname_now" >> /etc/hosts

fi

ln -sf /usr/share/zoneinfo/Asia/Jakarta /etc/localtime

# ================================================================
# DOMAIN SETUP
# ================================================================

clear

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}         DOMAIN SETUP${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo "1. Domain otomatis (IP.sslip.io)"
echo "2. Domain sendiri"

read_prompt "Pilih opsi (1/2): " pilihan

if [[ "$pilihan" == "1" ]]; then

    pub_ip=$(curl -4fsS --max-time 10 https://api.ipify.org 2>/dev/null || true)

    [[ -n "$pub_ip" ]] \
        || pub_ip=$(hostname -I | awk '{print $1}')

    [[ "$pub_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] \
        || die "IP publik tidak berhasil dideteksi."

    domain="${pub_ip}.sslip.io"

elif [[ "$pilihan" == "2" ]]; then

    read_prompt "Masukkan domain kamu: " domain

    [[ "$domain" =~ ^[A-Za-z0-9.-]+$ ]] \
        || die "Format domain tidak valid."

else

    die "Pilihan domain tidak valid."

fi

for f in \
    /root/domain \
    /root/scdomain \
    /etc/xray/domain \
    /etc/xray/scdomain \
    /etc/v2ray/domain \
    /etc/v2ray/scdomain; do

    printf '%s\n' "$domain" > "$f"

done

printf 'OS=%s\nIP=%s\n' "$PRETTY_NAME" "$domain" > /var/lib/ipvps.conf

info "Domain: $domain"

# ================================================================
# MODULE RUNNER
# ================================================================

run_module(){
    local rel="$1"

    [[ -f "$BASE_DIR/$rel" ]] \
        || die "Module tidak ditemukan: $rel"

    info "Menjalankan $rel ..."

    (
        cd "$BASE_DIR"
        bash "$BASE_DIR/$rel"
    )
}

# ================================================================
# NGINX BOOTSTRAP
# ================================================================

# Bootstrap Nginx hanya untuk HTTP/Webroot ACME.
# xray.conf FINAL dipasang oleh xray.sh setelah sertifikat tersedia.

rm -f \
    /etc/nginx/conf.d/xray.conf \
    /etc/nginx/conf.d/acme-bootstrap.conf

run_module install/nginx.sh

systemctl is-active --quiet nginx \
    || die "Nginx bootstrap gagal aktif."

# ================================================================
# XRAY INSTALL
# ================================================================

run_module install/xray.sh

# ================================================================
# XRAY API + STATS
#
# API hanya listen di 127.0.0.1.
# Tidak dibuka ke internet.
#
# API digunakan untuk membaca sesi online user VMess.
# ================================================================

info "Mengaktifkan Xray API + Stats..."

python3 - <<'PY'
import json
import shutil
import os
import sys

CONFIG = "/etc/xray/config.json"
BACKUP = "/etc/xray/config.json.before-api"

if not os.path.isfile(CONFIG):
    print("[ERROR] /etc/xray/config.json tidak ditemukan.")
    sys.exit(1)

# Backup hanya dibuat bila belum ada.
if not os.path.exists(BACKUP):
    shutil.copy2(CONFIG, BACKUP)

with open(CONFIG, "r", encoding="utf-8") as f:
    config = json.load(f)

# ------------------------------------------------
# API SERVICES
# ------------------------------------------------

config["api"] = {
    "tag": "api",
    "services": [
        "HandlerService",
        "LoggerService",
        "StatsService"
    ]
}

# ------------------------------------------------
# STATS
# ------------------------------------------------

config["stats"] = {}

# ------------------------------------------------
# API INBOUND
# ------------------------------------------------

inbounds = config.setdefault("inbounds", [])

api_inbound = None

for inbound in inbounds:
    if inbound.get("tag") == "api":
        api_inbound = inbound
        break

if api_inbound is None:

    api_inbound = {
        "listen": "127.0.0.1",
        "port": 10085,
        "protocol": "dokodemo-door",
        "settings": {
            "address": "127.0.0.1"
        },
        "tag": "api"
    }

    inbounds.insert(0, api_inbound)

else:

    # Pastikan API tidak terbuka ke publik.
    api_inbound["listen"] = "127.0.0.1"
    api_inbound["port"] = 10085
    api_inbound["protocol"] = "dokodemo-door"
    api_inbound["settings"] = {
        "address": "127.0.0.1"
    }

# ------------------------------------------------
# ROUTING API
# ------------------------------------------------

routing = config.setdefault("routing", {})

rules = routing.setdefault("rules", [])

api_rule_exists = False

for rule in rules:

    if (
        rule.get("type") == "field"
        and "api" in rule.get("inboundTag", [])
        and rule.get("outboundTag") == "api"
    ):
        api_rule_exists = True
        break

if not api_rule_exists:

    rules.insert(
        0,
        {
            "type": "field",
            "inboundTag": ["api"],
            "outboundTag": "api"
        }
    )

# ------------------------------------------------
# WRITE
# ------------------------------------------------

tmp = CONFIG + ".tmp"

with open(tmp, "w", encoding="utf-8") as f:
    json.dump(config, f, indent=2)
    f.write("\n")

os.replace(tmp, CONFIG)

print("[INFO] Xray API + Stats berhasil dipasang.")
print("[INFO] API listen: 127.0.0.1:10085")
PY

# ================================================================
# TEST XRAY CONFIG
# ================================================================

info "Memeriksa konfigurasi Xray setelah API + Stats..."

xray run -test -config /etc/xray/config.json \
    || die "Konfigurasi Xray setelah API/Stats tidak valid."

info "Xray API + Stats: OK"

# ================================================================
# INSTALL MODULE LAIN
# ================================================================

run_module install/ssh.sh
run_module install/wg.sh
run_module install/zivpn.sh

# ================================================================
# RUNTIME AYAH ALMA
# ================================================================

info "Memasang runtime Ayah Alma..."

mkdir -p \
    "$INSTALL_ROOT"/ssh \
    "$INSTALL_ROOT"/xray \
    "$INSTALL_ROOT"/wg \
    "$INSTALL_ROOT"/udp \
    "$INSTALL_ROOT"/tools \
    "$INSTALL_ROOT"/config \
    "$INSTALL_ROOT"/sshws \
    "$INSTALL_ROOT"/internal/go

for dir in ssh xray wg udp tools config sshws; do

    cp -a "$BASE_DIR/$dir/." "$INSTALL_ROOT/$dir/"

done

cp -a \
    "$BASE_DIR/internal/go/." \
    "$INSTALL_ROOT/internal/go/"

for f in \
    "$BASE_DIR"/ssh/* \
    "$BASE_DIR"/xray/* \
    "$BASE_DIR"/wg/* \
    "$BASE_DIR"/udp/* \
    "$BASE_DIR"/tools/*; do

    [[ -f "$f" ]] || continue

    install

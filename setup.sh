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
        read -rp "$prompt" "$var" </dev/tty || die "Input dibatalkan atau tidak dapat dibaca."
    else
        read -rp "$prompt" "$var" || die "Installer membutuhkan terminal interaktif untuk memilih domain. Jalankan kembali dari sesi SSH/terminal."
    fi
}

on_error(){
    local line=$1 code=$2
    echo -e "${RED}[ERROR]${NC} setup.sh gagal pada baris ${line} (exit ${code})." >&2
    echo "Log: /root/log-install.txt" >&2
}

trap 'on_error $LINENO $?' ERR
cleanup(){ [[ "$CLEAN_WORK" == true && -n "$WORK_DIR" ]] && rm -rf "$WORK_DIR"; }
trap cleanup EXIT

[[ $EUID -eq 0 ]] || die "Jalankan sebagai root."
command -v apt-get >/dev/null 2>&1 || die "Installer ini mendukung Ubuntu/Debian."
[[ -f /etc/os-release ]] || die "Tidak dapat membaca /etc/os-release."
. /etc/os-release

case "${ID:-}" in
    ubuntu|debian) ;;
    *) die "OS ${PRETTY_NAME:-unknown} belum didukung." ;;
esac

ARCH=$(dpkg --print-architecture)
case "$ARCH" in
    amd64|arm64) ;;
    *) die "Arsitektur $ARCH belum didukung. Gunakan amd64 atau arm64." ;;
esac

if command -v systemd-detect-virt >/dev/null 2>&1; then
    [[ "$(systemd-detect-virt || true)" != "openvz" ]] || die "OpenVZ tidak didukung."
fi

# Semua layanan dipasang sebagai unit systemd; hentikan lebih awal jika PID 1 bukan systemd.
[[ "$(ps -p 1 -o comm= 2>/dev/null | tr -d '[:space:]')" == "systemd" ]] \
    || die "Sistem ini tidak menjalankan systemd sebagai PID 1; layanan Ayah Alma tidak dapat dikelola dengan benar."

# Pilih lokasi kerja dengan ruang kosong minimal 1 GiB.
# Jangan memaksa /tmp: pada sebagian VPS, /tmp berupa tmpfs kecil.
MIN_FREE_KB=1048576
BEST_BASE=""
BEST_FREE_KB=0
for candidate in /var/tmp /root /tmp; do
    [[ -d "$candidate" && -w "$candidate" ]] || continue
    available_kb=$(df -Pk "$candidate" 2>/dev/null | awk 'NR == 2 {print $4}')
    [[ "$available_kb" =~ ^[0-9]+$ ]] || continue
    if (( available_kb > BEST_FREE_KB )); then
        BEST_BASE="$candidate"
        BEST_FREE_KB="$available_kb"
    fi
done
(( BEST_FREE_KB >= MIN_FREE_KB )) \
    || die "Ruang kosong kurang dari 1 GiB pada lokasi kerja (/var/tmp, /root, /tmp). Kosongkan disk lalu ulangi instalasi."
WORK_DIR=$(mktemp -d "$BEST_BASE/ayah-alma.XXXXXX") \
    || die "Gagal membuat direktori kerja pada $BEST_BASE."
CLEAN_WORK=true

: > /root/log-install.txt
exec > >(tee -a /root/log-install.txt) 2>&1

info "AYAH-ALMA AIO installer dimulai."
info "OS: ${PRETTY_NAME:-$ID} | Arch: $ARCH"

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y \
    ca-certificates curl wget jq tar gzip unzip git \
    python3 python3-pip coreutils openssl iptables \
    iptables-persistent netfilter-persistent vnstat screen \
    golang-go file

# Buka port publik yang memang dipakai layanan. Port 2082/2096/7300 hanya
# dipakai di loopback; 51820/UDP diperlukan WireGuard.
allow_iptables_port() {
    local family="$1" protocol="$2" port="$3"
    local cmd="iptables"
    [[ "$family" == "6" ]] && cmd="ip6tables"

    if ! command -v "$cmd" >/dev/null 2>&1; then
        [[ "$family" == "6" ]] && return 0
        die "Perintah $cmd tidak ditemukan."
    fi

    if ! "$cmd" -C INPUT -p "$protocol" --dport "$port" -j ACCEPT 2>/dev/null; then
        if ! "$cmd" -I INPUT 1 -p "$protocol" --dport "$port" -j ACCEPT; then
            if [[ "$family" == "6" ]]; then
                warn "Tidak dapat menambahkan aturan IPv6 untuk $protocol/$port; lanjutkan dengan pemeriksaan firewall provider." 
            else
                die "Gagal membuka port $protocol/$port pada firewall IPv4."
            fi
        fi
    fi
}

# Izinkan juga port SSH aktif bila VPS memakai port non-standar.
SSH_PORTS=(22)
if command -v sshd >/dev/null 2>&1; then
    while IFS= read -r ssh_port; do
        [[ "$ssh_port" =~ ^[0-9]+$ ]] && SSH_PORTS+=("$ssh_port")
    done < <(sshd -T 2>/dev/null | awk '$1 == "port" {print $2}' | sort -nu)
fi
for port in "${SSH_PORTS[@]}" 80 109 143 443 444 10011 10012 10013; do
    allow_iptables_port 4 tcp "$port"
    allow_iptables_port 6 tcp "$port"
done
for port in 51820 5667; do
    allow_iptables_port 4 udp "$port"
    allow_iptables_port 6 udp "$port"
done

if command -v netfilter-persistent >/dev/null 2>&1; then
    netfilter-persistent save >/dev/null 2>&1 || warn "Aturan firewall belum berhasil disimpan secara persisten."
fi

SOURCE_FILE="${BASH_SOURCE[0]:-}"

if [[ -n "$SOURCE_FILE" && -f "$SOURCE_FILE" ]]; then
    SELF_DIR="$(cd -- "$(dirname -- "$SOURCE_FILE")" && pwd)"
else
    SELF_DIR="$PWD"
fi

# MAIN GitHub adalah sumber utama; Release ZIP melengkapi file besar/runtime.
MAIN_DIR="$WORK_DIR/main"
ZIP_DIR=""
mkdir -p "$MAIN_DIR"

MAIN_GIT_URL="https://github.com/faisin/ayah-alma.git"

info "Mengambil source dari branch main..."

git clone --depth 1 --filter=blob:none --single-branch --branch main \
    "$MAIN_GIT_URL" "$MAIN_DIR" \
    || die "Gagal mengambil repository main."

required=(
    install/haproxy.sh
    install/xray.sh
    install/ssh.sh
    install/wg.sh
    install/zivpn.sh
    "bin/$ARCH/xray"
    "bin/$ARCH/zivpn"
    "bin/$ARCH/badvpn-udpgw"
    "bin/$ARCH/udp-custom"
    config/haproxy.cfg
    config/nginx-fallback.conf
    config/www/index.html
    config/xray.json
    ssh/addssh.sh
    ssh/trialssh.sh
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
    internal/go/go.mod
    menu.sh
    uninstall.sh
    clearcache
)

# Release ZIP hanya fallback bila ada file wajib yang tidak tersedia di branch main.
# File yang sudah ada di main tidak pernah ditimpa oleh Release.
missing_from_main=()
for rel in "${required[@]}"; do
    [[ -s "$MAIN_DIR/$rel" ]] || missing_from_main+=("$rel")
done

if (( ${#missing_from_main[@]} > 0 )); then
    info "Ada ${#missing_from_main[@]} file wajib yang belum ada di main; mencoba Release ZIP sebagai fallback..."
    ARCHIVE="$WORK_DIR/ayah-alma-release.zip"
    if wget -q --show-progress --https-only -O "$ARCHIVE" "$RELEASE_URL"; then
        unzip -tq "$ARCHIVE" >/dev/null || die "Release Ayah Alma rusak."
        mkdir -p "$WORK_DIR/release"
        unzip -q "$ARCHIVE" -d "$WORK_DIR/release"

        ZIP_DIR=""
        while IFS= read -r -d '' candidate; do
            if [[ -s "$candidate/install/xray.sh" && -s "$candidate/config/xray.json" ]]; then
                ZIP_DIR="$candidate"
                break
            fi
        done < <(
            find "$WORK_DIR/release" -type f -path '*/install/xray.sh' -print0 |
            while IFS= read -r -d '' f; do
                printf '%s\0' "$(dirname "$(dirname "$f")")"
            done
        )
        [[ -n "$ZIP_DIR" && -d "$ZIP_DIR" ]] || die "Struktur Release tidak valid."

        for rel in "${missing_from_main[@]}"; do
            if [[ ! -s "$MAIN_DIR/$rel" && -s "$ZIP_DIR/$rel" ]]; then
                mkdir -p "$MAIN_DIR/$(dirname "$rel")"
                cp -p "$ZIP_DIR/$rel" "$MAIN_DIR/$rel"
                info "Release fallback: $rel"
            fi
        done
    else
        warn "Release ZIP tidak dapat diunduh; lanjut memeriksa apakah file wajib tersedia dari sumber resmi lain."
    fi
else
    info "Semua file wajib tersedia di branch main; Release ZIP tidak diperlukan."
fi

# Arsip source yang diberikan tidak selalu menyertakan binary Xray. Jika tidak
# tersedia di branch/Release, ambil binary resmi XTLS dan verifikasi SHA-256
# dari file .dgst resmi sebelum mengekstraknya.
if [[ ! -s "$MAIN_DIR/bin/$ARCH/xray" ]]; then
    case "$ARCH" in
        amd64) XRAY_ASSET="Xray-linux-64.zip" ;;
        arm64) XRAY_ASSET="Xray-linux-arm64-v8a.zip" ;;
        *) die "Tidak ada binary Xray resmi yang dipetakan untuk arsitektur $ARCH." ;;
    esac
    info "Binary Xray tidak ada di source/Release; mengambil binary resmi XTLS ($XRAY_ASSET)..."
    XRAY_RELEASE_JSON="$WORK_DIR/xray-release.json"
    XRAY_ARCHIVE="$WORK_DIR/$XRAY_ASSET"
    XRAY_DIGEST="$WORK_DIR/$XRAY_ASSET.dgst"
    curl -fsSL --retry 3 --connect-timeout 15 \
        https://api.github.com/repos/XTLS/Xray-core/releases/latest -o "$XRAY_RELEASE_JSON" \
        || die "Gagal membaca metadata release resmi Xray."
    XRAY_URL=$(jq -r --arg name "$XRAY_ASSET" '.assets[]? | select(.name == $name) | .browser_download_url' "$XRAY_RELEASE_JSON" | head -n1)
    XRAY_DIGEST_URL=$(jq -r --arg name "$XRAY_ASSET.dgst" '.assets[]? | select(.name == $name) | .browser_download_url' "$XRAY_RELEASE_JSON" | head -n1)
    [[ "$XRAY_URL" == https://github.com/XTLS/Xray-core/releases/download/* ]] \
        || die "Asset Xray resmi $XRAY_ASSET tidak ditemukan pada release terbaru."
    [[ "$XRAY_DIGEST_URL" == https://github.com/XTLS/Xray-core/releases/download/* ]] \
        || die "Checksum resmi $XRAY_ASSET.dgst tidak ditemukan; binary tidak akan diunduh tanpa verifikasi."
    curl -fsSL --retry 3 --connect-timeout 15 "$XRAY_URL" -o "$XRAY_ARCHIVE" \
        || die "Gagal mengunduh binary Xray resmi."
    curl -fsSL --retry 3 --connect-timeout 15 "$XRAY_DIGEST_URL" -o "$XRAY_DIGEST" \
        || die "Gagal mengunduh checksum Xray resmi."
    EXPECTED_SHA256=$(awk '$1 == "SHA256:" {print $2; exit}' "$XRAY_DIGEST")
    ACTUAL_SHA256=$(sha256sum "$XRAY_ARCHIVE" | awk '{print $1}')
    [[ "$EXPECTED_SHA256" =~ ^[[:xdigit:]]{64}$ && "${EXPECTED_SHA256,,}" == "${ACTUAL_SHA256,,}" ]] \
        || die "Verifikasi SHA-256 binary Xray gagal."
    unzip -tq "$XRAY_ARCHIVE" >/dev/null || die "Arsip binary Xray resmi rusak."
    XRAY_MEMBER=$(unzip -Z1 "$XRAY_ARCHIVE" | awk '$0 == "xray" {print; exit}')
    [[ -n "$XRAY_MEMBER" ]] || die "Binary xray tidak ditemukan di dalam arsip resmi."
    mkdir -p "$MAIN_DIR/bin/$ARCH"
    unzip -p "$XRAY_ARCHIVE" "$XRAY_MEMBER" > "$MAIN_DIR/bin/$ARCH/xray"
    chmod 755 "$MAIN_DIR/bin/$ARCH/xray"
    info "Binary Xray resmi berhasil diverifikasi dan disiapkan."
fi

missing=()
for rel in "${required[@]}"; do
    if [[ ! -s "$MAIN_DIR/$rel" ]]; then
        missing+=("$rel")
    fi
done

if (( ${#missing[@]} > 0 )); then
    printf 'File wajib hilang dari branch main (atau binary tidak tersedia di Release):\n' >&2
    printf ' - %s\n' "${missing[@]}" >&2
    die "Source/runtime tidak lengkap; installer dihentikan sebelum pemasangan."
fi

BASE_DIR="$MAIN_DIR"
rm -f "$BASE_DIR/config/xray.conf" "$BASE_DIR/config/xray-stream.conf"

info "Sumber final: branch main; Release hanya mengisi file wajib yang hilang dan tidak menimpa file main."

# Validasi sintaks modul yang akan dieksekusi sebelum mengubah layanan sistem.
for script in install/haproxy.sh install/xray.sh install/ssh.sh install/wg.sh install/zivpn.sh; do
    bash -n "$BASE_DIR/$script" || die "Sintaks Bash tidak valid: $script"
done
jq -e . "$BASE_DIR/config/xray.json" >/dev/null || die "config/xray.json bukan JSON valid."
for rel in "bin/$ARCH/xray" "bin/$ARCH/zivpn" "bin/$ARCH/badvpn-udpgw" "bin/$ARCH/udp-custom"; do
    file "$BASE_DIR/$rel" | grep -q 'ELF' || die "Binary tidak valid atau bukan ELF: $rel"
done

# ================= LICENSE CHECK =================
LICENSE_URL="https://raw.githubusercontent.com/faisin/ayah-alma/main/config/license.conf"
LICENSE_FILE="$BASE_DIR/config/license.conf"

info "Memastikan konfigurasi lisensi dari main..."

mkdir -p "$(dirname "$LICENSE_FILE")"
LICENSE_TMP="$WORK_DIR/license.conf"

if ! wget -q --https-only --timeout=20 --tries=3 \
    -O "$LICENSE_TMP" "$LICENSE_URL"; then
    die "Gagal mengambil license.conf terbaru dari repository main. Periksa koneksi GitHub."
fi

[[ -s "$LICENSE_TMP" ]] || die "license.conf dari repository main kosong."

grep -Eq '^ALLOWED_IPS=\(' "$LICENSE_TMP" \
    || die "Format license.conf tidak valid: ALLOWED_IPS array tidak ditemukan."

cp -f "$LICENSE_TMP" "$LICENSE_FILE"
# Parse daftar IP sebagai data; jangan source file yang diunduh sebagai kode shell.
mapfile -t ALLOWED_IPS < <(sed -nE 's/^[[:space:]]*"([0-9]{1,3}(\.[0-9]{1,3}){3})"[[:space:]]*$/\1/p' "$LICENSE_FILE")
(( ${#ALLOWED_IPS[@]} > 0 )) \
    || die "Konfigurasi lisensi tidak valid: tidak ada IP IPv4 yang dapat dibaca."
for allowed_ip in "${ALLOWED_IPS[@]}"; do
    [[ "$allowed_ip" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] \
        || die "Konfigurasi lisensi berisi IP yang tidak valid."
    IFS='.' read -r -a ip_octets <<< "$allowed_ip"
    for octet in "${ip_octets[@]}"; do
        (( 10#$octet <= 255 )) || die "Konfigurasi lisensi berisi IP yang tidak valid: $allowed_ip"
    done
done

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
    [[ -s "$BASE_DIR/$rel" ]] || die "File wajib tidak ditemukan/kosong: $rel"
done

cd "$BASE_DIR"

# Normalisasi line endings dan deteksi marker yang tidak semestinya.
while IFS= read -r -d '' f; do
    sed -i 's/\r$//' "$f"

    [[ "$(basename "$f")" == "setup.sh" ]] && continue

    if grep -qE '\[span_[0-9]+\]|start_span|end_span' "$f"; then
        die "File rusak mengandung marker span: ${f#$BASE_DIR/}"
    fi
done < <(
    find "$BASE_DIR" -type f \
        \( -name '*.sh' -o -name 'm-*' -o -name '*.service' -o -name '*.py' -o -name '*.go' \) \
        -print0
)

mkdir -p /etc/xray /etc/v2ray /var/lib /etc/ayah-alma

local_ip=$(hostname -I | awk '{print $1}')
hostname_now=$(hostname)

if [[ -n "$local_ip" && -n "$hostname_now" ]] &&
    ! grep -Eq "^[[:space:]]*${local_ip//./\.}[[:space:]]+${hostname_now}([[:space:]]|$)" /etc/hosts; then
    echo "$local_ip $hostname_now" >> /etc/hosts
fi

ln -sf /usr/share/zoneinfo/Asia/Jakarta /etc/localtime

# ================= DOMAIN SETUP =================
clear >/dev/null 2>&1 || true

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}         DOMAIN SETUP${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo "1. Domain otomatis (IP.sslip.io)"
echo "2. Domain sendiri"

read_prompt "Pilih opsi (1/2): " pilihan

if [[ "$pilihan" == "1" ]]; then
    pub_ip=$(curl -4fsS --max-time 10 https://api.ipify.org 2>/dev/null || true)
    [[ -n "$pub_ip" ]] || pub_ip=$(hostname -I | awk '{print $1}')

    [[ "$pub_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] \
        || die "IP publik tidak berhasil dideteksi."

    domain="${pub_ip}.sslip.io"

elif [[ "$pilihan" == "2" ]]; then
    read_prompt "Masukkan domain atau subdomain Anda: " domain
    domain="${domain,,}"

    # Tidak membatasi jumlah tingkat subdomain.
    [[ -n "$domain" ]] || die "Domain tidak boleh kosong."
    [[ ${#domain} -le 253 ]] || die "Domain terlalu panjang (maksimal 253 karakter)."
    [[ "$domain" =~ ^[a-z0-9.-]+$ ]] || die "Format domain tidak valid."
    [[ "$domain" != *..* && "$domain" != .* && "$domain" != *. ]] \
        || die "Format domain tidak valid."

    IFS='.' read -r -a domain_labels <<< "$domain"
    IFS=$'\n\t'

    (( ${#domain_labels[@]} >= 2 )) \
        || die "Domain harus memiliki minimal dua bagian, misalnya contoh.com."

    for label in "${domain_labels[@]}"; do
        [[ ${#label} -le 63 && "$label" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]] \
            || die "Label domain tidak valid: $label"
    done

    unset domain_labels

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

# ================= MODULE INSTALLATION =================
run_module(){
    local rel="$1"
    [[ -f "$BASE_DIR/$rel" ]] || die "Module tidak ditemukan: $rel"
    info "Menjalankan $rel ..."
    (cd "$BASE_DIR" && bash "$BASE_DIR/$rel")
}

# HAProxy dipasang terlebih dahulu tetapi tidak bind port sampai sertifikat siap.
run_module install/haproxy.sh
command -v haproxy >/dev/null 2>&1 || die "HAProxy tidak terpasang."

run_module install/xray.sh
run_module install/ssh.sh
run_module install/wg.sh
run_module install/zivpn.sh

# ================= INSTALL RUNTIME =================
info "Memasang runtime Ayah Alma..."

mkdir -p "$INSTALL_ROOT"/{ssh,xray,wg,udp,tools,config,sshws,internal/go}

for dir in ssh xray wg udp tools config sshws; do
    [[ -d "$BASE_DIR/$dir" ]] && cp -a "$BASE_DIR/$dir/." "$INSTALL_ROOT/$dir/"
done

[[ -d "$BASE_DIR/internal/go" ]] &&
    cp -a "$BASE_DIR/internal/go/." "$INSTALL_ROOT/internal/go/"

for f in \
    "$BASE_DIR"/ssh/* \
    "$BASE_DIR"/xray/* \
    "$BASE_DIR"/wg/* \
    "$BASE_DIR"/udp/* \
    "$BASE_DIR"/tools/*; do
    [[ -f "$f" ]] || continue
    install -m 755 "$f" "/usr/bin/$(basename "$f")"
done

install -m 755 "$BASE_DIR/menu.sh" /usr/bin/menu
install -m 755 "$BASE_DIR/clearcache" /usr/bin/clearcache
install -m 755 "$BASE_DIR/uninstall.sh" /root/uninstall.sh

for f in \
    /usr/local/bin/xray \
    /usr/local/bin/dropbearws \
    /usr/local/bin/stunnelws \
    /usr/local/bin/badvpn-udpgw \
    /usr/local/bin/udp-custom \
    /usr/local/bin/zivpn; do
    [[ -x "$f" ]] || die "Binary wajib tidak executable: $f"
done

[[ -f /etc/xray/config.json ]] || die "Xray config tidak terpasang."
[[ -f /etc/haproxy/haproxy.cfg ]] || die "Konfigurasi HAProxy tidak terpasang."
[[ -f /etc/wireguard/wg0.conf ]] || die "WireGuard config tidak terpasang."

systemctl daemon-reload

services=(
    xray
    haproxy
    ssh
    dropbear
    dropbear-ws
    stunnel-ws
    udpgw
    udp-custom
    wg-quick@wg0
    zivpn
)

for svc in "${services[@]}"; do
    systemctl enable "$svc" >/dev/null 2>&1 \
        || die "Gagal enable service $svc"

    systemctl restart "$svc" >/dev/null 2>&1 \
        || {
            systemctl status "$svc" --no-pager || true
            die "Service $svc gagal start."
        }
done

for svc in "${services[@]}"; do
    systemctl is-active --quiet "$svc" \
        || {
            systemctl status "$svc" --no-pager || true
            die "Health check gagal: $svc"
        }
done

# ================= ROOT PROFILE =================
PROFILE_MARKER="# BEGIN AYAH-ALMA MENU"
if ! grep -Fq "$PROFILE_MARKER" /root/.profile 2>/dev/null; then
    cat >> /root/.profile <<'EOF'

# BEGIN AYAH-ALMA MENU
if [ "$BASH" ] && [ -f ~/.bashrc ]; then . ~/.bashrc; fi
if [ -t 0 ] && [ -t 1 ] && command -v menu >/dev/null 2>&1; then
    clear
    menu
fi
# END AYAH-ALMA MENU
EOF
fi
chmod 644 /root/.profile

printf '\nAYAH-ALMA INSTALLATION SUCCESSFUL\n' >> /root/log-install.txt

elapsed=$(( $(date +%s) - START_TIME ))

clear >/dev/null 2>&1 || true

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}   AYAH-ALMA INSTALLATION DONE${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo "Domain      : $domain"
echo "Xray        : OK"
echo "HAProxy     : OK"
echo "SSH/WS      : OK"
echo "WireGuard   : OK"
echo "UDP Custom  : OK"
echo "ZiVPN       : OK"
echo "Waktu       : $((elapsed/60)) menit $((elapsed%60)) detik"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
warn "Tidak otomatis reboot. Jalankan reboot jika diperlukan."

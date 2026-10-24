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

# Buka HTTP/HTTPS, SSH SSL-only, dan TCP TLS proxy pada firewall host.
# Ini sengaja ditempatkan di depan rule REJECT yang mungkin sudah ada.
for port in 80 443 444 10011 10012 10013; do
    iptables -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null \
        || iptables -I INPUT 1 -p tcp --dport "$port" -j ACCEPT
    if command -v ip6tables >/dev/null 2>&1; then
        ip6tables -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null \
            || ip6tables -I INPUT 1 -p tcp --dport "$port" -j ACCEPT
    fi
done

# UDP ZiVPN gateway. Xray carries proxied UDP inside its authenticated proxy
# connection; it does not require a separate public Xray UDP listener.
iptables -C INPUT -p udp --dport 5667 -j ACCEPT 2>/dev/null \
    || iptables -I INPUT 1 -p udp --dport 5667 -j ACCEPT
if command -v ip6tables >/dev/null 2>&1; then
    ip6tables -C INPUT -p udp --dport 5667 -j ACCEPT 2>/dev/null \
        || ip6tables -I INPUT 1 -p udp --dport 5667 -j ACCEPT
fi

if command -v netfilter-persistent >/dev/null 2>&1; then
    netfilter-persistent save >/dev/null 2>&1 || true
fi

SOURCE_FILE="${BASH_SOURCE[0]:-}"
if [[ -n "$SOURCE_FILE" && -f "$SOURCE_FILE" ]]; then
    SELF_DIR="$(cd -- "$(dirname -- "$SOURCE_FILE")" && pwd)"
else
    SELF_DIR="$PWD"
fi

# MAIN GitHub adalah sumber utama; Release ZIP melengkapi file besar/runtime.
# Semua file dari Release hanya menjadi fallback: file yang sudah ada di MAIN
# tidak ditimpa. File wajib yang hilang/kosong boleh dipulihkan dari Release.
WORK_DIR=$(mktemp -d /tmp/ayah-alma.XXXXXX)
CLEAN_WORK=true
MAIN_DIR="$WORK_DIR/main"
ZIP_DIR=""
mkdir -p "$MAIN_DIR"

MAIN_GIT_URL="https://github.com/faisin/ayah-alma.git"

info "Mengambil source dari branch main..."
git clone --depth 1 --filter=blob:none --single-branch --branch main "$MAIN_GIT_URL" "$MAIN_DIR" \
    || die "Gagal mengambil repository main."

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
    config/xray.conf
    config/xray.json
    config/xray-stream.conf
    SSH-SSL-ONLY.txt
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
    menu.sh
    uninstall.sh
    clearcache
)

info "Mengambil Release ZIP untuk melengkapi file besar/runtime yang tidak ada di MAIN..."
ARCHIVE="$WORK_DIR/ayah-alma-release.zip"
wget -q --show-progress --https-only -O "$ARCHIVE" "$RELEASE_URL" \
    || die "Gagal mengunduh release Ayah Alma."
unzip -tq "$ARCHIVE" >/dev/null || die "Release Ayah Alma rusak."
unzip -q "$ARCHIVE" -d "$WORK_DIR/release"
ZIP_DIR="$WORK_DIR/release/ayah-alma-main"
[[ -d "$ZIP_DIR" ]] || die "Struktur release Ayah Alma tidak valid."

# Fitur HTTP-01 Standalone + SSH SSL-only harus memakai modul yang sesuai.
# File fitur ini sengaja di-overlay dari Release meskipun versi lama sudah ada di MAIN.
# Jika setup.sh dijalankan dari ZIP hasil paket, file lokal menjadi prioritas terakhir.
FEATURE_FILES=(
    install/nginx.sh
    install/xray.sh
    install/ssh.sh
    config/xray.conf
    config/xray-stream.conf
    ssh/addssh.sh
    ssh/trialssh.sh
    SSH-SSL-ONLY.txt
)
for rel in "${FEATURE_FILES[@]}"; do
    if [[ -s "$ZIP_DIR/$rel" ]]; then
        mkdir -p "$MAIN_DIR/$(dirname "$rel")"
        cp -f "$ZIP_DIR/$rel" "$MAIN_DIR/$rel"
        info "Memuat modul fitur dari Release: $rel"
    fi
done

# Bila installer dijalankan langsung dari folder ZIP, gunakan file fitur lokal
# sebagai sumber terakhir agar paket ini tetap lengkap walau Release belum diperbarui.
PACKAGE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
for rel in "${FEATURE_FILES[@]}"; do
    if [[ -s "$PACKAGE_DIR/$rel" ]]; then
        mkdir -p "$MAIN_DIR/$(dirname "$rel")"
        cp -f "$PACKAGE_DIR/$rel" "$MAIN_DIR/$rel"
        info "Memuat modul fitur dari paket lokal: $rel"
    fi
done

missing=()
for rel in "${required[@]}"; do
    if [[ ! -s "$MAIN_DIR/$rel" ]]; then
        if [[ -s "$ZIP_DIR/$rel" ]]; then
            mkdir -p "$MAIN_DIR/$(dirname "$rel")"
            cp -f "$ZIP_DIR/$rel" "$MAIN_DIR/$rel"
            info "Release fallback untuk file wajib: $rel"
        else
            missing+=("$rel")
        fi
    fi
done
if (( ${#missing[@]} > 0 )); then
    printf 'File wajib hilang dari MAIN dan Release:\n' >&2
    printf ' - %s\n' "${missing[@]}" >&2
    die "Source tidak lengkap; installer dihentikan sebelum pemasangan."
fi

BASE_DIR="$MAIN_DIR"

# Lengkapi file runtime/biner besar dari Release hanya jika belum ada di MAIN.
# cp -an menjaga file MAIN, termasuk menu.sh dan varian menu, tetap utuh.
for dir in "bin/$ARCH" ssh xray wg udp tools config sshws internal/go; do
    if [[ -d "$ZIP_DIR/$dir" ]]; then
        mkdir -p "$BASE_DIR/$dir"
        cp -an "$ZIP_DIR/$dir/." "$BASE_DIR/$dir/"
    fi
done

info "Sumber final: MAIN prioritas; Release melengkapi file hilang tanpa menimpa file MAIN."

# ================= LICENSE CHECK =================
# license.conf selalu diambil langsung dari branch main.
LICENSE_URL="https://raw.githubusercontent.com/faisin/ayah-alma/main/config/license.conf"
LICENSE_FILE="$BASE_DIR/config/license.conf"

info "Memastikan konfigurasi lisensi dari main..."

mkdir -p "$(dirname "$LICENSE_FILE")"
LICENSE_TMP="$WORK_DIR/license.conf"
if ! wget -q --https-only --timeout=20 --tries=3 -O "$LICENSE_TMP" "$LICENSE_URL"; then
    die "Gagal mengambil license.conf terbaru dari repository main. Periksa koneksi GitHub."
fi
[[ -s "$LICENSE_TMP" ]] || die "license.conf dari repository main kosong."
# File lisensi yang diambil harus mendefinisikan ALLOWED_IPS sebagai array Bash.
grep -Eq '^ALLOWED_IPS=\(' "$LICENSE_TMP" \
    || die "Format license.conf tidak valid: ALLOWED_IPS array tidak ditemukan."
cp -f "$LICENSE_TMP" "$LICENSE_FILE"
source "$LICENSE_FILE"

declare -p ALLOWED_IPS 2>/dev/null | grep -q '^declare -a ALLOWED_IPS=' \
    || die "Konfigurasi lisensi tidak valid: ALLOWED_IPS bukan array."

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

for rel in "${required[@]}"; do [[ -s "$BASE_DIR/$rel" ]] || die "File wajib tidak ditemukan/kosong: $rel"; done
cd "$BASE_DIR"

# Normalize line endings and detect accidental span markers.
while IFS= read -r -d '' f; do
    sed -i 's/\r$//' "$f"

    # Jangan periksa installer ini sendiri.
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
    read_prompt "Masukkan domain utama (contoh adyersasak.my.id, tanpa subdomain): " domain
    [[ "$domain" =~ ^[A-Za-z0-9.-]+$ ]] || die "Format domain tidak valid."
    [[ "$domain" != *.*.*.* ]] || die "Format domain tidak valid."
    [[ "$domain" != *..* && "$domain" != .* && "$domain" != *. ]] || die "Format domain tidak valid."
    [[ "$domain" != *"*"* ]] || die "Masukkan domain utama, bukan wildcard atau subdomain."
else die "Pilihan domain tidak valid."; fi

for f in /root/domain /root/scdomain /etc/xray/domain /etc/xray/scdomain /etc/v2ray/domain /etc/v2ray/scdomain; do printf '%s\n' "$domain" > "$f"; done
printf 'OS=%s\nIP=%s\n' "$PRETTY_NAME" "$domain" > /var/lib/ipvps.conf
info "Domain: $domain"

run_module(){ local rel="$1"; [[ -f "$BASE_DIR/$rel" ]] || die "Module tidak ditemukan: $rel"; info "Menjalankan $rel ..."; (cd "$BASE_DIR" && bash "$BASE_DIR/$rel"); }

# Bootstrap Nginx dipakai sementara; xray.sh menghentikannya saat validasi HTTP-01 Standalone.
# xray.conf FINAL dipasang oleh xray.sh setelah sertifikat tersedia.
rm -f /etc/nginx/conf.d/xray.conf /etc/nginx/conf.d/acme-bootstrap.conf

run_module install/nginx.sh
systemctl is-active --quiet nginx || die "Nginx bootstrap gagal aktif."

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
services=(xray nginx ssh dropbear dropbear-ws stunnel-ws ayah-ssh-ssl udpgw udp-custom wg-quick@wg0 zivpn)
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

#!/bin/bash
# ==========================================
# Setup Script AYAH-ALMA (XRAY_AIO) - FULL AUTO FIX
# XRAY + WireGuard + UDP Custom + UDP ZIVPN + SSHWS
# ==========================================

echo "" > /root/log-install.txt

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
cd "$SCRIPT_DIR" || {
    error "Gagal masuk ke direktori script: $SCRIPT_DIR"
    exit 1
}

clear

# ==========================================
# COLOR
# ==========================================

red='\e[1;31m'
green='\e[0;32m'
yellow='\e[1;33m'
blue='\e[1;34m'
cyan='\e[1;36m'
NC='\e[0m'

# ==========================================
# FUNCTION
# ==========================================

function info() {
    echo -e "${green}[INFO]${NC} $1"
}

function warn() {
    echo -e "${yellow}[WARNING]${NC} $1"
}

function error() {
    echo -e "${red}[ERROR]${NC} $1"
}

# Jalankan perintah wajib. Jika gagal, instalasi langsung dihentikan.
run_required() {
    local description="$1"
    shift
    if ! "$@"; then
        error "$description gagal."
        exit 1
    fi
}

# ==========================================
# GITHUB REPOSITORY URL
# ==========================================

REPO_URL="https://raw.githubusercontent.com/faisin/ayah-alma/main"
API_URL="https://api.github.com/repos/faisin/ayah-alma/contents"

# ==========================================
# TIMER
# ==========================================

start_time=$(date +%s)

# ==========================================
# CHECK ROOT
# ==========================================

if [ "${EUID}" -ne 0 ]; then
    error "Script harus dijalankan sebagai root."
    exit 1
fi

# ==========================================
# CHECK VIRTUALIZATION
# ==========================================

if [ "$(systemd-detect-virt)" == "openvz" ]; then
    error "OpenVZ tidak didukung. Gunakan KVM/VMWare."
    exit 1
fi

# ==========================================
# AUTOMATIC OS & VERSION DETECTION
# ==========================================

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_NAME=$NAME
    OS_VERSION=$VERSION_ID
    OS_PRETTY=$PRETTY_NAME
else
    error "Sistem operasi tidak dapat dideteksi!"
    exit 1
fi

info "Mendeteksi OS: $OS_PRETTY"
sleep 1

# ==========================================
# FIX /etc/hosts
# ==========================================

localip=$(hostname -I | awk '{print $1}')
hostname=$(hostname)

domainline=$(grep -w "$hostname" /etc/hosts | awk '{print $2}')

if [[ "$hostname" != "$domainline" ]]; then
    echo "$localip $hostname" >> /etc/hosts
fi

# ==========================================
# CREATE REQUIRED FOLDER
# ==========================================

mkdir -p /etc/xray
mkdir -p /etc/v2ray
mkdir -p /var/lib
mkdir -p /etc/ayah-alma/{ssh,xray,wg,udp,tools,config,sshws,internal/go}

for file in domain scdomain; do
    touch /etc/xray/$file
    touch /etc/v2ray/$file
    touch /root/$file
done

touch /var/lib/ipvps.conf
echo "OS=$OS_PRETTY" >> /var/lib/ipvps.conf

# ==========================================
# SET TIMEZONE
# ==========================================

ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime

# ==========================================
# UPDATE & INSTALL PACKAGE & GOLANG
# ==========================================

info "Installing dependencies, jq, and Golang for $OS_PRETTY..."

if ! apt update -y; then
    error "apt update gagal."
    exit 1
fi

if ! apt install -y \
curl \
wget \
git \
screen \
unzip \
bzip2 \
gzip \
coreutils \
python3 \
python3-pip \
iptables \
iptables-persistent \
netfilter-persistent \
vnstat \
openssl \
ufw \
jq \
golang >/dev/null 2>&1; then
    error "Instalasi dependency gagal."
    exit 1
fi

# ==========================================
# INSTALL LINUX HEADER
# ==========================================

kernelver=$(uname -r)
headerpkg="linux-headers-$kernelver"

if ! dpkg -s $headerpkg >/dev/null 2>&1; then
    info "Installing $headerpkg..."
    if ! apt install -y "$headerpkg"; then
        error "Gagal memasang kernel header: $headerpkg"
        exit 1
    fi
fi

# ==========================================
# DOMAIN SETUP
# ==========================================

clear

echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${cyan}         DOMAIN SETUP${NC}"
echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "1. Menggunakan Domain dari Script (Default / Auto)"
echo -e "2. Pakai Domain Sendiri (Custom Domain)"
echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
read -rp "Pilih opsi (1/2) : " pilihan

if [[ "$pilihan" == "1" ]]; then
    pub_ip=$(curl -fsS https://api.ipify.org 2>/dev/null || true)

    if [[ -z "$pub_ip" ]]; then
        pub_ip=$(hostname -I | awk '{print $1}')
    fi

    if [[ -z "$pub_ip" ]]; then
        error "Gagal mendapatkan IP publik. IP kosong, instalasi dihentikan."
        exit 1
    fi

    domain="${pub_ip}.sslip.io"
    info "Menggunakan domain otomatis: $domain"
elif [[ "$pilihan" == "2" ]]; then
    echo ""
    read -rp "Masukkan domain kamu (contoh: domain.com) : " domain
    if [[ -z "$domain" ]]; then
        error "Domain tidak boleh kosong!"
        exit 1
    fi
else
    error "Pilihan tidak valid!"
    exit 1
fi

echo "$domain" > /root/domain

for dfile in domain scdomain; do
    echo "$domain" > /etc/xray/$dfile
    echo "$domain" > /etc/v2ray/$dfile
    echo "$domain" > /root/$dfile
done

cat > /var/lib/ipvps.conf <<EOF
OS=$OS_PRETTY
IP=$domain
EOF

echo ""
info "Domain berhasil diset: $domain"

sleep 2

# ==========================================
# DYNAMIC ALL-FILES DOWNLOADER (NO MISSING FILES)
# ==========================================

info "Mengunduh seluruh file secara otomatis & komprehensif dari GitHub..."

# Buat struktur direktori lokal lengkap
mkdir -p install ssh xray wg udp tools config sshws bin internal/go/dropbear-ws internal/go/stunnel-ws

# Download per-file melalui GitHub Contents API. File wajib yang gagal -> STOP.
download_folder() {
    local folder_path="$1"
    local api_response
    local files

    api_response=$(curl -fsSL "${API_URL}/${folder_path}") || {
        error "Gagal mengambil daftar file: $folder_path"
        exit 1
    }

    files=$(printf '%s' "$api_response" | jq -er '.[] | select(.type=="file") | .name') || {
        error "Gagal membaca daftar file GitHub: $folder_path"
        exit 1
    }

    while IFS= read -r file; do
        [ -n "$file" ] || continue
        if ! wget -q -O "${folder_path}/${file}" "${REPO_URL}/${folder_path}/${file}"; then
            error "Gagal mengunduh: ${folder_path}/${file}"
            exit 1
        fi
        [ -s "${folder_path}/${file}" ] || {
            error "File hasil download kosong: ${folder_path}/${file}"
            exit 1
        }
    done <<< "$files"
}

for dir in install ssh xray wg udp tools config sshws internal/go/dropbear-ws internal/go/stunnel-ws; do
    download_folder "$dir"
done

# File root wajib
for file in menu.sh uninstall.sh; do
    if ! wget -q -O "$file" "${REPO_URL}/${file}"; then
        error "Gagal mengunduh: $file"
        exit 1
    fi
    [ -s "$file" ] || {
        error "File hasil download kosong: $file"
        exit 1
    }
done

# Binary khusus UDP Custom wajib
if ! wget -q -O /usr/local/bin/udp-custom "${REPO_URL}/config/udp-custom"; then
    error "Gagal mengunduh binary udp-custom."
    exit 1
fi
[ -s /usr/local/bin/udp-custom ] || {
    error "Binary udp-custom kosong setelah download."
    exit 1
}
chmod +x /usr/local/bin/udp-custom || {
    error "Gagal memberi izin eksekusi pada udp-custom."
    exit 1
}

info "Seluruh file berhasil diunduh tanpa ada yang terlewat."

# ==========================================
# RUN INSTALLER / MODULES ONLINE
# ==========================================

info "Menjalankan modul instalasi layanan..."

info "Installing NGINX Reverse Proxy..."
[ -f install/nginx.sh ] || { error "install/nginx.sh tidak ditemukan."; exit 1; }
bash install/nginx.sh || { error "Instalasi NGINX gagal."; exit 1; }

info "Installing XRAY Core..."
[ -f install/xray.sh ] || { error "install/xray.sh tidak ditemukan."; exit 1; }
bash install/xray.sh || { error "Instalasi XRAY gagal."; exit 1; }

info "Installing SSH Websocket & Tunnel..."
[ -f install/ssh.sh ] || { error "install/ssh.sh tidak ditemukan."; exit 1; }
bash install/ssh.sh || { error "Instalasi SSH Websocket & Tunnel gagal."; exit 1; }

# Validasi hasil installer SSH. install/ssh.sh versi lama masih dapat
# mengembalikan status 0 walaupun sebagian proses internal gagal.
[ -f /etc/default/dropbear ] || { error "Konfigurasi Dropbear tidak terpasang."; exit 1; }
[ -f /etc/issue.net ] || { error "Banner SSH /etc/issue.net tidak terpasang."; exit 1; }
[ -f /etc/systemd/system/dropbear.service ] || { error "dropbear.service tidak terpasang."; exit 1; }

# BadVPN wajib tersedia karena udpgw.service menggunakannya.
if [ -f sshws/badvpn-udpgw ]; then
    cp -f sshws/badvpn-udpgw /usr/local/bin/badvpn-udpgw || { error "Gagal memasang badvpn-udpgw."; exit 1; }
elif [ -f bin/badvpn-udpgw ]; then
    cp -f bin/badvpn-udpgw /usr/local/bin/badvpn-udpgw || { error "Gagal memasang badvpn-udpgw."; exit 1; }
else
    error "Binary badvpn-udpgw tidak ditemukan."
    exit 1
fi

[ -s /usr/local/bin/badvpn-udpgw ] || { error "Binary badvpn-udpgw kosong."; exit 1; }
chmod +x /usr/local/bin/badvpn-udpgw || { error "Gagal memberi izin badvpn-udpgw."; exit 1; }

info "Installing WireGuard..."
[ -f install/wg.sh ] || { error "install/wg.sh tidak ditemukan."; exit 1; }
bash install/wg.sh || { error "Instalasi WireGuard gagal."; exit 1; }

info "Installing UDP ZIVPN..."
[ -f install/zivpn.sh ] || { error "install/zivpn.sh tidak ditemukan."; exit 1; }
bash install/zivpn.sh || { error "Instalasi UDP ZIVPN gagal."; exit 1; }

# ==========================================
# COPY ALL MENU COMMANDS & PERMISSIONS (WILDCARD LOOP)
# ==========================================

info "Menyalin seluruh command menu dan mengatur izin akses..."

# Bersihkan karakter format Windows (CRLF) jika ada
sed -i 's/\r$//' ssh/* xray/* wg/* udp/* tools/* install/* *.sh 2>/dev/null || true

# 1. Copy SELURUH isi dari semua folder modul ke /usr/bin/
for dir in ssh xray wg udp tools; do
    if [ -d "$dir" ]; then
        cp -fr "$dir"/* /usr/bin/ || { error "Gagal menyalin folder $dir ke /usr/bin/."; exit 1; }
    else
        error "Folder $dir tidak ditemukan."
        exit 1
    fi
done

# 2. Copy file menu utama & uninstall
cp -f menu.sh /usr/bin/menu || { error "Gagal memasang menu."; exit 1; }
cp -f uninstall.sh /root/uninstall.sh || { error "Gagal memasang uninstall.sh."; exit 1; }

# 3. Berikan akses eksekusi ke command utama
chmod +x /usr/bin/menu || { error "Gagal memberi izin eksekusi pada menu."; exit 1; }
for f in /usr/bin/m-* /usr/bin/*.sh; do
    [ -e "$f" ] || continue
    chmod +x "$f" || { error "Gagal memberi izin eksekusi: $f"; exit 1; }
done

# ==========================================
# COPY RUNTIME SCRIPT TO /etc/ayah-alma/
# ==========================================

info "Menyalin backup runtime ke /etc/ayah-alma/..."

mkdir -p /etc/ayah-alma/{ssh,xray,wg,udp,tools,config,sshws}
for dir in ssh xray wg udp tools config sshws; do
    if [ -d "$dir" ]; then
        cp -fr "$dir"/* /etc/ayah-alma/$dir/ || { error "Gagal menyalin runtime $dir."; exit 1; }
        for f in /etc/ayah-alma/$dir/*.sh; do
            [ -e "$f" ] || continue
            chmod +x "$f" || { error "Gagal memberi izin eksekusi: $f"; exit 1; }
        done
    fi
done

# ==========================================
# KOMPILASI GO BINARY & SETUP SERVICES
# ==========================================

info "Mengompilasi layanan Go WebSocket dan memasang systemd service..."

if [ -f "internal/go/dropbear-ws/main.go" ]; then
    cd "$SCRIPT_DIR/internal/go/dropbear-ws" || { error "Gagal masuk ke direktori dropbear-ws."; exit 1; }
    if [ ! -f go.mod ]; then
        go mod init dropbear-ws || { error "Gagal membuat go.mod dropbear-ws."; exit 1; }
    fi
    go build -o /usr/local/bin/dropbearws main.go || { error "Build dropbearws gagal."; exit 1; }
    chmod +x /usr/local/bin/dropbearws || { error "Gagal memberi izin dropbearws."; exit 1; }
    cd "$SCRIPT_DIR" || exit 1
fi

if [ -f "internal/go/stunnel-ws/main.go" ]; then
    cd "$SCRIPT_DIR/internal/go/stunnel-ws" || { error "Gagal masuk ke direktori stunnel-ws."; exit 1; }
    if [ ! -f go.mod ]; then
        go mod init stunnel-ws || { error "Gagal membuat go.mod stunnel-ws."; exit 1; }
    fi
    go build -o /usr/local/bin/stunnelws main.go || { error "Build stunnelws gagal."; exit 1; }
    chmod +x /usr/local/bin/stunnelws || { error "Gagal memberi izin stunnelws."; exit 1; }
    cd "$SCRIPT_DIR" || exit 1
fi

# Pasang hanya service SSHWS yang memang dipakai:
# - udpgw.service dan udp-custom.service berasal dari sshws/
# - dropbear-ws.service dan stunnel-ws.service berasal dari internal/go/
cp -f sshws/udpgw.service /etc/systemd/system/ || { error "Gagal memasang udpgw.service."; exit 1; }
cp -f sshws/udp-custom.service /etc/systemd/system/ || { error "Gagal memasang udp-custom.service."; exit 1; }
cp -f internal/go/dropbear-ws.service /etc/systemd/system/ || { error "Gagal memasang dropbear-ws.service."; exit 1; }
cp -f internal/go/stunnel-ws.service /etc/systemd/system/ || { error "Gagal memasang stunnel-ws.service."; exit 1; }

systemctl daemon-reload || { error "systemd daemon-reload gagal."; exit 1; }

# Hanya service yang memang dibuat/dibutuhkan oleh installer.
# ws-dropbear tidak dipanggil karena ssh.sh memasangnya sebagai dropbear-ws.service.
for svc in xray nginx dropbear wg-quick@wg0 udp-custom zivpn dropbear-ws stunnel-ws udpgw; do
    if ! systemctl cat "$svc" >/dev/null 2>&1; then
        error "Service wajib tidak ditemukan: $svc"
        exit 1
    fi
    systemctl enable "$svc" || { error "Gagal enable service: $svc"; exit 1; }
    systemctl restart "$svc" || { error "Gagal restart service: $svc"; exit 1; }
done

# ==========================================
# AUTO MENU LOGIN
# ==========================================

cat > /root/.profile <<-EOF
if [ "\$BASH" ]; then
    if [ -f ~/.bashrc ]; then
        . ~/.bashrc
    fi
fi

clear
menu
EOF

chmod 644 /root/.profile

# ==========================================
# CLEAN FILE
# ==========================================

cd "$SCRIPT_DIR" || exit 1
rm -rf install cf ins-xray.sh ssh xray wg udp tools config sshws bin internal menu.sh uninstall.sh || true

# ==========================================
# FINISH
# ==========================================

end_time=$(date +%s)
elapsed=$((end_time - start_time))

clear

echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${green}      INSTALLATION DONE       ${NC}"
echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e " Project     : AYAH-ALMA AIO"
echo -e " OS System   : $OS_PRETTY"
echo -e " SSH & WS    : INSTALLED & COMPILED"
echo -e " XRAY        : INSTALLED"
echo -e " WireGuard   : INSTALLED"
echo -e " UDP ZIVPN   : INSTALLED"

echo ""
echo -e " Installation Time : $((elapsed / 60)) menit $((elapsed % 60)) detik"

echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo ""
echo -e "${green}♻️ VPS akan reboot dalam 10 detik...${NC}"

sleep 10

reboot

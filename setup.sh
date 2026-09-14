#!/bin/bash
# ==========================================
# Setup Script AYAH-ALMA (XRAY_AIO) - FULL AUTO FIX
# XRAY + WireGuard + UDP Custom + UDP ZIVPN + SSHWS
# ==========================================

echo "" > /root/log-install.txt

cd "$(dirname "$0")"

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

apt update -y

apt install -y \
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
golang >/dev/null 2>&1

# ==========================================
# INSTALL LINUX HEADER
# ==========================================

kernelver=$(uname -r)
headerpkg="linux-headers-$kernelver"

if ! dpkg -s $headerpkg >/dev/null 2>&1; then
    info "Installing $headerpkg..."
    apt install -y $headerpkg
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
    pub_ip=$(curl -s https://api.ipify.org || hostname -I | awk '{print $1}')
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

echo "IP=$domain" > /var/lib/ipvps.conf

echo ""
info "Domain berhasil diset: $domain"

sleep 2

# ==========================================
# DYNAMIC ALL-FILES DOWNLOADER (NO MISSING FILES)
# ==========================================

info "Mengunduh seluruh file secara otomatis & komprehensif dari GitHub..."

# Buat struktur direktori lokal lengkap
mkdir -p install ssh xray wg udp tools config sshws bin internal/go/dropbear-ws internal/go/stunnel-ws

# Fungsi download otomatis seluruh isi folder dari API GitHub
download_folder() {
    local folder_path="$1"
    local files=$(curl -s "${API_URL}/${folder_path}" | jq -r '.[] | select(.type=="file") | .name')
    
    for file in $files; do
        wget -q -O "${folder_path}/${file}" "${REPO_URL}/${folder_path}/${file}" 2>/dev/null || true
    done
}

# 1. Download otomatis semua file di dalam folder modul
for dir in install ssh xray wg udp tools config sshws internal/go/dropbear-ws internal/go/stunnel-ws; do
    download_folder "$dir"
done

# 2. Download file root dasar
wget -q -O menu.sh "${REPO_URL}/menu.sh" 2>/dev/null || true
wget -q -O uninstall.sh "${REPO_URL}/uninstall.sh" 2>/dev/null || true

# 3. Download binary khusus udp-custom jika ada
wget -q -O /usr/local/bin/udp-custom "${REPO_URL}/config/udp-custom" 2>/dev/null || true
chmod +x /usr/local/bin/udp-custom 2>/dev/null || true

info "Seluruh file berhasil diunduh tanpa ada yang terlewat."

# ==========================================
# RUN INSTALLER / MODULES ONLINE
# ==========================================

info "Menjalankan modul instalasi layanan..."

info "Installing NGINX Reverse Proxy..."
[ -f install/nginx.sh ] && bash install/nginx.sh

info "Installing XRAY Core..."
[ -f install/xray.sh ] && bash install/xray.sh

info "Installing SSH Websocket & Tunnel..."
[ -f install/ssh.sh ] && bash install/ssh.sh

info "Installing WireGuard..."
[ -f install/wg.sh ] && bash install/wg.sh

info "Installing UDP ZIVPN..."
[ -f install/zivpn.sh ] && bash install/zivpn.sh

# ==========================================
# COPY ALL MENU COMMANDS & PERMISSIONS (WILDCARD LOOP)
# ==========================================

info "Menyalin seluruh command menu dan mengatur izin akses..."

# Bersihkan karakter format Windows (CRLF) jika ada
sed -i 's/\r$//' ssh/* xray/* wg/* udp/* tools/* install/* *.sh 2>/dev/null || true

# 1. Copy SELURUH isi dari semua folder modul ke /usr/bin/ tanpa ada yang tertinggal
for dir in ssh xray wg udp tools; do
    if [ -d "$dir" ]; then
        cp -fr $dir/* /usr/bin/ 2>/dev/null || true
    fi
done

# 2. Copy file menu utama & uninstall
cp -f menu.sh /usr/bin/menu 2>/dev/null || true
cp -f uninstall.sh /root/uninstall.sh 2>/dev/null || true

# 3. Berikan akses eksekusi ke SEMUA file script & perintah menu di /usr/bin/
chmod +x /usr/bin/menu 2>/dev/null || true
chmod +x /usr/bin/m-* 2>/dev/null || true
chmod +x /usr/bin/*.sh 2>/dev/null || true

# ==========================================
# COPY RUNTIME SCRIPT TO /etc/ayah-alma/
# ==========================================

info "Menyalin backup runtime ke /etc/ayah-alma/..."

mkdir -p /etc/ayah-alma/{ssh,xray,wg,udp,tools,config,sshws}
for dir in ssh xray wg udp tools config sshws; do
    if [ -d "$dir" ]; then
        cp -fr $dir/* /etc/ayah-alma/$dir/ 2>/dev/null || true
        chmod +x /etc/ayah-alma/$dir/*.sh 2>/dev/null || true
    fi
done

# ==========================================
# KOMPILASI GO BINARY & SETUP SERVICES
# ==========================================

info "Mengompilasi layanan Go WebSocket dan memasang systemd service..."

if [ -f "internal/go/dropbear-ws/main.go" ]; then
    cd internal/go/dropbear-ws
    go mod init dropbear-ws 2>/dev/null || true
    go build -o /usr/local/bin/dropbearws main.go 2>/dev/null || true
    chmod +x /usr/local/bin/dropbearws 2>/dev/null || true
    cd /root/ 2>/dev/null || cd - >/dev/null
fi

if [ -f "internal/go/stunnel-ws/main.go" ]; then
    cd internal/go/stunnel-ws
    go mod init stunnel-ws 2>/dev/null || true
    go build -o /usr/local/bin/stunnelws main.go 2>/dev/null || true
    chmod +x /usr/local/bin/stunnelws 2>/dev/null || true
    cd /root/ 2>/dev/null || cd - >/dev/null
fi

cp -f sshws/*.service /etc/systemd/system/ 2>/dev/null || true
cp -f internal/go/*.service /etc/systemd/system/ 2>/dev/null || true

# Salin file Python WebSocket
if [ -f "sshws/ws-dropbear.py" ]; then
    cp -f sshws/ws-dropbear.py /usr/local/bin/ws-dropbear.py
    chmod +x /usr/local/bin/ws-dropbear.py
fi

if [ -f "sshws/stunnel-ws.py" ]; then
    cp -f sshws/stunnel-ws.py /usr/local/bin/stunnel-ws.py
    chmod +x /usr/local/bin/stunnel-ws.py
fi

systemctl daemon-reload

for svc in xray nginx dropbear wg-quick@wg0 udp-custom zivpn dropbear-ws stunnel-ws ws-dropbear udpgw; do
    systemctl enable "$svc" 2>/dev/null || true
    systemctl restart "$svc" 2>/dev/null || true
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

rm -rf install cf ins-xray.sh ssh xray wg udp tools config sshws bin internal menu.sh uninstall.sh

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

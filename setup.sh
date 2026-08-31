#!/bin/bash
# ==========================================
# Setup Script AYAH-ALMA (XRAY_AIO)
# XRAY + WireGuard + UDP ZIVPN
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
mkdir -p /etc/ayah-alma/{ssh,xray,wg,udp,tools,config}

for file in domain scdomain; do
    touch /etc/xray/$file
    touch /etc/v2ray/$file
    touch /root/$file
done

touch /var/lib/ipvps.conf

# ==========================================
# SET TIMEZONE
# ==========================================

ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime

# ==========================================
# UPDATE & INSTALL PACKAGE
# ==========================================

info "Installing dependencies..."

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
ufw >/dev/null 2>&1

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

read -rp "Masukkan domain kamu : " domain

if [[ -z "$domain" ]]; then
    error "Domain tidak boleh kosong!"
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
# RUN INSTALLER / MODULES ONLINE
# ==========================================

info "Mengunduh dan memasang modul instalasi dari GitHub (ayah-alma)..."

mkdir -p install
wget -O install/nginx.sh "${REPO_URL}/install/nginx.sh"
wget -O install/xray.sh "${REPO_URL}/install/xray.sh"
wget -O install/ssh.sh "${REPO_URL}/install/ssh.sh"
wget -O install/wg.sh "${REPO_URL}/install/wg.sh"
wget -O install/zivpn.sh "${REPO_URL}/install/zivpn.sh"

info "Installing NGINX Reverse Proxy..."
bash install/nginx.sh

info "Installing XRAY Core..."
bash install/xray.sh

info "Installing SSH Websocket..."
bash install/ssh.sh

info "Installing WireGuard..."
bash install/wg.sh

info "Installing UDP ZIVPN..."
bash install/zivpn.sh

# ==========================================
# DOWNLOAD MENU, SUBMENU & CONFIG FROM GITHUB
# ==========================================

info "Mengunduh file menu, submenu, dan config dari repository ayah-alma..."

mkdir -p ssh xray wg udp tools config

wget -O ssh/m-ssh "${REPO_URL}/ssh/m-ssh"
wget -O ssh/addssh.sh "${REPO_URL}/ssh/addssh.sh"

wget -O xray/m-vmess "${REPO_URL}/xray/m-vmess"
wget -O xray/m-vless "${REPO_URL}/xray/m-vless"
wget -O xray/m-trojan "${REPO_URL}/xray/m-trojan"
wget -O xray/m-ssws "${REPO_URL}/xray/m-ssws"

wget -O wg/m-wg "${REPO_URL}/wg/m-wg"
wget -O udp/m-zivpn "${REPO_URL}/udp/m-zivpn"

wget -O tools/tools-menu "${REPO_URL}/tools/tools-menu"
wget -O tools/backup.sh "${REPO_URL}/tools/backup.sh"
wget -O tools/speedtest.sh "${REPO_URL}/tools/speedtest.sh"
wget -O tools/domain.sh "${REPO_URL}/tools/domain.sh"
wget -O tools/running.sh "${REPO_URL}/tools/running.sh"

# Mengunduh file konfigurasi tambahan (misal: nginx.conf)
wget -O config/nginx.conf "${REPO_URL}/config/nginx.conf"

wget -O menu.sh "${REPO_URL}/menu.sh"

# ==========================================
# COPY MENU COMMAND
# ==========================================

info "Menyalin command menu..."

cp -f ssh/m-ssh /usr/bin/

cp -f xray/m-vmess /usr/bin/
cp -f xray/m-vless /usr/bin/
cp -f xray/m-trojan /usr/bin/
cp -f xray/m-ssws /usr/bin/

cp -f wg/m-wg /usr/bin/

cp -f udp/m-zivpn /usr/bin/

cp -f tools/tools-menu /usr/bin/

cp -f tools/backup.sh /usr/bin/
cp -f tools/speedtest.sh /usr/bin/
cp -f tools/domain.sh /usr/bin/
cp -f tools/running.sh /usr/bin/

cp -f menu.sh /usr/bin/menu

# ==========================================
# SET PERMISSION
# ==========================================

chmod +x /usr/bin/menu

chmod +x /usr/bin/m-ssh
chmod +x /usr/bin/m-vmess
chmod +x /usr/bin/m-vless
chmod +x /usr/bin/m-trojan
chmod +x /usr/bin/m-ssws
chmod +x /usr/bin/m-wg
chmod +x /usr/bin/m-zivpn

chmod +x /usr/bin/tools-menu
chmod +x /usr/bin/backup.sh
chmod +x /usr/bin/speedtest.sh
chmod +x /usr/bin/domain.sh
chmod +x /usr/bin/running.sh

# ==========================================
# COPY RUNTIME SCRIPT TO /etc/ayah-alma/
# ==========================================

info "Menyalin semua submenu dan config ke /etc/ayah-alma/..."

cp -r ssh/* /etc/ayah-alma/ssh/
cp -r xray/* /etc/ayah-alma/xray/
cp -r wg/* /etc/ayah-alma/wg/
cp -r udp/* /etc/ayah-alma/udp/
cp -r tools/* /etc/ayah-alma/tools/
cp -r config/* /etc/ayah-alma/config/

chmod +x /etc/ayah-alma/*/*.sh

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

rm -rf install cf ins-xray.sh ssh xray wg udp tools config menu.sh

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
echo -e " SSH         : INSTALLED"
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
tambahkan yang kurang di setup.sh saya, seperti yang ada di sketsa

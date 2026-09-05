#!/bin/bash
# Subdomain Finder & CDN Detector by Ayah Alma

CYAN='\e[1;36m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
RED='\e[1;31m'
NC='\e[0m'

clear
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}         🔍 SUBDOMAIN FINDER & CDN CHECKER      ${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
read -p "👉 Masukkan target domain (contoh: google.com): " DOMAIN

if [ -z "$DOMAIN" ]; then
    echo -e "${RED}❌ Domain tidak boleh kosong!${NC}"
    sleep 2
    tools-menu
fi

echo -e "\n${CYAN}[+] Mengambil data subdomain untuk: $DOMAIN...${NC}"

# Memastikan curl dan dnsutils/dig terpasang
if ! command -v curl &> /dev/null || ! command -v host &> /dev/null; then
    apt update && apt install curl dnsutils -y
fi

# Mengambil subdomain dari crt.sh
SUBDOMAINS=$(curl -s "https://crt.sh/?q=%.$DOMAIN&output=json" | grep -o '"name_value":"[^"]*"' | awk -F'"' '{print $4}' | sort -u)

if [ -z "$SUBDOMAINS" ]; then
    echo -e "${RED}❌ Tidak ditemukan subdomain atau koneksi gagal.${NC}"
else
    echo -e "\n${GREEN}🎯 Hasil Subdomain & Pengecekan CDN:${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Loop untuk mengecek IP dan mendeteksi CDN setiap subdomain
    for sub in $SUBDOMAINS; do
        # Mengambil alamat IP dari subdomain
        IP=$(host "$sub" 2>/dev/null | grep "has address" | head -n 1 | awk '{print $4}')
        
        if [ -z "$IP" ]; then
            echo -e " • $sub -> ${RED}No IP (Inactive)${NC}"
        else
            # Deteksi sederhana apakah menggunakan Cloudflare / CDN berdasarkan ASN / Provider atau range IP umum
            # Cek header atau reverse lookup / IP check sederhana
            CDN_STATUS="${GREEN}Direct / Non-CDN${NC}"
            
            # Contoh deteksi Cloudflare berdasarkan hostname/provider IP atau bisa dicek via HTTP header
            # Menggunakan pengecekan HTTP Server header via curl ringkas
            HEADER=$(curl -s -I --max-time 2 "http://$sub" 2>/dev/null | grep -i "server:")
            
            if echo "$HEADER" | grep -qi "cloudflare"; then
                CDN_STATUS="${YELLOW}Cloudflare CDN${NC}"
            elif echo "$HEADER" | grep -qi "cloudfront"; then
                CDN_STATUS="${YELLOW}AWS CloudFront${NC}"
            elif echo "$HEADER" | grep -qi "akamaighost"; then
                CDN_STATUS="${YELLOW}Akamai CDN${NC}"
            fi
            
            echo -e " • $sub [$IP] — Status: $CDN_STATUS"
        fi
    done
    
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Opsi untuk menyimpan hasil
    read -p "💾 Simpan hasil ke file? (y/n): " save
    if [[ "$save" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        FILENAME="subdomain_cdn_${DOMAIN}.txt"
        echo "$SUBDOMAINS" > /root/$FILENAME
        echo -e "${GREEN}✔ Berhasil disimpan di: /root/$FILENAME${NC}"
    fi
fi

echo -e ""
read -n 1 -s -r -p "Tekan [ENTER] untuk kembali ke Menu Tools..."
tools-menu


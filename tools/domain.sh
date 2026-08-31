#!/bin/bash
# Atur ulang domain - by Ayah Alma

# Warna
CYAN='\e[1;36m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
NC='\e[0m'

clear
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}              🌐 GANTI DOMAIN XRAY            ${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Minta domain baru
read -rp "📌 Masukkan domain baru: " new_domain

# Validasi input
if [[ -z "$new_domain" ]]; then
    echo -e "${YELLOW}❌ Domain tidak boleh kosong!${NC}"
    exit 1
fi

# Simpan domain baru ke file sistem
echo "$new_domain" > /etc/xray/domain
if [ -d /root ]; then
    echo "$new_domain" > /root/domain
fi

# Restart service
systemctl restart xray

# Output
echo -e "${GREEN}✅ Domain berhasil diganti!${NC}"
echo -e "🌐 Domain baru: ${CYAN}$new_domain${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo ""
read -n 1 -s -r -p "Tekan apa saja untuk kembali ke menu tools..."
tools-menu

#!/bin/bash
# Speedtest VPS - by Ayah Alma

# Warna
GREEN='\e[1;32m'
CYAN='\e[1;36m'
YELLOW='\e[1;33m'
NC='\e[0m'

clear
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}              🌐 SPEEDTEST VPS                ${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Cek apakah speedtest terinstall
if ! command -v speedtest &> /dev/null; then
    echo -e "${YELLOW}⚠️ speedtest belum terinstall... installing...${NC}"
    apt-get update -y >/dev/null 2>&1
    apt-get install speedtest-cli -y >/dev/null 2>&1
fi

# Jalankan speedtest
echo -e "${CYAN}Sedang menguji koneksi... Mohon tunggu...${NC}"
speedtest --simple[span_4](start_span)[span_4](end_span)

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✔️ Selesai${NC}[span_5](start_span)[span_5](end_span)

echo ""
read -n 1 -s -r -p "Tekan apa saja untuk kembali ke menu tools..."
tools-menu


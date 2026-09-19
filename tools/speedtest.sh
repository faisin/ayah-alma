#!/bin/bash
# Speedtest VPS - by Ayah Alma

GREEN='\e[1;32m'
CYAN='\e[1;36m'
YELLOW='\e[1;33m'
WHITE='\e[1;37m'
NC='\e[0m'

clear

echo -e ""
echo -e "${CYAN}  ┌────────────────────────────────────────┐${NC}"
echo -e "${CYAN}  │${YELLOW}            🌐 SPEEDTEST VPS            ${CYAN}│${NC}"
echo -e "${CYAN}  └────────────────────────────────────────┘${NC}"
echo -e ""

if ! command -v speedtest &> /dev/null; then
    echo -e " ${YELLOW}⚠️ Speedtest belum terinstall${NC}"
    exit 1
fi

echo -e " ${CYAN}⏳ Sedang menguji koneksi, mohon tunggu...${NC}"
echo ""

echo -e "${WHITE}"

if speedtest -f human-readable; then
    RESULT=0
else
    RESULT=1
fi

echo -e "${NC}"

echo -e "${CYAN}  ──────────────────────────────────────────${NC}"

if [ $RESULT -eq 0 ]; then
    echo -e " ${GREEN}✔ Pengujian Selesai${NC}"
else
    echo -e " ${YELLOW}⚠️ Pengujian Gagal${NC}"
fi

echo -e "${CYAN}  ──────────────────────────────────────────${NC}"
echo ""

read -n 1 -s -r -p " Tekan tombol apa saja untuk kembali ke menu..."

menu

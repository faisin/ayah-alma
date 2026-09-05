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
    echo -e " ${YELLOW}⚠️  Speedtest belum terinstall, menginstall...${NC}"
    apt-get update -y >/dev/null 2>&1
    apt-get install speedtest-cli -y >/dev/null 2>&1
    echo -e ""
fi

echo -e " ${CYAN}⏳ Sedang menguji koneksi, mohon tunggu...${NC}"
echo -e ""
echo -e "${WHITE}"
speedtest --simple
echo -e "${NC}"

echo -e "${CYAN}  ──────────────────────────────────────────${NC}"
echo -e " ${GREEN}✔  Pengujian Selesai${NC}"
echo -e "${CYAN}  ──────────────────────────────────────────${NC}"
echo -e ""

read -n 1 -s -r -p " Tekan tombol apa saja untuk kembali ke menu..."

# Mengembalikan langsung ke menu utama (ganti 'menu' dengan perintah/path menu Anda jika berbeda)
menu

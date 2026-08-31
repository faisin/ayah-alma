#!/bin/bash
# Backup tool - by Ayah Alma

# Warna
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
CYAN='\e[1;36m'
NC='\e[0m'

clear
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}            🔄 BACKUP & RESTORE TOOLS         ${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}[1]${NC} Backup Data"
echo -e "${GREEN}[2]${NC} Restore Data"
echo -e "${GREEN}[x]${NC} Kembali ke menu"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
read -p "👉 Pilih opsi: " opt

backup_folder="/root/backup-autoscript"
rm -rf "$backup_folder"
mkdir -p "$backup_folder"

case $opt in
1)
  echo -e "\n📦 Membuat backup..."
  # Backup file konfigurasi dan direktori penting
  cp -r /etc/xray/config.json "$backup_folder/" 2>/dev/null
  cp -r /etc/xray/domain "$backup_folder/" 2>/dev/null
  
  if [ -d /etc/zivpn ]; then
      cp -r /etc/zivpn "$backup_folder/" 2>/dev/null
  fi
  
  if [ -f /etc/wireguard/wg0.conf ]; then
      mkdir -p "$backup_folder/wireguard"
      cp -r /etc/wireguard/wg0.conf "$backup_folder/wireguard/" 2>/dev/null
  fi

  cd /root
  rm -f /root/backup-autoscript.zip
  zip -r backup-autoscript.zip backup-autoscript >/dev/null
  
  echo -e "\n✅ Backup selesai!"
  echo -e "📁 File: /root/backup-autoscript.zip"
  echo -e "${YELLOW}Simpan file zip ini untuk restore nanti.${NC}"
  
  echo ""
  read -n 1 -s -r -p "Tekan apa saja untuk kembali ke menu tools..."
  tools-menu
  ;;
2)
  read -p "🗂 Masukkan path file ZIP backup (cth: /root/backup-autoscript.zip): " path
  if [[ -f "$path" ]]; then
    echo -e "\n🔄 Restore data..."
    rm -rf /root/tmp-restore
    mkdir -p /root/tmp-restore
    unzip "$path" -d /root/tmp-restore >/dev/null
    
    # Salin kembali ke direktori sistem asal
    if [ -f /root/tmp-restore/backup-autoscript/config.json ]; then
        cp -r /root/tmp-restore/backup-autoscript/config.json /etc/xray/
    fi
    if [ -f /root/tmp-restore/backup-autoscript/domain ]; then
        cp -r /root/tmp-restore/backup-autoscript/domain /etc/xray/
        cp -r /root/tmp-restore/backup-autoscript/domain /root/domain 2>/dev/null
    fi
    if [ -d /root/tmp-restore/backup-autoscript/zivpn ]; then
        cp -r /root/tmp-restore/backup-autoscript/zivpn /etc/ 2>/dev/null
    fi
    
    rm -rf /root/tmp-restore
    systemctl restart xray
    systemctl restart zivpn 2>/dev/null
    
    echo -e "\n✅ Restore selesai!"
  else
    echo -e "❌ File backup tidak ditemukan!"
  fi
  
  echo ""
  read -n 1 -s -r -p "Tekan apa saja untuk kembali ke menu tools..."
  tools-menu
  ;;
x|X) 
  tools-menu 
  ;;
*) 
  echo "❌ Pilihan salah!" 
  sleep 1 
  bash "$0" 
  ;;
esac

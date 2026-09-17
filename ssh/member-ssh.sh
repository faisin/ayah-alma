#!/bin/bash

clear

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "      LIST SSH ACCOUNTS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Membaca daftar user dari file passwd dengan shell /bin/bash atau /bin/sh
echo "No  | Username         | Expired Date"
echo "-------------------------------------"

no=1
while IFS=':' read -r user x uid gid comment home shell; do
    if [[ "$shell" == *"/bash"* || "$shell" == *"/sh"* ]]; then
        # Mengabaikan user sistem standar
        if [[ "$user" != "root" && "$user" != "daemon" && "$user" != "bin" && "$user" != "sys" && "$user" != "sync" && "$user" != "games" && "$user" != "man" && "$user" != "mail" && "$user" != "news" && "$user" != "uucp" && "$user" != "proxy" && "$user" != "www-data" && "$user" != "backup" && "$user" != "list" && "$user" != "irc" && "$user" != "gnats" && "$user" != "nobody" && "$user" != "systemd-network" && "$user" != "systemd-resolve" && "$user" != "messagebus" && "$user" != "_apt" && "$user" != "uuidd" && "$user" != "dnsmasq" && "$user" != "stunnel4" ]]; then
            
            # Mendapatkan tanggal expired akun menggunakan chage
            exp_date=$(chage -l "$user" | grep "Account expires" | cut -d: -f2 | xargs)
            if [[ "$exp_date" == "never" || -z "$exp_date" ]]; then
                exp_date="UNLIMITED"
            fi
            
            printf "%-3s | %-16s | %s\n" "$no" "$user" "$exp_date"
            no=$((no + 1))
        fi
    fi
done < /etc/passwd

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  x. Kembali ke Menu Utama"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
read -p "Tekan [x] untuk kembali: " menu_pilihan

if [[ "$menu_pilihan" == "x" || "$menu_pilihan" == "X" ]]; then
    /usr/bin/m-ssh 2>/dev/null || bash /etc/ayah-alma/ssh/m-ssh
    exit 0
fi

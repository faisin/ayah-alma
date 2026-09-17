#!/bin/bash

clear

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "      RENEW SSH ACCOUNT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  x. Kembali ke Menu Utama"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
read -p "Username to renew [atau ketik x]: " user

if [[ "$user" == "x" || "$user" == "X" ]]; then
    /usr/bin/m-ssh 2>/dev/null || bash /etc/ayah-alma/ssh/m-ssh
    exit 0
fi

if ! id "$user" &>/dev/null; then
    echo ""
    echo "[ ERROR ] Username does not exist!"
    echo ""
    sleep 2
    /usr/bin/m-ssh 2>/dev/null || bash /etc/ayah-alma/ssh/m-ssh
    exit 1
fi

read -p "Add Expired Days  : " days

if ! [[ "$days" =~ ^[0-9]+$ ]]; then
    echo ""
    echo "[ ERROR ] Invalid days format!"
    echo ""
    sleep 2
    /usr/bin/m-ssh 2>/dev/null || bash /etc/ayah-alma/ssh/m-ssh
    exit 1
fi

# Mengambil tanggal expired saat ini atau dari hari ini
current_exp=$(chage -l "$user" | grep "Account expires" | cut -d: -f2)
current_exp_sec=$(date -d "$current_exp" +%s 2>/dev/null)
today_sec=$(date +%s)

if [[ "$current_exp_sec" -ge "$today_sec" ]]; then
    new_exp_sec=$((current_exp_sec + (days * 86400)))
else
    new_exp_sec=$(date -d "+$days days" +%s)
fi

new_exp_date=$(date -d "@$new_exp_sec" +%Y-%m-%d)

chage -E "$new_exp_date" "$user"

# Update file akun jika ada di /root/accounts/
ACCOUNT_FILE="/root/accounts/${user}.txt"
if [ -f "$ACCOUNT_FILE" ]; then
    sed -i "s/Expired      : .*/Expired      : $new_exp_date/" "$ACCOUNT_FILE"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "SUCCESSFULLY RENEWED"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Username     : $user"
echo "New Expired  : $new_exp_date"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  x. Kembali ke Menu Utama"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
read -p "Tekan [x atau Enter] untuk kembali: " menu_pilihan
/usr/bin/m-ssh 2>/dev/null || bash /etc/ayah-alma/ssh/m-ssh

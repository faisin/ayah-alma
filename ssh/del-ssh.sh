#!/bin/bash

clear

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "      DELETE SSH ACCOUNT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  x. Kembali ke Menu Utama"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
read -p "Username to delete [atau ketik x]: " user

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

# Hapus user dari sistem Linux
userdel -r "$user" 2>/dev/null || userdel "$user" 2>/dev/null

# Hapus file detail akun jika ada di /root/accounts/
ACCOUNT_FILE="/root/accounts/${user}.txt"
if [ -f "$ACCOUNT_FILE" ]; then
    rm -f "$ACCOUNT_FILE"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "SUCCESSFULLY DELETED"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Username     : $user"
echo "Status       : Removed from system"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  x. Kembali ke Menu Utama"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
read -p "Tekan [x atau Enter] untuk kembali: " menu_pilihan
/usr/bin/m-ssh 2>/dev/null || bash /etc/ayah-alma/ssh/m-ssh

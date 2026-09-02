#!/bin/bash

clear

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "      DELETE SSH ACCOUNT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

read -p "Username to delete : " user

if ! id "$user" &>/dev/null; then
    echo ""
    echo "[ ERROR ] Username does not exist!"
    echo ""
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


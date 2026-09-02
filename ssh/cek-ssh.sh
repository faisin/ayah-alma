#!/bin/bash

clear

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "    DETAIL SSH LOGIN USERS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Checking active sessions..."
echo ""

# Cek koneksi dari Dropbear dan OpenSSH yang sedang aktif
netstat -ntp | grep -E 'dropbear|sshd' | grep ESTABLISHED | while read -r line; do
    ip_port=$(echo "$line" | awk '{print $5}')
    remote_ip=$(echo "$ip_port" | cut -d: -f1)
    
    # Cari PID dan User pemilik koneksi
    pid_process=$(echo "$line" | awk '{print $7}' | cut -d/ -f1)
    if [[ "$pid_process" =~ ^[0-9]+$ ]]; then
        user=$(ps -o user= -p "$pid_process" 2>/dev/null)
        if [[ -n "$user" && "$user" != "root" && "$user" != "nobody" ]]; then
            echo " Username : $user"
            echo " IP Client: $remote_ip"
            echo " Status   : Connected"
            echo "--------------------------------"
        fi
    fi
done

# Cek juga sesi dari log login jika ada user yang aktif
if [ -f /var/log/auth.log ]; then
    last -n 10 -d | grep logged | head -n 5
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"


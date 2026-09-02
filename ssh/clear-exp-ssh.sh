#!/bin/bash

clear

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "    AUTOCLEAN EXPIRED SSH"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

today=$(date +%s)
count=0

while IFS=':' read -r user x uid gid comment home shell; do
    if [[ "$shell" == *"/bash"* || "$shell" == *"/sh"* ]]; then
        if [[ "$user" != "root" && "$user" != "daemon" && "$user" != "bin" && "$user" != "sys" && "$user" != "sync" && "$user" != "games" && "$user" != "man" && "$user" != "mail" && "$user" != "news" && "$user" != "uucp" && "$user" != "proxy" && "$user" != "www-data" && "$user" != "backup" && "$user" != "list" && "$user" != "irc" && "$user" != "gnats" && "$user" != "nobody" && "$user" != "systemd-network" && "$user" != "systemd-resolve" && "$user" != "messagebus" && "$user" != "_apt" && "$user" != "uuidd" && "$user" != "dnsmasq" && "$user" != "stunnel4" ]]; then
            
            exp_date=$(chage -l "$user" | grep "Account expires" | cut -d: -f2 | xargs)
            if [[ "$exp_date" != "never" && -n "$exp_date" ]]; then
                exp_sec=$(date -d "$exp_date" +%s 2>/dev/null)
                if [[ -n "$exp_sec" && "$exp_sec" -lt "$today" ]]; then
                    echo " [DELETED] Expired User : $user ($exp_date)"
                    userdel -r "$user" 2>/dev/null || userdel "$user" 2>/dev/null
                    rm -f "/root/accounts/${user}.txt"
                    count=$((count + 1))
                fi
            fi
        fi
    fi
done < /etc/passwd

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Total expired accounts removed : $count"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""


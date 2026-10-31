#!/usr/bin/env bash
# AYAH ALMA - Port Manager
# Updates known AYAH ALMA service configs with backups, validation and rollback.
set -Eeuo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
BACKUP_ROOT=/root/ayah-alma-port-backups
STAMP=$(date +%Y%m%d-%H%M%S)
CHANGED=()

say(){ echo -e "${CYAN}$*${NC}"; }
ok(){ echo -e "${GREEN}[OK]${NC} $*"; }
warn(){ echo -e "${YELLOW}[PERINGATAN]${NC} $*"; }
err(){ echo -e "${RED}[ERROR]${NC} $*" >&2; }
need_root(){ [[ $EUID -eq 0 ]] || { err 'Jalankan sebagai root.'; exit 1; }; }

backup_file(){
  local f=$1
  [[ -f $f ]] || return 0
  mkdir -p "$BACKUP_ROOT/$STAMP$(dirname "$f")"
  cp -a "$f" "$BACKUP_ROOT/$STAMP$f"
  CHANGED+=("$f")
}
restore_all(){
  local f
  for f in "${CHANGED[@]}"; do
    [[ -f "$BACKUP_ROOT/$STAMP$f" ]] && cp -a "$BACKUP_ROOT/$STAMP$f" "$f"
  done
  systemctl daemon-reload >/dev/null 2>&1 || true
  warn "Konfigurasi dipulihkan dari $BACKUP_ROOT/$STAMP"
}
trap 'rc=$?; if (( rc != 0 )) && ((${#CHANGED[@]})); then err "Proses gagal. Melakukan rollback."; restore_all; fi' EXIT

valid_port(){ [[ ${1:-} =~ ^[0-9]{1,5}$ ]] && ((10#$1 >= 1 && 10#$1 <= 65535)); }
ask_port(){
  local label=$1 old=$2 new
  echo
  say "$label | port sekarang: $old"
  read -rp 'Port baru (Enter untuk batal): ' new
  [[ -z $new ]] && return 1
  valid_port "$new" || { err 'Port harus angka 1-65535.'; return 1; }
  [[ $new == "$old" ]] && { warn 'Port tidak berubah.'; return 1; }
  printf '%s' "$new"
}

# Replace an exact numeric port in a set of files. Files are backed up once.
replace_port(){
  local old=$1 new=$2; shift 2
  local f
  for f in "$@"; do
    [[ -f $f ]] || continue
    if grep -Eq "(^|[^0-9])${old}([^0-9]|$)" "$f"; then
      if [[ ! " ${CHANGED[*]} " == *" $f "* ]]; then backup_file "$f"; fi
      OLD_PORT="$old" NEW_PORT="$new" perl -0777 -i -pe 's/(?<![0-9])\Q$ENV{OLD_PORT}\E(?![0-9])/$ENV{NEW_PORT}/g' "$f"
    fi
  done
}

check_collision(){
  local p=$1 proto=${2:-tcp}
  if command -v ss >/dev/null 2>&1; then
    if [[ $proto == udp ]]; then ss -H -lun "sport = :$p" | grep -q . && return 0
    else ss -H -ltn "sport = :$p" | grep -q . && return 0; fi
  fi
  return 1
}

change_group(){
  local label=$1 old=$2 proto=$3; shift 3
  local new
  new=$(ask_port "$label" "$old") || return 0
  if check_collision "$new" "$proto"; then err "Port $new/$proto sedang digunakan. Tidak diubah."; return 1; fi
  replace_port "$old" "$new" "$@"
  ok "$label: $old -> $new"
}

current_from(){
  local file=$1 regex=$2 fallback=$3 value
  if [[ -f $file ]]; then value=$(grep -Eo "$regex" "$file" | head -n1 | grep -Eo '[0-9]{1,5}$' || true); fi
  printf '%s' "${value:-$fallback}"
}

show_ports(){
  echo '--- Listener TCP/UDP ---'
  if command -v ss >/dev/null 2>&1; then ss -lntup; else echo 'Perintah ss tidak ditemukan.'; fi
  echo
  echo '--- Port konfigurasi utama ---'
  grep -nE '^[[:space:]]*bind |server (nginx_fallback|sshws|sshwss)|"port"|"listen"' \
    /etc/haproxy/haproxy.cfg /etc/xray/config.json /etc/nginx/sites-enabled/ayah-alma-fallback \
    /etc/ssh/sshd_config /etc/default/dropbear /etc/zivpn/config.json /etc/udp-custom/config.json 2>/dev/null || true
}

validate_and_restart(){
  systemctl daemon-reload
  if [[ -f /etc/ssh/sshd_config ]] && command -v sshd >/dev/null 2>&1; then sshd -t; fi
  if [[ -f /etc/haproxy/haproxy.cfg ]] && command -v haproxy >/dev/null 2>&1; then haproxy -c -f /etc/haproxy/haproxy.cfg; fi
  if [[ -f /etc/nginx/nginx.conf ]] && command -v nginx >/dev/null 2>&1; then nginx -t; fi
  if [[ -f /etc/xray/config.json ]] && command -v jq >/dev/null 2>&1; then jq -e '.inbounds | type == "array"' /etc/xray/config.json >/dev/null; fi

  # Restart only services affected by the edited configuration files.
  local f s
  local -a services=()
  for f in "${CHANGED[@]}"; do
    case "$f" in
      /etc/ssh/sshd_config) services+=(ssh ayah-ssh-ssl) ;;
      /etc/systemd/system/dropbear.service) services+=(dropbear) ;;
      /etc/haproxy/haproxy.cfg) services+=(haproxy) ;;
      /etc/nginx/sites-available/ayah-alma-fallback) services+=(nginx) ;;
      /etc/xray/config.json) services+=(xray) ;;
      /etc/stunnel/ayah-ssh-ssl.conf) services+=(ayah-ssh-ssl) ;;
      /etc/systemd/system/udpgw.service) services+=(udpgw) ;;
      /etc/udp-custom/config.json) services+=(udp-custom) ;;
      /etc/zivpn/config.json) services+=(zivpn) ;;
    esac
  done
  for s in "${services[@]}"; do
    systemctl list-unit-files "${s}.service" --no-legend 2>/dev/null | grep -q "${s}.service" || continue
    systemctl restart "$s" || { err "Gagal restart $s"; return 1; }
  done
}

need_root
mkdir -p "$BACKUP_ROOT"
while true; do
  echo
  echo -e "${GREEN}╔════════════ AYAH ALMA PORT MANAGER ════════════╗${NC}"
  cat <<'MENU'
 [1] OpenSSH
 [2] Dropbear port utama (109)
 [3] Dropbear port kedua (143)
 [4] HTTP publik HAProxy (80)
 [5] HTTPS publik HAProxy (443)
 [6] SSH SSL-only HAProxy (444)
 [7] HAProxy raw Xray (10011 / 10012 / 10013)
 [8] Nginx fallback (8080)
 [9] SSH WebSocket (2082) - source Go
[10] SSH WSS (2096) - source Go
[11] Stunnel SSH SSL-only internal (2222)
[12] BadVPN UDPGW (7300)
[13] UDP-Custom
[14] ZiVPN UDP
[15] Tampilkan semua port
 [0] Keluar
MENU
  read -rp 'Pilih: ' choice
  case "$choice" in
    1) old=$(current_from /etc/ssh/sshd_config '^[[:space:]]*Port[[:space:]]+[0-9]+' 22); change_group 'OpenSSH' "$old" tcp /etc/ssh/sshd_config /etc/stunnel/ayah-ssh-ssl.conf ;;
    2) change_group 'Dropbear port utama' 109 tcp /etc/systemd/system/dropbear.service /etc/dropbear/config ;;
    3) change_group 'Dropbear port kedua' 143 tcp /etc/systemd/system/dropbear.service /etc/dropbear/config ;;
    4) change_group 'HAProxy HTTP' 80 tcp /etc/haproxy/haproxy.cfg ;;
    5) change_group 'HAProxy HTTPS' 443 tcp /etc/haproxy/haproxy.cfg ;;
    6) change_group 'SSH SSL-only publik' 444 tcp /etc/haproxy/haproxy.cfg ;;
    7) echo 'Pilih port Xray TCP: 1=10011, 2=10012, 3=10013'; read -rp 'Nomor: ' n; case "$n" in 1) old=10011;;2) old=10012;;3) old=10013;;*) warn 'Pilihan tidak valid'; continue;; esac; new=$(ask_port "HAProxy/Xray TCP $old" "$old") || continue; check_collision "$new" tcp && { err 'Port sedang digunakan'; continue; }; replace_port "$old" "$new" /etc/haproxy/haproxy.cfg /etc/xray/config.json ;;
    8) change_group 'Nginx fallback' 8080 tcp /etc/nginx/sites-available/ayah-alma-fallback /etc/haproxy/haproxy.cfg ;;
    9|10) if [[ -d /opt/ayah-alma/internal/go ]]; then src=/opt/ayah-alma/internal/go; elif [[ -d /root/ayah-alma-main/internal/go ]]; then src=/root/ayah-alma-main/internal/go; else err 'Source Go AYAH ALMA tidak ditemukan. Ubah source lalu rebuild binary secara manual; tidak aman mengubah binary langsung.'; continue; fi
       if [[ $choice == 9 ]]; then old=2082; dir=dropbear-ws; else old=2096; dir=stunnel-ws; fi
       new=$(ask_port "Go WebSocket $old" "$old") || continue
       check_collision "$new" tcp && { err 'Port sedang digunakan'; continue; }
       replace_port "$old" "$new" "$src/$dir/main.go" /etc/haproxy/haproxy.cfg
       (cd "$src" && go build -o "/usr/local/bin/${dir/dropbear-ws/dropbearws}" "./$dir") || { err 'Build Go gagal'; exit 1; }
       ;;
    11) change_group 'Stunnel SSH internal' 2222 tcp /etc/stunnel/ayah-ssh-ssl.conf ;;
    12) change_group 'BadVPN UDPGW' 7300 tcp /etc/systemd/system/udpgw.service ;;
    13) old=$(current_from /etc/udp-custom/config.json '"listen"[[:space:]]*:[[:space:]]*":[0-9]+' 36712); change_group 'UDP-Custom' "$old" udp /etc/udp-custom/config.json ;;
    14) change_group 'ZiVPN' 5667 udp /etc/zivpn/config.json ;;
    15) show_ports; continue ;;
    0) break ;;
    *) warn 'Pilihan tidak dikenal'; continue ;;
  esac
  if ((${#CHANGED[@]})); then
    echo
    read -rp 'Validasi dan restart layanan sekarang? [y/N]: ' go
    if [[ $go =~ ^[Yy]$ ]]; then validate_and_restart || exit 1; ok 'Perubahan diterapkan.'; else warn 'Perubahan tersimpan, layanan belum direstart. Jalankan ulang tools setelah siap.'; fi
    echo "Backup: $BACKUP_ROOT/$STAMP"
  fi
done
trap - EXIT

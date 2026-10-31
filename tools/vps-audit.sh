#!/usr/bin/env bash
# Read-only audit for running directly on the target VPS.
# Usage: bash tools/vps-audit.sh [--static|--post-install]
set -uo pipefail

MODE="${1:---static}"
case "$MODE" in
  --static|--post-install) ;;
  *) echo "Usage: $0 [--static|--post-install]" >&2; exit 2 ;;
esac
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
FAIL=0
WARN=0
PASS=0

ok(){ printf '[LULUS] %s\n' "$*"; PASS=$((PASS+1)); }
fail(){ printf '[GAGAL] %s\n' "$*"; FAIL=$((FAIL+1)); }
warn(){ printf '[PERINGATAN] %s\n' "$*"; WARN=$((WARN+1)); }
section(){ printf '\n=== %s ===\n' "$*"; }

section 'Identitas sistem'
printf 'Waktu: '; date -Is 2>/dev/null || date
printf 'OS: '; . /etc/os-release 2>/dev/null && printf '%s %s\n' "${PRETTY_NAME:-unknown}" "${VERSION_ID:-}"
printf 'Arsitektur paket: '; dpkg --print-architecture 2>/dev/null || uname -m
printf 'Kernel: '; uname -r
printf 'Root filesystem: '; df -hP / | awk 'NR==2 {print $4 " tersedia dari " $2}'

section 'Sintaks shell'
SHELL_COUNT=0
while IFS= read -r -d '' f; do
  SHELL_COUNT=$((SHELL_COUNT+1))
  if bash -n "$f" 2>/tmp/ayah-alma-bash-check.err; then :; else
    fail "Sintaks Bash: $f ($(tr '\n' ' ' </tmp/ayah-alma-bash-check.err))"
  fi
done < <(find . -type f -name '*.sh' -print0)
if (( SHELL_COUNT > 0 )); then ok "bash -n: $SHELL_COUNT file .sh diperiksa"; else warn 'Tidak ada file .sh yang ditemukan'; fi
rm -f /tmp/ayah-alma-bash-check.err

section 'Sintaks Python'
if command -v python3 >/dev/null 2>&1; then
  if python3 - <<'PY'
import ast, sys
from pathlib import Path
files = [p for p in Path('.').rglob('*.py') if '__pycache__' not in p.parts]
errors=[]
for p in files:
    try: ast.parse(p.read_text(encoding='utf-8'), filename=str(p))
    except Exception as e: errors.append(f'{p}: {e}')
for e in errors: print(e, file=sys.stderr)
print(f'{len(files)} file Python diperiksa')
sys.exit(bool(errors))
PY
  then ok 'Sintaks Python valid'; else fail 'Ada file Python dengan sintaks tidak valid'; fi
else warn 'python3 tidak tersedia; pemeriksaan Python dilewati'; fi

section 'JSON'
if command -v python3 >/dev/null 2>&1; then
  if python3 - <<'PY'
import json, sys
from pathlib import Path
files=list(Path('config').glob('*.json'))
errors=[]
for p in files:
    try: json.loads(p.read_text(encoding='utf-8'))
    except Exception as e: errors.append(f'{p}: {e}')
for e in errors: print(e, file=sys.stderr)
print(f'{len(files)} file JSON diperiksa')
sys.exit(bool(errors))
PY
  then ok 'JSON konfigurasi valid'; else fail 'Ada JSON konfigurasi yang tidak valid'; fi
fi

section 'Go'
if [[ -f internal/go/go.mod ]] && command -v go >/dev/null 2>&1; then
  if (cd internal/go && go test ./...); then ok 'go test ./...'; else fail 'go test ./... gagal'; fi
else warn 'Go atau internal/go/go.mod tidak tersedia; pengujian Go dilewati'; fi

section 'Binary paket'
ARCH="$(dpkg --print-architecture 2>/dev/null || true)"
if [[ -n "$ARCH" && -d "bin/$ARCH" ]]; then
  for name in xray zivpn badvpn-udpgw udp-custom; do
    if [[ -s "bin/$ARCH/$name" ]]; then
      if command -v file >/dev/null 2>&1 && file "bin/$ARCH/$name" | grep -q ELF; then ok "Binary ELF tersedia: bin/$ARCH/$name";
      else warn "File bin/$ARCH/$name ada tetapi belum terbukti binary ELF"; fi
    else warn "bin/$ARCH/$name tidak ada di source checkout; installer harus mendapatkannya dari Release/sumber yang dikonfigurasi"; fi
  done
else warn "Folder binary untuk arsitektur '${ARCH:-unknown}' tidak ada; pastikan installer memiliki sumber binary yang sesuai"; fi

section 'Proxy web fallback'
if [[ -s config/nginx-fallback.conf && -s config/www/index.html ]]; then
  if grep -Eq 'listen[[:space:]]+127\.0\.0\.1:8080' config/nginx-fallback.conf; then ok 'Nginx template dibatasi ke loopback 127.0.0.1:8080'; else fail 'Nginx template tidak ditemukan bind loopback 127.0.0.1:8080'; fi
else fail 'config/nginx-fallback.conf atau config/www/index.html tidak ditemukan'; fi

section 'HAProxy'
if [[ "$MODE" == '--post-install' ]]; then
  if command -v nginx >/dev/null 2>&1; then
    if nginx -t; then ok 'Konfigurasi Nginx valid'; else fail 'nginx -t gagal'; fi
  else fail 'Nginx tidak terpasang'; fi
  if command -v haproxy >/dev/null 2>&1; then
    if [[ -s /etc/haproxy/haproxy.cfg ]]; then
      if haproxy -c -f /etc/haproxy/haproxy.cfg; then ok 'Konfigurasi HAProxy terpasang valid'; else fail 'haproxy -c gagal pada /etc/haproxy/haproxy.cfg'; fi
    else fail '/etc/haproxy/haproxy.cfg tidak ditemukan'; fi
  else fail 'HAProxy tidak terpasang'; fi
else
  if command -v haproxy >/dev/null 2>&1; then
    if command -v openssl >/dev/null 2>&1; then
      TMP="$(mktemp -d /tmp/ayah-alma-audit.XXXXXX)"
      trap 'rm -rf "${TMP:-}"' EXIT
      if openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj '/CN=localhost' -keyout "$TMP/key.pem" -out "$TMP/cert.pem" >/dev/null 2>&1 && cat "$TMP/cert.pem" "$TMP/key.pem" > "$TMP/ayah-alma.pem"; then
        sed "s# /etc/haproxy/certs/ayah-alma\.pem# $TMP/ayah-alma.pem#g" config/haproxy.cfg > "$TMP/haproxy.cfg"
        if haproxy -c -f "$TMP/haproxy.cfg"; then ok 'Template HAProxy valid dengan sertifikat sementara'; else fail 'Validasi template HAProxy gagal'; fi
      else warn 'Tidak dapat membuat sertifikat sementara untuk validasi HAProxy'; fi
      rm -rf "$TMP"; trap - EXIT
    else warn 'openssl tidak tersedia; validasi template HAProxy dilewati'; fi
  else warn 'HAProxy belum terpasang; validasi HAProxy akan dilakukan setelah paket terpasang'; fi
fi

if [[ "$MODE" == '--post-install' ]]; then
  section 'Status layanan setelah instalasi'
  for svc in nginx xray haproxy ssh dropbear dropbear-ws dropbear-wss udpgw udp-custom wg-quick@wg0 zivpn; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then ok "service aktif: $svc"; else fail "service tidak aktif: $svc (lihat: journalctl -u $svc -n 80 --no-pager)"; fi
  done
  if command -v xray >/dev/null 2>&1 && [[ -s /etc/xray/config.json ]]; then
    if xray -test -config /etc/xray/config.json; then ok 'Konfigurasi Xray valid'; else fail 'Validasi konfigurasi Xray gagal'; fi
  else warn 'Binary xray atau /etc/xray/config.json tidak ditemukan; validasi Xray dilewati'; fi
  section 'Audit alur port AYAH ALMA'
  if command -v ss >/dev/null 2>&1; then
    listener_has() {
      local port="$1" process="$2" out
      out="$(ss -H -lntp "sport = :$port" 2>/dev/null || true)"
      [[ -n "$out" ]] && grep -q "$process" <<<"$out"
    }
    for port in 80 443; do
      out="$(ss -H -lntp "sport = :$port" 2>/dev/null || true)"
      if [[ -n "$out" ]] && ! grep -qv haproxy <<<"$out"; then ok "port publik $port hanya dimiliki HAProxy"; else fail "port publik $port bukan eksklusif HAProxy"; fi
    done
    listener_has 8080 nginx && ok 'Nginx backend 8080 aktif' || fail 'Nginx backend 127.0.0.1:8080 tidak aktif'
    listener_has 109 dropbear && ok 'Dropbear port 109 aktif' || fail 'Dropbear port 109 tidak aktif'
    listener_has 143 dropbear && ok 'Dropbear port 143 aktif' || fail 'Dropbear port 143 tidak aktif'
    listener_has 2082 dropbearws && ok 'SSH WS bridge 2082 aktif' || fail 'SSH WS bridge 2082 tidak aktif'
    listener_has 2096 dropbearwss && ok 'SSH WSS bridge 2096 aktif' || fail 'SSH WSS bridge 2096 tidak aktif'
  else
    warn 'ss tidak tersedia; audit listener dilewati'
  fi
  if command -v jq >/dev/null 2>&1 && [[ -s /etc/xray/config.json ]]; then
    if jq -e 'all(.inbounds[]; .listen == "127.0.0.1") and (([.inbounds[].port] | length) == ([.inbounds[].port] | unique | length)) and all(.inbounds[]; .port != 22 and .port != 80 and .port != 443 and .port != 109 and .port != 143 and .port != 2082 and .port != 2096 and .port != 8080)' /etc/xray/config.json >/dev/null; then ok 'Semua inbound Xray loopback dan tidak bentrok'; else fail 'Inbound Xray tidak loopback atau port bentrok'; fi
  else warn 'jq atau konfigurasi Xray tidak tersedia; audit bind Xray dilewati'; fi
  section 'Port yang sedang listen (diagnostik)'
  if command -v ss >/dev/null 2>&1; then ss -lntup; else warn 'Perintah ss tidak tersedia'; fi
  section 'Catatan firewall provider'
  echo 'Periksa juga Security List/NSG firewall cloud secara manual; firewall OS tidak membuka port di panel provider.'
fi

section 'Ringkasan'
printf 'LULUS=%d  PERINGATAN=%d  GAGAL=%d\n' "$PASS" "$WARN" "$FAIL"
if (( FAIL > 0 )); then exit 1; fi
exit 0

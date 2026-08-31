#!/bin/bash
# Lihat daftar akun aktif WireGuard - by Ayah Alma

echo -e "🔍 Daftar Akun Aktif WireGuard:"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
wg show wg0[span_1](start_span)[span_1](end_span)
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
read -n 1 -s -r -p "Tekan apa saja untuk kembali ke menu utama..."
menu

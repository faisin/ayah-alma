#!/bin/bash
# Hapus akun WireGuard - by Ayah Alma

read -p "Masukkan nama user yang ingin dihapus: " user
pubkey=$(grep -A 3 "# $user" /etc/wireguard/wg0.conf | grep PublicKey | awk '{print $3}')[span_0](start_span)[span_0](end_span)

if [[ -z "$pubkey" ]]; then
  echo "❌ User tidak ditemukan!"
  exit 1
fi

# Hapus dari config
sed -i "/# $user/,+4d" /etc/wireguard/wg0.conf[span_1](start_span)[span_1](end_span)
rm -f /etc/wireguard/clients/$user.conf[span_2](start_span)[span_2](end_span)

systemctl restart wg-quick@wg0[span_3](start_span)[span_3](end_span)
echo -e "\n✅ Akun WireGuard '$user' berhasil dihapus[span_4](start_span)!"[span_4](end_span)

echo ""
read -n 1 -s -r -p "Tekan apa saja untuk kembali ke menu utama..."
menu


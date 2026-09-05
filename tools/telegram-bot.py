#!/usr/bin/env python3
import time
import requests

TOKEN = "8664159948:AAHezPA1l7L_TZ8lJ-zd78LcEaeUoUuT0m4"
URL = f"https://api.telegram.org/bot{TOKEN}/"

def send_message(chat_id, text, reply_markup=None):
    url = URL + "sendMessage"
    payload = {
        "chat_id": chat_id,
        "text": text,
        "parse_mode": "Markdown"
    }
    if reply_markup:
        payload["reply_markup"] = reply_markup
    try:
        requests.post(url, json=payload)
    except Exception as e:
        print(f"Gagal mengirim pesan: {e}")

def answer_callback_query(callback_query_id, text):
    url = URL + "answerCallbackQuery"
    payload = {
        "callback_query_id": callback_query_id,
        "text": text,
        "show_alert": True
    }
    try:
        requests.post(url, json=payload)
    except Exception as e:
        print(f"Gagal membalas callback: {e}")

def check_updates(offset=None):
    url = URL + "getUpdates?timeout=30"
    if offset:
        url += f"&offset={offset}"
    try:
        response = requests.get(url)
        return response.json()
    except Exception as e:
        print(f"Error koneksi: {e}")
        return None

def main():
    print("🤖 Bot Panel AYAH ALMA Berjalan...")
    offset = None
    while True:
        updates = check_updates(offset)
        if updates and "result" in updates:
            for update in updates["result"]:
                offset = update["update_id"] + 1
                
                # Menangani Pesan Teks Masuk
                if "message" in update:
                    chat_id = update["message"]["chat"]["id"]
                    text = update["message"].get("text", "")
                    
                    print(f"Pesan diterima dari {chat_id}: {text}")
                    
                    if text.startswith("/start"):
                        reply = "Selamat datang di *AYAH ALMA STORE* 🛒\nSilakan pilih menu di bawah ini:"
                        # Membuat Tombol Inline Interaktif
                        keyboard = {
                            "inline_keyboard": [
                                [{"text": "🌐 Daftar Harga VPN / Xray", "callback_data": "menu_produk"}],
                                [{"text": "💳 Cara Order & Pembayaran", "callback_data": "menu_cara_order"}],
                                [{"text": "👤 Hubungi Admin", "url": "https://t.me/anindyaalmahyra"}]
                            ]
                        }
                        send_message(chat_id, reply, keyboard)
                
                # Menangani Klik Tombol (Callback Query)
                elif "callback_query" in update:
                    callback_query = update["callback_query"]
                    callback_query_id = callback_query["id"]
                    chat_id = callback_query["message"]["chat"]["id"]
                    data = callback_query["data"]
                    
                    if data == "menu_produk":
                        reply = (
                            "📦 *DAFTAR PRODUK PREMIUM AYAH ALMA*\n\n"
                            "1️⃣ *Akun VIP Xray (30 Hari)*\n"
                            "   • Kecepatan Unlimited\n"
                            "   • Support Semua Operator\n"
                            "   • Harga: Rp 15.000\n\n"
                            "2️⃣ *Akun VIP SSH / OpenVPN (30 Hari)*\n"
                            "   • Harga: Rp 10.000\n\n"
                            "Silakan klik tombol Hubungi Admin untuk melakukan pembelian."
                        )
                        send_message(chat_id, reply)
                        answer_callback_query(callback_query_id, "Memuat daftar produk...")
                        
                    elif data == "menu_cara_order":
                        reply = (
                            "💳 *CARA PEMBELIAN:*\n\n"
                            "1. Pilih produk yang diinginkan.\n"
                            "2. Hubungi Admin melalui tombol Hubungi Admin.\n"
                            "3. Lakukan pembayaran via QRIS / Transfer Bank / E-Wallet.\n"
                            "4. Akun akan langsung dibuatkan setelah pembayaran dikonfirmasi."
                        )
                        send_message(chat_id, reply)
                        answer_callback_query(callback_query_id, "Memuat informasi pembayaran...")
                        
        time.sleep(1)

if __name__ == "__main__":
    main()

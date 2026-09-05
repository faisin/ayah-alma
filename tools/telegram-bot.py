#!/usr/bin/env python3
import time
import requests

# Token bot Anda yang aktif
TOKEN = "8664159948:AAHezPA1l7L_TZ8lJ-zd78LcEaeUoUuT0m4"
URL = f"https://api.telegram.org/bot{TOKEN}/"

def send_message(chat_id, text):
    url = URL + "sendMessage"
    payload = {
        "chat_id": chat_id,
        "text": text,
        "parse_mode": "Markdown"
    }
    try:
        requests.post(url, json=payload)
    except Exception as e:
        print(f"Gagal mengirim pesan: {e}")

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
    print("🤖 Bot Telegram Panel AYAH ALMA Berjalan...")
    offset = None
    while True:
        updates = check_updates(offset)
        if updates and "result" in updates:
            for update in updates["result"]:
                offset = update["update_id"] + 1
                
                if "message" in update:
                    chat_id = update["message"]["chat"]["id"]
                    text = update["message"].get("text", "")
                    
                    print(f"Pesan diterima dari {chat_id}: {text}")
                    
                    # Perintah /start
                    if text.startswith("/start"):
                        reply = "Halo! Selamat datang di Bot Panel *AYAH ALMA*.\nGunakan menu di VPS untuk mengelola server Anda."
                        send_message(chat_id, reply)
                        
                    # Perintah /kaget (Fitur Dana Kaget)
                    elif text.startswith("/kaget"):
                        reply = "🔗 Link Dana Kaget terbaru akan di-update secara berkala di sini."
                        send_message(chat_id, reply)
                        
        time.sleep(1)

if __name__ == "__main__":
    main()

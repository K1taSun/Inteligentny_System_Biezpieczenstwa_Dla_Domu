#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "❌ Uruchom jako root (sudo)."
  exit
fi

echo "📦 Instalacja pakietów systemowych..."
apt update && apt install -y python3-pip libcamera-apps gpac

echo "🐍 Instalacja bibliotek Pythona..."
pip3 install pyserial google-api-python-client google-auth-oauthlib --break-system-packages 2>/dev/null || pip3 install pyserial google-api-python-client google-auth-oauthlib

echo "👤 Konfiguracja uprawnień..."
usermod -a -G dialout ${SUDO_USER:-$(whoami)}

echo "🎉 Gotowe! Zrestartuj: sudo reboot"

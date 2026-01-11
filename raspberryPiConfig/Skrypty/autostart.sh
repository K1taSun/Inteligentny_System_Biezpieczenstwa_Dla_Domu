#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "Uruchom jako root (sudo)."
  exit
fi

DIR=$(pwd)
USER=${SUDO_USER:-$(whoami)}

# Upewnij sie ze skrypt startowy jest wykonywalny
chmod +x "$DIR/start.sh"

echo "Konfiguracja uslugi systemd w: $DIR"

# Tworzenie pliku uslugi
cat > /etc/systemd/system/security_system.service << EOF
[Unit]
Description=Security System Service
After=network.target

[Service]
ExecStart=$DIR/start.sh
WorkingDirectory=$DIR
Restart=always
User=$USER

[Install]
WantedBy=multi-user.target
EOF

# Przeladowanie i uruchomienie
systemctl daemon-reload
systemctl enable security_system.service
systemctl start security_system.service

echo "Gotowe. System dziala w tle i uruchomi sie po restarcie."

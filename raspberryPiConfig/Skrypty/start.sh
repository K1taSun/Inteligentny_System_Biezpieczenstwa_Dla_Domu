#!/bin/bash

# Ustawienie katalogu roboczego na katalog, w którym znajduje się skrypt
CDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$CDIR"

LOG_FILE="system.log"

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_msg "=== Start Systemu Bezpieczeństwa ==="

# Sprawdzenie czy mamy uprawnienia do portu szeregowego
if [ ! -r /dev/ttyACM0 ] && [ ! -r /dev/ttyUSB0 ]; then
    log_msg "UWAGA: Brak dostępu do portu szeregowego lub urządzenie niepodłączone."
    # Próbujemy nadać uprawnienia (może wymagać sudo wcześniej, tu tylko próba)
    # sudo chmod 666 /dev/ttyACM0 2>/dev/null
fi

while true; do
    log_msg "Uruchamianie procesu Python..."
    
    # Uruchomienie skryptu Python w tle, logując wyjście
    # -u wymusza niebuforowane wyjście (ważne dla logów)
    python3 -u Projekt.py >> "$LOG_FILE" 2>&1
    
    EXIT_CODE=$?
    
    if [ $EXIT_CODE -eq 0 ]; then
        log_msg "Proces zakończył się poprawnie (kod 0). Restart za 5s."
        sleep 5
    elif [ $EXIT_CODE -eq 130 ]; then
        # Kod 130 to zazwyczaj Ctrl+C (SIGINT)
        log_msg "Zatrzymano ręcznie (Ctrl+C). Kończenie pracy."
        break
    else
        log_msg "Proces padł z błędem (kod $EXIT_CODE). Restart awaryjny za 10s..."
        sleep 10
    fi
done

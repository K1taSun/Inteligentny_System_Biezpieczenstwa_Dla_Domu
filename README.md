# 🏠 Inteligentny System Bezpieczeństwa Dla Domu

Prosty, ale potężny system alarmowy typu DIY (Do-It-Yourself), który łączy sprzętowe czujniki z chmurą i aplikacją mobilną. Projekt integruje Arduino, Raspberry Pi oraz Fluttera, tworząc kompletne rozwiązanie do monitoringu domowego.

## 🚀 Jak to działa?

1.  **Wykrywanie**: Arduino monitoruje czujniki ruchu (PIR) oraz otwarcia drzwi/okien (kontaktron). Mierzy również temperaturę i wilgotność (DHT11).
2.  **Przetwarzanie**: Po wykryciu zagrożenia, Arduino wysyła sygnał do Raspberry Pi przez port szeregowy.
3.  **Reakcja**: Raspberry Pi natychmiast:
    *   📸 Nagrywa wideo zdarzenia.
    *   📧 Wysyła powiadomienie e-mail.
    *   ☁️ Uploaduje nagranie na Google Drive.
4.  **Podgląd**: Aplikacja mobilna (Flutter) pozwala na zdalny dostęp do nagrań z chmury.

## 🛠️ Technologie i Systemy

### 📱 Aplikacja Mobilna (Flutter)
*   **Framework**: Flutter & Dart
*   **Platformy**: Android / iOS
*   **Kluczowe Biblioteki**:
    *   `google_sign_in` & `googleapis` - Bezpieczna autoryzacja i dostęp do Google Drive.
    *   `video_player` - Odtwarzanie nagrań alarmowych prosto z chmury.
    *   `shared_preferences` - Przechowywanie lokalnych ustawień użytkownika.

### 🖥️ Jednostka Centralna (Raspberry Pi / Python)
*   **Język**: Python 3
*   **Kluczowe Moduły**:
    *   `google-api-python-client` - Obsługa Google Drive API v3 (upload nagrań).
    *   `pyserial` - Dwukierunkowa komunikacja UART z Arduino.
    *   `smtplib` - Wysyłanie powiadomień e-mail z alertami (SMTP SSL).
*   **Narzędzia Systemowe**:
    *   `libcamera-vid` - Niskopoziomowa obsługa kamery Raspberry Pi.
    *   `MP4Box` (GPAC) - Konwersja surowego strumienia wideo do formatu MP4.

### ⚡ Mikrokontroler (Arduino)
*   **Język**: C++ (Arduino IDE)
*   **Sprzęt**: Arduino Uno/Nano (lub kompatybilne).
*   **Biblioteki**: `SimpleDHT` (obsługa czujnika temperatury i wilgotności).
*   **Peryferia i Czujniki**:
    *   **PIR (HC-SR501)** - Wykrywanie ruchu.
    *   **DHT11** - Monitoring warunków środowiskowych.
    *   **Buzzer & LED** - Sygnalizacja stanu uzbrojenia i alarmu.

## 💡 Ciekawostka

Czy wiesz, że ten system potrafi "uzbroić się" z opóźnieniem, dając Ci czas na spokojne wyjście z domu? Sygnalizuje to miganiem diody LED i dźwiękiem buzzera, podobnie jak profesjonalne systemy alarmowe!

---
*Projekt stworzony w celach edukacyjnych.*

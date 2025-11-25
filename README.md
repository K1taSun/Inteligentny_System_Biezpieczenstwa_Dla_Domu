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

## 🛠️ Technologie

*   **Hardware**: Arduino (logika czujników), Raspberry Pi (kamera, komunikacja).
*   **Backend**: Python (obsługa Serial, Google Drive API, SMTP).
*   **Mobile**: Flutter (Android/iOS) z integracją Google Sign-In.
*   **Sensors**: PIR, Kontaktron, DHT11.

## 💡 Ciekawostka

Czy wiesz, że ten system potrafi "uzbroić się" z opóźnieniem, dając Ci czas na spokojne wyjście z domu? Sygnalizuje to miganiem diody LED i dźwiękiem buzzera, podobnie jak profesjonalne systemy alarmowe!

---
*Projekt stworzony w celach edukacyjnych.*


<div align="center">

<img src="https://img.shields.io/badge/status-active-success.svg" alt="Status">
<img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License">
<img src="https://img.shields.io/badge/platform-Raspberry%20Pi%20%7C%20Arduino%20%7C%20iOS%20%7C%20Android-lightgrey.svg" alt="Platform">
<img src="https://img.shields.io/badge/flutter-%3E%3D3.9.0-02569B.svg?logo=flutter" alt="Flutter">
<img src="https://img.shields.io/badge/python-3.x-3776AB.svg?logo=python&logoColor=white" alt="Python">

# 🏠 Inteligentny System Bezpieczeństwa Dla Domu

**Modułowy, samodzielny system alarmowy DIY łączący sprzętowe czujniki, przetwarzanie w chmurze i nowoczesną aplikację mobilną.**

[Funkcje](#-funkcje) •
[Architektura](#-architektura-systemu) •
[Instalacja](#-instalacja) •
[Konfiguracja](#%EF%B8%8F-konfiguracja) •
[Dokumentacja](#-dokumentacja-techniczna)

</div>

---

## 📋 Spis treści

- [Funkcje](#-funkcje)
- [Architektura systemu](#-architektura-systemu)
- [Stack technologiczny](#-stack-technologiczny)
- [Wymagania sprzętowe](#-wymagania-sprzętowe)
- [Instalacja](#-instalacja)
- [Konfiguracja](#%EF%B8%8F-konfiguracja)
- [Dokumentacja techniczna](#-dokumentacja-techniczna)
- [API i komunikacja](#-api-i-komunikacja)
- [Bezpieczeństwo](#-bezpieczeństwo)
- [Licencja](#-licencja)

---

## ✨ Funkcje

<table>
<tr>
<td width="50%">

### 🔐 Bezpieczeństwo
- **Czujnik ruchu PIR** — natychmiastowe wykrywanie intruzów
- **Opóźnione uzbrajanie** — 10s na opuszczenie strefy
- **Zdalne sterowanie** — aktywacja/dezaktywacja z aplikacji

</td>
<td width="50%">

### 📹 Monitoring
- **Automatyczne nagrywanie** — wideo przy każdym alarmie
- **Upload do chmury** — synchronizacja z Google Drive
- **Powiadomienia e-mail** — natychmiastowe alerty SMTP
- **Historia zdarzeń** — przegląd aktywności w aplikacji

</td>
</tr>
<tr>
<td width="50%">

### 🌡️ Środowisko
- **Temperatura i wilgotność** — monitoring DHT11
- **Odczyty w czasie rzeczywistym** — dane co 30 sekund
- **Format JSON** — łatwa integracja z innymi systemami

</td>
<td width="50%">

### 📱 Aplikacja mobilna
- **Cross-platform** — Android i iOS (Flutter)
- **Google Sign-In** — bezpieczna autoryzacja OAuth2
- **Odtwarzacz wideo** — podgląd nagrań z chmury
- **Nowoczesny UI** — ciemny motyw, responsywny design

</td>
</tr>
</table>

---

## 🏗️ Architektura systemu

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              WARSTWA FIZYCZNA                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│         ┌──────────────┐       ┌──────────────┐       ┌───────────┐         │
│         │  PIR HC-SR501│       │    DHT11     │       │  Buzzer   │         │
│         │  (czujnik    │       │ (temperatura │       │   + LED   │         │
│         │   ruchu)     │       │  wilgotność) │       │           │         │
│         └──────┬───────┘       └──────┬───────┘       └─────┬─────┘         │
│                │                      │                     │               │
│                └──────────────────────┼─────────────────────┘               │
│                                       │                                     │
│                        ┌──────────────▼──────────────┐                      │
│                        │        ARDUINO UNO          │                      │
│                        │   ● Debouncing sygnałów     │                      │
│                        │   ● Logika alarmu           │                      │
│                        │   ● Komunikacja UART 9600   │                      │
│                        └──────────────┬──────────────┘                      │
│                                       │ USB/Serial                          │
└───────────────────────────────────────┼─────────────────────────────────────┘
                                        │
┌───────────────────────────────────────┼─────────────────────────────────────┐
│                         WARSTWA PRZETWARZANIA                               │
├───────────────────────────────────────┼─────────────────────────────────────┤
│                                       │                                     │
│                        ┌──────────────▼──────────────┐                      │
│                        │       RASPBERRY PI          │                      │
│                        │                             │                      │
│                        │   ┌────────────────────┐    │                      │
│                        │   │   Projekt.py       │    │                      │
│                        │   │   ● pyserial       │    │                      │
│                        │   │   ● smtplib        │    │                      │
│                        │   │   ● googleapis     │    │                      │
│                        │   └────────────────────┘    │                      │
│                        │                             │                      │
│                        │   ┌────────────────────┐    │                      │
│                        │   │      libcamera-vid │    │                      │
│                        │   │      MP4Box        │    │                      │
│                        │   └────────────────────┘    │                      │
│                        └──────────────┬──────────────┘                      │
│                                       │                                     │
└───────────────────────────────────────┼─────────────────────────────────────┘
                                        │ HTTPS
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              WARSTWA CHMURY                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────────┐        ┌─────────────────┐        ┌───────────────┐   │
│   │   Gmail SMTP    │        │   Google Drive  │        │  OAuth 2.0    │   │
│   │                 │        │                 │        │               │   │
│   │  Powiadomienia  │        │  Nagrania MP4   │        │  Autoryzacja  │   │
│   │  alarmowe       │        │  z kamer        │        │  użytkownika  │   │
│   └─────────────────┘        └────────┬────────┘        └───────────────┘   │
│                                       │                                     │
└───────────────────────────────────────┼─────────────────────────────────────┘
                                        │ Drive API v3
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                            WARSTWA KLIENCKA                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│      ┌─────────────────────────────────────────────────────────────┐        │
│      │                     FLUTTER APP (iOS/Android)               │        │
│      │                                                             │        │
│      │   ┌───────────┐   ┌───────────┐   ┌───────────────────┐     │        │
│      │   │  Status   │   │  Nagrania │   │  Odtwarzacz       │     │        │
│      │   │  systemu  │   │  z chmury │   │  wideo            │     │        │
│      │   └───────────┘   └───────────┘   └───────────────────┘     │        │
│      │                                                             │        │
│      └─────────────────────────────────────────────────────────────┘        │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 🛠️ Stack technologiczny

<table>
<tr>
<th align="center" width="33%">📱 Aplikacja mobilna</th>
<th align="center" width="33%">🖥️ Jednostka centralna</th>
<th align="center" width="33%">⚡ Mikrokontroler</th>
</tr>
<tr>
<td valign="top">

**Framework**
- Flutter 3.9+
- Dart SDK ^3.9.2

**Biblioteki**
- `google_sign_in` — OAuth2
- `googleapis` — Drive API
- `video_player` — streaming
- `google_fonts` — typografia
- `shared_preferences` — cache

**Platformy**
- Android 5.0+ (API 21)
- iOS 12.0+

</td>
<td valign="top">

**Środowisko**
- Raspberry Pi OS
- Python 3.x

**Moduły Python**
- `google-api-python-client`
- `google-auth-oauthlib`
- `pyserial`
- `smtplib` (stdlib)

**Narzędzia systemowe**
- `libcamera-vid`
- `MP4Box` (GPAC)

</td>
<td valign="top">

**Platforma**
- Arduino Uno / Nano
- ATmega328P

**Biblioteki**
- `SimpleDHT`

**Peryferia**
- PIR HC-SR501
- DHT11
- Buzzer pasywny
- LED + rezystor

**Komunikacja**
- UART 9600 baud

</td>
</tr>
</table>

---

## 📦 Wymagania sprzętowe

### Lista komponentów

| Komponent | Model | Ilość | Uwagi |
|-----------|-------|:-----:|-------|
| Mikrokontroler | Arduino Uno/Nano | 1 | ATmega328P |
| Komputer jednopłytkowy | Raspberry Pi 2W/3/4/5 | 1 | |
| Moduł kamery | Raspberry Pi Camera v2/v3 | 1 | lub kompatybilna CSI |
| Czujnik ruchu | PIR HC-SR501 | 1 | zasięg 3-7m |
| Czujnik temp./wilg. | DHT11 | 1 | opcjonalnie DHT22 |
| Moduł dźwiękowy | Buzzer pasywny | 1 | 5V |
| Dioda LED | 5mm | 1 | + rezystor 220Ω |
| Przycisk | Tact switch | 1 | uzbrajanie lokalne |
| Zasilanie | 5V 2.5A+ | 1 | dla RPi |

### Schemat połączeń (Arduino)

```
Arduino Uno          Peryferia
─────────────        ─────────────────
   D2  ────────────►  PIR (OUT)
   D4  ────────────►  Buzzer (+)
   D5  ────────────►  Przycisk
   D6  ────────────►  LED (anoda)
   D7  ────────────►  DHT11 (DATA)
  GND  ────────────►  Wspólna masa
  5V   ────────────►  Zasilanie czujników
```

---

## 🚀 Instalacja

### 1️⃣ Arduino

```bash
1. Zainstaluj Arduino IDE
2. Dodaj bibliotekę SimpleDHT:
   Sketch → Include Library → Manage Libraries → SimpleDHT

 3. Wgraj sketch:
   Otwórz: arduinoConfig/arduino_conf.ino
    Wybierz płytkę i port
     Upload
```

### 2️⃣ Raspberry Pi

```bash
# Aktualizacja systemu
sudo apt update && sudo apt upgrade -y

# Instalacja zależności systemowych
sudo apt install -y python3-pip libcamera-apps gpac

# Klonowanie repozytorium
git clone https://github.com/K1taSun/Inteligentny_System_Biezpieczenstwa_Dla_Domu.git
cd Inteligentny_System_Biezpieczenstwa_Dla_Domu/raspberryPiConfig/Skrypty

# Instalacja zależności Python
pip3 install pyserial google-api-python-client google-auth-oauthlib

# Konfiguracja (patrz sekcja poniżej)
cp secure_config_template.py secure_config.py
nano secure_config.py
```

### 3️⃣ Aplikacja Flutter

```bash
# Wymagania: Flutter SDK >= 3.9.0
cd app_IOS:Android/phoneapp

# Instalacja zależności
flutter pub get

# Build Android
flutter build apk --release

# Build iOS (wymaga macOS + Xcode)
flutter build ios --release
```

---

## ⚙️ Konfiguracja

### Plik `secure_config.py`

Utwórz plik `raspberryPiConfig/Skrypty/secure_config.py`:

```python
 ═══════════════════════════════════════════════════════════
                   KONFIGURACJA SYSTEMU
 ═══════════════════════════════════════════════════════════

# ─────────────────────────────────────────────────────────────
  POŁĄCZENIE Z ARDUINO
# ─────────────────────────────────────────────────────────────
SERIAL_PORT = '/dev/ttyACM0'           # lub /dev/ttyUSB0

# ─────────────────────────────────────────────────────────────
 NAGRYWANIE WIDEO
# ─────────────────────────────────────────────────────────────
RECORDING_DURATION_SECONDS = 60
RECORDINGS_FOLDER = '/home/pi/nagrania'

# ─────────────────────────────────────────────────────────────
  POWIADOMIENIA E-MAIL (Gmail SMTP)
# ─────────────────────────────────────────────────────────────
SMTP_USER = "twoj_email@gmail.com"
SMTP_SEND_TO = "odbiorca@example.com"
SMTP_PASS = "xxxx xxxx xxxx xxxx"      # Hasło aplikacji Google
ALERT_SUBJECT = "⚠️ ALARM BEZPIECZEŃSTWA"
ALERT_MESSAGE = "Wykryto naruszenie strefy. Sprawdź nagranie."

# ─────────────────────────────────────────────────────────────
  GOOGLE DRIVE API
# ─────────────────────────────────────────────────────────────
GDRIVE_CLIENT_SECRET_FILE = '/home/pi/credentials/service_account.json'
GDRIVE_FOLDER_ID = 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
GDRIVE_UPLOAD_TRACK_FILE = 'uploaded_files.txt'
```

### Uzyskanie poświadczeń Google

<details>
<summary><b>📖 Instrukcja krok po kroku</b></summary>

1. **Google Cloud Console**
   - Wejdź na [console.cloud.google.com](https://console.cloud.google.com)
   - Utwórz nowy projekt lub wybierz istniejący

2. **Włącz API**
   - APIs & Services → Library
   - Wyszukaj i włącz: `Google Drive API`

3. **Utwórz Service Account** (dla Raspberry Pi)
   - APIs & Services → Credentials
   - Create Credentials → Service Account
   - Pobierz klucz JSON

4. **Utwórz OAuth Client ID** (dla aplikacji mobilnej)
   - Create Credentials → OAuth Client ID
   - Application type: Android/iOS
   - Pobierz `client_id`

5. **Udostępnij folder Drive**
   - Utwórz folder na Google Drive
   - Udostępnij go dla adresu e-mail Service Account

</details>

---

## 📖 Dokumentacja techniczna

### Protokół komunikacji Arduino ↔ Raspberry Pi

System wykorzystuje komunikację szeregową UART (9600 baud) z formatem JSON.

#### Wiadomości wychodzące (Arduino → RPi)

| Typ | Format | Opis |
|-----|--------|------|
| Status systemu | `{"system_active":bool,"alarm_active":bool,"armed":bool,"temp":float,"humidity":float}` | Odpowiedź na komendę STATUS |
| Dane środowiskowe | `{"temp":float,"humidity":float}` | Wysyłane co 30s |
| Alarm wykryty | `SYSTEM: Alarm AKTYWNY!` | Trigger nagrywania |
| Alarm wyłączony | `SYSTEM: Alarm WYŁĄCZONY.` | Zakończenie alarmu |
| Uzbrojenie | `System uzbrojony` | Po 10s opóźnienia |

#### Wiadomości przychodzące (RPi → Arduino)

```json
// Aktywacja systemu
{"command":"activate"}

// Dezaktywacja systemu  
{"command":"deactivate"}

// Zapytanie o status
{"command":"status"}
```

**Alternatywnie (tekstowe):**
```
ACTIVATE | ON
DEACTIVATE | OFF
STATUS
```

---

## 🔐 Bezpieczeństwo

### Najlepsze praktyki

| ✅ Zalecane | ❌ Unikaj |
|------------|----------|
| Hasła aplikacji Google (App Passwords) | Główne hasło konta Gmail |
| Service Account dla RPi | Osobiste dane logowania w kodzie |
| `.gitignore` dla `secure_config.py` | Commitowanie poświadczeń |
| Szyfrowane połączenie HTTPS | Nieszyfrowany transfer |
| Regularna rotacja kluczy | Stałe, nigdy niezmieniane hasła |

### Struktura `.gitignore`

```gitignore
# Konfiguracja wrażliwa
secure_config.py
*.json  # pliki poświadczeń Google

# Pliki tymczasowe
*.h264
uploaded_files.txt

# Środowisko
__pycache__/
.env
```

---

## 📊 Diagram sekwencji — Alarm

```
┌─────────┐      ┌─────────┐      ┌──────────┐      ┌─────────┐       ┌───────────┐
│  PIR    │      │ Arduino │      │ Rasp. Pi │      │  Gmail  │       │ G. Drive  │
└────┬────┘      └────┬────┘      └────┬─────┘      └────┬────┘       └─────┬─────┘
     │                │                │                 │                  │
     │  Ruch wykryty  │                │                 │                  │
     │───────────────►│                │                 │                  │
     │                │                │                 │                  │
     │                │ "SYSTEM: Alarm │                 │                  │
     │                │   AKTYWNY!"    │                 │                  │
     │                │───────────────►│                 │                  │
     │                │                │                 │                  │
     │                │                │  E-mail SMTP    │                  │
     │                │                │────────────────►│                  │
     │                │                │                 │                  │ 
     │                │                │  libcamera-vid  │                  │
     │                │                │◄───────────────►│                  │
     │                │                │  (nagrywanie)   │                  │
     │                │                │                 │                  │
     │                │                │  MP4Box convert │                  │ 
     │                │                │◄───────────────►│                  │ 
     │                │                │                 │                  │ 
     │                │                │           Upload vdeo              │
     │                │                │────────────────────────────────────►
     │                │                │                 │                  │
     │                │                │                 │     ✓ Gotowe     │
     │                │                │◄────────────────────────────────────
     │                │                │                 │                  │
```

---

## 🧪 Testowanie

```bash
# Test komunikacji szeregowej
python3 -c "import serial; s=serial.Serial('/dev/ttyACM0',9600); print(s.readline())"

# Test kamery
libcamera-vid -t 5000 -o test.h264

# Test Google Drive API
python3 -c "from Projekt import gDrive; gDrive()"
```

---

## 🗂️ Struktura projektu

```
Inteligentny_System_Biezpieczenstwa_Dla_Domu/
│
├── 📱 app_IOS:Android/
│   └── phoneapp/
│       ├── lib/
│       │   ├── main.dart
│       │   ├── screens/
│       │   │   ├── splash_screen.dart
│       │   │   ├── onboarding_screen.dart
│       │   │   ├── main_shell.dart
│       │   │   ├── status_screen.dart
│       │   │   ├── recordings_screen.dart
│       │   │   └── video_screen.dart
│       │   └── theme/
│       │       └── app_theme.dart
│       ├── pubspec.yaml
│       ├── android/
│       └── ios/
│
├── ⚡ arduinoConfig/
│   └── arduino_conf.ino
│
├── 🖥️ raspberryPiConfig/
│   └── Skrypty/
│       ├── Projekt.py
│       ├── secure_config_template.py
│       └── start.sh
│
├── 📄 docs/
│   └── screenshots/
│
├── LICENSE
└── README.md
```

---

## 🤝 Współpraca

Masz pomysł na ulepszenie? Świetnie!

1. **Fork** repozytorium
2. Utwórz **branch** dla funkcji (`git checkout -b feature/MojaFunkcja`)
3. **Commit** zmian (`git commit -m 'Dodaj MojaFunkcja'`)
4. **Push** na branch (`git push origin feature/MojaFunkcja`)
5. Otwórz **Pull Request**

---

## 📜 Licencja

Projekt udostępniony na licencji **MIT**.  
Zobacz plik [LICENSE](LICENSE) po szczegóły.

---

## 👨‍💻 Autor Nikita Parkovskyi

Projekt stworzony w celach edukacyjnych.

<div align="center">

**⭐ Jeśli projekt Ci się podoba, zostaw gwiazdkę! ⭐**

</div>

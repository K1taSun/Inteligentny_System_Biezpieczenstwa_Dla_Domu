/*
  INTELIGENTNY SYSTEM BEZPIECZEŃSTWA DLA DOMU
  =============================================
  Ten program obsługuje system alarmowy z czujnikami ruchu (PIR) i otwarcia (kontaktron),
  monitoruje temperaturę/wilgotność (DHT11) i komunikuje się z Raspberry Pi.
*/

#include <SimpleDHT.h>

// --- KONFIGURACJA PINÓW ---
// Tutaj przypisujemy elementy fizyczne do pinów Arduino
const int pirPin = 2;       // Czujnik ruchu
const int reedPin = 3;      // Czujnik otwarcia drzwi/okna
const int buzzerPin = 4;    // Głośnik/Buzzer
const int buttonPin = 5;    // Przycisk sterowania
const int ledPin = 6;       // Dioda LED
const int dhtPin = 7;       // Czujnik temperatury i wilgotności

// Inicjalizacja czujnika temperatury
SimpleDHT11 dht(dhtPin);

// --- STANY SYSTEMU ---
// Główne flagi określające co się dzieje w systemie
bool systemAktywny = false;   // Czy ochrona jest włączona?
bool alarmAktywny = false;    // Czy alarm właśnie wyje?
unsigned long czasStartu = 0; // Kiedy włączono system
const unsigned long opoznienieStartu = 10000; // Czas na opuszczenie domu (10s)

// --- KONFIGURACJA SYGNALIZACJI ---
// Zmienne do obsługi migania diodą LED
unsigned long ostatniMig = 0;
bool stanMigania = false;
bool miganiePoUzbrojeniu = false;
unsigned long czasMigania = 0;
int licznikMigniec = 0;
unsigned long ostatniaZmianaMigniecia = 0;
const unsigned long czasMigniecia = 150;

// --- OBSŁUGA PRZYCISKU ---
// Zmienne do eliminacji drgań styków (debounce)
bool ostatniStanPrzycisku = HIGH;
unsigned long czasOstatniegoNacisniecia = 0;
const unsigned long debouncePrzycisku = 50;

// --- OBSŁUGA CZUJNIKÓW ---
// Pamięć stanów czujników, żeby reagować tylko na zmiany
bool poprzedniStanOkna;
bool ostatniZarejestrowanyStanOkna;
unsigned long czasOstatniejZmianyOkna = 0;
const unsigned long debounceOkna = 50;
bool poprzedniStanPIR = false;
unsigned long czasOstatniejZmianyPIR = 0;
const unsigned long debouncePIR = 100;

// --- OBSŁUGA DŹWIĘKU ---
// Zmienne do odtwarzania dźwięków bez zatrzymywania programu
bool buzzerAktywny = false;
unsigned long czasBuzzerStart = 0;
unsigned long czasBuzzerStop = 0;
int trybBuzzer = 0; // 1=beep, 2=melodia
int licznikBeep = 0;
const unsigned long czasBeepON = 150;
const unsigned long czasBeepOFF = 150;
const unsigned long czasMelodiaON = 200;
const unsigned long czasMelodiaOFF = 100;

// --- OBSŁUGA DHT11 I KOMUNIKACJI ---
// Zmienne do pomiarów i wysyłania danych
float temperatura = 0.0;
float wilgotnosc = 0.0;
unsigned long ostatniOdczytDHT = 0;
const unsigned long interwalOdczytuDHT = 2000; // DHT potrzebuje min. 2s przerwy
unsigned long ostatnieWyslanieDanych = 0;
const unsigned long interwalWysylania = 30000; // Wysyłamy dane co 30s
bool dhtGotowy = false;

// --- OBSŁUGA KOMEND ZDALNYCH ---
// Bufor na polecenia z Raspberry Pi
String odebranaKomenda = "";
bool nowaKomenda = false;
const int maxDlugoscKomendy = 100;

// ================================================================
// KONFIGURACJA WSTĘPNA (uruchamiana raz)
// ================================================================
void setup() {
  // Ustawienie trybów pracy pinów
  pinMode(pirPin, INPUT);
  pinMode(reedPin, INPUT_PULLUP);
  pinMode(buttonPin, INPUT_PULLUP);
  pinMode(ledPin, OUTPUT);
  pinMode(buzzerPin, OUTPUT);

  // Stan początkowy wyjść
  digitalWrite(buzzerPin, HIGH); // Wyłączony (stan wysoki)
  analogWrite(ledPin, 0);        // Wyłączona
  
  // Start komunikacji z komputerem/RPi
  Serial.begin(9600);

  // Inicjalizacja liczników czasu i stanów
  ostatniOdczytDHT = millis();
  ostatnieWyslanieDanych = millis();
  poprzedniStanOkna = digitalRead(reedPin);
  ostatniZarejestrowanyStanOkna = poprzedniStanOkna;
  poprzedniStanPIR = (digitalRead(pirPin) == HIGH);
}

// ================================================================
// GŁÓWNA PĘTLA PROGRAMU (działa w kółko)
// ================================================================
void loop() {
  unsigned long teraz = millis(); // Aktualny czas systemu
  
  // 1. Sprawdź czy ktoś nacisnął przycisk (z eliminacją zakłóceń)
  bool aktualnyStanPrzycisku = digitalRead(buttonPin);
  if (aktualnyStanPrzycisku == LOW && ostatniStanPrzycisku == HIGH) {
    if (teraz - czasOstatniegoNacisniecia > debouncePrzycisku) {
      czasOstatniegoNacisniecia = teraz;
      aktywujSystem(teraz, !systemAktywny); // Przełącz stan systemu
    }
  }
  ostatniStanPrzycisku = aktualnyStanPrzycisku;

  // 2. Obsłuż zadania w tle (dźwięk, komunikacja, czujniki)
  aktualizujBuzzer(teraz);
  odczytajKomende();

  // 3. Wykonaj odebraną komendę zdalną (jeśli jest)
  if (nowaKomenda) {
    obsluzKomende(teraz);
    nowaKomenda = false;
    odebranaKomenda = "";
  }

  // 4. Odczytaj temperaturę i wilgotność
  aktualizujDHT(teraz);

  // 5. Wyślij dane do Raspberry Pi co określony czas
  if (teraz - ostatnieWyslanieDanych >= interwalWysylania) {
    wyslijDaneDHT();
    ostatnieWyslanieDanych = teraz;
  }

  // 6. Efekt świetlny podczas uzbrajania (odliczanie)
  if (systemAktywny && !miganiePoUzbrojeniu && !alarmAktywny) {
    unsigned long czasOdStartu = teraz - czasStartu;
    if (czasOdStartu <= opoznienieStartu) {
      // Rozjaśniaj diodę w miarę upływu czasu
      int jasnosc = map(czasOdStartu, 0, opoznienieStartu, 0, 255);
      analogWrite(ledPin, jasnosc);
    }
  }

  // 7. Potwierdzenie uzbrojenia (dwa mignięcia po czasie na wyjście)
  if (miganiePoUzbrojeniu) {
    unsigned long czasOdMigania = teraz - czasMigania;
    if (czasOdMigania > opoznienieStartu) {
      if (teraz - ostatniaZmianaMigniecia >= czasMigniecia) {
        ostatniaZmianaMigniecia = teraz;
        stanMigania = !stanMigania;
        analogWrite(ledPin, stanMigania ? 255 : 0);
        
        if (!stanMigania) {
          licznikMigniec++;
          if (licznikMigniec >= 2) {
            // Koniec sekwencji uzbrajania
            miganiePoUzbrojeniu = false;
            analogWrite(ledPin, 0);
            Serial.println("System uzbrojony");
            // Zresetuj stany czujników, żeby nie wywołać alarmu od razu
            poprzedniStanOkna = digitalRead(reedPin);
            ostatniZarejestrowanyStanOkna = poprzedniStanOkna;
            poprzedniStanPIR = (digitalRead(pirPin) == HIGH);
          }
        }
      }
    } else {
      // Jeśli jeszcze trwa odliczanie, świeć zależnie od czasu
      unsigned long czasOdStartu = teraz - czasStartu;
      int jasnosc = map(czasOdStartu, 0, opoznienieStartu, 0, 255);
      analogWrite(ledPin, jasnosc);
    }
  }

  // 8. MONITOROWANIE BEZPIECZEŃSTWA (tylko gdy system czuwa)
  if (systemAktywny && (teraz - czasStartu > opoznienieStartu) && !miganiePoUzbrojeniu) {
    // Sprawdź czujniki
    bool aktualnieOknoOtwarte = odczytajOkno(teraz);
    bool wykrytoRuch = odczytajPIR(teraz);

    // Raportuj zmiany stanu okna
    if (aktualnieOknoOtwarte != ostatniZarejestrowanyStanOkna) {
      if (aktualnieOknoOtwarte == HIGH) {
        Serial.println("ALARM OKNA: Okno zostało otwarte!");
      } else {
        Serial.println("INFO OKNA: Okno zostało zamknięte.");
      }
      ostatniZarejestrowanyStanOkna = aktualnieOknoOtwarte;
    }

    // Czy włączyć alarm?
    bool nowyStanAlarmu = wykrytoRuch || aktualnieOknoOtwarte;

    if (nowyStanAlarmu) {
      if (!alarmAktywny) {
        Serial.println("SYSTEM: Alarm AKTYWNY!");
        alarmAktywny = true;
      }

      // Mrugaj agresywnie diodą
      if (teraz - ostatniMig >= 100) {
        stanMigania = !stanMigania;
        analogWrite(ledPin, stanMigania ? 255 : 0);
        ostatniMig = teraz;
      }
      
      // Włącz syrenę
      if (trybBuzzer != 2) {
        uruchomMelodie();
      }
    } else {
      // Jeśli zagrożenie minęło, wyłącz alarm
      if (alarmAktywny) {
        Serial.println("SYSTEM: Alarm WYŁĄCZONY.");
        analogWrite(ledPin, 0);
        wylaczBuzzer();
        alarmAktywny = false;
      }
    }
  }
}

// ================================================================
// FUNKCJE POMOCNICZE
// ================================================================

// Odczytuje stan okna, ignorując krótkie zakłócenia
bool odczytajOkno(unsigned long teraz) {
  bool aktualnyStan = digitalRead(reedPin);
  
  if (aktualnyStan != poprzedniStanOkna) {
    if (teraz - czasOstatniejZmianyOkna > debounceOkna) {
      czasOstatniejZmianyOkna = teraz;
      poprzedniStanOkna = aktualnyStan;
      return aktualnyStan;
    }
  }
  return poprzedniStanOkna;
}

// Odczytuje czujnik ruchu, ignorując zakłócenia
bool odczytajPIR(unsigned long teraz) {
  bool aktualnyStan = (digitalRead(pirPin) == HIGH);
  
  if (aktualnyStan != poprzedniStanPIR) {
    if (teraz - czasOstatniejZmianyPIR > debouncePIR) {
      czasOstatniejZmianyPIR = teraz;
      poprzedniStanPIR = aktualnyStan;
      return aktualnyStan;
    }
  }
  return poprzedniStanPIR;
}

void aktualizujBuzzer(unsigned long teraz) {
  if (trybBuzzer == 0) return;

  if (trybBuzzer == 1) {
    if (buzzerAktywny) {
      if (teraz - czasBuzzerStart >= czasBeepON) {
        digitalWrite(buzzerPin, HIGH);
        buzzerAktywny = false;
        czasBuzzerStop = teraz;
      }
    } else {
      if (teraz - czasBuzzerStop >= czasBeepOFF) {
        if (licznikBeep > 0) {
          digitalWrite(buzzerPin, LOW);
          buzzerAktywny = true;
          czasBuzzerStart = teraz;
          licznikBeep--;
        } else {
          trybBuzzer = 0;
          digitalWrite(buzzerPin, HIGH);
        }
      }
    }
  } else if (trybBuzzer == 2) {
    if (buzzerAktywny) {
      if (teraz - czasBuzzerStart >= czasMelodiaON) {
        digitalWrite(buzzerPin, HIGH);
        buzzerAktywny = false;
        czasBuzzerStop = teraz;
      }
    } else {
      if (teraz - czasBuzzerStop >= czasMelodiaOFF) {
        digitalWrite(buzzerPin, LOW);
        buzzerAktywny = true;
        czasBuzzerStart = teraz;
      }
    }
  }
}

void uruchomBeep(int ilosc) {
  if (ilosc > 0) {
    trybBuzzer = 1;
    licznikBeep = ilosc * 2 - 1;
    buzzerAktywny = true;
    czasBuzzerStart = millis();
    digitalWrite(buzzerPin, LOW);
  }
}

void uruchomMelodie() {
  trybBuzzer = 2;
  buzzerAktywny = true;
  czasBuzzerStart = millis();
  digitalWrite(buzzerPin, LOW);
}

void wylaczBuzzer() {
  trybBuzzer = 0;
  buzzerAktywny = false;
  licznikBeep = 0;
  digitalWrite(buzzerPin, HIGH);
}

void aktualizujDHT(unsigned long teraz) {
  if (teraz - ostatniOdczytDHT >= interwalOdczytuDHT) {
    ostatniOdczytDHT = teraz;
    byte temp = 0;
    byte humidity = 0;
    int err = dht.read(&temp, &humidity, NULL);

    if (err == SimpleDHTErrSuccess) {
      temperatura = (float)temp;
      wilgotnosc = (float)humidity;
      dhtGotowy = true;
    } else {
      dhtGotowy = false;
    }
  }
}

void wyslijDaneDHT() {
  if (dhtGotowy) {
    Serial.print("{\"temp\":");
    Serial.print(temperatura, 1);
    Serial.print(",\"humidity\":");
    Serial.print(wilgotnosc, 1);
    Serial.println("}");
  } else {
    Serial.println("{\"error\":\"DHT11 not ready\"}");
  }
}

void odczytajKomende() {
  while (Serial.available() > 0 && odebranaKomenda.length() < maxDlugoscKomendy) {
    char znak = Serial.read();
    
    if (znak == '\n' || znak == '\r') {
      if (odebranaKomenda.length() > 0) {
        odebranaKomenda.trim();
        nowaKomenda = true;
        return;
      }
    } else {
      odebranaKomenda += znak;
    }
  }
  
  if (odebranaKomenda.length() >= maxDlugoscKomendy) {
    odebranaKomenda = "";
  }
}

void obsluzKomende(unsigned long teraz) {
  odebranaKomenda.trim();
  
  if (odebranaKomenda.startsWith("{") && odebranaKomenda.endsWith("}")) {
    if (odebranaKomenda.indexOf("\"command\"") >= 0) {
      if (odebranaKomenda.indexOf("\"activate\"") >= 0) {
        aktywujSystem(teraz, true);
        Serial.println("{\"status\":\"activated\",\"message\":\"System aktywowany zdalnie\"}");
      } else if (odebranaKomenda.indexOf("\"deactivate\"") >= 0) {
        aktywujSystem(teraz, false);
        Serial.println("{\"status\":\"deactivated\",\"message\":\"System dezaktywowany zdalnie\"}");
      } else if (odebranaKomenda.indexOf("\"status\"") >= 0) {
        wyslijStatus();
      } else {
        Serial.println("{\"error\":\"Unknown command\"}");
      }
      return;
    }
  }
  
  odebranaKomenda.toUpperCase();
  if (odebranaKomenda == "ACTIVATE" || odebranaKomenda == "ON") {
    aktywujSystem(teraz, true);
    Serial.println("{\"status\":\"activated\",\"message\":\"System aktywowany zdalnie\"}");
  } else if (odebranaKomenda == "DEACTIVATE" || odebranaKomenda == "OFF") {
    aktywujSystem(teraz, false);
    Serial.println("{\"status\":\"deactivated\",\"message\":\"System dezaktywowany zdalnie\"}");
  } else if (odebranaKomenda == "STATUS") {
    wyslijStatus();
  } else {
    Serial.println("{\"error\":\"Unknown command\"}");
  }
}

void aktywujSystem(unsigned long teraz, bool aktywuj) {
  systemAktywny = aktywuj;
  
  if (systemAktywny) {
    czasStartu = teraz;
    analogWrite(ledPin, 0);
    uruchomBeep(1);
    Serial.println("System aktywowany, uzbrojenie za 10 s.");
    miganiePoUzbrojeniu = true;
    czasMigania = teraz;
    licznikMigniec = 0;
    poprzedniStanOkna = digitalRead(reedPin);
    ostatniZarejestrowanyStanOkna = poprzedniStanOkna;
    poprzedniStanPIR = (digitalRead(pirPin) == HIGH);
  } else {
    alarmAktywny = false;
    miganiePoUzbrojeniu = false;
    analogWrite(ledPin, 0);
    wylaczBuzzer();
    uruchomBeep(2);
    Serial.println("System dezaktywowany.");
  }
}

void wyslijStatus() {
  Serial.print("{\"system_active\":");
  Serial.print(systemAktywny ? "true" : "false");
  Serial.print(",\"alarm_active\":");
  Serial.print(alarmAktywny ? "true" : "false");
  Serial.print(",\"armed\":");
  bool uzbrojony = systemAktywny && (millis() - czasStartu > opoznienieStartu) && !miganiePoUzbrojeniu;
  Serial.print(uzbrojony ? "true" : "false");
  Serial.print(",\"temp\":");
  Serial.print(temperatura, 1);
  Serial.print(",\"humidity\":");
  Serial.print(wilgotnosc, 1);
  Serial.println("}");
}

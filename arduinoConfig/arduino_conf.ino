#include <SimpleDHT.h>

const int pirPin = 2;    // Czujnik ruchu
const int buzzerPin = 4; // Głośnik/Buzzer
const int buttonPin = 5; // Przycisk sterowania
const int ledPin = 6;    // Dioda LED
const int dhtPin = 7;    // Czujnik temperatury i wilgotności

// inicjalizacja czujnika temperatury
SimpleDHT11 dht(dhtPin);

// główne flagi określające co się dzieje w systemie
bool systemAktywny = false;
bool alarmAktywny = false;
unsigned long czasStartu = 0;
const unsigned long opoznienieStartu = 10000;

// zmienne do obsługi migania diodą LED
unsigned long ostatniMig = 0;
bool stanMigania = false;
bool miganiePoUzbrojeniu = false;
unsigned long czasMigania = 0;
int licznikMigniec = 0;
unsigned long ostatniaZmianaMigniecia = 0;
const unsigned long czasMigniecia = 150;

// zmienne do eliminacji drgań styków (debounce)
bool ostatniStanPrzycisku = HIGH;
unsigned long czasOstatniegoNacisniecia = 0;
const unsigned long debouncePrzycisku = 50;

// pamięć stanów czujników, żeby reagować tylko na zmiany
bool poprzedniStanPIR = false;
unsigned long czasOstatniejZmianyPIR = 0;
const unsigned long debouncePIR = 100;

// zmienne do odtwarzania dźwięków bez zatrzymywania programu
bool buzzerAktywny = false;
unsigned long czasBuzzerStart = 0;
unsigned long czasBuzzerStop = 0;
int trybBuzzer = 0; // 1=beep, 2=melodia
int licznikBeep = 0;
const unsigned long czasBeepON = 150;
const unsigned long czasBeepOFF = 150;
const unsigned long czasMelodiaON = 200;
const unsigned long czasMelodiaOFF = 100;

// zmienne do pomiarów i wysyłania danych
float temperatura = 0.0;
float wilgotnosc = 0.0;
unsigned long ostatniOdczytDHT = 0;
const unsigned long interwalOdczytuDHT = 2000;
unsigned long ostatnieWyslanieDanych = 0;
const unsigned long interwalWysylania = 30000;
bool dhtGotowy = false;

// obsługa komend zdalnych
String odebranaKomenda = "";
bool nowaKomenda = false;
const int maxDlugoscKomendy = 100;

//_________________konfiguracja wstępna____________________
void setup() {

  // ustawienie trybów pracy pinów
  pinMode(pirPin, INPUT);
  pinMode(buttonPin, INPUT_PULLUP);
  pinMode(ledPin, OUTPUT);
  pinMode(buzzerPin, OUTPUT);

  // stan początkowy wyjść
  digitalWrite(buzzerPin, HIGH);
  analogWrite(ledPin, 0);

  // komunikacja
  Serial.begin(9600);

  // inicjalizacja liczników czasu i stanów
  ostatniOdczytDHT = millis();
  ostatnieWyslanieDanych = millis();
  poprzedniStanPIR = (digitalRead(pirPin) == HIGH);
}

// Główna pętla logiki systemu
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

            miganiePoUzbrojeniu = false;
            analogWrite(ledPin, 0);
            Serial.println(
                "{\"status\":\"armed\",\"message\":\"System uzbrojony\"}");

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

  // 8. MONITOROWANIE BEZPIECZEŃSTWA
  if (systemAktywny && (teraz - czasStartu > opoznienieStartu) &&
      !miganiePoUzbrojeniu) {

    // sprawdzanie czujnika ruchu
    bool wykrytoRuch = odczytajPIR(teraz);

    if (wykrytoRuch) {
      if (!alarmAktywny) {
        Serial.println("SYSTEM: Alarm AKTYWNY!");
        alarmAktywny = true;
      }

      if (teraz - ostatniMig >= 100) {
        stanMigania = !stanMigania;
        analogWrite(ledPin, stanMigania ? 255 : 0);
        ostatniMig = teraz;
      }

      if (trybBuzzer != 2) {
        uruchomMelodie();
      }
    } else {

      if (alarmAktywny) {
        Serial.println("SYSTEM: Alarm WYŁĄCZONY.");
        analogWrite(ledPin, 0);
        wylaczBuzzer();
        alarmAktywny = false;
      }
    }
  }
}

//__________________Funkcje do obsługi systemu____________________

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

// obsługa dźwięku
void aktualizujBuzzer(unsigned long teraz) {
  if (trybBuzzer == 0)
    return;

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

// obsługa dźwięku
void uruchomBeep(int ilosc) {
  if (ilosc > 0) {
    trybBuzzer = 1;
    licznikBeep = ilosc * 2 - 1;
    buzzerAktywny = true;
    czasBuzzerStart = millis();
    digitalWrite(buzzerPin, LOW);
  }
}

// obsługa melodii
void uruchomMelodie() {
  trybBuzzer = 2;
  buzzerAktywny = true;
  czasBuzzerStart = millis();
  digitalWrite(buzzerPin, LOW);
}

// wyłączanie dźwięku
void wylaczBuzzer() {
  trybBuzzer = 0;
  buzzerAktywny = false;
  licznikBeep = 0;
  digitalWrite(buzzerPin, HIGH);
}

// aktualizacja dht
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

// wysyłanie danych dht
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

// odczytywanie komend zdalnych
void odczytajKomende() {
  while (Serial.available() > 0 &&
         odebranaKomenda.length() < maxDlugoscKomendy) {
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

// obsługa komend zdalnych
void obsluzKomende(unsigned long teraz) {
  odebranaKomenda.trim();

  if (odebranaKomenda.startsWith("{") && odebranaKomenda.endsWith("}")) {
    if (odebranaKomenda.indexOf("\"command\"") >= 0) {
      if (odebranaKomenda.indexOf("\"activate\"") >= 0) {
        aktywujSystem(teraz, true);
        Serial.println("{\"status\":\"activated\",\"message\":\"System "
                       "aktywowany zdalnie\"}");
      } else if (odebranaKomenda.indexOf("\"deactivate\"") >= 0) {
        aktywujSystem(teraz, false);
        Serial.println("{\"status\":\"deactivated\",\"message\":\"System "
                       "dezaktywowany zdalnie\"}");
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
    Serial.println(
        "{\"status\":\"activated\",\"message\":\"System aktywowany zdalnie\"}");
  } else if (odebranaKomenda == "DEACTIVATE" || odebranaKomenda == "OFF") {
    aktywujSystem(teraz, false);
    Serial.println("{\"status\":\"deactivated\",\"message\":\"System "
                   "dezaktywowany zdalnie\"}");
  } else if (odebranaKomenda == "STATUS") {
    wyslijStatus();
  } else {
    Serial.println("{\"error\":\"Unknown command\"}");
  }
}

// aktywacja systemu
void aktywujSystem(unsigned long teraz, bool aktywuj) {
  systemAktywny = aktywuj;

  if (systemAktywny) {
    czasStartu = teraz;
    analogWrite(ledPin, 0);
    uruchomBeep(1);
    Serial.println("{\"status\":\"activated\",\"message\":\"System aktywowany, "
                   "uzbrojenie za 10s\"}");
    miganiePoUzbrojeniu = true;
    czasMigania = teraz;
    licznikMigniec = 0;
    poprzedniStanPIR = (digitalRead(pirPin) == HIGH);
  } else {
    alarmAktywny = false;
    miganiePoUzbrojeniu = false;
    analogWrite(ledPin, 0);
    wylaczBuzzer();
    uruchomBeep(2);
    Serial.println(
        "{\"status\":\"deactivated\",\"message\":\"System dezaktywowany\"}");
  }
}

// wysyłanie statusu systemu JSON
void wyslijStatus() {
  Serial.print("{\"system_active\":");
  Serial.print(systemAktywny ? "true" : "false");
  Serial.print(",\"alarm_active\":");
  Serial.print(alarmAktywny ? "true" : "false");
  Serial.print(",\"armed\":");
  bool uzbrojony = systemAktywny &&
                   (millis() - czasStartu > opoznienieStartu) &&
                   !miganiePoUzbrojeniu;
  Serial.print(uzbrojony ? "true" : "false");
  Serial.print(",\"temp\":");
  Serial.print(temperatura, 1);
  Serial.print(",\"humidity\":");
  Serial.print(wilgotnosc, 1);
  Serial.println("}");
}

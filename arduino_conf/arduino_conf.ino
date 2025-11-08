const int pirPin = 2;
const int reedPin = 3;
const int buzzerPin = 4;
const int buttonPin = 5;
const int ledPin = 6;

bool systemAktywny = false;
bool alarmAktywny = false;
unsigned long czasStartu = 0;
const unsigned long opoznienieStartu = 10000;
unsigned long ostatniMig = 0;
bool stanMigania = false;
bool ostatniStanPrzycisku = HIGH;
bool miganiePoUzbrojeniu = false;
unsigned long czasMigania = 0;
bool poprzedniStanOkna;

void setup() {
  pinMode(pirPin, INPUT);
  pinMode(reedPin, INPUT_PULLUP);
  pinMode(buttonPin, INPUT_PULLUP);
  pinMode(ledPin, OUTPUT);
  pinMode(buzzerPin, OUTPUT);

  digitalWrite(buzzerPin, HIGH);
  analogWrite(ledPin, 0);
  Serial.begin(9600);

  poprzedniStanOkna = digitalRead(reedPin);
}

void loop() {
  unsigned long teraz = millis();
  bool przyciskNacisniety = (digitalRead(buttonPin) == LOW);

  if (przyciskNacisniety && ostatniStanPrzycisku == HIGH) {
    delay(50);
    if (digitalRead(buttonPin) == LOW) {
      systemAktywny = !systemAktywny;

      if (systemAktywny) {
        czasStartu = teraz;
        analogWrite(ledPin, 0);
        beep(1);
        Serial.println("System aktywowany, uzbrojenie za 10 s.");
        miganiePoUzbrojeniu = true;
        czasMigania = teraz;
        poprzedniStanOkna = digitalRead(reedPin);
      } else {
        alarmAktywny = false;
        miganiePoUzbrojeniu = false;
        analogWrite(ledPin, 0);  // <-- wyłączenie diody
        digitalWrite(buzzerPin, HIGH);
        beep(2);
        Serial.println("System dezaktywowany.");
      }
    }
  }
  ostatniStanPrzycisku = digitalRead(buttonPin);

  if (systemAktywny && teraz - czasStartu <= opoznienieStartu) {
    int jasnosc = map(teraz - czasStartu, 0, opoznienieStartu, 0, 255);
    analogWrite(ledPin, jasnosc);
  }

  if (miganiePoUzbrojeniu && (teraz - czasMigania > opoznienieStartu)) {
    for (int i = 0; i < 2; i++) {
      analogWrite(ledPin, 0);
      delay(150);
      analogWrite(ledPin, 255);
      delay(150);
    }
    miganiePoUzbrojeniu = false;
    Serial.println("System uzbrojony");
    poprzedniStanOkna = digitalRead(reedPin);
    analogWrite(ledPin, 255);
  }

  if (systemAktywny && (teraz - czasStartu > opoznienieStartu) && !miganiePoUzbrojeniu) {
    bool wykrytoRuch = (digitalRead(pirPin) == HIGH);
    bool aktualnieOknoOtwarte = digitalRead(reedPin);

    if (aktualnieOknoOtwarte != poprzedniStanOkna) {
      if (aktualnieOknoOtwarte == HIGH) {
        Serial.println("ALARM OKNA: Okno zostało otwarte!");
      } else {
        Serial.println("INFO OKNA: Okno zostało zamknięte.");
      }
      poprzedniStanOkna = aktualnieOknoOtwarte;
    }

    bool nowyStanAlarmu = wykrytoRuch || aktualnieOknoOtwarte;

    if (nowyStanAlarmu) {
      if (!alarmAktywny) {
        Serial.println("SYSTEM: Alarm AKTYWNY!");
      }
      alarmAktywny = true;

      if (teraz - ostatniMig >= 100) {
        stanMigania = !stanMigania;
        analogWrite(ledPin, stanMigania ? 255 : 0);
        ostatniMig = teraz;
      }
      grajMelodie();
    } else {
      if (alarmAktywny) {
        Serial.println("SYSTEM: Alarm WYŁĄCZONY.");
        analogWrite(ledPin, 255);
        digitalWrite(buzzerPin, HIGH);
        alarmAktywny = false;
      }
    }
  }
}

void grajMelodie() {
  digitalWrite(buzzerPin, LOW);
  delay(200);
  digitalWrite(buzzerPin, HIGH);
  delay(100);
}

void beep(int ilosc) {
  for (int i = 0; i < ilosc; i++) {
    digitalWrite(buzzerPin, LOW);
    delay(150);
    digitalWrite(buzzerPin, HIGH);
    delay(150);
  }
}

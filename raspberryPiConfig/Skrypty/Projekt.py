import pickle
import smtplib
import serial
import time
import subprocess
import os
import threading
import json
import io
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime
import firebase_admin
from firebase_admin import credentials, db

# Globalne blokady dla zasobów
camera_lock = threading.Lock()


# KONFIGURACJA I IMPORTY

try:
	from secure_config import (
		SERIAL_PORT,              # Port Arduino (np. /dev/ttyACM0)
		RECORDING_DURATION_SECONDS, # Długość nagrania w sekundach
		RECORDINGS_FOLDER,        # Gdzie zapisywać filmy na RPi
		SMTP_USER,                # Twój Gmail
		SMTP_SEND_TO,             # Gdzie wysyłać alerty
		SMTP_PASS,                # Hasło aplikacji Google
		ALERT_SUBJECT,            # Temat maila alarmowego
		ALERT_MESSAGE,            # Treść maila alarmowego
		FIREBASE_CREDENTIALS_FILE # Ścieżka do klucza Firebase
	)
except ImportError as exc:
	raise RuntimeError(
		"BRAK PLIKU secure_config.py!\n"
		"Upewnij się, że masz zdefiniowane FIREBASE_CREDENTIALS_FILE w secure_config.py"
	) from exc


# INICJALIZACJA


# Tworzymy folder na nagrania, żeby kamera miała gdzie pisać
if not os.path.exists(RECORDINGS_FOLDER):
	try:
		os.makedirs(RECORDINGS_FOLDER)
		print(f"Utworzono folder na nagrania: {RECORDINGS_FOLDER}")
	except OSError as e:
		print(f"Nie udało się utworzyć folderu {RECORDINGS_FOLDER}: {e}")

# Próbujemy połączyć się z Arduino (pętla, aż się uda)
ser = None
while ser is None:
    try:
        ser = serial.Serial(SERIAL_PORT, 9600, timeout=1)
        time.sleep(2) # Arduino resetuje się po połączeniu, daj mu chwilę
        print(f"Połączono z Arduino na porcie: {SERIAL_PORT}")
    except serial.SerialException as e:
        print(f"Czekam na podłączenie Arduino do {SERIAL_PORT}... ({e})")
        time.sleep(5) # Spróbuj ponownie za 5 sekund

# Inicjalizacja Firebase
try:
	cred = credentials.Certificate(FIREBASE_CREDENTIALS_FILE)
	firebase_admin.initialize_app(cred, {
		'databaseURL': 'https://TWOJ-PROJEKT.firebaseio.com/' # ZMIEŃ TO NA SWÓJ URL
	})
	print("Połączono z Firebase!")
except Exception as e:
	print(f"Błąd inicjalizacji Firebase: {e}")

# FUNKCJE POMOCNICZE


def nagraj_wideo():
	"""
	1. Nagrywa surowe wideo z kamery (.h264)
	2. Konwertuje je do formatu .mp4 (żeby działało na telefonie)
	3. Usuwa surowy plik, żeby nie śmiecić
	"""
	"""
	1. Nagrywa surowe wideo z kamery (.h264)
	2. Konwertuje je do formatu .mp4 (żeby działało na telefonie)
	3. Usuwa surowy plik, żeby nie śmiecić
	"""
	# Sprawdzamy, czy kamera nie jest już zajęta
	if not camera_lock.acquire(blocking=False):
		print("⚠️ Kamera jest zajęta! Pomijam nagrywanie.")
		return None
		
	try:
		timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
		plik_h264 = os.path.join(RECORDINGS_FOLDER, f"alarm_{timestamp}.h264")
		plik_mp4 = os.path.join(RECORDINGS_FOLDER, f"alarm_{timestamp}.mp4")
		
		print(f"🎥 Rozpoczynam nagrywanie wideo: {plik_h264}")
		
		# Uruchamiamy systemowe narzędzie do nagrywania
		subprocess.run([
			"libcamera-vid",
			"-t", str(RECORDING_DURATION_SECONDS * 1000), # czas w milisekundach
			"-o", plik_h264,
			"--width", "1296",
			"--height", "972",
			"--nopreview" # bez podglądu na ekranie RPi (oszczędza zasoby)
		], check=True)
		
		print(f"🎬 Koniec nagrywania. Przerabiam na MP4...")
		
		# Konwersja (MP4Box jest szybszy niż ffmpeg)
		if os.path.exists(plik_h264):
			subprocess.run(
				["MP4Box", "-add", plik_h264, plik_mp4],
				stdout=subprocess.DEVNULL, # Nie wypisuj śmieci na ekran
				stderr=subprocess.DEVNULL
			)
			print(f"Film gotowy: {plik_mp4}")
			os.remove(plik_h264) # Kasujemy plik tymczasowy
			return plik_mp4
		else:
			print(f"Coś poszło nie tak - brak pliku z kamery!")
			return None
			
	except Exception as e:
		print(f"Błąd kamery (czy jest podłączona?): {e}")
		return None
	finally:
		# Zwalniamy blokadę, żeby inny wątek mógł użyć kamery
		camera_lock.release()

def mail_alarmowy():
	"""Wysyła szybkiego maila z ostrzeżeniem."""
	try:
		msg = MIMEMultipart()
		msg['Subject'] = ALERT_SUBJECT
		msg['From'] = SMTP_USER
		msg['To'] = SMTP_SEND_TO
		msg.attach(MIMEText(ALERT_MESSAGE, 'plain'))
		
		# Łączymy się z Gmailem przez bezpieczne połączenie SSL
		with smtplib.SMTP_SSL("smtp.gmail.com", 465) as server:
			server.login(SMTP_USER, SMTP_PASS)
			server.sendmail(SMTP_USER, SMTP_SEND_TO, msg.as_string())
			
		print("Mail alarmowy wysłany!")
	except Exception as e:
		print(f"Nie udało się wysłać maila (sprawdź hasło/internet): {e}")

def gDrive_upload():
	"""Wrzuca nowe filmy na Google Drive, żebyś mógł je zobaczyć w aplikacji."""
	try:
		# === Sprawdź, co już wysłaliśmy ===
		def load_uploaded_files():
			if not os.path.exists(GDRIVE_UPLOAD_TRACK_FILE):
				return set()
			with open(GDRIVE_UPLOAD_TRACK_FILE, 'r') as f:
				return set(line.strip() for line in f)

		# === Zapamiętaj wysłany plik ===
		def save_uploaded_file(filename):
			with open(GDRIVE_UPLOAD_TRACK_FILE, 'a') as f:
				f.write(filename + '\n')

		# === Start Wysyłania ===
		service = get_drive_service()
		if not service:
			return

		print("Sprawdzam, czy są nowe filmy do wysłania...")
		uploaded_files = load_uploaded_files()
		
		files_found = False
		# Przeszukaj folder z nagraniami
		for filename in os.listdir(RECORDINGS_FOLDER):
			# Jeśli to plik MP4 i jeszcze go nie wysłaliśmy
			if filename.lower().endswith('.mp4') and filename not in uploaded_files:
				files_found = True
				file_path = os.path.join(RECORDINGS_FOLDER, filename)

				# Przygotuj dane dla Google
				file_metadata = {
					'name': filename,
					'parents': [GDRIVE_FOLDER_ID] # ID folderu z configa
				}

				media = MediaFileUpload(file_path, mimetype='video/mp4', resumable=True)

				print(f'Wysyłam: {filename} ...')
				service.files().create(
					body=file_metadata,
					media_body=media,
					fields='id'
				).execute(num_retries=3) # Spróbuj 3 razy, jakby zerwało neta

				save_uploaded_file(filename)
				print(f'Wysłano sukcesywnie!')
		
		if not files_found:
			print("Wszystko aktualne, brak nowych nagrań.")
		else:
			print("Synchronizacja zakończona.")

	except Exception as e:
		print(f"Problem z Google Drive (Upload): {e}")

def procedura_alarmowa():
	"""
	To jest główna akcja po wykryciu włamywacza.
	Działa w osobnym wątku, żeby nie blokować reszty systemu.
	"""
	print(">>> [ALARM] Uruchamiam procedurę bezpieczeństwa! <<<")
	
	# 1. Najpierw wyślij maila (bo to najszybsze)
	mail_thread = threading.Thread(target=mail_alarmowy)
	mail_thread.start()
	
	# 2. Zacznij nagrywać (to chwilę potrwa)
	plik = nagraj_wideo()
	
	# 3. Jak nagrało, to wyślij do chmury
	if plik:
		gDrive_upload()
	
	# Poczekaj aż mail wyjdzie, żeby posprzątać wątek
	mail_thread.join(timeout=10)
	print("<<< [ALARM] Procedura zakończona. Czuwam dalej. >>>")


# ZDALNE STEROWANIE (REMOTE CONTROL)


REMOTE_FILE_NAME = "remote_status.json"
# Listener Firebase (zastępuje polling)
def on_firebase_change(event):
	"""Wywoływane automatycznie, gdy zmienią się dane w bazie."""
	global last_known_remote_state
	
	if event.data is None: return
	
	try:
		# Jeśli zmieniono bezpośrednio 'armed' lub cały obiekt 'system_status'
		data = event.data
		is_armed = False
		
		# Logika zależy od tego czy dostaniemy słownik czy wartość
		if isinstance(data, dict) and 'armed' in data:
			is_armed = data['armed']
		elif isinstance(data, bool): # Jeśli nasłuchujemy bezpośrednio pola armed (zależnie od path)
			is_armed = data
			
		# Wysyłamy do Arduino tylko jeśli stan się zmienił
		if last_known_remote_state != is_armed:
			print(f"🔥 Firebase: Zmiana stanu na {'UZBROJONY' if is_armed else 'ROZBROJONY'}")
			command = "ACTIVATE" if is_armed else "DEACTIVATE"
			if ser and ser.is_open:
				ser.write((command + "\n").encode('utf-8'))
			last_known_remote_state = is_armed

	except Exception as e:
		print(f"Błąd przetwarzania z Firebase: {e}")

# Podpinamy listener
try:
	ref = db.reference('system_status')
	ref.listen(on_firebase_change)
except Exception as e:
	print(f"Nie udało się podpiąć listenera: {e}")

# PĘTLA GŁÓWNA


print("=== SYSTEM GOTOWY I NASŁUCHUJE ===")
alarm_aktywny = False

# Startujemy wątek, który sprawdza aplikację w tle
threading.Thread(target=watek_zdalnego_sterowania, daemon=True).start()

try:
	while True:
		try:
			# Sprawdzamy czy Arduino coś do nas mówi
			if ser.in_waiting > 0:
				try:
					raw_line = ser.readline()
					line = raw_line.decode('utf-8').strip()
				except UnicodeDecodeError:
					print(f"Dostałem śmieci z Arduino (zakłócenia): {raw_line}")
					continue
				
				if line:
					print(f"[Arduino]: {line}")
					
					# Próbujemy sparsować JSON z Arduino
					try:
						arduino_data = json.loads(line)
						
						# Synchronizacja stanu: Arduino -> Chmura
						if 'status' in arduino_data:
							if arduino_data['status'] == 'activated':
								if last_known_remote_state is not True:
									db.reference('system_status').update({'armed': True})
									last_known_remote_state = True
							elif arduino_data['status'] == 'deactivated':
								if last_known_remote_state is not False:
									db.reference('system_status').update({'armed': False})
									last_known_remote_state = False

						# Cache temperature/humidity if present
						updates = {}
						if 'temp' in arduino_data: 
							updates['temp'] = arduino_data['temp']
						if 'humidity' in arduino_data: 
							updates['humidity'] = arduino_data['humidity']
						
						if updates:
							db.reference('system_status').update(updates)

					except json.JSONDecodeError:
						# To nie był JSON, ignorujemy (ale logujemy wyżej)
						pass

				# === LOGIKA ALARMU ===
				# Jeśli Arduino krzyczy, że jest alarm
				if "SYSTEM: Alarm AKTYWNY!" in line and not alarm_aktywny:
					alarm_aktywny = True
					print("!!! WŁAMANIE !!! ")
					
					# Odpalamy całą maszynę (mail, wideo, chmura) w tle
					threading.Thread(target=procedura_alarmowa, daemon=True).start()

				# Jeśli alarm się uspokoił
				elif "SYSTEM: Alarm WYŁĄCZONY." in line and alarm_aktywny:
					alarm_aktywny = False
					print("Sytuacja opanowana - alarm wyłączony.")

			# Krótka drzemka dla procesora
			time.sleep(0.05)
			
		except OSError as e:
			print(f"Odłączono Arduino! Próbuję połączyć ponownie... ({e})")
			time.sleep(5)
			try:
				ser.close()
				ser = serial.Serial(SERIAL_PORT, 9600, timeout=1)
				print("Uff, wróciło połączenie.")
			except:
				pass

except KeyboardInterrupt:
	print("\nZatrzymuję system na żądanie użytkownika...")
	if ser:
		ser.close()
	print("Do widzenia!")

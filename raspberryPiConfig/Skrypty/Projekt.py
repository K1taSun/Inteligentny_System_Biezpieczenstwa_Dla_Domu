import pickle
import smtplib
import serial
import time
import subprocess
import os
import subprocess
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
from google.oauth2 import service_account

try:
	from secure_config import (
		SERIAL_PORT,
		RECORDING_DURATION_SECONDS,
		RECORDINGS_FOLDER,
		SMTP_USER,
		SMTP_SEND_TO,
		SMTP_PASS,
		ALERT_SUBJECT,
		ALERT_MESSAGE,
		GDRIVE_CLIENT_SECRET_FILE,
		GDRIVE_FOLDER_ID,
		GDRIVE_UPLOAD_TRACK_FILE,
	)
except ImportError as exc:
	raise RuntimeError(
		"Brak pliku secure_config.py. Skopiuj go z secure_config_template.py i uzupełnij danymi."
	) from exc


ser = serial.Serial(SERIAL_PORT,9600,timeout=1)
time.sleep(2)


if not os.path.exists(RECORDINGS_FOLDER):
	os.makedirs(RECORDINGS_FOLDER)


def nagraj_wideo():
	timestamp=datetime.now().strftime("%Y%m%d_%H%M%S")
	plik_h264=os.path.join(RECORDINGS_FOLDER, f"alarm_{timestamp}.h264")
	plik_mp4=os.path.join(RECORDINGS_FOLDER, f"alarm_{timestamp}.mp4")
	print(f"Start nagrywania: {plik_h264}")

	subprocess.run([
		"libcamera-vid",
		"-t", str(RECORDING_DURATION_SECONDS*1000),
		"-o", plik_h264,
		"--width", "1296",
		"--height", "972",
		"--nopreview"
	])
	print(f"Nagranie zakończone: {plik_h264}")
	time.sleep(1)
	print(f"Konwertacja do MP4.....")

	if os.path.exists(plik_h264):
		subprocess.run([
		"MP4Box", "-add", plik_h264, plik_mp4])
		print(f"Gotowe: {plik_mp4}")
		os.remove(plik_h264)
	else:
		print(f"PROBLEM Z PLIKIEM")
def mail_alarmowy():
	msg = MIMEMultipart()
	msg['Subject']= ALERT_SUBJECT
	msg['From']= SMTP_USER
	msg['To']= SMTP_SEND_TO
	msg.attach(MIMEText(ALERT_MESSAGE,'plain'))
	try:
		with smtplib.SMTP_SSL("smtp.gmail.com", 465) as server:
			server.login(SMTP_USER,SMTP_PASS)
			server.sendmail(SMTP_USER, SMTP_SEND_TO, msg.as_string())
			server.quit()
		print("Wiadomość e-mail awtomatycznie wysłana.")
	except Exception as e:
		print(f"Błąd wysyłania e-maila: {e}")
def gDrive():
	# === Ustawienia ===
	CLIENT_SECRET_FILE = GDRIVE_CLIENT_SECRET_FILE
	API_NAME = 'drive'
	API_VERSION = 'v3'
	SCOPES = ['https://www.googleapis.com/auth/drive']
	FOLDER_ID = GDRIVE_FOLDER_ID
	LOCAL_FOLDER = RECORDINGS_FOLDER
	UPLOADED_TRACK_FILE = GDRIVE_UPLOAD_TRACK_FILE

	# === Funkcja autoryzacji ===
	def Create_Service(client_secret_file, api_name, api_version, scopes):
    		creds = service_account.Credentials.from_service_account_file(client_secret_file, scopes=scopes)
    		return build(api_name, api_version, credentials=creds)

	# === Wczytaj listę już przesłanych plików ===
	def load_uploaded_files():
    		if not os.path.exists(UPLOADED_TRACK_FILE):
        		return set()
    		with open(UPLOADED_TRACK_FILE, 'r') as f:
        		return set(line.strip() for line in f)
	# === Zapisz nazwę przesłanego pliku ===
	def save_uploaded_file(filename):
    		with open(UPLOADED_TRACK_FILE, 'a') as f:
        		f.write(filename + '\n')

	# === Start ===
	service = Create_Service(CLIENT_SECRET_FILE, API_NAME, API_VERSION, SCOPES)
	uploaded_files = load_uploaded_files()

	# Pobierz wszystkie .mp4 z folderu
	for filename in os.listdir(LOCAL_FOLDER):
    		if filename.lower().endswith('.mp4') and filename not in uploaded_files:
        		file_path = os.path.join(LOCAL_FOLDER, filename)

        		file_metadata = {
            			'name': filename,
            			'parents': [FOLDER_ID]
        		}

        		media = MediaFileUpload(file_path, mimetype='video/mp4', resumable=True)

        		print(f'Wysyłanie: {filename}')
        		service.files().create(
            			body=file_metadata,
            			media_body=media,
            			fields='id'
        		).execute(num_retries=3)

        		save_uploaded_file(filename)
        		print(f'✅ Wysłano: {filename}\n')

	print("Gotowe. Wszystkie nowe pliki zostały przesłane.")


#LOGIKA
alarm_aktywny = False
try:
	while True:
		if ser.in_waiting > 0:
			line = ser.readline().decode('utf-8').strip()
			print(f"Odebrano: {line}")

			if "SYSTEM: Alarm AKTYWNY!" in line and not alarm_aktywny:
				alarm_aktywny=True
				print("<<< ALARM WYKRYTY >>>")
				print("LOGIKA_START mail_alarmowy()")
				mail_alarmowy()
				print("KONIEC_1 oraz START nagraj_wideo()")
				nagraj_wideo()
				print("KONIEC_2")
				gDrive()
				print("KONIEC_3")

			elif "SYSTEM: Alarm WYŁĄCZONY." in line and alarm_aktywny:
				alarm_aktywny=False
				print(">>> ALARM WYŁĄCZONY <<<")

except KeyboardInterrupt:
	print(f"Zatrzymywanie programu.......")
	ser.close()

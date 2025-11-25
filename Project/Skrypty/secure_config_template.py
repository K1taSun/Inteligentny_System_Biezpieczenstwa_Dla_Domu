"""
Skopiuj ten plik do secure_config.py i uzupełnij prawdziwymi danymi.
secure_config.py powinien pozostać poza repozytorium (patrz Project/.gitignore).
"""

SERIAL_PORT = '/dev/ttyACM0'
RECORDING_DURATION_SECONDS = 60
RECORDINGS_FOLDER = '/home/USERNAME/Desktop/Project/Nagrania'

SMTP_USER = "twoj_email@gmail.com"
SMTP_SEND_TO = "adres_docelowy@example.com"
SMTP_PASS = "haslo_lub_app_password"
ALERT_SUBJECT = "ALARM_ZOSTAŁ_UROCHOMIONY"
ALERT_MESSAGE = (
	"Alarm został uruchomiony. Sprawdź nagranie i folder na dysku."
)

GDRIVE_CLIENT_SECRET_FILE = '/ścieżka/do/sekretu/google.json'
GDRIVE_FOLDER_ID = 'folderIdZNagran'
GDRIVE_UPLOAD_TRACK_FILE = 'uploaded_files.txt'


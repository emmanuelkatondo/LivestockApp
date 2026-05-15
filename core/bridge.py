import serial
import requests
import json
import time

# 1. MIPANGILIO - Badilisha hapa
arduino_port = 'COM3'  # Kwa Linux: '/dev/ttyACM0'
baud_rate = 9600
api_url = "http://192.168.0.11:8000/api/locations/" # URL ya Django yako

try:
    ser = serial.Serial(arduino_port, baud_rate, timeout=1)
    print(f"Imeunganishwa na Arduino kwenye {arduino_port}")
except Exception as e:
    print(f"Hitilafu: {e}")
    exit()

while True:
    try:
        line = ser.readline().decode('utf-8').strip()
        if line.startswith('{'): # Inasubiri JSON kutoka kwa Arduino
            data = json.loads(line)
            
            # 2. DATA YA KUTUMA - Hakikisha 'animal' ID ipo kwenye Database yako
            payload = {
                "animal": 1,  # ID ya mnyama uliyemsajili kwenye Django
                "latitude": data['latitude'],
                "longitude": data['longitude']
            }
            
            # 3. TUMA KWENYE DJANGO
            response = requests.post(api_url, json=payload)
            
            if response.status_code == 201:
                print(f"Data Imehifadhiwa DB! Lat: {data['latitude']}, Lon: {data['longitude']}")
            else:
                print(f"Django Error {response.status_code}: {response.text}")
                
    except Exception as e:
        if line:
            print(f"Data isiyoeleweka: {line}")
    
    time.sleep(2) # Usijaze database haraka sana
# Livestock Tracking & Management System (LivestockApp)

An end-to-end IoT-enabled platform designed for real-time livestock tracking, health monitoring, and farm management. This repository integrates a **Django REST Framework** backend API with a **Flutter** cross-platform mobile application, leveraging GPS/GSM telemetry data to streamline livestock operations.

---

## 🛠 Tech Stack & Architecture

### **Backend Framework**
* **Language:** Python 3.x
* **Framework:** Django & Django REST Framework (DRF)
* **Database:** PostgreSQL / SQLite (Development)
* **Authentication:** JWT (JSON Web Tokens) / Token Authentication

### **Mobile Client**
* **Framework:** Flutter (Dart)
* **State Management:** Provider / BLoC
* **Networking:** Http / Dio REST API Client

### **Hardware & Telemetry Integration**
* **Protocols:** HTTP REST API / MQTT
* **Sensors:** GPS & GSM Collars (Location, Geofencing, Alert Triggers)

---

## 📂 Repository Structure

```tex
LivestockApp/
├── LSTP/            # Django REST API service
│   ├── manage.py
│   ├── requirements.txt
│   └── ...
├── mobile_app/         # Flutter mobile application
│   ├── pubspec.yaml
│   ├── lib/
│   └── ...
└── README.md           # Project documentation

🚀 Getting Started
Prerequisites

    Python >= 3.10

    Flutter SDK >= 3.1.1

    Git installed on your system

1. Backend Setup (Django)

    Navigate to the backend directory:
    Bash

    cd backend

    Create and activate a virtual environment:
    Bash

    python3 -m venv venv
    source venv/bin/activate        # Linux / macOS
    # On Windows use: venv\Scripts\activate

    Install dependencies:
    Bash

    pip install -r requirements.txt

    Apply database migrations:
    Bash

    python manage.py makemigrations
    python manage.py migrate

    Start the development server:
    Bash

    python manage.py runserver server address

    The API engine will be active at: http://server address:8000/

2. Mobile Client Setup (Flutter)

    Navigate to the mobile app directory:
    Bash

    cd mobile_app

    Fetch dependencies:
    Bash

    flutter pub get

    Run the app on a connected device/emulator:
    Bash

    flutter run

🔑 Key Features

    📍 Real-Time GPS Tracking: Live location monitoring powered by hardware telemetry data.

    🛡️ Geofencing & Alerts: Automated notifications triggered when livestock cross predefined perimeter boundaries.

    📋 Livestock Management Records: Centralized management for livestock profiles, medical history, and vaccination schedules.

    📊 Analytics Dashboard: Graphical insights into livestock distribution, movement history, and health metrics.

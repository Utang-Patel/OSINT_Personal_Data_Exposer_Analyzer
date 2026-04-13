# 🔍 OSINT Investigation Platform

An advanced **Open Source Intelligence (OSINT) platform** that allows users to gather publicly available information using multiple powerful tools integrated into a single system.

---

## 🚀 Tech Stack

### 🖥️ Frontend

* **Flutter** (Cross-platform mobile/web UI)

### ⚙️ Backend

* **Django** (Python-based backend framework)
* Hosted on **AWS EC2**

### 🗄️ Database

* **PostgreSQL**
* Hosted on **Supabase**

---

## 🧰 Integrated OSINT Tools

This platform integrates multiple OSINT tools to provide comprehensive data gathering:

* 🔎 **Mr.Holmes** – Username & digital footprint investigation
* 📧 **HIBP (Have I Been Pwned)** – Email breach detection
* 🌐 **WhatsMyName** – Username search across platforms
* 🕳️ **Holehe** – Email account discovery across services

---

## ✨ Features

* 🔍 Search by **username / email**
* 📊 Aggregated results from multiple OSINT tools
* ⚡ Fast backend processing using Django
* 🌍 Cross-platform UI with Flutter
* 🔐 Secure API handling
* ☁️ Cloud deployment (AWS + Supabase)

---

## 🏗️ Project Architecture

```
Frontend (Flutter)
        ↓
   Django API (AWS EC2)
        ↓
PostgreSQL (Supabase)
        ↓
 Integrated OSINT Tools
```

---

## ⚙️ Setup Instructions

### 🔹 1. Clone Repository

```bash
git clone https://github.com/your-username/your-repo-name.git
cd your-repo-name
```

---

### 🔹 2. Backend Setup (Django)

```bash
cd backend
pip install -r requirements.txt
python manage.py migrate
python manage.py runserver
```

> ⚠️ Note: Virtual environment is not used in this project.

---

### 🔹 3. Database Configuration

Update your **Django settings.py** with Supabase PostgreSQL credentials:

```python
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'your-db-name',
        'USER': 'your-user',
        'PASSWORD': 'your-password',
        'HOST': 'your-host',
        'PORT': '5432',
    }
}
```

---

### 🔹 4. Frontend Setup (Flutter)

```bash
cd frontend
flutter pub get
flutter run
```

---

## ☁️ Deployment

### 🔸 Backend

* Hosted on **AWS EC2**
* Runs Django server directly

### 🔸 Database

* Hosted on **Supabase (PostgreSQL)**

---

## 📌 Future Improvements

* 🔐 Authentication system (JWT / OAuth)
* 📊 Advanced analytics dashboard
* 🌐 More OSINT tool integrations
* ⚡ Background task processing (Celery / Redis)
* 📱 Improved UI/UX

---

## ⚠️ Disclaimer

This tool is developed for **educational and ethical purposes only**.
Do not use it for illegal activities or unauthorized investigations.

---

## 👨‍💻 Author

**Your Name**

* GitHub: https://github.com/Utang-Patel
* LinkedIn: https://www.linkedin.com/in/utang-patel-217167255/

---

## ⭐ Support

If you like this project, give it a ⭐ on GitHub!

---

# Invoice & POS Billing Software

Commercial-grade retail billing software for auto-parts shops.  
Cross-platform: **Android APK** + **Windows EXE/MSI**.

## Quick Start

### 1. Backend Setup
```
scripts\setup_backend.bat
```
Edit `backend\.env` — set your MongoDB Atlas URI and JWT secret, then:
```
cd backend && npm start
```

### 2. Set API URL in Flutter
Edit `app\lib\core\constants\app_constants.dart`:
```dart
static const String baseUrl = 'http://YOUR_SERVER_IP:5000/api';
```

### 3. Run the App (development)
```
scripts\start_dev.bat
```

### 4. Build Releases
| Target | Script |
|--------|--------|
| Android APK | `scripts\build_apk.bat` |
| Windows EXE | `scripts\build_windows.bat` |
| Windows MSI | Compile `scripts\create_installer.iss` with Inno Setup |

---

## Features
- ✅ POS billing with barcode scanning
- ✅ Inventory management with stock alerts
- ✅ Customer & supplier management
- ✅ Expense tracking
- ✅ Sales & profit reports with charts
- ✅ PDF invoice generation + print/share
- ✅ Offline mode with auto-sync (SQLite → MongoDB Atlas)
- ✅ Wi-Fi export (CSV over local network)
- ✅ Auto-update system (Android APK + Windows)
- ✅ JWT authentication
- ✅ Responsive UI (mobile + desktop)

## Project Structure
```
software1/
├── backend/          Node.js + Express + MongoDB Atlas API
│   ├── src/models/   Mongoose schemas (User, Product, Sale, Customer…)
│   ├── src/routes/   REST endpoints
│   └── server.js     Entry point
├── app/              Flutter cross-platform frontend
│   ├── lib/
│   │   ├── core/     Theme, DB, network, constants
│   │   ├── models/   Dart data models
│   │   ├── providers/ Riverpod state management
│   │   ├── screens/  All UI screens
│   │   └── services/ PDF, sync, update, Wi-Fi export
│   ├── android/      Android platform config
│   └── windows/      Windows platform config
└── scripts/          Build & deploy automation
```

## MongoDB Atlas Setup
1. Create free cluster at [mongodb.com/atlas](https://mongodb.com/atlas)
2. Create database user (username + password)
3. Whitelist IP `0.0.0.0/0` (or your server IP)
4. Copy connection string into `backend/.env`

## Default Login
Register a new account on first launch.

# QuickBus SG 🇸🇬 🚌

**Latest Version:** `v1.0.12+13` · [Full Changelog](./CHANGELOG.md)

A minimalist, high-speed Singapore Bus Arrival & Transit Flutter application (`flutter_project/`), powered by LTA DataMall v3 and a complete bundled offline Singapore transit database.

---

## 📱 Prebuilt Android APK (`releases/`)

The pre-compiled universal ARM release APK is stored in the [`releases/`](./releases) directory:

| Architecture | File | Recommended For |
| :--- | :--- | :--- |
| **Combined ARM** (`arm64-v8a` + `armeabi-v7a`) | [`releases/quickbus-sg-v1.0.12+13-arm-universal.apk`](./releases/quickbus-sg-v1.0.12+13-arm-universal.apk) | All ARM Android devices (Android 8.0+) |

---

## ⚙️ Environment Setup (`.env`)

1. Copy `.env.example` to `.env` inside `flutter_project/`:
   ```bash
   cd flutter_project
   cp .env.example .env
   ```
2. Set your LTA DataMall `AccountKey` in `flutter_project/.env`:
   ```env
   LTA_DATAMALL_KEY="YOUR_LTA_DATAMALL_ACCOUNT_KEY"
   ```

---

## 🚀 Building & Running the Flutter App

From `flutter_project/`:

```bash
cd flutter_project

# Run in debug mode (Web):
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 --dart-define-from-file=.env

# Run tests:
flutter test

# Build universal ARM release APK (keeps the 5 most recent in releases/):
flutter build apk --release --target-platform android-arm,android-arm64 --dart-define-from-file=.env
```


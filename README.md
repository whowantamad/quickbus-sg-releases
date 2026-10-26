# QuickBus SG 🇸🇬 🚌

**Latest Version:** `v1.0.4+5` · [Full Changelog](./CHANGELOG.md)

A minimalist, high-speed Singapore Bus Arrival & Transit Flutter application (`flutter_project/`), powered by LTA DataMall v3 and a complete bundled offline Singapore transit database.

---

## 📱 Prebuilt Android APKs (`releases/`)

Pre-compiled release APKs are stored in the [`releases/`](./releases) directory for direct installation:

### Latest Release: `v1.0.4+5`
| Variant | Architecture | File | Recommended For |
| :--- | :--- | :--- | :--- |
| **ARM64 Split APK** *(Recommended)* | `arm64-v8a` (64-bit) | [`releases/quickbus-sg-v1.0.4+5-arm64-v8a.apk`](./releases/quickbus-sg-v1.0.4+5-arm64-v8a.apk) | Modern Android phones (Android 8.0+) |
| **ARMv7 Split APK** | `armeabi-v7a` (32-bit) | [`releases/quickbus-sg-v1.0.4+5-armeabi-v7a.apk`](./releases/quickbus-sg-v1.0.4+5-armeabi-v7a.apk) | Older 32-bit Android devices |
| **Combined ARM APK** | `arm64-v8a` + `armeabi-v7a` | [`releases/quickbus-sg-v1.0.4+5-arm-universal.apk`](./releases/quickbus-sg-v1.0.4+5-arm-universal.apk) | Single installer supporting all ARM Android phones |

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

# Build split release APKs (arm64-v8a & armeabi-v7a):
flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64 --dart-define-from-file=.env

# Build single universal ARM release APK:
flutter build apk --release --target-platform android-arm,android-arm64 --dart-define-from-file=.env
```


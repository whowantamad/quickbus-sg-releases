# QuickBus SG 🇸🇬 🚌

**Latest Version:** `v1.0.2+3` · [Full Changelog](./CHANGELOG.md)

A minimalist, high-speed Singapore Bus Arrival & Transit application built with both a **Flutter Android native app** (`flutter_project/`) and a **React + TypeScript + Express web app** (`src/`, `server.ts`), powered by LTA DataMall v3 and a complete bundled offline Singapore transit database.

---

## 📱 Prebuilt Android APKs (`releases/`)

Pre-compiled release APKs are stored in the [`releases/`](./releases) directory for direct installation, with previous versions preserved for rollback testing:

### Latest Release: `v1.0.2+3`
| Variant | Architecture | File | Recommended For |
| :--- | :--- | :--- | :--- |
| **ARM64 Split APK** *(Recommended)* | `arm64-v8a` (64-bit) | [`releases/quickbus-sg-v1.0.2-arm64-v8a.apk`](./releases/quickbus-sg-v1.0.2-arm64-v8a.apk) | All modern Android phones (Android 8.0+) |
| **ARMv7 Split APK** | `armeabi-v7a` (32-bit) | [`releases/quickbus-sg-v1.0.2-armeabi-v7a.apk`](./releases/quickbus-sg-v1.0.2-armeabi-v7a.apk) | Older 32-bit Android devices |
| **Combined ARM APK** | `arm64-v8a` + `armeabi-v7a` | [`releases/quickbus-sg-v1.0.2-arm-universal.apk`](./releases/quickbus-sg-v1.0.2-arm-universal.apk) | Single installer supporting all ARM Android phones |

### Previous Releases
| Version | `arm64-v8a` (64-bit) | `armeabi-v7a` (32-bit) | Combined ARM |
| :--- | :--- | :--- | :--- |
| **`v1.0.1+2`** | [`quickbus-sg-v1.0.1-arm64-v8a.apk`](./releases/quickbus-sg-v1.0.1-arm64-v8a.apk) | [`quickbus-sg-v1.0.1-armeabi-v7a.apk`](./releases/quickbus-sg-v1.0.1-armeabi-v7a.apk) | [`quickbus-sg-v1.0.1-arm-universal.apk`](./releases/quickbus-sg-v1.0.1-arm-universal.apk) |
| **`v1.0.0+1`** | [`quickbus-sg-v1.0.0-arm64-v8a.apk`](./releases/quickbus-sg-v1.0.0-arm64-v8a.apk) | [`quickbus-sg-v1.0.0-armeabi-v7a.apk`](./releases/quickbus-sg-v1.0.0-armeabi-v7a.apk) | [`quickbus-sg-v1.0.0-arm-universal.apk`](./releases/quickbus-sg-v1.0.0-arm-universal.apk) |

---

## ✨ What's New in `v1.0.2+3`

- **Custom QuickBus SG Launcher Icon**: Uses the React `icon.svg` lightning-bolt + `G` icon across all Android launcher mipmap densities (`mdpi` to `xxxhdpi`), web icons, and the in-app header badge.
- **Smart Dual-Visit Direction Labels**: Bus arrival cards only display `→ <Road Name>` when a bus service visits the stop twice in two loops/directions (such as Bus `358` East & West loops at Pasir Ris Interchange), keeping regular single-visit bus cards clean.
- **Interactive MRT System Map (`mrt-map.png`)**: Full-bleed LTA Singapore Rail System Map on the **MRT** tab with pinch-to-zoom, pan, and smooth double-tap zoom/reset gestures.
- **Refined Bottom Navigation Bar & Settings**: Crisp white (`#FFFFFF`) and dark navy (`#0C1220`) navigation bar theme matching the React design, with the database status card positioned at the bottom of Settings.

---

## ⚙️ Environment Setup (`.env`)

1. Copy `.env.example` to `.env` in the workspace root (automatically linked into `flutter_project/.env`):
   ```bash
   cp .env.example .env
   ```
2. Set your LTA DataMall `AccountKey` in `.env`:
   ```env
   LTA_DATAMALL_KEY="YOUR_LTA_DATAMALL_ACCOUNT_KEY"
   ```

---

## 🚀 Building the Flutter Android APK

From `flutter_project/`:

```bash
cd flutter_project

# 1. Build split APKs for arm64-v8a and armeabi-v7a:
flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64 --dart-define-from-file=.env

# 2. Or build a single combined ARM (arm64-v8a + armeabi-v7a) APK:
flutter build apk --release --target-platform android-arm,android-arm64 --dart-define-from-file=.env
```

---

## 💻 Running the Web / Express App Locally

**Prerequisites:** Node.js or Bun

1. Install dependencies:
   ```bash
   npm install
   ```
2. Configure `.env` with `LTA_DATAMALL_KEY`.
3. Start the development server:
   ```bash
   npm run dev
   ```

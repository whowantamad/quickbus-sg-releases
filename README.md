# QuickBus SG 🇸🇬 🚌

**Version:** `v1.0.0+1` · [Changelog](./CHANGELOG.md)

A minimalist, high-speed Singapore Bus Arrival & Transit application built with both a **Flutter Android native app** (`flutter_project/`) and a **React + TypeScript + Express web app** (`src/`, `server.ts`), powered by LTA DataMall v3 and a complete bundled offline Singapore transit database.

---

## 📱 Prebuilt Android APKs (`v1.0.0+1`)

Pre-compiled release APKs are located in the [`releases/`](./releases) directory for direct installation and testing on Android devices:

| Variant | Architecture | File | Recommended For |
| :--- | :--- | :--- | :--- |
| **ARM64 Split APK** *(Recommended)* | `arm64-v8a` (64-bit) | [`releases/quickbus-sg-v1.0.0-arm64-v8a.apk`](./releases/quickbus-sg-v1.0.0-arm64-v8a.apk) | All modern Android phones (Android 8.0+) |
| **ARMv7 Split APK** | `armeabi-v7a` (32-bit) | [`releases/quickbus-sg-v1.0.0-armeabi-v7a.apk`](./releases/quickbus-sg-v1.0.0-armeabi-v7a.apk) | Older 32-bit Android devices |
| **Combined ARM APK** | `arm64-v8a` + `armeabi-v7a` | [`releases/quickbus-sg-v1.0.0-arm-universal.apk`](./releases/quickbus-sg-v1.0.0-arm-universal.apk) | Single installer supporting all ARM Android phones |

---

## ✨ What's New in `v1.0.0+1` (Changelog)

- **Bundled Offline Transit Database (`sg_transit_snapshot.json`)**: Instant offline access to **5,208+ Singapore Bus Stops**, **602+ Bus Routes**, and **per-stop, per-service First/Last Bus Operating Hours**.
- **Offline-First Progressive Hydration**: Bus Stop Detail view renders all bus services from the offline database immediately at `0ms` and hydrates live LTA arrival timings in-place.
- **Live LTA DataMall v3 Integration via `.env`**: Reads `LTA_DATAMALL_KEY` automatically from `.env` (or `--dart-define`) in [`LtaApiService`](./flutter_project/lib/services/lta_api_service.dart), with an optional runtime key override in the Settings sheet.
- **Dynamic Service Sorting**:
  1. **Starred / Favorite Bus Services** pinned at the top
  2. **Services with Active Arrival Timings** ordered right after favorites
  3. **Services without Arrival Timings** (`No Est. Available` / `Not In Operation`) grouped at the bottom
- **Official LTA No-Arrival Advisements**: Automatically distinguishes between `"Not In Operation"` (outside that specific stop & service's scheduled hours in Singapore Time, `UTC+8`) and `"No Est. Available"`.
- **2-Layer Double Decker Badge & Load Bars**: Clean neutral arrival slots with color-coded bottom load indicator bars (`SEA` Emerald, `SDA` Amber, `LSD` Rose) and a custom 2-layer Double Decker icon.
- **4-Tab Navigation & Settings Sheet**: **Starred**, **Nearby**, **Search**, and **MRT Map** tabs, swipe-to-delete with confirmation dialog, pull-down to refresh, **Light / Dark / Auto** theme selector, and in-app version & changelog viewer.

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

# Changelog

All notable changes to **QuickBus SG** are documented in this file.

## [1.0.2+3] - 2026-10-25

### Changed
- **App Launcher Icon & Brand Logo (`android/app/src/main/res/mipmap-*/ic_launcher.png`, `home_screen.dart`, `web/`)**:
  - Replaced default Flutter launcher icons with the official QuickBus SG lightning-bolt + `G` icon from `public/icon.svg` across all Android mipmap densities (`mdpi` through `xxxhdpi`) and web icons.
  - Updated the in-app header brand icon to render the exact SVG vector path from `public/icon.svg`.
- **Bus Service Arrival Cards (`transit_db_service.dart`, `bus_arrival_card.dart`)**:
  - Displayed the `→ <Road Name>` direction label **only** when a bus service visits the bus stop twice in two directions/loops (e.g., Bus `358` and `359` East/West loops at Pasir Ris Interchange), keeping single-visit bus service cards clean and compact.
- **Prebuilt Android Release APKs (`releases/`)**:
  - Added `v1.0.2` APKs (`arm64-v8a`, `armeabi-v7a`, and combined ARM) alongside preserved `v1.0.1` and `v1.0.0` APKs.

---

## [1.0.1+2] - 2026-10-25

### Changed
- **MRT Map Tab (`mrt_map_screen.dart`)**:
  - Replaced station list with the full official LTA Singapore Rail System Map image (`assets/mrt-map.png`).
  - Removed floating zoom buttons in favor of native pinch-to-zoom, drag/pan, and animated double-tap zoom (`2.5x` toggle).
- **Bottom Navigation Bar (`main.dart`, `home_screen.dart`)**:
  - Removed Material 3 brown surface tinting (`surfaceTintColor: Colors.transparent`) and matched the React navigation bar colors (`#FFFFFF` light / `#0C1220` dark background, `#FFF1F2` / `#4C0519` active pill, and `#E11D48` / `#FB7185` active accents).
- **Settings Sheet (`settings_sheet.dart`)**:
  - Removed the LTA DataMall AccountKey input field (now managed exclusively via `.env`) and in-app changelog section.
  - Moved the **Offline Transit Database** status card to the bottom below **Auto-Refresh Interval**.
- **Prebuilt Android Release APKs (`releases/`)**:
  - Added `v1.0.1` APKs alongside the preserved `v1.0.0` APKs.

---

## [1.0.0+1] - 2026-10-25

### Added
- **Flutter Android Native App (`flutter_project/`)**:
  - Material 3 light, dark, and system-adaptive themes (`#E11D48` primary rose palette).
  - Bundled offline Singapore transit database (`assets/sg_transit_snapshot.json`) with **5,208+ bus stops**, **602+ bus routes**, and per-stop, per-service first/last bus operating hours.
  - Zero-latency (`0ms`) offline-first progressive hydration for bus stop detail views.
  - Live LTA DataMall v3 `BusArrival` API integration via `.env` (`LTA_DATAMALL_KEY`) and `--dart-define`.
  - Dynamic bus service sorting:
    1. Starred / favorite bus services pinned at the top
    2. Services with active live arrival estimates
    3. Services with `No Est. Available` or `Not In Operation` at the bottom
  - Official LTA no-arrival advisements distinguishing scheduled operating hours (`Not In Operation`) from temporary GPS/telemetry gaps (`No Est. Available`).
  - Custom 2-layer Double Decker badge and neutral arrival slots with load-colored bottom indicator bars (`SEA` Emerald, `SDA` Amber, `LSD` Rose).
  - 4-tab navigation (**Starred**, **Nearby**, **Search**, **MRT**) with horizontal swipe-to-delete confirmation on starred and recent stops.
- **Prebuilt Android Release APKs (`releases/`)**:
  - `releases/quickbus-sg-v1.0.0-arm64-v8a.apk` (64-bit ARM — modern Android devices)
  - `releases/quickbus-sg-v1.0.0-armeabi-v7a.apk` (32-bit ARM — legacy Android devices)
  - `releases/quickbus-sg-v1.0.0-arm-universal.apk` (Combined `arm64-v8a` + `armeabi-v7a` APK)

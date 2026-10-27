# Changelog

All notable changes to **QuickBus SG** are documented in this file.

## [1.0.7+8] - 2026-10-26

### Fixed
- **GPS "Could not acquire GPS signal" (`nearby_screen.dart`)**:
  - Replaced chained 5–6s location attempts (each timeout cancelled the native request and restarted the GPS cold start) with a single 20s high-accuracy request (40s when GPS must first be enabled), falling back to last known position.
  - On Fused provider errors, falls back to last known position then a 20s Android LocationManager fix.
- **Prebuilt Android Release APK (`releases/`)**:
  - Built `v1.0.7+8` universal ARM release APK.

---

## [1.0.6+7] - 2026-10-26

### Fixed & Improved
- **Dual-Loop Visit Routing & Arrival Separation (`bus_arrival.dart`, `transit_db_service.dart`, `lta_api_service.dart`)**:
  - Parsed LTA DataMall `VisitNumber` (`"1"` vs `"2"`) to correctly separate arrival timings for bus services visiting an interchange twice (e.g., Bus 358 at Pasir Ris Interchange).
  - Aligned loop wings to chronological visits (Wing 1 / West loop = Visit 1, Wing 2 / East loop = Visit 2) without inverted display order.
- **Dual-Loop Arrival Card Visual Labels (`bus_arrival_card.dart`)**:
  - Added dedicated `1st Visit` (muted chip) and `2nd Visit` (rose highlighted chip) badges beside the service number badge for clear destination distinction.
- **Full Route & Dual Circuit Display in Route Sheet (`bus_route_sheet.dart`, `transit_db_service.dart`)**:
  - Added multi-tab navigation to the Route & Schedule sheet: `All Routes (Full Circuit)`, `1st Visit · <Direction>`, and `2nd Visit · <Direction>`.
  - Added visual sequence markers (`1st Visit`, `2nd Visit`, `Terminus`) along the stop timeline for full circuit view.
- **Prebuilt Android Release APK (`releases/`)**:
  - Built `v1.0.6+7` universal ARM release APK and maintained 5-APK release retention policy.

---

## [1.0.5+6] - 2026-10-26

### Fixed & Improved
- **GPS Permission & Settings Bounce Loop (`nearby_screen.dart`)**:
  - Prevented automatic recursive navigation into Android Settings when returning to the app without granting GPS permission.
- **Pull-to-Refresh & API Error Feedback (`bus_stop_detail_screen.dart`, `lta_api_service.dart`)**:
  - Displayed honest error indicators and toasts on network timeouts or HTTP 401/403/500 responses instead of false success toasts.
- **Resource & Battery Optimization (`bus_stop_detail_screen.dart`)**:
  - Halted idle 1-second countdown ticker when auto-refresh is turned off, preventing redundant background widget rebuilds.
- **Settings Sheet Immediate Persistence (`settings_sheet.dart`)**:
  - Immediately persisted auto-refresh interval selection on tap to ensure choices are retained when closing via the header X button.
- **Bus Route Return Direction Toggle (`bus_route_sheet.dart`)**:
  - Added direction toggle chips in the route detail bottom sheet to view stops and schedules for both outbound and return journeys.
- **Search Performance (`search_screen.dart`)**:
  - Added a 150ms debounce before executing string queries across all 5,208 bus stops.
- **Code Cleanliness & Automated Tests (`widget_test.dart`, `models/`)**:
  - Removed dead model boilerplate (`NextBusInfo.copyWith`, `BusStop.toJson`) and expanded test suite coverage to 7 passing tests.
- **Prebuilt Android Release APK (`releases/`)**:
  - Added `v1.0.5+6` universal ARM release APK.

---

## [1.0.3+4] - 2026-10-25

### Added & Changed
- **Auto-Refresh Countdown & Pull-to-Refresh Toast (`bus_stop_detail_screen.dart`)**:
  - Added a subtle right-aligned `"Updating in Xs"` countdown timer above the bus arrivals list.
  - Added a floating confirmation toast (`"Arrivals up to date · Live LTA DataMall"` / `"Arrivals updated · Offline Schedule Sim"`) when pulling down to refresh.
- **Arrival Parsing & Simulation Fixes (`lta_api_service.dart`, `bus_arrival.dart`)**:
  - Removed the artificial 1-in-9 `"No Est. Available"` simulation drop and replaced platform-dependent `.hashCode` with a deterministic cross-platform hash.
  - Hardened JSON parsing in `BusArrivalService.fromJson` and `NextBusInfo.fromJson` using safe `.toString()` conversions.
  - Separated `flutter_project/.env` and `flutter_project/.env.example` into independent files so `.env.example` never overwrites `.env`.
- **Prebuilt Android Release APKs (`releases/`)**:
  - Added `v1.0.3` APKs (`arm64-v8a`, `armeabi-v7a`, and combined ARM) alongside preserved `v1.0.2`, `v1.0.1`, and `v1.0.0` APKs.

---

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

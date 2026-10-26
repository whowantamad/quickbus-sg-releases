# Changelog

All notable changes to **QuickBus SG** are documented in this file.

## [1.0.0+1] - 2026-10-25

### Added
- **Flutter Android Native App (`flutter_project/`)**:
  - Material 3 light, dark, and system-adaptive themes (`#E11D48` primary rose palette).
  - Bundled offline Singapore transit database (`assets/sg_transit_snapshot.json`) with **5,208+ bus stops**, **602+ bus routes**, and per-stop, per-service first/last bus operating hours.
  - Zero-latency (`0ms`) offline-first progressive hydration for bus stop detail views.
  - Live LTA DataMall v3 `BusArrival` API integration via `.env` (`LTA_DATAMALL_KEY`), `--dart-define`, or in-app Settings override.
  - Dynamic bus service sorting:
    1. Starred / favorite bus services pinned at the top
    2. Services with active live arrival estimates
    3. Services with `No Est. Available` or `Not In Operation` at the bottom
  - Official LTA no-arrival advisements distinguishing scheduled operating hours (`Not In Operation`) from temporary GPS/telemetry gaps (`No Est. Available`).
  - Custom 2-layer Double Decker badge and neutral arrival slots with load-colored bottom indicator bars (`SEA` Emerald, `SDA` Amber, `LSD` Rose).
  - 4-tab navigation (**Starred**, **Nearby**, **Search**, **MRT Map**) with horizontal swipe-to-delete confirmation on starred and recent stops.
  - In-app **Settings** sheet displaying app version (`v1.0.0+1`), offline database stats, auto-refresh interval (`15s`, `30s`, `60s`, `Off`), LTA DataMall AccountKey input, and release changelog.
- **Prebuilt Android Release APKs (`releases/`)**:
  - `releases/quickbus-sg-v1.0.0-arm64-v8a.apk` (64-bit ARM — modern Android devices)
  - `releases/quickbus-sg-v1.0.0-armeabi-v7a.apk` (32-bit ARM — legacy Android devices)
  - `releases/quickbus-sg-v1.0.0-arm-universal.apk` (Combined `arm64-v8a` + `armeabi-v7a` APK)


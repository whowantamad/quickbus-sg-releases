# QuickBus SG - Flutter Edition 🇸🇬 🚌

A minimalist, high-speed Singapore Bus Arrival app built in **Flutter (Dart)** with Material Design 3 and a complete bundled offline Singapore transit database.

## Features (Synced with React Codebase)
- **Bundled Offline Transit Database (`assets/sg_transit_snapshot.json`)**: Instant offline access to **5,208+ Singapore Bus Stops**, **602+ Bus Routes**, and **per-stop, per-service First/Last Bus Operating Hours**.
- **Offline-First Progressive Hydration**: Bus Stop Detail view renders all bus services from the offline database at `0ms` with slot skeletons and hydrates live arrival timings in-place.
- **Dynamic Service Sorting**: Automatically orders services on each stop:
  1. **Starred / Favorite Bus Services** pinned at the top
  2. **Services with Active Arrival Timings** right after favorites
  3. **Services without Arrival Timings** (`No Est. Available` / `Not In Operation`) at the bottom
- **LTA Official No-Arrival Advisements**: Automatically distinguishes between `"Not In Operation"` (outside that specific stop & service's scheduled hours in Singapore Time) and `"No Est. Available"`.
- **2-Layer Double Decker Badge & Neutral Arrival Slots**: Clean neutral slot backgrounds with color-coded bottom load bars (`SEA` Emerald, `SDA` Amber, `LSD` Rose) and a 2-layer Double Decker custom icon.
- **Swipe-to-Delete with Confirmation Dialog**: Horizontal swipe gesture on Starred and Recent stops with a confirmation prompt before removing.
- **Pull-Down to Refresh**: Pull down on the bus services list to refresh live arrivals.
- **4-Tab Navigation & Settings Sheet**: **Starred**, **Nearby**, **Search**, and **MRT Map** tabs, plus **Settings** containing the **Light / Dark / Auto** theme selector, auto-refresh interval, and optional LTA DataMall AccountKey.

## Project Structure
```
flutter_project/
├── pubspec.yaml
├── README.md
├── assets/
│   └── sg_transit_snapshot.json
└── lib/
    ├── main.dart
    ├── models/
    │   ├── bus_arrival.dart
    │   └── bus_stop.dart
    ├── services/
    │   ├── favorites_service.dart
    │   ├── lta_api_service.dart
    │   └── transit_db_service.dart
    ├── widgets/
    │   ├── bus_arrival_card.dart
    │   ├── bus_route_sheet.dart
    │   ├── settings_sheet.dart
    │   └── stop_list_item.dart
    └── screens/
        ├── bus_stop_detail_screen.dart
        ├── favorites_screen.dart
        ├── home_screen.dart
        ├── mrt_map_screen.dart
        ├── nearby_screen.dart
        └── search_screen.dart
```

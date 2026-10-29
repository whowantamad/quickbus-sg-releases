# Changelog

All notable changes to **QuickBus SG** are documented in this file, separated into **What's New (App)** for users and **Developer Notes (Code)** for contributors.

## [1.0.13+14] - 2026-10-28

### What's New (App)
- **Crowd-Colored & Pulsing `"Arr"` Indicator**: When a bus is arriving now (`Arr`), its text color now matches its seat availability (`Green` for seats available, `Amber` for standing, `Red` for limited standing) with a gentle pulse animation instead of always turning red.

### Developer Notes (Code)
- `bus_arrival_card.dart`: Updated `_buildArrivalSlot` so `isArriving` uses `loadColor` when `bus.load` is known (`SEA`/`SDA`/`LSD`) and wrapped the `"Arr"` `Text` widget in `_SubtlePulse` (`SingleTickerProviderStateMixin` + `FadeTransition`, `0.42..1.0` over `900ms`).
- `releases/`: Built `quickbus-sg-v1.0.13+14-arm-universal.apk`.

---

## [1.0.12+13] - 2026-10-28

### What's New (App)
- **Instant Star Sync Across Tabs**: Starring or unstarring a bus stop inside the bus arrival page now immediately updates its star icon on the `Search` and `Nearby` lists when you go back.
- **Live-Only Arrival Data**: Removed offline fake/simulated bus arrival times so the app only displays real LTA DataMall arrival estimates (or `No Est. Available` / `Not In Operation`).
- **Cleaner `Extra Large` Layout**: Fixed 4-character bus numbers (like `857A`) and `1st/2nd Visit` badges so they never wrap or overflow when `Extra Large` text size is enabled.

### Developer Notes (Code)
- `favorites_service.dart`, `stop_list_item.dart`: Added `FavoritesService.starredNotifier` (`ValueNotifier<int>`) incremented in `saveFavorites`, and subscribed `_StopListItemState` (`initState`/`didUpdateWidget`/`dispose`) to sync `_starred` from `_starredCodesCache`.
- `lta_api_service.dart`, `bus_stop_detail_screen.dart`, `favorites_screen.dart`: Deleted `_generateSimulatedArrivals`, `_stableSeed`, and the `stopServices` parameter from `getBusArrivals`; missing `AccountKey` now sets `lastErrorMessage` and returns `const []`.
- `bus_arrival_card.dart`, `transit_db_service.dart`, `favorites_screen.dart`, `widget_test.dart`: Added `FittedBox(fit: BoxFit.scaleDown)` on the `56px` service badge and `Flexible` on visit badges, guarded `findOppositeStop` when `!isSideA && !isSideB` (codes ending in `0`/`5`), disposed dialog `TextEditingController`s, and added `1.35x` widget tests.

---

## [1.0.11+12] - 2026-10-28

### What's New (App)
- **Text Size Setting**: Added a **Text Size** selector (`Default`, `Large`, `Extra Large`) with visual `Aa` previews in Settings for easier reading.

### Developer Notes (Code)
- `favorites_service.dart`, `settings_sheet.dart`, `main.dart`: Added `textScale` (`1.0`, `1.18`, `1.35`) to `UserSettings` JSON serialization, added selector chips in `SettingsSheet`, and applied `TextScaler.linear(_settings.textScale)` via `MaterialApp.builder`.

---

## [1.0.10+11] - 2026-10-27

### What's New (App)
- **Live Starred Bus Timings on `Starred` Tab**: Starred bus stops now show live arrival pills (e.g. `★ 147  2m · 9m`) directly on the `Starred` tab for any bus services you starred at that stop, with pull-down-to-refresh.
- **Custom Stop Labels & Tags**: Tap the edit icon (or long-press a starred stop) to give it a custom name (e.g. `Home`, `Office`) and filter tag (`Commute`, `Home`, `Work`, `School`, or custom).
- **Opposite Stop Quick-Switch (`↔`)**: Tap the swap icon in the top bar of a bus stop page to jump directly to the opposite bus stop across the road.
- **Smarter Route Sheet**: Opening a bus route now auto-scrolls to your current stop, marks it with `Here`, shows `+N stop(s)` on upcoming stops, and updates first/last bus hours when switching directions.
- **Accurate Wheelchair (`WAB`) Indicator**: Fixed wheelchair icon handling so it reflects actual bus feature data.

### Developer Notes (Code)
- `favorites_service.dart`, `favorites_screen.dart`, `stop_list_item.dart`: Added `updateFavorite` and `getAllStarredServices`, parallel per-stop arrival fetching in `_fetchStarredArrivals`, `_showEditFavoriteDialog`, and `starredArrivals` pills in `StopListItem`.
- `transit_db_service.dart`, `bus_stop_detail_screen.dart`: Added `TransitDbService.findOppositeStop` using LTA 5-digit parity (`1..4` $\leftrightarrow$ `6..9`) + same-road `250m` fallback, and wired `Icons.swap_horiz_rounded` in `BusStopDetailScreen`.
- `bus_route_sheet.dart`, `transit_db_service.dart`, `bus_arrival.dart`: Added `GlobalKey` + `Scrollable.ensureVisible` auto-scroll, downstream `+N stops` counter, direction-2 `matches[1]` selection in `getStopServiceSchedule`, and `.trim().toUpperCase()` normalization in `NextBusInfo.fromJson`.

---

## [1.0.9+10] - 2026-10-27

### What's New (App)
- **Smart Nearby Stop Prediction**: When GPS is off or warming up, the `Nearby` tab predicts your starting area based on your routine by **weekday vs. weekend** and **time of day** (morning, afternoon, evening), or falls back to your last known location.
- **Pull-to-Refresh on Nearby**: Pull down on the `Nearby` list anytime to refresh your GPS position.

### Developer Notes (Code)
- `favorites_service.dart`, `bus_stop.dart`, `nearby_screen.dart`, `home_screen.dart`: Removed predefined transit hubs, added 100-entry rolling `LocationRecord` history with `300m` spatial clustering and circular time-of-day/weekday scoring in `getPredictedOrLastLocation`, and gated hardware GPS requests on `NearbyScreen.isActive`.

---

## [1.0.8+9] - 2026-10-27

### What's New (App)
- **GPS & Permission Modals**: Clear prompt dialogs with direct shortcuts to Location Settings or App Settings when GPS is turned off or permission is denied.
- **More Accurate Stop Distances**: Improved distance calculation for Singapore coordinates and refined GPS accuracy over a 5-second window.
- **Centered Toast & Banner Messages**: Centered status toasts and error banners for cleaner readability.

### Developer Notes (Code)
- `transit_db_service.dart`, `nearby_screen.dart`, `bus_stop_detail_screen.dart`: Replaced spherical Haversine with flat-earth Pythagorean distance calibrated for Singapore (`1.35°N`: `111,288 m/°` lon, `110,575 m/°` lat), added `_refinePositionAccuracy` stream listener, and centered `SnackBar`/banner `Row` contents.

---

## [1.0.7+8] - 2026-10-26

### What's New (App)
- **Reliable GPS Lock on Cold Start**: Fixed `"Could not acquire GPS signal"` errors when opening the app outdoors or enabling GPS from cold start.

### Developer Notes (Code)
- `nearby_screen.dart`: Replaced chained 5–6s location timeouts (which cancelled native GPS acquisition mid-lock) with a single 20s high-accuracy request (40s when enabling GPS), falling back to `getLastKnownPosition` and Android `LocationManager`.

---

## [1.0.6+7] - 2026-10-26

### What's New (App)
- **Dual-Loop `1st Visit` & `2nd Visit` Separation**: Bus services that visit an interchange twice (such as `358`, `291`, `811`, `911`) now show separate `1st Visit` and `2nd Visit` arrival cards with accurate timings for each loop wing.
- **Full Circuit Route View**: Added `All Routes`, `1st Visit`, and `2nd Visit` tabs in the route sheet with `1st Visit`, `2nd Visit`, and `Terminus` badges along the stop list.

### Developer Notes (Code)
- `bus_arrival.dart`, `transit_db_service.dart`, `bus_arrival_card.dart`, `bus_route_sheet.dart`: Parsed LTA `VisitNumber` (`1` vs `2`), split dual-loop arrivals by visit number in `expandServicesForStop`, and added `allStops` full-circuit view in `BusRouteInfo`.

---

## [1.0.5+6] - 2026-10-26

### What's New (App)
- **Return Direction Toggle in Route Sheet**: Switch between outbound and return directions when viewing a bus route.
- **Honest Network Error Feedback**: Pull-to-refresh now shows clear error messages when offline or when the LTA API times out.
- **Better Battery Life & Faster Search**: Stopped background countdown timers when auto-refresh is `Off` and smoothed stop search typing.

### Developer Notes (Code)
- `nearby_screen.dart`, `bus_stop_detail_screen.dart`, `lta_api_service.dart`, `settings_sheet.dart`, `bus_route_sheet.dart`, `search_screen.dart`: Removed recursive settings bounce on permission denial, exposed `lastErrorMessage` on `LtaApiService`, halted `_tickerTimer` when `autoRefreshSeconds == 0`, added 150ms search debounce, and persisted settings immediately on tap.

---

## [1.0.3+4] - 2026-10-25

### What's New (App)
- **Auto-Refresh Countdown & Refresh Toast**: Added an `"Updating in Xs"` countdown above the arrivals list and a confirmation toast on pull-to-refresh.

### Developer Notes (Code)
- `bus_stop_detail_screen.dart`, `lta_api_service.dart`, `bus_arrival.dart`: Added 1-second countdown ticker, hardened `.fromJson` string conversions, and separated `.env` from `.env.example`.

---

## [1.0.2+3] - 2026-10-25

### What's New (App)
- **Official QuickBus SG Icon**: Updated the Android home screen icon and in-app header logo.
- **Cleaner Single-Direction Bus Cards**: Hid redundant road direction subtitles on buses that only visit a stop once.

### Developer Notes (Code)
- `home_screen.dart`, `transit_db_service.dart`, `bus_arrival_card.dart`, `android/app/src/main/res/mipmap-*`: Added `_QuickBusLogoPainter` matching `public/icon.svg` and restricted `resolveDirectionLabel` to dual-visit stops.

---

## [1.0.1+2] - 2026-10-25

### What's New (App)
- **Interactive Official MRT Map**: Pinch-to-zoom, pan, and double-tap to zoom the full Singapore Rail System map.
- **Refined Navigation Bar & Settings**: Cleaner bottom navigation bar colors and streamlined Settings sheet.

### Developer Notes (Code)
- `mrt_map_screen.dart`, `main.dart`, `settings_sheet.dart`: Replaced station list with `InteractiveViewer` + `assets/mrt-map.png`, set `surfaceTintColor: Colors.transparent` on `NavigationBarThemeData`, and removed the in-app API key text input.

---

## [1.0.0+1] - 2026-10-25

### What's New (App)
- **Initial Release of QuickBus SG**: Fast, minimalist Singapore bus arrival app with **Starred**, **Nearby**, **Search**, and **MRT** tabs, Material 3 light/dark themes, double-decker & wheelchair indicators, crowd-level bars, and offline access to all **5,208+ bus stops** and **602+ bus routes**.

### Developer Notes (Code)
- `flutter_project/`: Initial Flutter Android & Web architecture with bundled `assets/sg_transit_snapshot.json` (`TransitDbService`), LTA DataMall v3 `BusArrival` client (`LtaApiService`), `SharedPreferences` persistence (`FavoritesService`), and prebuilt ARM release APKs in `releases/`.

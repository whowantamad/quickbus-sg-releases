# <img src="./icon.png" width="36" height="36" align="top" /> QuickBus SG — Android Releases

**Latest Release:** `v1.0.27` (2026-10-30)

Minimalist, high-speed Singapore Bus Arrival & Transit app powered by **LTA DataMall v3** and a complete bundled offline Singapore transit SQLite3 database (`5,211` bus stops and `604` bus routes).

---

## 📥 Download APK

All builds are **Universal ARM APKs** (`arm64-v8a` + `armeabi-v7a`) compatible with Android 8.0+.

| Version | APK File | Date | Status |
| :--- | :--- | :--- | :--- |
| **`v1.0.27`** | [**`quickbus-sg-v1.0.27-arm-universal.apk`**](./quickbus-sg-v1.0.27-arm-universal.apk) | 2026-10-30 | **Latest** |
| `v1.0.26` | [`quickbus-sg-v1.0.26-arm-universal.apk`](./quickbus-sg-v1.0.26-arm-universal.apk) | 2026-10-30 | Previous |
| `v1.0.25` | [`quickbus-sg-v1.0.25-arm-universal.apk`](./quickbus-sg-v1.0.25-arm-universal.apk) | 2026-10-30 | Previous |
| `v1.0.24` | [`quickbus-sg-v1.0.24-arm-universal.apk`](./quickbus-sg-v1.0.24-arm-universal.apk) | 2026-10-30 | Previous |
| `v1.0.23` | [`quickbus-sg-v1.0.23-arm-universal.apk`](./quickbus-sg-v1.0.23-arm-universal.apk) | 2026-10-30 | Previous |

---

## ✨ App Features

- **Live LTA Bus Arrivals (`1st`, `2nd`, `3rd` Bus)**: Real-time arrival countdowns (`Arr` / minutes), crowd load bars (`Seats Available`, `Standing Available`, `Limited Standing`), bus type icons (`Single Deck`, `Double Decker`, `Bendy`), and wheelchair (`WAB`) indicators.
- **Tap Any Arrival Slot for Live Bus Location**: View estimated distance (`~350m away`, `~1.2 km away`), which stop along the route the incoming bus is currently near (`~3 stops away` or `At Interchange`), and exact arrival clock time.
- **Dual-Loop `1st Visit` & `2nd Visit` Separation**: Services that visit an interchange or stop twice (`358`, `291`, `811`, `911`, etc.) display separate `1st Visit` and `2nd Visit` arrival cards and dedicated route tabs.
- **Complete Offline Singapore Transit Database**: Built-in SQLite3 database covering all `5,211` stops and `604` routes with instant search by stop code, stop name, road name, or bus service number, plus official LTA First/Last Bus schedules and Peak/Off-Peak headway frequencies.
- **Smart Route Timeline & Last-Bus Warnings**: Locks bidirectional routes to your current direction, badges the incoming `Next Bus` and `Here` stop, collapses passed stops (`Show N earlier stops`), and shows an amber `Last Bus HH:MM` warning when a service is near closing.
- **Starred Stops, Custom Tags & Live Starred Bus Pills**: Star stops and individual bus services to see live arrival pills directly on the `Starred` tab; organize stops with custom names (`Home`, `Office`) and filter tags.
- **Opposite Stop Quick-Switch (`↔`) & Routine-Aware Nearby**: One-tap jump to the opposite stop across the road, plus GPS nearby stops with routine-based fallback by weekday/weekend and time of day.
- **Interactive Official MRT Map**: High-resolution pinch-to-zoom and double-tap-to-zoom Singapore Rail System map.
- **Customizable Experience**: Light/Dark/System themes, configurable auto-refresh intervals (`15s`, `30s`, `60s`, `Off`), and `Default` / `Large` / `Extra Large` text scaling.
- **Voluntary Tip Jar**: Support independent app development directly from Settings with silent perpetual ad-free protection.

---

## 📋 Release Changelog

### [1.0.27] - 2026-10-30
- **Voluntary Tip Jar & Supporter Perks**: Added an optional Tip Jar in Settings for commuters who wish to support independent QuickBus SG development.
- **Silent Ad Suppression**: Remote configuration capability defaults ads to off; any future remote promotions or ads are silently and permanently suppressed for app supporters.
- **Clean Settings Experience**: Refined settings interface with zero intrusive ad copy or banner clutter.

### [1.0.26] - 2026-10-30
- **Accurate Starred Seating Availability**: Starred bus arrival pills now display individual crowd colors for both incoming buses (`Seats Available` green, `Standing Available` amber, `Limited Standing` red) matching the bus stop detail page.
- **Subtle Starred Pill Border**: Replaced the hardcoded amber border with a clean, neutral border so the pill doesn't look like an amber warning when buses have seats available.
- **Starred Tab Auto-Refresh**: Starred arrivals automatically refresh based on your auto-refresh settings (`15s`, `30s`, `60s`), keeping live arrivals and crowd data fresh without manual pull-to-refresh.

### [1.0.25] - 2026-10-30
- **Nearby Tab Location Prompt (Once per Session)**: Entering the Nearby tab automatically asks to enable Location Services or grant permissions on the first visit of the session without repeatedly popping up on tab switches.
- **Active Transit Alert Updates**: Transit disruptions and bridging bus alerts are automatically refreshed when resuming the app from the background or periodically while active.
- **Cold-Start DB Optimization**: Faster startup database initialization by reading SQLite file header directly from disk before loading asset buffers into memory.

### [1.0.24] - 2026-10-30
- **Global Transit Alert Banner**: Prominently displays emergency alerts and advisories at the top of the app across all tabs, ensuring bus commuters immediately see disruptions and free bridging bus activations.
- **Persistent Notification Bell**: Dismissing an alert smoothly collapses it into a notification bell in the top app bar for instant re-access without cluttering the screen.
- **Smart Escalation Updates**: Dismissed alerts automatically re-surface if LTA updates the incident, adds affected stations, or activates emergency shuttle buses.
- **Streamlined MRT Tab**: Removed the notification dot on the MRT tab icon and cleared duplicate alert UI, giving full screen height to the interactive rail map.

### [1.0.23] - 2026-10-30
- **Drag-and-Drop Starred Reordering**: Long press any starred bus stop card in Default mode to reorder favorites with a dynamic drag handle and live reordering.
- **Segmented Starred Sort Pill**: Seamlessly toggle between `↕ Default` custom order and `Nearest` GPS proximity order directly in the header.
- **Streamlined Distance Badges**: Walking distance tags (`~450m`, `~1.4km`) are positioned beside the stop name as clean text chips.
- **MRT Map Snap-Back Bounce**: Swiping the MRT system map at normal 1.0x scale now springs and bounces back to center instead of drifting off-screen.

### [1.0.20] - 2026-10-29
- **Consolidated Bicycle Parking & Taxi Stand Pills**: Replaced repeating individual amenity chips with single count pills (`N Bicycle Parking ›` and `N Taxi Stand(s) ›`) for a cleaner, non-scrolling stop view.
- **Amenity Details Modal**: Tapping the Bicycle Parking or Taxi Stand pill opens an informative bottom sheet showing each physical spot's installation type (metal racks vs. yellow box), roof shelter status, bicycle capacity, and exact walking distance.
- **Clean Version Display**: Settings sheet now displays the clean version name (`v1.0.20`) without internal build numbers.

### [1.0.19+20] - 2026-10-29
- **Real-Time Train Service Alerts (`/TrainServiceAlerts`)**: Receive instant heads-up about Singapore train disruptions. The bottom navigation bar's MRT tab lights up with a 🔴 red notification badge for active delays or breakdowns, and a 🟡 amber badge for planned maintenance or early closure advisories. Inside the MRT tab, an alert card details affected stations, route segments, and free bridging bus activations.
- **Nearby Stop Amenities (Bicycle Parking & Taxi Stands)**: Bus stop views now show compact amenity chips for nearby bicycle parking (with sheltered status and rack counts) and taxi stands within walking distance.
- **Amenities Settings Toggles**: Separately toggle Bicycle Parking and Taxi Stands on or off in the Settings sheet.

### [1.0.18+19] - 2026-10-29
- **Refreshed App Icon (`⚡G BUS`)**: Updated the app icon across Android and Web with a unified lightning-bolt `S`, squared geometric `G`, and bold `BUS` wordmark on the signature rose-to-coral gradient.

### [1.0.17+18] - 2026-10-29
- **Tilde `~` Prefix for Estimated Distances & Stops**: Distances and stop counts are now explicitly marked with `~` (e.g. `~350m away`, `~1.2 km away`, and `~3 stops away` in the arrival status modal, and `~450m` / `~1.4km` on Nearby bus stop cards) to clearly indicate estimates.

### [1.0.16+17] - 2026-10-29
- **Updated Singapore Bus Routes & Stops (`5,211` stops, `604` routes)**: Refreshed the bundled offline transit database directly from LTA DataMall, including newly added stops and services (`861C`, `873`, `873M`, `874`).
- **Official LTA Peak & Off-Peak Frequencies**: Route schedule cards now show official LTA DataMall morning peak, evening peak, and off-peak headway frequencies (including accurate `Peak Hours Only` indicators for peak-only supplementary services).
- **Accurate Interchange Departure Schedules**: Fixed Direction 2 interchanges so operating hours always display boarding departure times from that interchange rather than alighting arrival times.

### [1.0.15+16] - 2026-10-28
- **Current-Direction Route & Schedule View**: Opening a bidirectional bus route now automatically locks to the direction that serves your current stop and hides the opposite-direction toggle, while keeping the `All Routes`, `1st Visit`, and `2nd Visit` tabs on dual-loop services.
- **Collapsed Earlier Stops on Long Routes (`Show N earlier stops`)**: Long trunk and loop routes now start right at your incoming `Next Bus` or `Here` stop with earlier passed stops collapsed behind a single `Show N earlier stops` button, so you only see the stops ahead of you by default.

### [1.0.14+15] - 2026-10-28
- **Tap Any Arrival Slot for Live Bus Position & Details**: Tap the `1st`, `2nd`, or `3rd` arrival slot on any bus card to open a live status modal showing how far away the bus is (`m` / `km`), which stop along the route it is currently near (`N stops away` or `At Interchange`), exact estimated arrival clock time, crowd level, bus type (`Single Deck` / `Double Decker` / `Bendy`), and wheelchair accessibility.
- **`Next Bus` Marker on Route Timeline**: Opening the full route sheet now badges the stop where the next incoming bus is currently located.
- **Last-Bus Warning Badge (`Last Bus HH:MM`)**: Displays an amber warning badge on bus cards when a service is within 30 minutes of its scheduled last bus at that stop (or within 45 minutes when only one bus remains).
- **Neutral Pulsing `"Arr"` Text**: Kept `"Arr"` in high-contrast neutral text with a subtle fade pulse so only the bottom bar uses green/amber/red crowd colors.

### [1.0.13+14] - 2026-10-28
- **Crowd-Colored & Pulsing `"Arr"` Indicator**: Added subtle pulse animation when a bus is arriving now (`Arr`).

### [1.0.12+13] - 2026-10-28
- **Instant Star Sync Across Tabs**: Starring or unstarring a bus stop inside the bus arrival page now immediately updates its star icon on the `Search` and `Nearby` lists when you go back.
- **Live-Only Arrival Data**: Removed offline simulated bus arrival times so the app only displays real LTA DataMall arrival estimates (or `No Est. Available` / `Not In Operation`).
- **Cleaner `Extra Large` Layout**: Fixed 4-character bus numbers (like `857A`) and `1st/2nd Visit` badges so they never wrap or overflow when `Extra Large` text size is enabled.

### [1.0.11+12] - 2026-10-28
- **Text Size Setting**: Added a **Text Size** selector (`Default`, `Large`, `Extra Large`) with visual `Aa` previews in Settings for easier reading.

### [1.0.10+11] - 2026-10-27
- **Live Starred Bus Timings on `Starred` Tab**: Starred bus stops now show live arrival pills (e.g. `★ 147  2m · 9m`) directly on the `Starred` tab for any bus services you starred at that stop, with pull-down-to-refresh.
- **Custom Stop Labels & Tags**: Tap the edit icon (or long-press a starred stop) to give it a custom name (e.g. `Home`, `Office`) and filter tag (`Commute`, `Home`, `Work`, `School`, or custom).
- **Opposite Stop Quick-Switch (`↔`)**: Tap the swap icon in the top bar of a bus stop page to jump directly to the opposite bus stop across the road.
- **Smarter Route Sheet**: Opening a bus route now auto-scrolls to your current stop, marks it with `Here`, shows `+N stop(s)` on upcoming stops, and updates first/last bus hours when switching directions.
- **Accurate Wheelchair (`WAB`) Indicator**: Fixed wheelchair icon handling so it reflects actual bus feature data.

### [1.0.9+10] - 2026-10-27
- **Smart Nearby Stop Prediction**: When GPS is off or warming up, the `Nearby` tab predicts your starting area based on your routine by **weekday vs. weekend** and **time of day** (morning, afternoon, evening), or falls back to your last known location.
- **Pull-to-Refresh on Nearby**: Pull down on the `Nearby` list anytime to refresh your GPS position.

### [1.0.8+9] - 2026-10-27
- **GPS & Permission Modals**: Clear prompt dialogs with direct shortcuts to Location Settings or App Settings when GPS is turned off or permission is denied.
- **More Accurate Stop Distances**: Improved distance calculation for Singapore coordinates and refined GPS accuracy over a 5-second window.
- **Centered Toast & Banner Messages**: Centered status toasts and error banners for cleaner readability.

### [1.0.7+8] - 2026-10-26
- **Reliable GPS Lock on Cold Start**: Fixed `"Could not acquire GPS signal"` errors when opening the app outdoors or enabling GPS from cold start.

### [1.0.6+7] - 2026-10-26
- **Dual-Loop `1st Visit` & `2nd Visit` Separation**: Bus services that visit an interchange twice (such as `358`, `291`, `811`, `911`) now show separate `1st Visit` and `2nd Visit` arrival cards with accurate timings for each loop wing.
- **Full Circuit Route View**: Added `All Routes`, `1st Visit`, and `2nd Visit` tabs in the route sheet with `1st Visit`, `2nd Visit`, and `Terminus` badges along the stop list.

### [1.0.5+6] - 2026-10-26
- **Return Direction Toggle in Route Sheet**: Switch between outbound and return directions when viewing a bus route.
- **Honest Network Error Feedback**: Pull-to-refresh now shows clear error messages when offline or when the LTA API times out.
- **Better Battery Life & Faster Search**: Stopped background countdown timers when auto-refresh is `Off` and smoothed stop search typing.

### [1.0.3+4] - 2026-10-25
- **Auto-Refresh Countdown & Refresh Toast**: Added an `"Updating in Xs"` countdown above the arrivals list and a confirmation toast on pull-to-refresh.

### [1.0.2+3] - 2026-10-25
- **Official QuickBus SG Icon**: Updated the Android home screen icon and in-app header logo.
- **Cleaner Single-Direction Bus Cards**: Hid redundant road direction subtitles on buses that only visit a stop once.

### [1.0.1+2] - 2026-10-25
- **Interactive Official MRT Map**: Pinch-to-zoom, pan, and double-tap to zoom the full Singapore Rail System map.
- **Refined Navigation Bar & Settings**: Cleaner bottom navigation bar colors and streamlined Settings sheet.

### [1.0.0+1] - 2026-10-25
- **Initial Release**: Offline Singapore transit snapshot, live LTA DataMall v3 bus arrivals, starred stops & services, search by stop or service, and GPS nearby stops.


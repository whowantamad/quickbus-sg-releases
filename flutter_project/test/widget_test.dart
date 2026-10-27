import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quickbus_sg/main.dart';
import 'package:quickbus_sg/models/bus_arrival.dart';
import 'package:quickbus_sg/services/favorites_service.dart';
import 'package:quickbus_sg/services/lta_api_service.dart';
import 'package:quickbus_sg/services/transit_db_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('NextBusInfo.minutesToArrival computes remaining minutes accurately',
      () {
    final futureIso = DateTime.now()
        .toUtc()
        .add(const Duration(minutes: 5, seconds: 30))
        .toIso8601String();
    final pastIso = DateTime.now()
        .toUtc()
        .subtract(const Duration(minutes: 2))
        .toIso8601String();

    expect(
      NextBusInfo(estimatedArrival: futureIso).minutesToArrival,
      equals(5),
    );
    expect(
      NextBusInfo(estimatedArrival: pastIso).minutesToArrival,
      equals(0),
    );
    expect(const NextBusInfo().minutesToArrival, isNull);
  });

  test('Dual-loop expansion preserves real arrival timestamps on both wings',
      () async {
    await TransitDbService.init();

    expect(TransitDbService.isDualLoopAtStop('358', '77009'), isTrue);
    expect(TransitDbService.isDualLoopAtStop('147', '03223'), isFalse);

    const sampleEta = '2026-10-25T12:00:00.000Z';
    final raw = [
      const BusArrivalService(
        serviceNo: '358',
        operator: 'SBST',
        nextBus: NextBusInfo(estimatedArrival: sampleEta, load: 'SEA'),
      ),
    ];

    final expanded = TransitDbService.expandServicesForStop(raw, '77009');
    expect(expanded.length, equals(2));
    expect(expanded[0].routeKey, equals('358-wing-1'));
    expect(expanded[1].routeKey, equals('358-wing-2'));
    expect(expanded[0].nextBus?.estimatedArrival, equals(sampleEta));
    expect(expanded[1].nextBus?.estimatedArrival, equals(sampleEta));

    final nearest =
        TransitDbService.getNearestStops(1.2929, 103.8529, limit: 5);
    expect(nearest.length, equals(5));
    expect(
      nearest.first.distanceMeters! <= nearest.last.distanceMeters!,
      isTrue,
    );
  });

  test(
      'Dual-loop service separates 1st and 2nd visit arrivals and exposes all routes',
      () async {
    await TransitDbService.init();

    const etaVisit1 = '2026-10-26T17:40:00+08:00';
    const etaVisit2 = '2026-10-26T17:42:00+08:00';
    final raw = [
      const BusArrivalService(
        serviceNo: '358',
        operator: 'GAS',
        nextBus: NextBusInfo(estimatedArrival: etaVisit1, visitNumber: 1),
        nextBus2: NextBusInfo(estimatedArrival: etaVisit2, visitNumber: 2),
      ),
    ];

    final expanded = TransitDbService.expandServicesForStop(raw, '77009');
    expect(expanded.length, equals(2));

    // Wing 1 (Visit 1: Pasir Ris Dr 10)
    final wing1 = expanded[0];
    expect(wing1.isFirstVisit, isTrue);
    expect(wing1.isSecondVisit, isFalse);
    expect(wing1.loopDirectionLabel, equals('Pasir Ris Dr 10'));
    expect(wing1.nextBus?.estimatedArrival, equals(etaVisit1));
    expect(wing1.nextBus2, isNull);

    // Wing 2 (Visit 2: Pasir Ris Dr 4)
    final wing2 = expanded[1];
    expect(wing2.isFirstVisit, isFalse);
    expect(wing2.isSecondVisit, isTrue);
    expect(wing2.loopDirectionLabel, equals('Pasir Ris Dr 4'));
    expect(wing2.nextBus?.estimatedArrival, equals(etaVisit2));
    expect(wing2.nextBus2, isNull);

    // Check all routes on BusRouteInfo
    final routeInfo = TransitDbService.getBusRouteAndSchedule('358');
    expect(routeInfo.isDualLoop, isTrue);
    expect(routeInfo.allStops?.length, equals(23));
    expect(routeInfo.direction1Stops.length, equals(12));
    expect(routeInfo.direction2Stops?.length, equals(12));
  });

  test(
      'FavoritesService caches starred stops and caps recent stop history at 30',
      () async {
    SharedPreferences.setMockInitialValues({});
    await FavoritesService.getFavorites();

    expect(FavoritesService.isStarredSync('03223'), isTrue);
    await FavoritesService.toggleStarred('03223');
    expect(FavoritesService.isStarredSync('03223'), isFalse);

    for (var i = 0; i < 40; i++) {
      await FavoritesService.recordStopOpen(i.toString().padLeft(5, '0'));
    }
    final recents = await FavoritesService.getRecentStopRecords();
    expect(recents.length, equals(30));
  });

  test('UserSettings serialization preserves custom auto-refresh and theme',
      () async {
    SharedPreferences.setMockInitialValues({});
    const custom = UserSettings(
      datamallKey: 'test-key',
      autoRefreshSeconds: 15,
      themeMode: ThemeMode.dark,
    );
    await FavoritesService.saveSettings(custom);
    final loaded = await FavoritesService.getSettings();
    expect(loaded.autoRefreshSeconds, equals(15));
    expect(loaded.themeMode, equals(ThemeMode.dark));
    expect(loaded.datamallKey, equals('test-key'));
  });

  test('LtaApiService tracks error messages and live status', () async {
    final api = LtaApiService(accountKey: '');
    final simulated = await api.getBusArrivals('03223', stopServices: ['147']);
    expect(simulated.isNotEmpty, isTrue);
    expect(api.lastFetchIsLive, isFalse);
    expect(api.lastFetchHadError, isFalse);
    expect(api.lastErrorMessage, isNull);
  });

  test('BusRouteInfo contains bidirectional stops and schedule windows',
      () async {
    await TransitDbService.init();
    final route = TransitDbService.getBusRouteAndSchedule('147');
    expect(route.serviceNo, equals('147'));
    expect(route.direction1Stops.isNotEmpty, isTrue);
    expect(route.direction2Stops, isNotNull);
    expect(route.direction2Stops!.isNotEmpty, isTrue);
    expect(route.schedule.weekday.first, isNotEmpty);
    expect(route.schedule.weekday.last, isNotEmpty);
  });

  test(
      'Location history predicts coordinates by weekday/weekend and time of day',
      () async {
    SharedPreferences.setMockInitialValues({});
    await TransitDbService.init();

    // Home (Tampines): Weekday 8:00 AM
    await FavoritesService.recordLocation(
      1.35408,
      103.94339,
      timestamp: DateTime(2026, 10, 19, 8, 0), // Monday
    );
    await FavoritesService.recordLocation(
      1.35412,
      103.94342,
      timestamp: DateTime(2026, 10, 20, 8, 15), // Tuesday
    );

    // Work (Raffles Place): Weekday 6:00 PM
    await FavoritesService.recordLocation(
      1.28520,
      103.85256,
      timestamp: DateTime(2026, 10, 19, 18, 0), // Monday
    );
    await FavoritesService.recordLocation(
      1.28525,
      103.85260,
      timestamp: DateTime(2026, 10, 20, 18, 10), // Tuesday
    );

    // Weekend spot (Orchard): Saturday 2:00 PM
    await FavoritesService.recordLocation(
      1.30417,
      103.83383,
      timestamp: DateTime(2026, 10, 24, 14, 0), // Saturday
    );

    // Query on Wednesday 8:10 AM -> should predict Tampines (Home)
    final wedMorning = await FavoritesService.getPredictedOrLastLocation(
      now: DateTime(2026, 10, 21, 8, 10),
    );
    expect(wedMorning, isNotNull);
    expect(wedMorning!.isPredicted, isTrue);
    expect(wedMorning.label, contains('Weekday Morning'));
    expect(
      TransitDbService.distanceMeters(
          wedMorning.lat, wedMorning.lng, 1.3541, 103.9434),
      lessThan(50),
    );

    // Query on Wednesday 6:05 PM -> should predict Raffles Place (Work)
    final wedEvening = await FavoritesService.getPredictedOrLastLocation(
      now: DateTime(2026, 10, 21, 18, 5),
    );
    expect(wedEvening, isNotNull);
    expect(wedEvening!.label, contains('Weekday Evening'));
    expect(
      TransitDbService.distanceMeters(
          wedEvening.lat, wedEvening.lng, 1.2852, 103.8526),
      lessThan(50),
    );

    // Query on Sunday 2:15 PM -> should predict Orchard (Weekend)
    final sunAfternoon = await FavoritesService.getPredictedOrLastLocation(
      now: DateTime(2026, 10, 25, 14, 15),
    );
    expect(sunAfternoon, isNotNull);
    expect(sunAfternoon!.label, contains('Weekend Afternoon'));
    expect(
      TransitDbService.distanceMeters(
          sunAfternoon.lat, sunAfternoon.lng, 1.30417, 103.83383),
      lessThan(50),
    );

    // Query at 3:00 AM (outside ±3h window) -> falls back to Last Location
    final lateNight = await FavoritesService.getPredictedOrLastLocation(
      now: DateTime(2026, 10, 26, 3, 0),
    );
    expect(lateNight, isNotNull);
    expect(lateNight!.label, equals('Last Location'));

    // If a new GPS fix was recorded 10 minutes ago (e.g. Jurong East at 8:00 AM),
    // querying at 8:10 AM prefers that recent fix over the Tampines routine
    await FavoritesService.recordLocation(
      1.33235,
      103.74066,
      timestamp: DateTime(2026, 10, 27, 8, 0),
    );
    final recentOverride = await FavoritesService.getPredictedOrLastLocation(
      now: DateTime(2026, 10, 27, 8, 10),
    );
    expect(recentOverride, isNotNull);
    expect(recentOverride!.isPredicted, isFalse);
    expect(recentOverride.label, equals('Last Location'));
    expect(
      TransitDbService.distanceMeters(
          recentOverride.lat, recentOverride.lng, 1.33235, 103.74066),
      lessThan(20),
    );
  });

  test('WAB normalization, opposite stop lookup, and favorite editing work',
      () async {
    SharedPreferences.setMockInitialValues({});
    await TransitDbService.init();

    // WAB normalization
    final wabBus = NextBusInfo.fromJson({
      'EstimatedArrival': '2026-10-27T08:00:00+08:00',
      'Feature': ' wab ',
      'Type': ' dd ',
      'Load': ' sea ',
    });
    expect(wabBus.isWheelchairAccessible, isTrue);
    expect(wabBus.isDoubleDecker, isTrue);
    expect(wabBus.load, equals('SEA'));

    final nonWabBus = NextBusInfo.fromJson({
      'EstimatedArrival': '2026-10-27T08:00:00+08:00',
      'Feature': '',
      'Type': 'SD',
    });
    expect(nonWabBus.isWheelchairAccessible, isFalse);

    // Opposite stop lookup: two-way road (01012 Hotel Grand Pacific <-> 01019 Bras Basah Complex)
    // vs one-way road (09048 Lucky Plaza on Orchard Rd -> null)
    final twoWayStop = TransitDbService.getStopByCode('01012');
    expect(twoWayStop, isNotNull);
    final opp = TransitDbService.findOppositeStop(twoWayStop!);
    expect(opp, isNotNull);
    expect(opp!.code, equals('01019'));

    final oneWayStop = TransitDbService.getStopByCode('09048');
    expect(oneWayStop, isNotNull);
    expect(TransitDbService.findOppositeStop(oneWayStop!), isNull);

    // Favorite update & starred services map
    await FavoritesService.getFavorites();
    await FavoritesService.updateFavorite(
      '03223',
      customName: 'Morning Office Stop',
      tag: 'Home',
    );
    final updatedFavs = await FavoritesService.getFavorites();
    final edited = updatedFavs.firstWhere((f) => f.code == '03223');
    expect(edited.customName, equals('Morning Office Stop'));
    expect(edited.tag, equals('Home'));

    await FavoritesService.toggleStarredServiceForStop('03223', '147');
    final allStarred = await FavoritesService.getAllStarredServices();
    expect(allStarred['03223'], contains('147'));
  });

  testWidgets('QuickBus SG app smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await FavoritesService.getFavorites();
    await tester.pumpWidget(
      const QuickBusApp(initialSettings: UserSettings()),
    );
    expect(find.text('QuickBus SG'), findsOneWidget);
  });
}

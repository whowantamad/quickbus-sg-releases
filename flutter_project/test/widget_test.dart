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

  test('NextBusInfo.minutesToArrival computes remaining minutes accurately', () {
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

  test('Dual-loop expansion preserves real arrival timestamps on both wings', () async {
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

    final nearest = TransitDbService.getNearestStops(1.2929, 103.8529, limit: 5);
    expect(nearest.length, equals(5));
    expect(
      nearest.first.distanceMeters! <= nearest.last.distanceMeters!,
      isTrue,
    );
  });

  test('FavoritesService caches starred stops and caps recent stop history at 30', () async {
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

  test('UserSettings serialization preserves custom auto-refresh and theme', () async {
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

  test('BusRouteInfo contains bidirectional stops and schedule windows', () async {
    await TransitDbService.init();
    final route = TransitDbService.getBusRouteAndSchedule('147');
    expect(route.serviceNo, equals('147'));
    expect(route.direction1Stops.isNotEmpty, isTrue);
    expect(route.direction2Stops, isNotNull);
    expect(route.direction2Stops!.isNotEmpty, isTrue);
    expect(route.schedule.weekday.first, isNotEmpty);
    expect(route.schedule.weekday.last, isNotEmpty);
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

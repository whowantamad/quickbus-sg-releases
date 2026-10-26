import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import '../models/bus_arrival.dart';
import 'transit_db_service.dart';

class LtaApiService {
  static const String baseUrl =
      'https://datamall2.mytransport.sg/ltaodataservice/v3';

  static const String _dartDefineDatamallKey = String.fromEnvironment(
    'LTA_DATAMALL_KEY',
    defaultValue: '',
  );
  static String _envFileDatamallKey = '';

  /// Default LTA DataMall AccountKey resolved from `--dart-define` or `.env`.
  static String get defaultAccountKey {
    final fromDefine = _sanitizeKey(_dartDefineDatamallKey);
    if (fromDefine.isNotEmpty) return fromDefine;
    return _envFileDatamallKey;
  }

  static String _sanitizeKey(String raw) {
    var val = raw.trim();
    if ((val.startsWith('"') && val.endsWith('"')) ||
        (val.startsWith("'") && val.endsWith("'"))) {
      val = val.substring(1, val.length - 1).trim();
    }
    if (val.isEmpty || val == 'YOUR_LTA_DATAMALL_ACCOUNT_KEY') {
      return '';
    }
    return val;
  }

  /// Loads `LTA_DATAMALL_KEY` from the bundled `.env` file at startup.
  static Future<void> initEnv() async {
    try {
      final content = await rootBundle.loadString('.env');
      for (final rawLine in content.split('\n')) {
        final line = rawLine.trim();
        if (line.isEmpty || line.startsWith('#')) continue;
        final eqIndex = line.indexOf('=');
        if (eqIndex <= 0) continue;
        final key = line.substring(0, eqIndex).trim();
        final value = line.substring(eqIndex + 1).trim();
        if (key == 'LTA_DATAMALL_KEY') {
          _envFileDatamallKey = _sanitizeKey(value);
          break;
        }
      }
    } catch (_) {
      // .env asset not present or unreadable; fall back to --dart-define or in-app settings
    }
  }

  final String? accountKey;
  bool lastFetchIsLive = false;

  LtaApiService({this.accountKey});

  /// Fetches real-time bus arrivals for a bus stop code.
  /// Resolves the API key from the constructor argument, `.env`, or `--dart-define`.
  /// If no accountKey is provided, falls back to realistic simulation using the offline stop's services.
  Future<List<BusArrivalService>> getBusArrivals(
    String busStopCode, {
    List<String>? stopServices,
  }) async {
    final resolvedKey = (accountKey != null && accountKey!.trim().isNotEmpty)
        ? accountKey!.trim()
        : defaultAccountKey;

    if (resolvedKey.isNotEmpty) {
      try {
        final url = Uri.parse('$baseUrl/BusArrival?BusStopCode=$busStopCode');
        final response = await http.get(
          url,
          headers: {
            'AccountKey': resolvedKey,
            'accept': 'application/json',
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final servicesList = data['Services'] as List<dynamic>? ?? [];
          lastFetchIsLive = true;
          return servicesList
              .map((s) => BusArrivalService.fromJson(s as Map<String, dynamic>))
              .toList();
        }
      } catch (_) {
        // Fallback to simulation if network or API error occurs
      }
    }

    lastFetchIsLive = false;
    return _generateSimulatedArrivals(busStopCode, stopServices: stopServices);
  }

  List<BusArrivalService> _generateSimulatedArrivals(
    String busStopCode, {
    List<String>? stopServices,
  }) {
    final now = DateTime.now().toUtc();
    final stop = TransitDbService.getStopByCode(busStopCode);
    final servicesToSimulate = (stopServices != null && stopServices.isNotEmpty)
        ? stopServices
        : (stop != null && stop.services.isNotEmpty)
            ? stop.services
            : ['65', '147', '190', '857', '106'];

    return servicesToSimulate.map((svc) {
      final probeService = BusArrivalService(serviceNo: svc, operator: 'SBST');
      final inOperation = TransitDbService.isServiceInOperation(
        probeService,
        stopCode: busStopCode,
      );

      if (!inOperation) {
        return BusArrivalService(
          serviceNo: svc,
          operator: svc.length > 2 ? 'SMRT' : 'SBST',
        );
      }

      final seed = _stableSeed('$busStopCode:$svc');

      final min1 = (seed % 6);
      final min2 = min1 + (seed % 5) + 6;
      final min3 = min2 + (seed % 6) + 8;

      const loadTypes = ['SEA', 'SDA', 'LSD'];
      const deckTypes = ['SD', 'DD'];

      return BusArrivalService(
        serviceNo: svc,
        operator: svc.length > 2 ? 'SMRT' : 'SBST',
        nextBus: NextBusInfo(
          estimatedArrival: now.add(Duration(minutes: min1)).toIso8601String(),
          load: loadTypes[seed % 3],
          type: deckTypes[seed % 2],
          feature: (seed % 5 != 0) ? 'WAB' : '',
        ),
        nextBus2: NextBusInfo(
          estimatedArrival: now.add(Duration(minutes: min2)).toIso8601String(),
          load: loadTypes[(seed + 1) % 3],
          type: deckTypes[(seed + 1) % 2],
          feature: 'WAB',
        ),
        nextBus3: NextBusInfo(
          estimatedArrival: now.add(Duration(minutes: min3)).toIso8601String(),
          load: 'SEA',
          type: 'SD',
          feature: 'WAB',
        ),
      );
    }).toList();
  }

  static int _stableSeed(String input) {
    var hash = 0;
    for (final unit in input.codeUnits) {
      hash = ((hash * 31) + unit) & 0x7fffffff;
    }
    return hash;
  }
}

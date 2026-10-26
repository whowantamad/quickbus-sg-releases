import 'dart:convert';
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

  /// Default LTA DataMall AccountKey resolved from `--dart-define` / `--dart-define-from-file=.env`.
  static String get defaultAccountKey => _sanitizeKey(_dartDefineDatamallKey);

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

  final String? accountKey;
  bool lastFetchIsLive = false;
  String? lastErrorMessage;
  bool get lastFetchHadError => lastErrorMessage != null;

  LtaApiService({this.accountKey});

  /// Fetches real-time bus arrivals for a bus stop code.
  /// When a valid AccountKey is configured, network/API errors return an empty list
  /// so the UI displays honest "No Est. Available" status rather than fake simulated times.
  /// Simulation is used only when no AccountKey is configured at all.
  Future<List<BusArrivalService>> getBusArrivals(
    String busStopCode, {
    List<String>? stopServices,
  }) async {
    final resolvedKey = (accountKey != null && _sanitizeKey(accountKey!).isNotEmpty)
        ? _sanitizeKey(accountKey!)
        : defaultAccountKey;

    if (resolvedKey.isNotEmpty) {
      try {
        final url = Uri.parse('$baseUrl/BusArrival?BusStopCode=$busStopCode');
        final response = await http
            .get(
              url,
              headers: {
                'AccountKey': resolvedKey,
                'accept': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final servicesList = data['Services'] as List<dynamic>? ?? [];
          lastFetchIsLive = true;
          lastErrorMessage = null;
          return servicesList
              .map((s) => BusArrivalService.fromJson(s as Map<String, dynamic>))
              .toList();
        } else {
          lastErrorMessage = response.statusCode == 401 || response.statusCode == 403
              ? 'Invalid or expired LTA DataMall Key (${response.statusCode})'
              : 'LTA DataMall API error (${response.statusCode})';
        }
      } catch (_) {
        lastErrorMessage = 'Network error or request timeout';
      }
      lastFetchIsLive = false;
      return const [];
    }

    lastFetchIsLive = false;
    lastErrorMessage = null;
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

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/bus_arrival.dart';
import 'transit_db_service.dart';

class LtaApiService {
  static const String baseUrl =
      'https://datamall2.mytransport.sg/ltaodataservice/v3';

  final String? accountKey;

  LtaApiService({this.accountKey});

  /// Fetches real-time bus arrivals for a bus stop code.
  /// If no accountKey is provided, falls back to realistic simulation using the offline stop's services.
  Future<List<BusArrivalService>> getBusArrivals(
    String busStopCode, {
    List<String>? stopServices,
  }) async {
    if (accountKey != null && accountKey!.trim().isNotEmpty) {
      try {
        final url = Uri.parse('$baseUrl/BusArrival?BusStopCode=$busStopCode');
        final response = await http.get(
          url,
          headers: {
            'AccountKey': accountKey!.trim(),
            'accept': 'application/json',
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final servicesList = data['Services'] as List<dynamic>? ?? [];
          return servicesList
              .map((s) => BusArrivalService.fromJson(s as Map<String, dynamic>))
              .toList();
        }
      } catch (_) {
        // Fallback to simulation if network or API error occurs
      }
    }

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

      final seed = (busStopCode.hashCode + svc.hashCode).abs();
      // Deterministic ~12% chance of "No Est. Available" during operating hours for realism
      if (seed % 9 == 0) {
        return BusArrivalService(
          serviceNo: svc,
          operator: svc.length > 2 ? 'SMRT' : 'SBST',
        );
      }

      final min1 = (seed % 7);
      final min2 = min1 + (seed % 8) + 5;
      final min3 = min2 + 9;

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
}

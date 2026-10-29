import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/bus_arrival.dart';

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
  /// Returns an empty list on missing AccountKey or network/API errors so the UI
  /// displays honest "No Est. Available" / "Not In Operation" status.
  Future<List<BusArrivalService>> getBusArrivals(String busStopCode) async {
    final resolvedKey =
        (accountKey != null && _sanitizeKey(accountKey!).isNotEmpty)
            ? _sanitizeKey(accountKey!)
            : defaultAccountKey;

    if (resolvedKey.isEmpty) {
      lastFetchIsLive = false;
      lastErrorMessage = 'LTA DataMall API key not configured';
      return const [];
    }

    try {
      final url = Uri.parse('$baseUrl/BusArrival?BusStopCode=$busStopCode');
      final response = await http.get(
        url,
        headers: {
          'AccountKey': resolvedKey,
          'accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final servicesList = data['Services'] as List<dynamic>? ?? [];
        lastFetchIsLive = true;
        lastErrorMessage = null;
        return servicesList
            .map((s) => BusArrivalService.fromJson(s as Map<String, dynamic>))
            .toList();
      } else {
        lastErrorMessage = response.statusCode == 401 ||
                response.statusCode == 403
            ? 'Invalid or expired LTA DataMall Key (${response.statusCode})'
            : 'LTA DataMall API error (${response.statusCode})';
      }
    } catch (_) {
      lastErrorMessage = 'Network error or request timeout';
    }
    lastFetchIsLive = false;
    return const [];
  }
}

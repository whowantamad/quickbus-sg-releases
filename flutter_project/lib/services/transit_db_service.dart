import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import '../models/bus_stop.dart';
import '../models/bus_arrival.dart';

class BusScheduleWindow {
  final String first;
  final String last;

  const BusScheduleWindow({required this.first, required this.last});
}

class BusSchedule {
  final BusScheduleWindow weekday;
  final BusScheduleWindow saturday;
  final BusScheduleWindow sunday;
  final String morningPeak;
  final String eveningPeak;
  final String offPeak;

  const BusSchedule({
    required this.weekday,
    required this.saturday,
    required this.sunday,
    required this.morningPeak,
    required this.eveningPeak,
    required this.offPeak,
  });
}

class BusRouteInfo {
  final String serviceNo;
  final String origin;
  final String destination;
  final bool isLoop;
  final bool isDualLoop;
  final String direction1Name;
  final String? direction2Name;
  final BusSchedule schedule;
  final List<BusStop> direction1Stops;
  final List<BusStop>? direction2Stops;

  const BusRouteInfo({
    required this.serviceNo,
    required this.origin,
    required this.destination,
    this.isLoop = false,
    this.isDualLoop = false,
    required this.direction1Name,
    this.direction2Name,
    required this.schedule,
    required this.direction1Stops,
    this.direction2Stops,
  });
}

class _DualLoopMeta {
  final List<String> interchangeCodes;
  final int? splitIndex;
  final String wing1Label;
  final String wing2Label;
  final bool swapDisplayOrder;

  const _DualLoopMeta({
    required this.interchangeCodes,
    this.splitIndex,
    required this.wing1Label,
    required this.wing2Label,
    this.swapDisplayOrder = false,
  });
}

class TransitDbService {
  static bool _initialized = false;
  static String versionHash = 'v2-bundled';
  static List<BusStop> allStops = [];
  static Map<String, BusStop> _stopByCode = {};
  static Map<String, Map<String, dynamic>> _routes = {};
  static Map<String, List<String>> _firstLast = {};

  static const Map<String, _DualLoopMeta> _dualLoopConfig = {
    '358': _DualLoopMeta(
      interchangeCodes: ['77009'],
      wing1Label: 'Pasir Ris Dr 10',
      wing2Label: 'Pasir Ris Dr 4',
      swapDisplayOrder: true,
    ),
    '359': _DualLoopMeta(
      interchangeCodes: ['77009'],
      wing1Label: 'Pasir Ris St 71',
      wing2Label: 'Pasir Ris St 21',
      swapDisplayOrder: true,
    ),
    '291': _DualLoopMeta(
      interchangeCodes: ['75009'],
      wing1Label: 'Tampines St 81',
      wing2Label: 'Tampines St 33',
      swapDisplayOrder: true,
    ),
    '293': _DualLoopMeta(
      interchangeCodes: ['75009'],
      wing1Label: 'Tampines St 71',
      wing2Label: 'Tampines St 42',
      swapDisplayOrder: true,
    ),
    '811': _DualLoopMeta(
      interchangeCodes: ['59009', '59072', '59159'],
      splitIndex: 24,
      wing1Label: 'Yishun Ave 6',
      wing2Label: 'Yishun Ave 5',
    ),
    '812': _DualLoopMeta(
      interchangeCodes: ['59009'],
      wing1Label: 'Yishun Ave 4',
      wing2Label: 'Yishun Ave 2',
    ),
    '911': _DualLoopMeta(
      interchangeCodes: ['46009', '46008'],
      wing1Label: 'Woodlands Ave 1',
      wing2Label: 'Woodlands Ctr Rd',
    ),
    '912': _DualLoopMeta(
      interchangeCodes: ['46009', '46008'],
      wing1Label: 'Woodlands Ave 7',
      wing2Label: 'Woodlands Ctr Rd',
    ),
    '913': _DualLoopMeta(
      interchangeCodes: ['46009', '46008'],
      wing1Label: 'Woodlands Ave 6',
      wing2Label: 'Woodlands Ctr Rd',
    ),
  };

  static int get stopCount => allStops.length;
  static int get routeCount => _routes.length;

  static Future<void> init() async {
    if (_initialized && allStops.isNotEmpty) return;
    try {
      final rawJson =
          await rootBundle.loadString('assets/sg_transit_snapshot.json');
      final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
      versionHash = decoded['versionHash'] as String? ?? 'v2-bundled';

      final stopsList = decoded['stops'] as List<dynamic>? ?? [];
      allStops = stopsList
          .map((e) => BusStop.fromJson(e as Map<String, dynamic>))
          .toList();
      _stopByCode = {for (final s in allStops) s.code: s};

      final routesMap = decoded['routes'] as Map<String, dynamic>? ?? {};
      _routes = routesMap.map(
        (key, value) => MapEntry(key, value as Map<String, dynamic>),
      );

      final firstLastMap = decoded['firstLast'] as Map<String, dynamic>? ?? {};
      _firstLast = firstLastMap.map(
        (key, value) => MapEntry(
          key,
          (value as List<dynamic>).map((e) => e.toString()).toList(),
        ),
      );

      _initialized = true;
    } catch (_) {
      _initialized = true;
    }
  }

  static BusStop? getStopByCode(String? code) {
    if (code == null || code.isEmpty) return null;
    return _stopByCode[code.trim()];
  }

  static List<BusStop> searchStops(String query, {int limit = 50}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return allStops.take(limit).toList();

    final results = <BusStop>[];
    if (RegExp(r'^\d{5}$').hasMatch(q)) {
      final exact = _stopByCode[q];
      if (exact != null) results.add(exact);
    }

    for (final s in allStops) {
      if (results.length >= limit) break;
      if (results.any((r) => r.code == s.code)) continue;
      if (s.code.toLowerCase().contains(q) ||
          s.name.toLowerCase().contains(q) ||
          s.road.toLowerCase().contains(q) ||
          s.services.any((svc) => svc.toLowerCase() == q)) {
        results.add(s);
      }
    }
    return results;
  }

  static List<BusStop> getNearestStops(
    double lat,
    double lng, {
    int limit = 15,
  }) {
    final pairs = [
      for (final stop in allStops)
        (
          stop: stop,
          dist: _haversineMeters(lat, lng, stop.lat, stop.lng).round(),
        ),
    ]..sort((a, b) => a.dist.compareTo(b.dist));

    return pairs
        .take(limit)
        .map((p) => p.stop.copyWith(distanceMeters: p.dist))
        .toList();
  }

  static double _haversineMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180.0;
    final dLon = (lon2 - lon1) * pi / 180.0;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180.0) *
            cos(lat2 * pi / 180.0) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  static String _getMidpointRoadName(List<BusStop> stops) {
    if (stops.isEmpty) return 'Terminal';
    final mid = stops[stops.length ~/ 2];
    return mid.road.isNotEmpty ? mid.road : mid.name;
  }

  static int _findDualLoopSplitIndex(List<String> dir1Codes, String serviceNo) {
    final config = _dualLoopConfig[serviceNo];
    if (config?.splitIndex != null &&
        config!.splitIndex! < dir1Codes.length - 2) {
      return config.splitIndex!;
    }
    if (dir1Codes.length < 14) return -1;
    final firstCode = dir1Codes.first;
    final lastCode = dir1Codes.last;
    if (firstCode != lastCode) return -1;

    final firstStop = getStopByCode(firstCode);
    for (int i = 6; i <= dir1Codes.length - 6; i++) {
      final code = dir1Codes[i];
      if (code == firstCode) return i;
      if (firstStop != null) {
        final s = getStopByCode(code);
        if (s != null && s.name == firstStop.name) return i;
      }
    }
    return -1;
  }

  static bool isDualLoopAtStop(String serviceNo, String stopCode) {
    final config = _dualLoopConfig[serviceNo];
    if (config != null && config.interchangeCodes.contains(stopCode)) {
      return true;
    }
    final bundled = _routes[serviceNo];
    if (bundled != null) {
      final routesList = bundled['routes'] as List<dynamic>? ?? [];
      if (routesList.length == 1) {
        final dir1Codes =
            (routesList[0] as List<dynamic>).map((e) => e.toString()).toList();
        final splitIdx = _findDualLoopSplitIndex(dir1Codes, serviceNo);
        if (splitIdx != -1) {
          if (stopCode == dir1Codes[0] || stopCode == dir1Codes[splitIdx]) {
            return true;
          }
        }
        // Check if this service visits stopCode twice as a boarding stop
        final boardingCodes = dir1Codes.length > 1 &&
                dir1Codes.first == dir1Codes.last
            ? dir1Codes.sublist(0, dir1Codes.length - 1)
            : dir1Codes;
        final visitCount =
            boardingCodes.where((code) => code == stopCode).length;
        if (visitCount >= 2) {
          return true;
        }
      } else if (routesList.length > 1) {
        final dir1Codes =
            (routesList[0] as List<dynamic>).map((e) => e.toString()).toList();
        final dir2Codes =
            (routesList[1] as List<dynamic>).map((e) => e.toString()).toList();
        final dir1Boarding = dir1Codes.length > 1
            ? dir1Codes.sublist(0, dir1Codes.length - 1)
            : dir1Codes;
        final dir2Boarding = dir2Codes.length > 1
            ? dir2Codes.sublist(0, dir2Codes.length - 1)
            : dir2Codes;
        if (dir1Boarding.contains(stopCode) &&
            dir2Boarding.contains(stopCode)) {
          return true;
        }
      }
    }
    return false;
  }

  static String _formatRawBusTime(String? raw) {
    if (raw == null || raw == '-' || !RegExp(r'^\d{4}$').hasMatch(raw)) {
      return '—';
    }
    if (raw == '2400') return '00:00';
    return '${raw.substring(0, 2)}:${raw.substring(2, 4)}';
  }

  static BusSchedule getStopServiceSchedule(
    String serviceNo, {
    String? stopCode,
    int? loopWing,
  }) {
    final svcNo = serviceNo.trim();
    final isFeeder =
        RegExp(r'^(2\d\d|3\d\d|80\d|81\d|90\d|91\d|92\d)$', caseSensitive: false)
            .hasMatch(svcNo);
    final isPeakOrShortTrip =
        RegExp(r'^(65\d|66\d|67\d)$', caseSensitive: false).hasMatch(svcNo) ||
            RegExp(r'^\d+[ABCeTWXabcewx]$').hasMatch(svcNo);

    final morningPeak = isPeakOrShortTrip
        ? '8 - 15 mins'
        : isFeeder
            ? '5 - 8 mins'
            : '6 - 9 mins';
    final eveningPeak = isPeakOrShortTrip
        ? '8 - 15 mins'
        : isFeeder
            ? '5 - 8 mins'
            : '7 - 10 mins';
    final offPeak = isPeakOrShortTrip
        ? 'Peak Hours Only'
        : isFeeder
            ? '8 - 12 mins'
            : '9 - 13 mins';

    final bundled = _routes[svcNo];
    String? originCode;
    if (bundled != null) {
      final routesList = bundled['routes'] as List<dynamic>?;
      if (routesList != null && routesList.isNotEmpty) {
        final firstRoute = routesList[0] as List<dynamic>;
        if (firstRoute.isNotEmpty) originCode = firstRoute[0].toString();
      }
    }

    final candidates = <String>[
      if (stopCode != null && stopCode.trim().isNotEmpty) stopCode.trim(),
      if (originCode != null && originCode.isNotEmpty) originCode,
    ];

    for (final targetCode in candidates) {
      final entries = _firstLast[targetCode];
      if (entries == null || entries.isEmpty) continue;

      final matches = entries.where((line) {
        final firstSpace = line.indexOf(' ');
        final entrySvc = firstSpace != -1 ? line.substring(0, firstSpace) : line;
        return entrySvc == svcNo;
      }).toList();

      if (matches.isNotEmpty) {
        String chosenLine = matches[0];
        if (matches.length > 1 && loopWing != null) {
          final config = _dualLoopConfig[svcNo];
          if (config != null && config.interchangeCodes.contains(targetCode)) {
            if (config.swapDisplayOrder) {
              chosenLine = loopWing == 1 ? matches[1] : matches[0];
            } else {
              chosenLine = loopWing == 2 ? matches[1] : matches[0];
            }
          }
        }

        final parts = chosenLine.trim().split(RegExp(r'\s+'));
        if (parts.length >= 7) {
          final wd1 = parts[1];
          final wd2 = parts[2];
          final sat1 = parts[3] == '=' ? wd1 : parts[3];
          final sat2 = parts[4] == '=' ? wd2 : parts[4];
          final sun1 = parts[5] == '=' ? wd1 : parts[5];
          final sun2 = parts[6] == '=' ? wd2 : parts[6];

          return BusSchedule(
            weekday: BusScheduleWindow(
              first: _formatRawBusTime(wd1),
              last: _formatRawBusTime(wd2),
            ),
            saturday: BusScheduleWindow(
              first: _formatRawBusTime(sat1),
              last: _formatRawBusTime(sat2),
            ),
            sunday: BusScheduleWindow(
              first: _formatRawBusTime(sun1),
              last: _formatRawBusTime(sun2),
            ),
            morningPeak: morningPeak,
            eveningPeak: eveningPeak,
            offPeak: offPeak,
          );
        }
      }
    }

    if (isPeakOrShortTrip) {
      return BusSchedule(
        weekday: const BusScheduleWindow(first: '06:30', last: '19:30'),
        saturday: const BusScheduleWindow(first: '—', last: '—'),
        sunday: const BusScheduleWindow(first: '—', last: '—'),
        morningPeak: morningPeak,
        eveningPeak: eveningPeak,
        offPeak: offPeak,
      );
    }

    return BusSchedule(
      weekday: BusScheduleWindow(
        first: isFeeder ? '05:15' : '05:30',
        last: isFeeder ? '00:35' : '23:45',
      ),
      saturday: BusScheduleWindow(
        first: isFeeder ? '05:15' : '05:30',
        last: isFeeder ? '00:35' : '23:45',
      ),
      sunday: BusScheduleWindow(
        first: isFeeder ? '05:30' : '05:45',
        last: isFeeder ? '00:35' : '23:30',
      ),
      morningPeak: morningPeak,
      eveningPeak: eveningPeak,
      offPeak: offPeak,
    );
  }

  static BusRouteInfo getBusRouteAndSchedule(
    String serviceNo, {
    String? stopCode,
    int? loopWing,
  }) {
    final schedule = getStopServiceSchedule(
      serviceNo,
      stopCode: stopCode,
      loopWing: loopWing,
    );
    final bundled = _routes[serviceNo];

    if (bundled != null) {
      final routesList = bundled['routes'] as List<dynamic>? ?? [];
      if (routesList.isNotEmpty) {
        final dir1Codes =
            (routesList[0] as List<dynamic>).map((e) => e.toString()).toList();
        final dir2Codes = routesList.length > 1
            ? (routesList[1] as List<dynamic>).map((e) => e.toString()).toList()
            : null;

        if (dir2Codes == null || dir2Codes.isEmpty) {
          final splitIdx = _findDualLoopSplitIndex(dir1Codes, serviceNo);
          if (splitIdx != -1) {
            final rawWing1Stops = dir1Codes
                .sublist(0, splitIdx + 1)
                .map(getStopByCode)
                .whereType<BusStop>()
                .toList();
            final rawWing2Stops = dir1Codes
                .sublist(splitIdx)
                .map(getStopByCode)
                .whereType<BusStop>()
                .toList();

            final config = _dualLoopConfig[serviceNo];
            final origin = rawWing1Stops.isNotEmpty
                ? rawWing1Stops.first.name
                : 'Interchange';
            final w1Label =
                config?.wing1Label ?? _getMidpointRoadName(rawWing1Stops);
            final w2Label =
                config?.wing2Label ?? _getMidpointRoadName(rawWing2Stops);

            if (config?.swapDisplayOrder == true) {
              return BusRouteInfo(
                serviceNo: serviceNo,
                origin: origin,
                destination: w2Label,
                isLoop: true,
                isDualLoop: true,
                direction1Name: w2Label,
                direction2Name: w1Label,
                schedule: schedule,
                direction1Stops: rawWing2Stops,
                direction2Stops: rawWing1Stops,
              );
            }

            return BusRouteInfo(
              serviceNo: serviceNo,
              origin: origin,
              destination: w1Label,
              isLoop: true,
              isDualLoop: true,
              direction1Name: w1Label,
              direction2Name: w2Label,
              schedule: schedule,
              direction1Stops: rawWing1Stops,
              direction2Stops: rawWing2Stops,
            );
          }
        }

        final dir1Stops =
            dir1Codes.map(getStopByCode).whereType<BusStop>().toList();
        final dir2Stops = dir2Codes != null && dir2Codes.isNotEmpty
            ? dir2Codes.map(getStopByCode).whereType<BusStop>().toList()
            : null;

        final origin =
            dir1Stops.isNotEmpty ? dir1Stops.first.name : 'Terminal';
        final rawDest =
            dir1Stops.isNotEmpty ? dir1Stops.last.name : 'Terminal';
        final isSingleLoop = dir2Stops == null &&
            dir1Stops.length > 2 &&
            (dir1Stops.first.code == dir1Stops.last.code || origin == rawDest);

        if (isSingleLoop) {
          final midpointRoad = _getMidpointRoadName(dir1Stops);
          return BusRouteInfo(
            serviceNo: serviceNo,
            origin: origin,
            destination: midpointRoad,
            isLoop: true,
            isDualLoop: false,
            direction1Name: midpointRoad,
            schedule: schedule,
            direction1Stops: dir1Stops,
          );
        }

        return BusRouteInfo(
          serviceNo: serviceNo,
          origin: origin,
          destination: rawDest,
          isLoop: false,
          isDualLoop: false,
          direction1Name: rawDest,
          direction2Name: dir2Stops != null && dir2Stops.isNotEmpty
              ? dir2Stops.last.name
              : null,
          schedule: schedule,
          direction1Stops: dir1Stops,
          direction2Stops: dir2Stops,
        );
      }
    }

    final matching =
        allStops.where((s) => s.services.contains(serviceNo)).toList();
    final fallbackStops =
        matching.isNotEmpty ? matching : allStops.take(10).toList();
    final origin =
        fallbackStops.isNotEmpty ? fallbackStops.first.name : 'Terminal';
    final dest =
        fallbackStops.isNotEmpty ? fallbackStops.last.name : 'Terminal';

    return BusRouteInfo(
      serviceNo: serviceNo,
      origin: origin,
      destination: dest,
      direction1Name: dest,
      direction2Name: origin,
      schedule: schedule,
      direction1Stops: fallbackStops,
      direction2Stops: fallbackStops.reversed.toList(),
    );
  }

  /// Returns the direction/road label ONLY when the service visits the stop twice
  /// (e.g. Bus 358 East & West wings at Pasir Ris Int). Returns empty string for
  /// services that only visit the bus stop once.
  static String resolveDirectionLabel(
    BusArrivalService service,
    String? currentStopCode,
  ) {
    if (service.loopDirectionLabel != null &&
        service.loopDirectionLabel!.isNotEmpty) {
      return service.loopDirectionLabel!;
    }

    if (currentStopCode != null &&
        isDualLoopAtStop(service.serviceNo, currentStopCode)) {
      final route = getBusRouteAndSchedule(service.serviceNo);
      if (service.loopWing == 2) {
        return route.direction2Name ?? route.origin;
      }
      return route.direction1Name;
    }

    return '';
  }

  static int? _parseTimeToMinutes(String? timeStr) {
    if (timeStr == null || !timeStr.contains(':')) return null;
    final parts = timeStr.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  static bool _isWithinWindow(int currentMinutes, int? firstMin, int? lastMin) {
    if (firstMin == null || lastMin == null) return false;
    if (lastMin < firstMin) {
      return currentMinutes >= firstMin || currentMinutes <= lastMin;
    }
    return currentMinutes >= firstMin && currentMinutes <= lastMin;
  }

  static bool isServiceInOperation(
    BusArrivalService service, {
    String? stopCode,
  }) {
    // Convert current UTC time to Singapore Time (UTC+8)
    final sgtNow = DateTime.now().toUtc().add(const Duration(hours: 8));
    final currentMinutes = sgtNow.hour * 60 + sgtNow.minute;
    final weekday = sgtNow.weekday; // 1 = Mon ... 6 = Sat, 7 = Sun

    final schedule = getStopServiceSchedule(
      service.serviceNo,
      stopCode: stopCode,
      loopWing: service.loopWing,
    );

    final todayWindow = weekday == DateTime.sunday
        ? schedule.sunday
        : weekday == DateTime.saturday
            ? schedule.saturday
            : schedule.weekday;

    final todayFirst = _parseTimeToMinutes(todayWindow.first);
    final todayLast = _parseTimeToMinutes(todayWindow.last);

    if (_isWithinWindow(currentMinutes, todayFirst, todayLast)) {
      return true;
    }

    // Check post-midnight tail (00:00 - 03:59) from yesterday's schedule
    if (currentMinutes < 4 * 60) {
      final yesterdayWindow = weekday == DateTime.monday
          ? schedule.sunday
          : weekday == DateTime.sunday
              ? schedule.saturday
              : schedule.weekday;
      final yFirst = _parseTimeToMinutes(yesterdayWindow.first);
      final yLast = _parseTimeToMinutes(yesterdayWindow.last);
      if (yFirst != null &&
          yLast != null &&
          yLast < yFirst &&
          currentMinutes <= yLast) {
        return true;
      }
    }

    return false;
  }

  static String getNoArrivalAdvisement(
    BusArrivalService service, {
    String? stopCode,
  }) {
    return isServiceInOperation(service, stopCode: stopCode)
        ? 'No Est. Available'
        : 'Not In Operation';
  }

  static List<BusArrivalService> expandServicesForStop(
    List<BusArrivalService> rawServices,
    String stopCode,
  ) {
    final expanded = <BusArrivalService>[];
    for (final svc in rawServices) {
      if (isDualLoopAtStop(svc.serviceNo, stopCode)) {
        final routeInfo = getBusRouteAndSchedule(svc.serviceNo);
        expanded.add(
          svc.copyWith(
            loopWing: 1,
            loopDirectionLabel: routeInfo.direction1Name,
            routeKey: '${svc.serviceNo}-wing-1',
          ),
        );
        expanded.add(
          svc.copyWith(
            loopWing: 2,
            loopDirectionLabel: routeInfo.direction2Name ?? routeInfo.origin,
            routeKey: '${svc.serviceNo}-wing-2',
          ),
        );
      } else {
        expanded.add(svc.copyWith(routeKey: svc.serviceNo));
      }
    }
    return expanded;
  }

  static List<BusArrivalService> buildOfflineServices(BusStop stop) {
    final base = stop.services
        .map((svcNo) => BusArrivalService(serviceNo: svcNo, operator: ''))
        .toList();
    return expandServicesForStop(base, stop.code);
  }
}

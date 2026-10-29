import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bus_stop.dart';
import 'lta_api_service.dart';
import 'transit_db_service.dart';

void showAppToast(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      duration: const Duration(milliseconds: 2200),
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      content: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
            size: 16,
            color: isError ? const Color(0xFFF43F5E) : const Color(0xFF10B981),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class UserSettings {
  final String datamallKey;
  final int autoRefreshSeconds;
  final ThemeMode themeMode;
  final double textScale;

  const UserSettings({
    this.datamallKey = '',
    this.autoRefreshSeconds = 30,
    this.themeMode = ThemeMode.system,
    this.textScale = 1.0,
  });

  UserSettings copyWith({
    String? datamallKey,
    int? autoRefreshSeconds,
    ThemeMode? themeMode,
    double? textScale,
  }) {
    return UserSettings(
      datamallKey: datamallKey ?? this.datamallKey,
      autoRefreshSeconds: autoRefreshSeconds ?? this.autoRefreshSeconds,
      themeMode: themeMode ?? this.themeMode,
      textScale: textScale ?? this.textScale,
    );
  }

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    final themeStr = json['theme'] as String? ?? 'system';
    ThemeMode mode = ThemeMode.system;
    if (themeStr == 'light') mode = ThemeMode.light;
    if (themeStr == 'dark') mode = ThemeMode.dark;

    final savedKey = (json['datamallKey'] as String? ?? '').trim();
    final rawScale = (json['textScale'] as num?)?.toDouble() ?? 1.0;
    final clampedScale = rawScale.clamp(0.9, 1.5);

    return UserSettings(
      datamallKey:
          savedKey.isNotEmpty ? savedKey : LtaApiService.defaultAccountKey,
      autoRefreshSeconds: (json['autoRefreshSeconds'] as num?)?.toInt() ?? 30,
      themeMode: mode,
      textScale: clampedScale,
    );
  }

  Map<String, dynamic> toJson() {
    String themeStr = 'system';
    if (themeMode == ThemeMode.light) themeStr = 'light';
    if (themeMode == ThemeMode.dark) themeStr = 'dark';
    return {
      'datamallKey': datamallKey,
      'autoRefreshSeconds': autoRefreshSeconds,
      'theme': themeStr,
      'textScale': textScale,
    };
  }
}

class FavoritesService {
  static const String _favoritesKey = 'quickbus_favorites_v2';
  static const String _recentStopsKey = 'quickbus_recent_stops';
  static const String _starredServicesKey = 'quickbus_starred_services';
  static const String _settingsKey = 'quickbus_settings';
  static const String _locationHistoryKey = 'quickbus_location_history';
  static const int _maxRecentStops = 30;
  static const int _maxLocationHistory = 100;

  static Set<String>? _starredCodesCache;

  static final List<FavoriteStop> _initialFavorites = [
    FavoriteStop(
      code: '03223',
      customName: 'City Hall Hub',
      pinnedAt: DateTime.now().millisecondsSinceEpoch - 100000,
      tag: 'Work',
    ),
    FavoriteStop(
      code: '09048',
      customName: 'Orchard Lucky Plaza',
      pinnedAt: DateTime.now().millisecondsSinceEpoch - 50000,
      tag: 'Shopping',
    ),
    FavoriteStop(
      code: '75009',
      customName: 'Tampines Interchange',
      pinnedAt: DateTime.now().millisecondsSinceEpoch,
      tag: 'Transit',
    ),
  ];

  static Future<List<FavoriteStop>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_favoritesKey);
    if (raw == null || raw.isEmpty) {
      await saveFavorites(_initialFavorites);
      return _initialFavorites;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final parsed = list
          .map((e) => FavoriteStop.fromJson(e as Map<String, dynamic>))
          .toList();
      _starredCodesCache = {for (final f in parsed) f.code};
      return parsed;
    } catch (_) {
      _starredCodesCache = {for (final f in _initialFavorites) f.code};
      return _initialFavorites;
    }
  }

  static Future<void> saveFavorites(List<FavoriteStop> favorites) async {
    _starredCodesCache = {for (final f in favorites) f.code};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _favoritesKey,
      jsonEncode(favorites.map((f) => f.toJson()).toList()),
    );
  }

  static bool? isStarredSync(String code) => _starredCodesCache?.contains(code);

  static Future<bool> isStarred(String code) async {
    if (_starredCodesCache != null) {
      return _starredCodesCache!.contains(code);
    }
    final list = await getFavorites();
    return list.any((f) => f.code == code);
  }

  static Future<bool> toggleStarred(
    String code, {
    String? customName,
    String? tag,
  }) async {
    final current = await getFavorites();
    final exists = current.any((f) => f.code == code);
    List<FavoriteStop> updated;
    if (exists) {
      updated = current.where((f) => f.code != code).toList();
    } else {
      updated = [
        FavoriteStop(
          code: code,
          customName: customName ?? '',
          pinnedAt: DateTime.now().millisecondsSinceEpoch,
          tag: tag ?? 'Commute',
        ),
        ...current,
      ];
    }
    await saveFavorites(updated);
    return !exists;
  }

  static Future<void> removeFavorite(String code) async {
    final current = await getFavorites();
    final updated = current.where((f) => f.code != code).toList();
    await saveFavorites(updated);
  }

  static Future<void> updateFavorite(
    String code, {
    required String customName,
    required String tag,
  }) async {
    final current = await getFavorites();
    final updated = current.map((f) {
      if (f.code != code) return f;
      return FavoriteStop(
        code: f.code,
        customName: customName.trim(),
        pinnedAt: f.pinnedAt,
        tag: tag.trim(),
      );
    }).toList();
    await saveFavorites(updated);
  }

  // Recent stop records (sorted by open count descending, then recency)
  static Future<List<RecentStopRecord>> getRecentStopRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recentStopsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final records = list
          .map((e) => RecentStopRecord.fromJson(e as Map<String, dynamic>))
          .toList();
      records.sort((a, b) {
        final cmp = b.count.compareTo(a.count);
        return cmp != 0 ? cmp : b.lastOpenedAt.compareTo(a.lastOpenedAt);
      });
      return records;
    } catch (_) {
      return [];
    }
  }

  static Future<void> recordStopOpen(String code) async {
    final stopCode = code.trim();
    if (stopCode.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final current = await getRecentStopRecords();
    final idx = current.indexWhere((r) => r.code == stopCode);
    final now = DateTime.now().millisecondsSinceEpoch;

    if (idx >= 0) {
      final existing = current[idx];
      current[idx] = RecentStopRecord(
        code: stopCode,
        count: existing.count + 1,
        lastOpenedAt: now,
      );
    } else {
      current.add(
        RecentStopRecord(
          code: stopCode,
          count: 1,
          lastOpenedAt: now,
        ),
      );
    }
    current.sort((a, b) {
      final cmp = b.count.compareTo(a.count);
      return cmp != 0 ? cmp : b.lastOpenedAt.compareTo(a.lastOpenedAt);
    });
    final capped = current.take(_maxRecentStops).toList();
    await prefs.setString(
      _recentStopsKey,
      jsonEncode(capped.map((r) => r.toJson()).toList()),
    );
  }

  static Future<void> removeRecentStopRecord(String code) async {
    final stopCode = code.trim();
    final prefs = await SharedPreferences.getInstance();
    final current = await getRecentStopRecords();
    final updated = current.where((r) => r.code != stopCode).toList();
    await prefs.setString(
      _recentStopsKey,
      jsonEncode(updated.map((r) => r.toJson()).toList()),
    );
  }

  // Per-stop starred bus services
  static Future<Map<String, List<String>>> getAllStarredServices() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_starredServicesKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final entry in map.entries)
          if (entry.value is List)
            entry.key: (entry.value as List<dynamic>)
                .map((e) => e.toString())
                .toList(),
      };
    } catch (_) {
      return {};
    }
  }

  static Future<List<String>> getStarredServicesForStop(String stopCode) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_starredServicesKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final list = map[stopCode.trim()] as List<dynamic>?;
      return list?.map((e) => e.toString()).toList() ?? [];
    } catch (_) {
      return [];
    }
  }

  static Future<List<String>> toggleStarredServiceForStop(
    String stopCode,
    String serviceKey,
  ) async {
    final code = stopCode.trim();
    final key = serviceKey.trim();
    if (code.isEmpty || key.isEmpty) return [];
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> map = {};
    final raw = prefs.getString(_starredServicesKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        map = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {}
    }
    final current =
        (map[code] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    if (current.contains(key)) {
      current.remove(key);
    } else {
      current.add(key);
    }
    map[code] = current;
    await prefs.setString(_starredServicesKey, jsonEncode(map));
    return current;
  }

  // App Settings
  static Future<UserSettings> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsKey);
    if (raw == null || raw.isEmpty) {
      return UserSettings(datamallKey: LtaApiService.defaultAccountKey);
    }
    try {
      return UserSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return UserSettings(datamallKey: LtaApiService.defaultAccountKey);
    }
  }

  static Future<UserSettings> saveSettings(UserSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
    return settings;
  }

  // Location History & Time/Day Predictive Algorithm
  static Future<List<LocationRecord>> getLocationHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_locationHistoryKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final records = list
          .map((e) => LocationRecord.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.timestampMs.compareTo(a.timestampMs));
      return records;
    } catch (_) {
      return [];
    }
  }

  static Future<void> recordLocation(
    double lat,
    double lng, {
    DateTime? timestamp,
  }) async {
    final nowMs = (timestamp ?? DateTime.now()).millisecondsSinceEpoch;
    final prefs = await SharedPreferences.getInstance();
    final current = await getLocationHistory();

    // Deduplicate: if newest record is within 150m and 15 minutes, update in place
    if (current.isNotEmpty) {
      final newest = current.first;
      final dist =
          TransitDbService.distanceMeters(lat, lng, newest.lat, newest.lng);
      final ageMs = (nowMs - newest.timestampMs).abs();
      if (dist <= 150 && ageMs <= 15 * 60 * 1000) {
        current[0] = LocationRecord(
          lat: lat,
          lng: lng,
          timestampMs: nowMs,
        );
        await prefs.setString(
          _locationHistoryKey,
          jsonEncode(current.map((r) => r.toJson()).toList()),
        );
        return;
      }
    }

    final updated = [
      LocationRecord(lat: lat, lng: lng, timestampMs: nowMs),
      ...current,
    ].take(_maxLocationHistory).toList();

    await prefs.setString(
      _locationHistoryKey,
      jsonEncode(updated.map((r) => r.toJson()).toList()),
    );
  }

  static bool _isWeekend(DateTime dt) =>
      dt.weekday == DateTime.saturday || dt.weekday == DateTime.sunday;

  static String _timeContextLabel(DateTime dt) {
    final dayLabel = _isWeekend(dt) ? 'Weekend' : 'Weekday';
    final h = dt.hour;
    final period = h < 12 ? 'Morning' : (h < 18 ? 'Afternoon' : 'Evening');
    return 'Predicted · $dayLabel $period';
  }

  /// Predicts the user's starting coordinates based on time-of-day and weekday/weekend
  /// location history clusters, falling back to the last recorded location or recent/starred stop.
  static Future<PredictedLocation?> getPredictedOrLastLocation({
    DateTime? now,
  }) async {
    final targetTime = now ?? DateTime.now();
    final history = await getLocationHistory();

    if (history.isNotEmpty) {
      final nowMs = targetTime.millisecondsSinceEpoch;
      final latest = history.first;

      // If a live GPS fix was recorded within the last 30 minutes, prefer it over routine predictions
      final latestAgeMs = nowMs - latest.timestampMs;
      if (latestAgeMs >= 0 && latestAgeMs <= 30 * 60 * 1000) {
        return PredictedLocation(
          lat: latest.lat,
          lng: latest.lng,
          label: 'Last Location',
          isPredicted: false,
        );
      }

      final targetWeekend = _isWeekend(targetTime);
      final targetMinutes = targetTime.hour * 60 + targetTime.minute;

      final clusters = <_LocationCluster>[];

      for (final rec in history) {
        final recTime = DateTime.fromMillisecondsSinceEpoch(rec.timestampMs);
        final recWeekend = _isWeekend(recTime);
        final recMinutes = recTime.hour * 60 + recTime.minute;

        // Circular minute distance on 24h clock [0..720]
        final diff = (targetMinutes - recMinutes).abs();
        final circularDiff = min(diff, 1440 - diff);

        // Only score records within ±3 hours (180 minutes) for time-of-day prediction
        if (circularDiff > 180) continue;

        final dayWeight = (recWeekend == targetWeekend) ? 2.5 : 0.4;
        final timeWeight = 1.0 - (circularDiff / 180.0) * 0.85;
        final ageDays = max(0.0, (nowMs - rec.timestampMs) / 86400000.0);
        final recencyWeight = 0.6 + 0.4 * exp(-ageDays / 30.0);
        final score = dayWeight * timeWeight * recencyWeight;

        // Group into spatial clusters within 300m
        _LocationCluster? matched;
        for (final c in clusters) {
          if (TransitDbService.distanceMeters(
                  rec.lat, rec.lng, c.centerLat, c.centerLng) <=
              300) {
            matched = c;
            break;
          }
        }
        if (matched != null) {
          matched.add(rec.lat, rec.lng, score);
        } else {
          clusters.add(_LocationCluster(rec.lat, rec.lng, score));
        }
      }

      if (clusters.isNotEmpty) {
        clusters.sort((a, b) => b.totalScore.compareTo(a.totalScore));
        final best = clusters.first;
        return PredictedLocation(
          lat: best.centerLat,
          lng: best.centerLng,
          label: history.length > 1
              ? _timeContextLabel(targetTime)
              : 'Last Location',
          isPredicted: history.length > 1,
        );
      }

      // Fallback 1: Most recent recorded GPS location
      return PredictedLocation(
        lat: latest.lat,
        lng: latest.lng,
        label: 'Last Location',
        isPredicted: false,
      );
    }

    // Fallback 2: Most recent stop opened or starred stop
    final recents = await getRecentStopRecords();
    for (final r in recents) {
      final stop = TransitDbService.getStopByCode(r.code);
      if (stop != null) {
        return PredictedLocation(
          lat: stop.lat,
          lng: stop.lng,
          label: 'Last Visited Area',
          isPredicted: false,
        );
      }
    }

    final favs = await getFavorites();
    for (final f in favs) {
      final stop = TransitDbService.getStopByCode(f.code);
      if (stop != null) {
        return PredictedLocation(
          lat: stop.lat,
          lng: stop.lng,
          label: 'Saved Stop Area',
          isPredicted: false,
        );
      }
    }

    return null;
  }
}

class _LocationCluster {
  double _weightedLatSum;
  double _weightedLngSum;
  double totalScore;

  _LocationCluster(double lat, double lng, double score)
      : _weightedLatSum = lat * score,
        _weightedLngSum = lng * score,
        totalScore = score;

  double get centerLat => _weightedLatSum / totalScore;
  double get centerLng => _weightedLngSum / totalScore;

  void add(double lat, double lng, double score) {
    _weightedLatSum += lat * score;
    _weightedLngSum += lng * score;
    totalScore += score;
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bus_stop.dart';

class UserSettings {
  final String datamallKey;
  final int autoRefreshSeconds;
  final ThemeMode themeMode;

  const UserSettings({
    this.datamallKey = '',
    this.autoRefreshSeconds = 30,
    this.themeMode = ThemeMode.system,
  });

  UserSettings copyWith({
    String? datamallKey,
    int? autoRefreshSeconds,
    ThemeMode? themeMode,
  }) {
    return UserSettings(
      datamallKey: datamallKey ?? this.datamallKey,
      autoRefreshSeconds: autoRefreshSeconds ?? this.autoRefreshSeconds,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    final themeStr = json['theme'] as String? ?? 'system';
    ThemeMode mode = ThemeMode.system;
    if (themeStr == 'light') mode = ThemeMode.light;
    if (themeStr == 'dark') mode = ThemeMode.dark;

    return UserSettings(
      datamallKey: json['datamallKey'] as String? ?? '',
      autoRefreshSeconds: (json['autoRefreshSeconds'] as num?)?.toInt() ?? 30,
      themeMode: mode,
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
    };
  }
}

class FavoritesService {
  static const String _favoritesKey = 'quickbus_favorites_v2';
  static const String _recentStopsKey = 'quickbus_recent_stops';
  static const String _starredServicesKey = 'quickbus_starred_services';
  static const String _settingsKey = 'quickbus_settings';

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
      return list
          .map((e) => FavoriteStop.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return _initialFavorites;
    }
  }

  static Future<void> saveFavorites(List<FavoriteStop> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _favoritesKey,
      jsonEncode(favorites.map((f) => f.toJson()).toList()),
    );
  }

  static Future<bool> isStarred(String code) async {
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
    await prefs.setString(
      _recentStopsKey,
      jsonEncode(current.map((r) => r.toJson()).toList()),
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
    if (raw == null || raw.isEmpty) return const UserSettings();
    try {
      return UserSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const UserSettings();
    }
  }

  static Future<UserSettings> saveSettings(UserSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
    return settings;
  }
}

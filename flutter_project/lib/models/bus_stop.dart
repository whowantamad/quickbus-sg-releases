class BusStop {
  final String code;
  final String name;
  final String road;
  final double lat;
  final double lng;
  final String? mrtNearby;
  final List<String> services;
  final int? distanceMeters;

  const BusStop({
    required this.code,
    required this.name,
    required this.road,
    required this.lat,
    required this.lng,
    this.mrtNearby,
    this.services = const [],
    this.distanceMeters,
  });

  BusStop copyWith({
    String? code,
    String? name,
    String? road,
    double? lat,
    double? lng,
    String? mrtNearby,
    List<String>? services,
    int? distanceMeters,
  }) {
    return BusStop(
      code: code ?? this.code,
      name: name ?? this.name,
      road: road ?? this.road,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      mrtNearby: mrtNearby ?? this.mrtNearby,
      services: services ?? this.services,
      distanceMeters: distanceMeters ?? this.distanceMeters,
    );
  }

  factory BusStop.fromJson(Map<String, dynamic> json) {
    return BusStop(
      code: json['code'] as String? ?? json['BusStopCode'] as String? ?? '',
      name: json['name'] as String? ?? json['Description'] as String? ?? '',
      road: json['road'] as String? ?? json['RoadName'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble() ??
          (json['Latitude'] as num?)?.toDouble() ??
          0.0,
      lng: (json['lng'] as num?)?.toDouble() ??
          (json['Longitude'] as num?)?.toDouble() ??
          0.0,
      mrtNearby: json['mrtNearby'] as String?,
      services: (json['services'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

class FavoriteStop {
  final String code;
  final String customName;
  final int pinnedAt;
  final String tag;

  const FavoriteStop({
    required this.code,
    this.customName = '',
    required this.pinnedAt,
    this.tag = 'Commute',
  });

  factory FavoriteStop.fromJson(Map<String, dynamic> json) {
    return FavoriteStop(
      code: json['code'] as String? ?? '',
      customName: json['customName'] as String? ?? '',
      pinnedAt: (json['pinnedAt'] as num?)?.toInt() ?? 0,
      tag: json['tag'] as String? ?? 'Commute',
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'customName': customName,
        'pinnedAt': pinnedAt,
        'tag': tag,
      };
}

class RecentStopRecord {
  final String code;
  final int count;
  final int lastOpenedAt;

  const RecentStopRecord({
    required this.code,
    required this.count,
    required this.lastOpenedAt,
  });

  factory RecentStopRecord.fromJson(Map<String, dynamic> json) {
    return RecentStopRecord(
      code: json['code'] as String? ?? '',
      count: (json['count'] as num?)?.toInt() ?? 1,
      lastOpenedAt: (json['lastOpenedAt'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'count': count,
        'lastOpenedAt': lastOpenedAt,
      };
}

class NextBusInfo {
  final String? estimatedArrival;
  final String? load; // SEA (Seats Available), SDA (Standing Available), LSD (Limited Standing)
  final String? feature; // WAB (Wheelchair Accessible)
  final String? type; // SD (Single Deck), DD (Double Deck), BD (Bendy)
  final String? originCode;
  final String? destinationCode;
  final String? latitude;
  final String? longitude;

  const NextBusInfo({
    this.estimatedArrival,
    this.load,
    this.feature,
    this.type,
    this.originCode,
    this.destinationCode,
    this.latitude,
    this.longitude,
  });

  NextBusInfo copyWith({
    String? estimatedArrival,
    String? load,
    String? feature,
    String? type,
    String? originCode,
    String? destinationCode,
    String? latitude,
    String? longitude,
  }) {
    return NextBusInfo(
      estimatedArrival: estimatedArrival ?? this.estimatedArrival,
      load: load ?? this.load,
      feature: feature ?? this.feature,
      type: type ?? this.type,
      originCode: originCode ?? this.originCode,
      destinationCode: destinationCode ?? this.destinationCode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  factory NextBusInfo.fromJson(Map<String, dynamic> json) {
    return NextBusInfo(
      estimatedArrival: json['EstimatedArrival'] as String?,
      load: json['Load'] as String?,
      feature: json['Feature'] as String?,
      type: json['Type'] as String?,
      originCode: json['OriginCode'] as String?,
      destinationCode: json['DestinationCode'] as String?,
      latitude: json['Latitude'] as String?,
      longitude: json['Longitude'] as String?,
    );
  }

  int? get minutesToArrival {
    if (estimatedArrival == null || estimatedArrival!.isEmpty) return null;
    try {
      final arrivalTime = DateTime.parse(estimatedArrival!).toUtc();
      final now = DateTime.now().toUtc();
      final diffMs = arrivalTime.difference(now).inMilliseconds;
      final diffMinutes = (diffMs / (60 * 1000)).floor();
      return diffMinutes <= 0 ? 0 : diffMinutes;
    } catch (_) {
      return null;
    }
  }

  bool get isDoubleDecker => type == 'DD';
  bool get isWheelchairAccessible => feature == 'WAB';
}

class BusArrivalService {
  final String serviceNo;
  final String operator;
  final NextBusInfo? nextBus;
  final NextBusInfo? nextBus2;
  final NextBusInfo? nextBus3;
  final int? loopWing; // 1 or 2 for dual-loop services
  final String? loopDirectionLabel;
  final String? routeKey;

  const BusArrivalService({
    required this.serviceNo,
    required this.operator,
    this.nextBus,
    this.nextBus2,
    this.nextBus3,
    this.loopWing,
    this.loopDirectionLabel,
    this.routeKey,
  });

  String get effectiveKey => routeKey ?? serviceNo;

  bool get hasArrival =>
      nextBus?.minutesToArrival != null ||
      nextBus2?.minutesToArrival != null ||
      nextBus3?.minutesToArrival != null;

  BusArrivalService copyWith({
    String? serviceNo,
    String? operator,
    NextBusInfo? nextBus,
    NextBusInfo? nextBus2,
    NextBusInfo? nextBus3,
    int? loopWing,
    String? loopDirectionLabel,
    String? routeKey,
  }) {
    return BusArrivalService(
      serviceNo: serviceNo ?? this.serviceNo,
      operator: operator ?? this.operator,
      nextBus: nextBus ?? this.nextBus,
      nextBus2: nextBus2 ?? this.nextBus2,
      nextBus3: nextBus3 ?? this.nextBus3,
      loopWing: loopWing ?? this.loopWing,
      loopDirectionLabel: loopDirectionLabel ?? this.loopDirectionLabel,
      routeKey: routeKey ?? this.routeKey,
    );
  }

  factory BusArrivalService.fromJson(Map<String, dynamic> json) {
    return BusArrivalService(
      serviceNo: json['ServiceNo'] as String? ?? '',
      operator: json['Operator'] as String? ?? '',
      nextBus: json['NextBus'] != null
          ? NextBusInfo.fromJson(json['NextBus'] as Map<String, dynamic>)
          : null,
      nextBus2: json['NextBus2'] != null
          ? NextBusInfo.fromJson(json['NextBus2'] as Map<String, dynamic>)
          : null,
      nextBus3: json['NextBus3'] != null
          ? NextBusInfo.fromJson(json['NextBus3'] as Map<String, dynamic>)
          : null,
    );
  }
}

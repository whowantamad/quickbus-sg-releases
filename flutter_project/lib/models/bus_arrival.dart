class NextBusInfo {
  final String? estimatedArrival;
  final String?
      load; // SEA (Seats Available), SDA (Standing Available), LSD (Limited Standing)
  final String? feature; // WAB (Wheelchair Accessible)
  final String? type; // SD (Single Deck), DD (Double Deck), BD (Bendy)
  final String? originCode;
  final String? destinationCode;
  final String? latitude;
  final String? longitude;
  final int? visitNumber;

  const NextBusInfo({
    this.estimatedArrival,
    this.load,
    this.feature,
    this.type,
    this.originCode,
    this.destinationCode,
    this.latitude,
    this.longitude,
    this.visitNumber,
  });

  factory NextBusInfo.fromJson(Map<String, dynamic> json) {
    return NextBusInfo(
      estimatedArrival: json['EstimatedArrival']?.toString().trim(),
      load: json['Load']?.toString().trim().toUpperCase(),
      feature: json['Feature']?.toString().trim().toUpperCase(),
      type: json['Type']?.toString().trim().toUpperCase(),
      originCode: json['OriginCode']?.toString().trim(),
      destinationCode: json['DestinationCode']?.toString().trim(),
      latitude: json['Latitude']?.toString().trim(),
      longitude: json['Longitude']?.toString().trim(),
      visitNumber: int.tryParse(json['VisitNumber']?.toString() ?? ''),
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

  bool get isDoubleDecker => type?.trim().toUpperCase() == 'DD';
  bool get isWheelchairAccessible => feature?.trim().toUpperCase() == 'WAB';
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
  final int? visitNumber; // 1 or 2

  const BusArrivalService({
    required this.serviceNo,
    required this.operator,
    this.nextBus,
    this.nextBus2,
    this.nextBus3,
    this.loopWing,
    this.loopDirectionLabel,
    this.routeKey,
    this.visitNumber,
  });

  String get effectiveKey => routeKey ?? serviceNo;

  bool get isFirstVisit => loopWing == 1 || visitNumber == 1;
  bool get isSecondVisit => loopWing == 2 || visitNumber == 2;

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
    bool clearArrivals = false,
    int? loopWing,
    String? loopDirectionLabel,
    String? routeKey,
    int? visitNumber,
  }) {
    return BusArrivalService(
      serviceNo: serviceNo ?? this.serviceNo,
      operator: operator ?? this.operator,
      nextBus: clearArrivals ? nextBus : (nextBus ?? this.nextBus),
      nextBus2: clearArrivals ? nextBus2 : (nextBus2 ?? this.nextBus2),
      nextBus3: clearArrivals ? nextBus3 : (nextBus3 ?? this.nextBus3),
      loopWing: loopWing ?? this.loopWing,
      loopDirectionLabel: loopDirectionLabel ?? this.loopDirectionLabel,
      routeKey: routeKey ?? this.routeKey,
      visitNumber: visitNumber ?? this.visitNumber,
    );
  }

  factory BusArrivalService.fromJson(Map<String, dynamic> json) {
    return BusArrivalService(
      serviceNo: json['ServiceNo']?.toString().trim() ?? '',
      operator: json['Operator']?.toString().trim() ?? '',
      nextBus: json['NextBus'] is Map<String, dynamic>
          ? NextBusInfo.fromJson(json['NextBus'] as Map<String, dynamic>)
          : null,
      nextBus2: json['NextBus2'] is Map<String, dynamic>
          ? NextBusInfo.fromJson(json['NextBus2'] as Map<String, dynamic>)
          : null,
      nextBus3: json['NextBus3'] is Map<String, dynamic>
          ? NextBusInfo.fromJson(json['NextBus3'] as Map<String, dynamic>)
          : null,
    );
  }
}

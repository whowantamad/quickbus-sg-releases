import 'package:flutter/material.dart';
import '../models/bus_arrival.dart';
import '../services/transit_db_service.dart';

class BusArrivalCard extends StatelessWidget {
  final BusArrivalService service;
  final String? currentStopCode;
  final bool isStarred;
  final bool isLoading;
  final VoidCallback? onToggleStar;
  final VoidCallback? onTap;

  const BusArrivalCard({
    super.key,
    required this.service,
    this.currentStopCode,
    this.isStarred = false,
    this.isLoading = false,
    this.onToggleStar,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final hasNoArrivalData = !service.hasArrival;
    final noArrivalAdvisement = hasNoArrivalData
        ? TransitDbService.getNoArrivalAdvisement(
            service,
            stopCode: currentStopCode,
          )
        : null;
    final directionLabel = TransitDbService.resolveDirectionLabel(
      service,
      currentStopCode,
    );
    final lastBusWarning = hasNoArrivalData
        ? null
        : TransitDbService.getLastBusWarning(
            service,
            stopCode: currentStopCode,
          );

    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF131B2E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              // Left Column: Bus Service Badge & Loop/Destination Stop Label below it
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          constraints:
                              const BoxConstraints(minWidth: 48, minHeight: 32),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color:
                                isDark ? Colors.white : const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          width: 56,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              service.serviceNo,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: isDark
                                    ? const Color(0xFF0F172A)
                                    : Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                        ),
                        if (service.isSecondVisit) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE11D48)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFE11D48)
                                      .withValues(alpha: 0.35),
                                  width: 0.8,
                                ),
                              ),
                              child: const Text(
                                '2nd Visit',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFE11D48),
                                ),
                              ),
                            ),
                          ),
                        ] else if (service.isFirstVisit) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white10
                                    : Colors.black.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '1st Visit',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (directionLabel.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 11,
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              directionLabel,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.8),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (lastBusWarning != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFF59E0B).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color:
                                const Color(0xFFF59E0B).withValues(alpha: 0.4),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.access_time_filled_rounded,
                              size: 10,
                              color: Color(0xFFF59E0B),
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                lastBusWarning,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFF59E0B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Right Column: Arrival Slots / Status + Star & Chevron
              if (isLoading && hasNoArrivalData)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSlotSkeleton(isDark),
                    const SizedBox(width: 6),
                    _buildSlotSkeleton(isDark),
                    const SizedBox(width: 6),
                    _buildSlotSkeleton(isDark),
                  ],
                )
              else if (hasNoArrivalData)
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B).withValues(alpha: 0.5)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    noArrivalAdvisement ?? 'No Est. Available',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildArrivalSlot(
                      context,
                      service.nextBus,
                      slotLabel: '1st Bus',
                      isFirst: true,
                    ),
                    const SizedBox(width: 6),
                    _buildArrivalSlot(
                      context,
                      service.nextBus2,
                      slotLabel: '2nd Bus',
                    ),
                    const SizedBox(width: 6),
                    _buildArrivalSlot(
                      context,
                      service.nextBus3,
                      slotLabel: '3rd Bus',
                    ),
                  ],
                ),

              const SizedBox(width: 6),
              if (onToggleStar != null)
                InkWell(
                  onTap: onToggleStar,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isStarred
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.14)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isStarred
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 18,
                      color: isStarred
                          ? const Color(0xFFF59E0B)
                          : theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.4),
                    ),
                  ),
                ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlotSkeleton(bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 48,
        height: 48,
        color: isDark
            ? const Color(0xFF1E293B).withValues(alpha: 0.5)
            : const Color(0xFFF1F5F9),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 20,
              height: 12,
              decoration: BoxDecoration(
                color: isDark ? Colors.white12 : Colors.black12,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Container(
              height: 4,
              width: double.infinity,
              color: isDark ? Colors.white10 : Colors.black12,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArrivalSlot(
    BuildContext context,
    NextBusInfo? bus, {
    required String slotLabel,
    bool isFirst = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final slotBg = isDark
        ? const Color(0xFF1E293B).withValues(alpha: 0.5)
        : const Color(0xFFF1F5F9);

    if (bus == null || bus.minutesToArrival == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 48,
          height: 48,
          color: slotBg,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Center(
                  child: Text(
                    '—',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              Container(
                height: 4,
                width: double.infinity,
                color: isDark ? Colors.white10 : Colors.black12,
              ),
            ],
          ),
        ),
      );
    }

    final mins = bus.minutesToArrival!;
    final isArriving = mins == 0;
    final displayText = isArriving ? 'Arr' : '$mins';

    Color loadColor = const Color(0xFF94A3B8);
    if (bus.load == 'SEA') {
      loadColor = const Color(0xFF10B981);
    } else if (bus.load == 'SDA') {
      loadColor = const Color(0xFFF59E0B);
    } else if (bus.load == 'LSD') {
      loadColor = const Color(0xFFF43F5E);
    }

    final textWidget = Text(
      displayText,
      style: TextStyle(
        fontSize: isFirst ? 15.5 : 13.5,
        fontWeight: FontWeight.w900,
        color: isDark ? Colors.white : const Color(0xFF0F172A),
        fontFeatures: const [FontFeature.tabularFigures()],
        height: 1.0,
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Material(
        color: slotBg,
        child: InkWell(
          onTap: () => _showNextBusModal(
            context,
            slotLabel: slotLabel,
            bus: bus,
            loadColor: loadColor,
          ),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3, right: 4),
                  child: SizedBox(
                    height: 11,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (bus.isDoubleDecker)
                          Padding(
                            padding: const EdgeInsets.only(right: 2),
                            child: CustomPaint(
                              size: const Size(10, 10),
                              painter: _DoubleDeckPainter(
                                color: isDark
                                    ? const Color(0xFF818CF8)
                                    : const Color(0xFF4F46E5),
                              ),
                            ),
                          ),
                        if (bus.isWheelchairAccessible)
                          Icon(
                            Icons.accessible_rounded,
                            size: 10,
                            color: isDark
                                ? const Color(0xFF38BDF8)
                                : const Color(0xFF0284C7),
                          ),
                      ],
                    ),
                  ),
                ),
                isArriving ? _SubtlePulse(child: textWidget) : textWidget,
                Container(
                  height: 4,
                  width: double.infinity,
                  color: loadColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showNextBusModal(
    BuildContext context, {
    required String slotLabel,
    required NextBusInfo bus,
    required Color loadColor,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mins = bus.minutesToArrival ?? 0;
    final pos = TransitDbService.locateBusOnRoute(
      service.serviceNo,
      bus,
      currentStopCode: currentStopCode,
      loopWing: service.loopWing,
    );

    String? clockStr;
    if (bus.estimatedArrival != null && bus.estimatedArrival!.isNotEmpty) {
      try {
        final sgt = DateTime.parse(bus.estimatedArrival!)
            .toUtc()
            .add(const Duration(hours: 8));
        final hh = sgt.hour.toString().padLeft(2, '0');
        final mm = sgt.minute.toString().padLeft(2, '0');
        clockStr = '$hh:$mm';
      } catch (_) {}
    }

    final distMeters = pos.distanceFromCurrentMeters;
    final distLabel = distMeters == null
        ? null
        : distMeters < 1000
            ? '~$distMeters' 'm away'
            : '~${(distMeters / 1000).toStringAsFixed(1)} km away';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151C2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Service badge + Slot title + ETA pill
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      service.serviceNo,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          slotLabel,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          mins <= 0
                              ? 'Arriving now${clockStr != null ? ' · $clockStr' : ''}'
                              : 'In $mins min${clockStr != null ? ' · Est. $clockStr' : ''}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Live Position Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A).withValues(alpha: 0.7)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE11D48).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.my_location_rounded,
                        size: 18,
                        color: Color(0xFFE11D48),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: !bus.hasLiveCoordinates
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'At Interchange / Terminal',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Scheduled departure — waiting to leave terminal',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        pos.nearestStop != null
                                            ? 'Near ${pos.nearestStop!.name}'
                                            : 'En Route (Live GPS)',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (distLabel != null) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 1.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE11D48)
                                              .withValues(alpha: 0.14),
                                          borderRadius:
                                              BorderRadius.circular(5),
                                        ),
                                        child: Text(
                                          distLabel,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFFE11D48),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  pos.nearestStop != null
                                      ? '${pos.nearestStop!.code} · ${pos.nearestStop!.road}${pos.stopsAway != null ? (pos.stopsAway == 0 ? ' · At this stop' : ' · ~${pos.stopsAway} ${pos.stopsAway == 1 ? 'stop' : 'stops'} away') : ''}'
                                      : (distLabel ?? 'Live telemetry active'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Attributes row: Crowd, Deck Type, WAB
              Row(
                children: [
                  Expanded(
                    child: _buildAttrTile(
                      isDark,
                      icon: Icons.people_alt_rounded,
                      iconColor: loadColor,
                      label: 'Crowd',
                      value: bus.loadLabel,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildAttrTile(
                      isDark,
                      icon: Icons.directions_bus_rounded,
                      iconColor: isDark
                          ? const Color(0xFF818CF8)
                          : const Color(0xFF4F46E5),
                      label: 'Bus Type',
                      value: bus.typeLabel,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildAttrTile(
                      isDark,
                      icon: Icons.accessible_rounded,
                      iconColor: bus.isWheelchairAccessible
                          ? (isDark
                              ? const Color(0xFF38BDF8)
                              : const Color(0xFF0284C7))
                          : Colors.grey,
                      label: 'Access',
                      value: bus.isWheelchairAccessible ? 'WAB Ready' : 'Standard',
                    ),
                  ),
                ],
              ),

              if (onTap != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      onTap?.call();
                    },
                    icon: const Icon(Icons.route_rounded, size: 16),
                    label: const Text('View Full Route & Schedule'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttrTile(
    bool isDark, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F172A).withValues(alpha: 0.5)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9.5,
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubtlePulse extends StatefulWidget {
  final Widget child;

  const _SubtlePulse({required this.child});

  @override
  State<_SubtlePulse> createState() => _SubtlePulseState();
}

class _SubtlePulseState extends State<_SubtlePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.42,
    upperBound: 1.0,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: widget.child,
    );
  }
}

/// Custom 2-Layer Deck Icon Painter (strictly 2 layers for Double Decker buses)
class _DoubleDeckPainter extends CustomPainter {
  final Color color;

  const _DoubleDeckPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Top deck diamond
    final topDeck = Path()
      ..moveTo(w * 0.5, h * 0.16)
      ..lineTo(w * 0.12, h * 0.38)
      ..lineTo(w * 0.5, h * 0.60)
      ..lineTo(w * 0.88, h * 0.38)
      ..close();

    // Bottom deck chevron (2nd layer)
    final bottomDeck = Path()
      ..moveTo(w * 0.12, h * 0.64)
      ..lineTo(w * 0.5, h * 0.86)
      ..lineTo(w * 0.88, h * 0.64);

    canvas.drawPath(topDeck, paint);
    canvas.drawPath(bottomDeck, paint);
  }

  @override
  bool shouldRepaint(covariant _DoubleDeckPainter oldDelegate) =>
      oldDelegate.color != color;
}

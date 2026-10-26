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
                          constraints: const BoxConstraints(minWidth: 48, minHeight: 32),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          width: 56,
                          child: Text(
                            service.serviceNo,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: isDark ? const Color(0xFF0F172A) : Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        if (service.isSecondVisit) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE11D48).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFFE11D48).withValues(alpha: 0.35),
                                width: 0.8,
                              ),
                            ),
                            child: const Text(
                              '2nd Visit',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFE11D48),
                              ),
                            ),
                          ),
                        ] else if (service.isFirstVisit) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '1st Visit',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurfaceVariant,
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
                    _buildArrivalSlot(context, service.nextBus, isFirst: true),
                    const SizedBox(width: 6),
                    _buildArrivalSlot(context, service.nextBus2),
                    const SizedBox(width: 6),
                    _buildArrivalSlot(context, service.nextBus3),
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
                      isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 18,
                      color: isStarred
                          ? const Color(0xFFF59E0B)
                          : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 48,
        height: 48,
        // Default neutral slot background (no color-coded tint) with color-coded bottom bar
        color: slotBg,
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
            Text(
              displayText,
              style: TextStyle(
                fontSize: isFirst ? 15.5 : 13.5,
                fontWeight: FontWeight.w900,
                color: isArriving
                    ? const Color(0xFFF43F5E)
                    : (isDark ? Colors.white : const Color(0xFF0F172A)),
                fontFeatures: const [FontFeature.tabularFigures()],
                height: 1.0,
              ),
            ),
            Container(
              height: 4,
              width: double.infinity,
              color: loadColor,
            ),
          ],
        ),
      ),
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

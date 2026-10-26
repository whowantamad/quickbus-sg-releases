import 'package:flutter/material.dart';
import '../models/bus_stop.dart';
import '../services/transit_db_service.dart';

class BusRouteSheet extends StatefulWidget {
  final String serviceNo;
  final String? currentStopCode;
  final int? initialDirection;
  final ValueChanged<BusStop> onSelectStop;

  const BusRouteSheet({
    super.key,
    required this.serviceNo,
    this.currentStopCode,
    this.initialDirection,
    required this.onSelectStop,
  });

  @override
  State<BusRouteSheet> createState() => _BusRouteSheetState();
}

class _BusRouteSheetState extends State<BusRouteSheet> {
  int? _activeDirection;

  @override
  void initState() {
    super.initState();
    final routeInfo = TransitDbService.getBusRouteAndSchedule(
      widget.serviceNo,
      stopCode: widget.currentStopCode,
      loopWing: widget.initialDirection,
    );
    _activeDirection = _resolveInitialDirection(routeInfo);
  }

  int _resolveInitialDirection(BusRouteInfo routeInfo) {
    if (widget.initialDirection != null) return widget.initialDirection!;
    if (widget.currentStopCode != null &&
        routeInfo.direction2Stops != null &&
        routeInfo.direction2Stops!.isNotEmpty) {
      final idx1 = routeInfo.direction1Stops
          .indexWhere((s) => s.code == widget.currentStopCode);
      final idx2 = routeInfo.direction2Stops!
          .indexWhere((s) => s.code == widget.currentStopCode);
      if ((idx2 != -1 && idx1 == -1) ||
          (idx1 == routeInfo.direction1Stops.length - 1 && idx2 == 0)) {
        return 2;
      }
    }
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final routeInfo = TransitDbService.getBusRouteAndSchedule(
      widget.serviceNo,
      stopCode: widget.currentStopCode,
      loopWing: widget.initialDirection,
    );
    final activeDir = _activeDirection ?? _resolveInitialDirection(routeInfo);
    final hasTwoDirections = routeInfo.direction2Stops != null &&
        routeInfo.direction2Stops!.isNotEmpty;
    final activeStops = activeDir == 1
        ? routeInfo.direction1Stops
        : (routeInfo.direction2Stops ?? routeInfo.direction1Stops);

    final activeOrigin = routeInfo.isDualLoop
        ? routeInfo.origin
        : activeDir == 2
            ? routeInfo.direction1Name
            : routeInfo.origin;
    final activeDestination = routeInfo.isDualLoop
        ? (activeDir == 2
            ? (routeInfo.direction2Name ?? routeInfo.destination)
            : routeInfo.direction1Name)
        : (activeDir == 2
            ? (routeInfo.direction2Name ?? routeInfo.origin)
            : routeInfo.direction1Name);

    final scheduleStopCode =
        widget.currentStopCode ?? (activeStops.isNotEmpty ? activeStops.first.code : null);
    final scheduleStop = TransitDbService.getStopByCode(scheduleStopCode);
    final schedule = TransitDbService.getStopServiceSchedule(
      widget.serviceNo,
      stopCode: scheduleStopCode,
      loopWing: activeDir,
    );

    return Container(
      height: MediaQuery.of(context).size.height * 0.86,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0C1220).withValues(alpha: 0.7)
                  : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    widget.serviceNo,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        routeInfo.isLoop
                            ? 'Loop Route & Schedule'
                            : 'Route & Schedule',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              activeOrigin,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              routeInfo.isLoop
                                  ? Icons.sync_rounded
                                  : Icons.arrow_forward_rounded,
                              size: 12,
                              color: routeInfo.isLoop
                                  ? const Color(0xFFE11D48)
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              activeDestination,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
          ),

          // Body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Direction Toggle (when 2 directions exist)
                if (hasTwoDirections) ...[
                  Row(
                    children: [
                      _buildDirectionChip(
                        isDark,
                        direction: 1,
                        label: 'To ${routeInfo.direction1Name}',
                        active: activeDir == 1,
                      ),
                      const SizedBox(width: 8),
                      _buildDirectionChip(
                        isDark,
                        direction: 2,
                        label: 'To ${routeInfo.direction2Name ?? routeInfo.origin}',
                        active: activeDir == 2,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // Operating Schedule Card (without redundant Frequency header span)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A).withValues(alpha: 0.6)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 15,
                            color: Color(0xFFE11D48),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Operating Hours${scheduleStop != null ? ' · ${scheduleStop.name} (${scheduleStop.code})' : ''}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildScheduleBox(
                            isDark,
                            'WEEKDAY',
                            '${schedule.weekday.first} - ${schedule.weekday.last}',
                          ),
                          const SizedBox(width: 6),
                          _buildScheduleBox(
                            isDark,
                            'SATURDAY',
                            '${schedule.saturday.first} - ${schedule.saturday.last}',
                          ),
                          const SizedBox(width: 6),
                          _buildScheduleBox(
                            isDark,
                            'SUN / PH',
                            '${schedule.sunday.first} - ${schedule.sunday.last}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Morning Peak: ${schedule.morningPeak}',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            'Off-Peak: ${schedule.offPeak}',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Route Stops Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ROUTE STOPS (${activeStops.length})',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Tap stop to view arrivals',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Sequential Route Stop Timeline
                ...activeStops.asMap().entries.map((entry) {
                  final stop = entry.value;
                  final isCurrent = stop.code == widget.currentStopCode;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? (isDark
                              ? const Color(0xFF1E293B).withValues(alpha: 0.7)
                              : const Color(0xFFF1F5F9))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCurrent
                            ? const Color(0xFFF43F5E).withValues(alpha: 0.6)
                            : Colors.transparent,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.onSelectStop(stop);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? const Color(0xFFE11D48)
                                    : (isDark
                                        ? const Color(0xFF131B2E)
                                        : Colors.white),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFE11D48),
                                  width: 2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Line 1: Bus stop name
                                  Text(
                                    stop.name,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: isCurrent
                                          ? const Color(0xFFE11D48)
                                          : null,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  // Line 2: bus stop code | road name
                                  Row(
                                    children: [
                                      Text(
                                        stop.code,
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                        ),
                                        child: Text(
                                          '|',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: theme
                                                .colorScheme.onSurfaceVariant
                                                .withValues(alpha: 0.4),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          stop.road,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionChip(
    bool isDark, {
    required int direction,
    required String label,
    required bool active,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeDirection = direction),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFFE11D48)
                : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active
                  ? const Color(0xFFE11D48)
                  : (isDark ? Colors.white10 : Colors.black12),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: active ? Colors.white : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleBox(bool isDark, String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131B2E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black12,
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import '../models/bus_stop.dart';
import '../models/bus_arrival.dart';
import '../services/lta_api_service.dart';
import '../services/favorites_service.dart';
import '../services/transit_db_service.dart';
import '../widgets/bus_arrival_card.dart';
import '../widgets/bus_route_sheet.dart';

class BusStopDetailScreen extends StatefulWidget {
  final BusStop busStop;

  const BusStopDetailScreen({super.key, required this.busStop});

  @override
  State<BusStopDetailScreen> createState() => _BusStopDetailScreenState();
}

class _BusStopDetailScreenState extends State<BusStopDetailScreen> {
  late BusStop _currentStop;
  List<BusArrivalService> _services = [];
  List<String> _starredServices = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isStarred = false;
  String _searchQuery = '';
  DateTime? _lastUpdatedAt;
  int _secondsUntilRefresh = 0;
  Timer? _tickerTimer;
  UserSettings _settings = const UserSettings();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _currentStop = widget.busStop;
    _initForStop(_currentStop);
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    super.dispose();
  }

  Future<void> _initForStop(BusStop stop) async {
    _tickerTimer?.cancel();
    setState(() {
      _currentStop = stop;
      // Offline-first: render all services for this stop immediately at 0ms
      _services = TransitDbService.buildOfflineServices(stop);
      _isLoading = true;
      _lastUpdatedAt = null;
    });

    await FavoritesService.recordStopOpen(stop.code);
    final settings = await FavoritesService.getSettings();
    final starred = await FavoritesService.isStarred(stop.code);
    final starredSvcs =
        await FavoritesService.getStarredServicesForStop(stop.code);

    if (mounted) {
      setState(() {
        _settings = settings;
        _isStarred = starred;
        _starredServices = starredSvcs;
        _secondsUntilRefresh = settings.autoRefreshSeconds;
      });
    }

    await _fetchArrivals(silent: false);
    _startTicker();
  }

  void _startTicker() {
    _tickerTimer?.cancel();
    if (_settings.autoRefreshSeconds <= 0) {
      if (mounted) setState(() => _secondsUntilRefresh = 0);
      return;
    }
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final now = DateTime.now();
      final elapsed = _lastUpdatedAt != null
          ? now.difference(_lastUpdatedAt!).inSeconds
          : 0;
      final interval = _settings.autoRefreshSeconds;

      if (interval > 0) {
        final remaining = (interval - elapsed).clamp(0, interval);
        setState(() {
          _secondsUntilRefresh = remaining;
        });
        if (remaining == 0 && !_isRefreshing && !_isLoading) {
          _fetchArrivals(silent: true);
        }
      }
    });
  }

  void _showRefreshToast({String? error}) {
    if (!mounted) return;
    showAppToast(
      context,
      error ?? 'Arrival data updated',
      isError: error != null,
    );
  }

  Future<void> _fetchArrivals({
    bool silent = false,
    bool showToast = false,
  }) async {
    if (!mounted) return;
    final requestedCode = _currentStop.code;
    final requestedServices = List<String>.from(_currentStop.services);
    setState(() {
      if (!silent) _isLoading = true;
      _isRefreshing = true;
    });

    final api = LtaApiService(accountKey: _settings.datamallKey);
    final liveList = await api.getBusArrivals(
      requestedCode,
      stopServices: requestedServices,
    );

    if (!mounted || _currentStop.code != requestedCode) return;

    final activeMap = <String, BusArrivalService>{
      for (final s in liveList) s.serviceNo: s,
    };

    final rawServices = <BusArrivalService>[];
    final seen = <String>{};

    for (final svcNo in requestedServices) {
      seen.add(svcNo);
      final liveSvc = activeMap[svcNo];
      if (liveSvc != null) {
        rawServices.add(liveSvc);
      } else {
        rawServices.add(BusArrivalService(serviceNo: svcNo, operator: ''));
      }
    }

    for (final liveSvc in liveList) {
      if (!seen.contains(liveSvc.serviceNo)) {
        rawServices.add(liveSvc);
      }
    }

    final expanded = TransitDbService.expandServicesForStop(
      rawServices,
      requestedCode,
    );

    if (mounted && _currentStop.code == requestedCode) {
      setState(() {
        _services = expanded;
        _isLoading = false;
        _isRefreshing = false;
        _lastUpdatedAt = DateTime.now();
        _secondsUntilRefresh = _settings.autoRefreshSeconds;
        _errorMessage = api.lastErrorMessage;
      });
      if (showToast) {
        _showRefreshToast(error: api.lastErrorMessage);
      }
    }
  }

  Future<void> _handleToggleStopStar() async {
    final nowStarred = await FavoritesService.toggleStarred(
      _currentStop.code,
      customName: _currentStop.name,
    );
    if (mounted) {
      setState(() => _isStarred = nowStarred);
    }
  }

  Future<void> _handleToggleServiceStar(String svcKey) async {
    final updated = await FavoritesService.toggleStarredServiceForStop(
      _currentStop.code,
      svcKey,
    );
    if (mounted) {
      setState(() => _starredServices = updated);
    }
  }

  void _openRouteSheet(BusArrivalService svc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BusRouteSheet(
        serviceNo: svc.serviceNo,
        currentStopCode: _currentStop.code,
        initialDirection: svc.loopWing,
        onSelectStop: (newStop) {
          _initForStop(newStop);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Dynamic sorting:
    // 1. Starred services pinned at the top
    // 2. Services with live arrival times right after favorites
    // 3. Services without arrival times at the bottom
    final filtered = _services.where((s) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.trim().toLowerCase();
      return s.serviceNo.toLowerCase().contains(q) ||
          (s.loopDirectionLabel != null &&
              s.loopDirectionLabel!.toLowerCase().contains(q));
    }).toList()
      ..sort((a, b) {
        final keyA = a.effectiveKey;
        final keyB = b.effectiveKey;
        final starA = _starredServices.contains(keyA);
        final starB = _starredServices.contains(keyB);
        if (starA && !starB) return -1;
        if (!starA && starB) return 1;
        if (starA && starB) {
          return _starredServices
              .indexOf(keyA)
              .compareTo(_starredServices.indexOf(keyB));
        }

        final arrA = a.hasArrival;
        final arrB = b.hasArrival;
        if (arrA && !arrB) return -1;
        if (!arrA && arrB) return 1;
        return 0;
      });

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        centerTitle: true,
        title: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    _currentStop.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white12 : Colors.black12,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    _currentStop.code,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              _currentStop.road,
              style: TextStyle(
                fontSize: 11,
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
              color: _isStarred ? const Color(0xFFF59E0B) : null,
            ),
            onPressed: _handleToggleStopStar,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter services search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Filter bus service (e.g. 147)...',
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                filled: true,
                fillColor: isDark ? const Color(0xFF131B2E) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                ),
              ),
            ),
          ),

          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE11D48).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 13, color: Color(0xFFE11D48)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFFE11D48),
                            fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Right-aligned small faded countdown text ("Updating in 30s")
          if (_settings.autoRefreshSeconds > 0 || _isRefreshing)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 20, 2),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _isRefreshing
                      ? 'Updating...'
                      : 'Updating in ${_secondsUntilRefresh}s',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),

          // Pull-Down to Refresh Bus Services List
          Expanded(
            child: RefreshIndicator(
              color: const Color(0xFFE11D48),
              onRefresh: () async {
                final start = DateTime.now();
                await _fetchArrivals(silent: true, showToast: true);
                final elapsed = DateTime.now().difference(start).inMilliseconds;
                if (elapsed < 500) {
                  await Future.delayed(Duration(milliseconds: 500 - elapsed));
                }
              },
              child: filtered.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 120),
                        Center(
                          child: Text(
                            '—',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(top: 2, bottom: 28),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final svc = filtered[index];
                        final svcKey = svc.effectiveKey;
                        return BusArrivalCard(
                          key: ValueKey(svcKey),
                          service: svc,
                          currentStopCode: _currentStop.code,
                          isStarred: _starredServices.contains(svcKey),
                          isLoading: _isLoading,
                          onToggleStar: () => _handleToggleServiceStar(svcKey),
                          onTap: () => _openRouteSheet(svc),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

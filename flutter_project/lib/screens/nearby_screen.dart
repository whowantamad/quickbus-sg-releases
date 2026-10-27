import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/bus_stop.dart';
import '../services/transit_db_service.dart';
import '../widgets/stop_list_item.dart';

class _SgHub {
  final String name;
  final double lat;
  final double lng;

  const _SgHub({required this.name, required this.lat, required this.lng});
}

class NearbyScreen extends StatefulWidget {
  final ValueChanged<BusStop> onSelectStop;
  final VoidCallback? onFavoritesChanged;

  const NearbyScreen({
    super.key,
    required this.onSelectStop,
    this.onFavoritesChanged,
  });

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen>
    with WidgetsBindingObserver {
  static const List<_SgHub> _hubs = [
    _SgHub(name: 'City Hall', lat: 1.29250, lng: 103.85145),
    _SgHub(name: 'Orchard', lat: 1.30417, lng: 103.83383),
    _SgHub(name: 'Raffles Place', lat: 1.28520, lng: 103.85256),
    _SgHub(name: 'Bugis', lat: 1.30076, lng: 103.85611),
    _SgHub(name: 'Tampines', lat: 1.35408, lng: 103.94339),
    _SgHub(name: 'Jurong East', lat: 1.33235, lng: 103.74066),
    _SgHub(name: 'Woodlands', lat: 1.43695, lng: 103.78594),
    _SgHub(name: 'Bedok', lat: 1.32454, lng: 103.92904),
  ];

  String _selectedHub = 'City Hall';
  bool _isLocating = false;
  bool _usingGps = false;
  bool _waitingForSettingsReturn = false;
  String? _geoError;
  List<BusStop> _stops = [];
  StreamSubscription<Position>? _refineSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectHub(_hubs.first);
  }

  @override
  void dispose() {
    _refineSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingForSettingsReturn) {
      _waitingForSettingsReturn = false;
      _checkAndResumeGps();
    }
  }

  Future<void> _checkAndResumeGps() async {
    try {
      final permission = await Geolocator.checkPermission();
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever &&
          serviceEnabled) {
        _handleUseGps();
      } else if (mounted) {
        setState(() {
          _isLocating = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _selectHub(_SgHub hub) {
    _refineSub?.cancel();
    final nearest =
        TransitDbService.getNearestStops(hub.lat, hub.lng, limit: 15);
    setState(() {
      _selectedHub = hub.name;
      _usingGps = false;
      _geoError = null;
      _stops = nearest;
    });
  }

  LocationSettings _buildLocationSettings({
    required LocationAccuracy accuracy,
    Duration? timeLimit,
    bool forceLocationManager = false,
  }) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: accuracy,
        intervalDuration: const Duration(milliseconds: 500),
        forceLocationManager: forceLocationManager,
        timeLimit: timeLimit,
      );
    }
    return LocationSettings(
      accuracy: accuracy,
      timeLimit: timeLimit,
    );
  }

  bool _isFreshAndAccurate(Position pos) {
    final age = DateTime.now().difference(pos.timestamp).abs();
    return age <= const Duration(minutes: 3) && pos.accuracy <= 80;
  }

  Future<Position?> _tryGetLastKnownPosition({bool onlyFresh = false}) async {
    try {
      final fusedLast = await Geolocator.getLastKnownPosition();
      if (fusedLast != null && (!onlyFresh || _isFreshAndAccurate(fusedLast))) {
        return fusedLast;
      }
    } catch (_) {}

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final managerLast = await Geolocator.getLastKnownPosition(
          forceAndroidLocationManager: true,
        );
        if (managerLast != null &&
            (!onlyFresh || _isFreshAndAccurate(managerLast))) {
          return managerLast;
        }
      } catch (_) {}
    }
    return null;
  }

  Future<void> _showLocationPromptModal({
    required bool isGpsOff,
    bool isPermanentlyDenied = false,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final title =
            isGpsOff ? 'Location Services Off' : 'Location Permission Needed';
        final subtitle = isGpsOff
            ? 'Device GPS is turned off'
            : (isPermanentlyDenied
                ? 'Permission disabled in settings'
                : 'Required to find nearby stops');
        final message = isGpsOff
            ? 'Please turn on device Location Services (GPS) to find bus stops near your current location.'
            : (isPermanentlyDenied
                ? 'Location access is disabled for QuickBus SG. Please enable it in App Settings to locate nearby bus stops.'
                : 'QuickBus SG needs location permission to calculate distances and show bus stops near you.');
        final actionLabel = isGpsOff
            ? 'Open Settings'
            : (isPermanentlyDenied || kIsWeb ? 'App Settings' : 'Allow Access');

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF151C2E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFE11D48).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isGpsOff
                      ? Icons.location_off_rounded
                      : Icons.my_location_rounded,
                  color: const Color(0xFFE11D48),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            if (!kIsWeb)
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE11D48),
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  if (isGpsOff) {
                    _waitingForSettingsReturn = true;
                    await Geolocator.openLocationSettings();
                  } else if (isPermanentlyDenied) {
                    _waitingForSettingsReturn = true;
                    await Geolocator.openAppSettings();
                  } else {
                    final perm = await Geolocator.requestPermission();
                    if (perm != LocationPermission.denied &&
                        perm != LocationPermission.deniedForever) {
                      _handleUseGps();
                    } else if (perm == LocationPermission.deniedForever) {
                      _waitingForSettingsReturn = true;
                      await Geolocator.openAppSettings();
                    }
                  }
                },
                child: Text(actionLabel),
              ),
          ],
        );
      },
    );
  }

  void _applyPosition(Position pos, {bool stopLocating = true}) {
    if (!mounted) return;
    final nearest = TransitDbService.getNearestStops(
      pos.latitude,
      pos.longitude,
      limit: 15,
    );
    setState(() {
      _selectedHub = 'GPS';
      _usingGps = true;
      if (stopLocating) _isLocating = false;
      _geoError = null;
      _stops = nearest;
    });
  }

  /// Refines coarse initial fixes (e.g. cell/Wi-Fi > 25m accuracy returned on first callback)
  /// for up to 5 seconds until a sharp GPS fix (<= 20m) arrives.
  void _startShortAccuracyRefinement(Position initialPos) {
    _refineSub?.cancel();
    if (kIsWeb || initialPos.accuracy <= 20.0) return;

    var bestAccuracy = initialPos.accuracy;
    final stream = Geolocator.getPositionStream(
      locationSettings: _buildLocationSettings(accuracy: LocationAccuracy.best),
    );

    Timer? stopTimer;
    stopTimer = Timer(const Duration(seconds: 5), () {
      _refineSub?.cancel();
      _refineSub = null;
    });

    _refineSub = stream.listen(
      (pos) {
        if (!mounted || !_usingGps) {
          stopTimer?.cancel();
          _refineSub?.cancel();
          return;
        }
        if (pos.accuracy < bestAccuracy) {
          bestAccuracy = pos.accuracy;
          _applyPosition(pos, stopLocating: true);
        }
        if (pos.accuracy <= 20.0) {
          stopTimer?.cancel();
          _refineSub?.cancel();
          _refineSub = null;
        }
      },
      onError: (_) {
        stopTimer?.cancel();
        _refineSub?.cancel();
        _refineSub = null;
      },
    );
  }

  Future<void> _handleUseGps() async {
    if (_isLocating) return;
    _refineSub?.cancel();
    setState(() {
      _isLocating = true;
      _geoError = null;
    });

    try {
      // 1. Check / request app location permission first
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _isLocating = false;
            _geoError = 'Location permission denied — tap to grant access';
          });
          await _showLocationPromptModal(isGpsOff: false);
        }
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _isLocating = false;
            _geoError = 'Permission disabled — tap to open App Settings';
          });
          await _showLocationPromptModal(
            isGpsOff: false,
            isPermanentlyDenied: true,
          );
        }
        return;
      }

      // 2. Check whether location services are already on
      bool serviceInitiallyEnabled = false;
      try {
        serviceInitiallyEnabled = await Geolocator.isLocationServiceEnabled();
      } catch (_) {
        serviceInitiallyEnabled = false;
      }

      // Only preview cached position if it is fresh (<= 3 min) and accurate (<= 80m)
      if (serviceInitiallyEnabled) {
        final quickLast = await _tryGetLastKnownPosition(onlyFresh: true);
        if (quickLast != null && mounted) {
          _applyPosition(quickLast, stopLocating: false);
        }
      }

      // 3. Request best-accuracy position.
      Position? pos;

      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: _buildLocationSettings(
            accuracy: LocationAccuracy.best,
            timeLimit: Duration(seconds: serviceInitiallyEnabled ? 20 : 40),
          ),
        );
      } on LocationServiceDisabledException {
        if (mounted) {
          setState(() {
            _isLocating = false;
            _geoError =
                'Device GPS is off — tap here to open Location Settings';
          });
          await _showLocationPromptModal(isGpsOff: true);
        }
        return;
      } on PermissionDeniedException {
        if (mounted) {
          setState(() {
            _isLocating = false;
            _geoError = 'Location permission denied — tap to grant access';
          });
          await _showLocationPromptModal(isGpsOff: false);
        }
        return;
      } on TimeoutException {
        pos = await _tryGetLastKnownPosition();
      } catch (e) {
        final errStr = e.toString();
        if (errStr.contains('LOCATION_SERVICES_DISABLED')) {
          if (mounted) {
            setState(() {
              _isLocating = false;
              _geoError =
                  'Device GPS is off — tap here to open Location Settings';
            });
            await _showLocationPromptModal(isGpsOff: true);
          }
          return;
        }
        pos = await _tryGetLastKnownPosition();
        if (pos == null &&
            !kIsWeb &&
            defaultTargetPlatform == TargetPlatform.android) {
          try {
            pos = await Geolocator.getCurrentPosition(
              locationSettings: _buildLocationSettings(
                accuracy: LocationAccuracy.best,
                forceLocationManager: true,
                timeLimit: const Duration(seconds: 20),
              ),
            );
          } catch (_) {}
        }
      }

      if (pos == null) {
        final serviceNowEnabled =
            await Geolocator.isLocationServiceEnabled().catchError((_) => true);
        if (!serviceNowEnabled && mounted) {
          setState(() {
            _isLocating = false;
            _geoError =
                'Device GPS is off — tap here to open Location Settings';
          });
          await _showLocationPromptModal(isGpsOff: true);
          return;
        }
        if (mounted) {
          setState(() {
            _isLocating = false;
            if (!_usingGps) {
              _geoError = 'Could not acquire GPS signal — please try again';
            }
          });
        }
        return;
      }

      _applyPosition(pos, stopLocating: true);
      _startShortAccuracyRefinement(pos);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLocating = false;
          if (!_usingGps) {
            _geoError = 'Could not acquire GPS location';
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Header with GPS Locate Button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.near_me_rounded,
                    size: 18,
                    color: Color(0xFFE11D48),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Nearby',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '· $_selectedHub',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Material(
                color: _usingGps
                    ? const Color(0xFF059669)
                    : const Color(0xFFE11D48),
                shape: const CircleBorder(),
                elevation: 1,
                child: InkWell(
                  onTap: _handleUseGps,
                  customBorder: const CircleBorder(),
                  child: SizedBox(
                    width: 34,
                    height: 34,
                    child: Center(
                      child: _isLocating
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.my_location_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Transit Hub Selector
        SizedBox(
          height: 38,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: _hubs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, idx) {
              final hub = _hubs[idx];
              final active = _selectedHub == hub.name && !_usingGps;
              return InkWell(
                onTap: () => _selectHub(hub),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: active
                        ? (isDark ? Colors.white : const Color(0xFF0F172A))
                        : (isDark ? const Color(0xFF131B2E) : Colors.white),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    hub.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: active
                          ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                          : null,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // GPS Error Banner
        if (_geoError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                if (kIsWeb) {
                  _handleUseGps();
                  return;
                }
                final msg = _geoError ?? '';
                if (msg.contains('Location Settings')) {
                  await _showLocationPromptModal(isGpsOff: true);
                } else if (msg.contains('App Settings')) {
                  await _showLocationPromptModal(
                    isGpsOff: false,
                    isPermanentlyDenied: true,
                  );
                } else if (msg.contains('permission')) {
                  await _showLocationPromptModal(isGpsOff: false);
                } else {
                  _handleUseGps();
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF78350F).withValues(alpha: 0.25)
                      : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF92400E).withValues(alpha: 0.5)
                        : const Color(0xFFFDE68A),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 15,
                      color: isDark
                          ? const Color(0xFFFBBF24)
                          : const Color(0xFFB45309),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _geoError!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFFFCD34D)
                              : const Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        const SizedBox(height: 8),

        // Bus Stop Cards List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: _stops.length,
            itemBuilder: (context, idx) {
              final stop = _stops[idx];
              return StopListItem(
                stop: stop,
                onSelect: () => widget.onSelectStop(stop),
                onStarToggled: widget.onFavoritesChanged,
              );
            },
          ),
        ),
      ],
    );
  }
}

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
    _SgHub(name: 'City Hall', lat: 1.2929, lng: 103.8529),
    _SgHub(name: 'Orchard', lat: 1.3040, lng: 103.8340),
    _SgHub(name: 'Raffles Place', lat: 1.2858, lng: 103.8528),
    _SgHub(name: 'Bugis', lat: 1.3005, lng: 103.8565),
    _SgHub(name: 'Tampines', lat: 1.3533, lng: 103.9452),
    _SgHub(name: 'Jurong East', lat: 1.3331, lng: 103.7423),
    _SgHub(name: 'Woodlands', lat: 1.4368, lng: 103.7865),
    _SgHub(name: 'Bedok', lat: 1.3243, lng: 103.9304),
  ];

  String _selectedHub = 'City Hall';
  bool _isLocating = false;
  bool _usingGps = false;
  bool _waitingForSettingsReturn = false;
  String? _geoError;
  List<BusStop> _stops = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectHub(_hubs.first);
  }

  @override
  void dispose() {
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
    final nearest = TransitDbService.getNearestStops(hub.lat, hub.lng, limit: 15);
    setState(() {
      _selectedHub = hub.name;
      _usingGps = false;
      _geoError = null;
      _stops = nearest;
    });
  }

  LocationSettings _buildLocationSettings({
    required LocationAccuracy accuracy,
    required Duration timeLimit,
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

  Future<Position?> _tryGetLastKnownPosition() async {
    try {
      final fusedLast = await Geolocator.getLastKnownPosition();
      if (fusedLast != null) return fusedLast;
    } catch (_) {}

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final managerLast = await Geolocator.getLastKnownPosition(
          forceAndroidLocationManager: true,
        );
        if (managerLast != null) return managerLast;
      } catch (_) {}
    }
    return null;
  }

  Future<Position?> _acquireFallbackPosition() async {
    // Stage 2: Fused balanced/medium accuracy (fast Wi-Fi + cell + GPS indoors)
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: _buildLocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 5),
        ),
      );
    } catch (_) {}

    // Stage 3 & 4: Last known cached position (Fused, then LocationManager)
    final lastKnown = await _tryGetLastKnownPosition();
    if (lastKnown != null) return lastKnown;

    // Stage 5: Direct Android LocationManager live fix
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: _buildLocationSettings(
            accuracy: LocationAccuracy.medium,
            forceLocationManager: true,
            timeLimit: const Duration(seconds: 6),
          ),
        );
      } catch (_) {}
    }
    return null;
  }

  Future<void> _handleUseGps() async {
    if (_isLocating) return;
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
            _geoError = 'Location permission denied';
          });
        }
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _isLocating = false;
            _geoError = 'Permission disabled — tap to open App Settings';
          });
        }
        return;
      }

      // 2. Check whether location services are already on (without aborting if off,
      //    so getCurrentPosition can trigger the native Android system dialog to enable GPS)
      bool serviceInitiallyEnabled = false;
      try {
        serviceInitiallyEnabled = await Geolocator.isLocationServiceEnabled();
      } catch (_) {
        serviceInitiallyEnabled = false;
      }

      // If GPS is already enabled and we have a recent cached position, show it right away
      // while we refine with a fresh fix.
      if (serviceInitiallyEnabled) {
        final quickLast = await _tryGetLastKnownPosition();
        if (quickLast != null && mounted) {
          final initialStops = TransitDbService.getNearestStops(
            quickLast.latitude,
            quickLast.longitude,
            limit: 15,
          );
          setState(() {
            _selectedHub = 'GPS';
            _usingGps = true;
            _stops = initialStops;
          });
        }
      }

      // 3. Request high-accuracy position.
      //    On Android, if device GPS is off, FusedLocationClient automatically triggers
      //    the native system resolution dialog ("Turn on device location?").
      Position? pos;

      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: _buildLocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: serviceInitiallyEnabled ? 5 : 20),
          ),
        );
      } on LocationServiceDisabledException {
        if (mounted) {
          setState(() {
            _isLocating = false;
            _geoError = 'Device GPS is off — tap here to open Location Settings';
          });
        }
        return;
      } on PermissionDeniedException {
        if (mounted) {
          setState(() {
            _isLocating = false;
            _geoError = 'Location permission denied';
          });
        }
        return;
      } on TimeoutException {
        pos = await _acquireFallbackPosition();
      } catch (e) {
        final errStr = e.toString();
        if (errStr.contains('LOCATION_SERVICES_DISABLED')) {
          if (mounted) {
            setState(() {
              _isLocating = false;
              _geoError =
                  'Device GPS is off — tap here to open Location Settings';
            });
          }
          return;
        }
        pos = await _acquireFallbackPosition();
      }

      if (pos == null) {
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

      final nearest = TransitDbService.getNearestStops(
        pos.latitude,
        pos.longitude,
        limit: 15,
      );

      if (mounted) {
        setState(() {
          _selectedHub = 'GPS';
          _usingGps = true;
          _isLocating = false;
          _geoError = null;
          _stops = nearest;
        });
      }
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
                  _waitingForSettingsReturn = true;
                  await Geolocator.openLocationSettings();
                } else if (msg.contains('App Settings')) {
                  _waitingForSettingsReturn = true;
                  await Geolocator.openAppSettings();
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
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 15,
                      color: isDark
                          ? const Color(0xFFFBBF24)
                          : const Color(0xFFB45309),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _geoError!,
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

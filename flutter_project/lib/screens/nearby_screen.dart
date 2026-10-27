import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/bus_stop.dart';
import '../services/favorites_service.dart';
import '../services/transit_db_service.dart';
import '../widgets/stop_list_item.dart';

class NearbyScreen extends StatefulWidget {
  final bool isActive;
  final ValueChanged<BusStop> onSelectStop;
  final VoidCallback? onFavoritesChanged;

  const NearbyScreen({
    super.key,
    this.isActive = true,
    required this.onSelectStop,
    this.onFavoritesChanged,
  });

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen>
    with WidgetsBindingObserver {
  String _statusLabel = 'Locating...';
  bool _isLocating = false;
  bool _usingGps = false;
  bool _waitingForSettingsReturn = false;
  String? _geoError;
  List<BusStop> _stops = [];
  StreamSubscription<Position>? _refineSub;
  Timer? _refineTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initStartupLocation();
  }

  @override
  void didUpdateWidget(covariant NearbyScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      if (!_usingGps) {
        _loadPredictedLocation();
        if (!_isLocating) {
          _tryAutoStartLiveGps();
        }
      }
    }
  }

  @override
  void dispose() {
    _cancelRefinement();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _cancelRefinement() {
    _refineTimer?.cancel();
    _refineTimer = null;
    _refineSub?.cancel();
    _refineSub = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingForSettingsReturn) {
      _waitingForSettingsReturn = false;
      _checkAndResumeGps();
    }
  }

  Future<PredictedLocation?> _loadPredictedLocation() async {
    final predicted = await FavoritesService.getPredictedOrLastLocation();
    if (predicted != null && mounted && !_usingGps) {
      final nearest = TransitDbService.getNearestStops(
        predicted.lat,
        predicted.lng,
        limit: 15,
      );
      setState(() {
        _statusLabel = predicted.label;
        _stops = nearest;
      });
    }
    return predicted;
  }

  Future<void> _initStartupLocation() async {
    final predicted = await _loadPredictedLocation();
    if (widget.isActive) {
      await _tryAutoStartLiveGps(hasFallback: predicted != null);
    } else if (predicted == null && mounted) {
      setState(() => _statusLabel = 'Tap GPS to locate');
    }
  }

  Future<void> _tryAutoStartLiveGps({bool hasFallback = true}) async {
    try {
      final permission = await Geolocator.checkPermission();
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever &&
          serviceEnabled) {
        await _handleUseGps(silentPrompt: true);
      } else if (!hasFallback && _stops.isEmpty && mounted) {
        setState(() {
          _statusLabel = 'Location Off';
        });
      }
    } catch (_) {
      if (!hasFallback && _stops.isEmpty && mounted) {
        setState(() {
          _statusLabel = 'Location Off';
        });
      }
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

  void _showLocationToast({String? error}) {
    if (!mounted) return;
    showAppToast(
      context,
      error ?? 'GPS location updated',
      isError: error != null,
    );
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
    return age <= const Duration(minutes: 3) &&
        pos.accuracy > 0 &&
        pos.accuracy <= 80;
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

  void _applyPosition(
    Position pos, {
    bool stopLocating = true,
    bool recordHistory = true,
    bool isLiveFix = true,
  }) {
    if (!mounted) return;
    if (recordHistory && isLiveFix) {
      FavoritesService.recordLocation(pos.latitude, pos.longitude);
    }
    final nearest = TransitDbService.getNearestStops(
      pos.latitude,
      pos.longitude,
      limit: 15,
    );
    setState(() {
      _statusLabel = isLiveFix ? 'Live GPS' : 'Last Location';
      _usingGps = isLiveFix;
      if (stopLocating) _isLocating = false;
      _geoError = null;
      _stops = nearest;
    });
  }

  /// Refines coarse initial fixes (e.g. cell/Wi-Fi > 25m accuracy returned on first callback)
  /// for up to 5 seconds until a sharp GPS fix (0 < accuracy <= 20m) arrives.
  void _startShortAccuracyRefinement(Position initialPos) {
    _cancelRefinement();
    if (kIsWeb || (initialPos.accuracy > 0 && initialPos.accuracy <= 20.0)) {
      return;
    }

    var bestAccuracy =
        initialPos.accuracy > 0 ? initialPos.accuracy : double.infinity;
    final stream = Geolocator.getPositionStream(
      locationSettings: _buildLocationSettings(accuracy: LocationAccuracy.best),
    );

    _refineTimer = Timer(const Duration(seconds: 5), _cancelRefinement);

    _refineSub = stream.listen(
      (pos) {
        if (!mounted || !_usingGps) {
          _cancelRefinement();
          return;
        }
        if (pos.accuracy > 0 && pos.accuracy < bestAccuracy) {
          bestAccuracy = pos.accuracy;
          _applyPosition(
            pos,
            stopLocating: true,
            recordHistory: true,
            isLiveFix: true,
          );
        }
        if (pos.accuracy > 0 && pos.accuracy <= 20.0) {
          _cancelRefinement();
        }
      },
      onError: (_) => _cancelRefinement(),
    );
  }

  Future<void> _handleUseGps({
    bool silentPrompt = false,
    bool showToast = false,
  }) async {
    if (_isLocating) return;
    _cancelRefinement();
    setState(() {
      _isLocating = true;
      _geoError = null;
    });

    try {
      // 1. Check / request app location permission first
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && !silentPrompt) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _isLocating = false;
            _geoError = 'Location permission denied — tap to grant access';
          });
          if (showToast) {
            _showLocationToast(error: 'Location permission denied');
          }
          if (!silentPrompt) {
            await _showLocationPromptModal(isGpsOff: false);
          }
        }
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _isLocating = false;
            _geoError = 'Permission disabled — tap to open App Settings';
          });
          if (showToast) {
            _showLocationToast(error: 'Location permission disabled');
          }
          if (!silentPrompt) {
            await _showLocationPromptModal(
              isGpsOff: false,
              isPermanentlyDenied: true,
            );
          }
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

      // Only preview cached position if it is fresh (<= 3 min) and accurate (0 < accuracy <= 80m)
      if (serviceInitiallyEnabled) {
        final quickLast = await _tryGetLastKnownPosition(onlyFresh: true);
        if (quickLast != null && mounted) {
          _applyPosition(
            quickLast,
            stopLocating: false,
            recordHistory: false,
            isLiveFix: true,
          );
        }
      }

      // 3. Request best-accuracy position.
      Position? pos;
      var isLiveFix = false;

      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: _buildLocationSettings(
            accuracy: LocationAccuracy.best,
            timeLimit: Duration(seconds: serviceInitiallyEnabled ? 20 : 40),
          ),
        );
        isLiveFix = true;
      } on LocationServiceDisabledException {
        if (mounted) {
          setState(() {
            _isLocating = false;
            _geoError =
                'Device GPS is off — tap here to open Location Settings';
          });
          if (showToast) {
            _showLocationToast(error: 'Device GPS is off');
          }
          if (!silentPrompt) {
            await _showLocationPromptModal(isGpsOff: true);
          }
        }
        return;
      } on PermissionDeniedException {
        if (mounted) {
          setState(() {
            _isLocating = false;
            _geoError = 'Location permission denied — tap to grant access';
          });
          if (showToast) {
            _showLocationToast(error: 'Location permission denied');
          }
          if (!silentPrompt) {
            await _showLocationPromptModal(isGpsOff: false);
          }
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
            if (showToast) {
              _showLocationToast(error: 'Device GPS is off');
            }
            if (!silentPrompt) {
              await _showLocationPromptModal(isGpsOff: true);
            }
          }
          return;
        }
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          try {
            pos = await Geolocator.getCurrentPosition(
              locationSettings: _buildLocationSettings(
                accuracy: LocationAccuracy.best,
                forceLocationManager: true,
                timeLimit: const Duration(seconds: 20),
              ),
            );
            isLiveFix = true;
          } catch (_) {}
        }
        pos ??= await _tryGetLastKnownPosition();
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
          if (showToast) {
            _showLocationToast(error: 'Device GPS is off');
          }
          if (!silentPrompt) {
            await _showLocationPromptModal(isGpsOff: true);
          }
          return;
        }
        if (mounted) {
          setState(() {
            _isLocating = false;
            if (!_usingGps && _stops.isEmpty) {
              _geoError = 'Could not acquire GPS signal — please try again';
            }
          });
          if (showToast) {
            _showLocationToast(error: 'Could not acquire GPS signal');
          }
        }
        return;
      }

      _applyPosition(
        pos,
        stopLocating: true,
        recordHistory: isLiveFix,
        isLiveFix: isLiveFix,
      );
      if (showToast) {
        _showLocationToast(
          error:
              isLiveFix ? null : 'Live GPS timed out · showing last location',
        );
      }
      if (isLiveFix) {
        _startShortAccuracyRefinement(pos);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLocating = false;
          if (!_usingGps && _stops.isEmpty) {
            _geoError = 'Could not acquire GPS location';
          }
        });
        if (showToast) {
          _showLocationToast(error: 'Could not acquire GPS location');
        }
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.near_me_rounded,
                      size: 18,
                      color: Color(0xFFE11D48),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Nearby',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '· $_statusLabel',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              _usingGps ? FontWeight.w600 : FontWeight.w500,
                          color: _usingGps
                              ? const Color(0xFF10B981)
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: _usingGps
                    ? const Color(0xFF059669)
                    : const Color(0xFFE11D48),
                shape: const CircleBorder(),
                elevation: 1,
                child: InkWell(
                  onTap: () => _handleUseGps(showToast: true),
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

        // GPS Error Banner
        if (_geoError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
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

        const SizedBox(height: 4),

        // Bus Stop Cards List with Pull-to-Refresh
        Expanded(
          child: RefreshIndicator(
            color: const Color(0xFFE11D48),
            onRefresh: () => _handleUseGps(showToast: true),
            child: _stops.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: 280,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.my_location_rounded,
                                size: 36,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _isLocating
                                    ? 'Acquiring GPS signal...'
                                    : 'Pull down or tap GPS to find nearby stops',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
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
        ),
      ],
    );
  }
}

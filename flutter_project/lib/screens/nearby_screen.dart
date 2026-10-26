import 'package:flutter/material.dart';
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

class _NearbyScreenState extends State<NearbyScreen> {
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
  List<BusStop> _stops = [];

  @override
  void initState() {
    super.initState();
    _selectHub(_hubs.first);
  }

  void _selectHub(_SgHub hub) {
    final nearest = TransitDbService.getNearestStops(hub.lat, hub.lng, limit: 15);
    setState(() {
      _selectedHub = hub.name;
      _stops = nearest;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
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
              final active = _selectedHub == hub.name;
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

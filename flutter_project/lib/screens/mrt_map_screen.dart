import 'package:flutter/material.dart';
import '../models/bus_stop.dart';
import '../services/transit_db_service.dart';
import '../widgets/stop_list_item.dart';

class _MrtStation {
  final String code;
  final String name;
  final String line;
  final Color color;
  final double lat;
  final double lng;

  const _MrtStation({
    required this.code,
    required this.name,
    required this.line,
    required this.color,
    required this.lat,
    required this.lng,
  });
}

class MrtMapScreen extends StatefulWidget {
  final ValueChanged<BusStop> onSelectStop;
  final VoidCallback? onFavoritesChanged;

  const MrtMapScreen({
    super.key,
    required this.onSelectStop,
    this.onFavoritesChanged,
  });

  @override
  State<MrtMapScreen> createState() => _MrtMapScreenState();
}

class _MrtMapScreenState extends State<MrtMapScreen> {
  static const List<_MrtStation> _stations = [
    _MrtStation(code: 'NS1/EW24', name: 'Jurong East', line: 'NSL/EWL', color: Color(0xFFD42E12), lat: 1.3331, lng: 103.7423),
    _MrtStation(code: 'NS9/TE2', name: 'Woodlands', line: 'NSL/TEL', color: Color(0xFFD42E12), lat: 1.4368, lng: 103.7865),
    _MrtStation(code: 'NS13', name: 'Yishun', line: 'NSL', color: Color(0xFFD42E12), lat: 1.4294, lng: 103.8350),
    _MrtStation(code: 'NS17/CC15', name: 'Bishan', line: 'NSL/CCL', color: Color(0xFFD42E12), lat: 1.3508, lng: 103.8482),
    _MrtStation(code: 'NS22/TE14', name: 'Orchard', line: 'NSL/TEL', color: Color(0xFFD42E12), lat: 1.3040, lng: 103.8320),
    _MrtStation(code: 'NS24/NE6/CC1', name: 'Dhoby Ghaut', line: 'NSL/NEL/CCL', color: Color(0xFF9900AA), lat: 1.2988, lng: 103.8456),
    _MrtStation(code: 'NS25/EW13', name: 'City Hall', line: 'NSL/EWL', color: Color(0xFF009645), lat: 1.2929, lng: 103.8525),
    _MrtStation(code: 'NS26/EW14', name: 'Raffles Place', line: 'NSL/EWL', color: Color(0xFF009645), lat: 1.2841, lng: 103.8515),
    _MrtStation(code: 'EW1', name: 'Pasir Ris', line: 'EWL', color: Color(0xFF009645), lat: 1.3730, lng: 103.9493),
    _MrtStation(code: 'EW2/DT32', name: 'Tampines', line: 'EWL/DTL', color: Color(0xFF009645), lat: 1.3533, lng: 103.9452),
    _MrtStation(code: 'EW5', name: 'Bedok', line: 'EWL', color: Color(0xFF009645), lat: 1.3240, lng: 103.9302),
    _MrtStation(code: 'EW8/CC9', name: 'Paya Lebar', line: 'EWL/CCL', color: Color(0xFFFA9E0D), lat: 1.3175, lng: 103.8927),
    _MrtStation(code: 'EW12/DT14', name: 'Bugis', line: 'EWL/DTL', color: Color(0xFF005EC4), lat: 1.3005, lng: 103.8560),
    _MrtStation(code: 'NE1/CC29', name: 'HarbourFront', line: 'NEL/CCL', color: Color(0xFF9900AA), lat: 1.2653, lng: 103.8215),
    _MrtStation(code: 'NE12/CC13', name: 'Serangoon', line: 'NEL/CCL', color: Color(0xFF9900AA), lat: 1.3497, lng: 103.8736),
    _MrtStation(code: 'NE17', name: 'Punggol', line: 'NEL', color: Color(0xFF9900AA), lat: 1.4052, lng: 103.9023),
  ];

  _MrtStation _selectedStation = _stations[6]; // City Hall default
  List<BusStop> _nearbyStops = [];

  @override
  void initState() {
    super.initState();
    _selectStation(_selectedStation);
  }

  void _selectStation(_MrtStation stn) {
    final stops = TransitDbService.getNearestStops(stn.lat, stn.lng, limit: 8);
    setState(() {
      _selectedStation = stn;
      _nearbyStops = stops;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(Icons.train_rounded, size: 18, color: Color(0xFFE11D48)),
              SizedBox(width: 8),
              Text(
                'MRT Station Transfers',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),

        // Horizontal MRT Station Chips
        SizedBox(
          height: 44,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
            scrollDirection: Axis.horizontal,
            itemCount: _stations.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, idx) {
              final stn = _stations[idx];
              final active = _selectedStation.code == stn.code;
              return InkWell(
                onTap: () => _selectStation(stn),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: active
                        ? stn.color
                        : (isDark ? const Color(0xFF131B2E) : Colors.white),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: active
                          ? stn.color
                          : (isDark ? Colors.white10 : Colors.black12),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active ? Colors.white : stn.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${stn.name} (${stn.code})',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: active ? Colors.white : null,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            'Bus stops near ${_selectedStation.name} MRT',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: _nearbyStops.length,
            itemBuilder: (context, idx) {
              final stop = _nearbyStops[idx];
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

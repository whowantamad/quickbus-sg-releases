import 'package:flutter/material.dart';
import '../models/bus_stop.dart';
import '../services/favorites_service.dart';
import '../services/transit_db_service.dart';
import '../widgets/stop_list_item.dart';

class SearchScreen extends StatefulWidget {
  final ValueChanged<BusStop> onSelectStop;
  final VoidCallback? onFavoritesChanged;

  const SearchScreen({
    super.key,
    required this.onSelectStop,
    this.onFavoritesChanged,
  });

  @override
  State<SearchScreen> createState() => SearchScreenState();
}

class SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';
  List<BusStop> _results = [];

  @override
  void initState() {
    super.initState();
    reloadRecentOrDefault();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> reloadRecentOrDefault() async {
    if (_query.trim().isNotEmpty) return;
    final records = await FavoritesService.getRecentStopRecords();
    if (records.isNotEmpty) {
      final recentStops = records
          .map((r) => TransitDbService.getStopByCode(r.code))
          .whereType<BusStop>()
          .toList();
      if (recentStops.isNotEmpty) {
        if (mounted) {
          setState(() => _results = recentStops);
        }
        return;
      }
    }
    final defaults = TransitDbService.searchStops('', limit: 40);
    if (mounted) {
      setState(() => _results = defaults);
    }
  }

  Future<void> _handleSearch(String q) async {
    setState(() => _query = q);
    if (q.trim().isEmpty) {
      await reloadRecentOrDefault();
      return;
    }
    final matches = TransitDbService.searchStops(q, limit: 50);
    if (mounted) {
      setState(() => _results = matches);
    }
  }

  Future<void> _handleDeleteRecent(BusStop stop) async {
    await FavoritesService.removeRecentStopRecord(stop.code);
    if (mounted) {
      setState(() {
        _results.removeWhere((s) => s.code == stop.code);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _controller,
            onChanged: _handleSearch,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Stop code, road, or bus (e.g. 147)...',
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _controller.clear();
                        _handleSearch('');
                      },
                    )
                  : null,
              isDense: true,
              filled: true,
              fillColor: isDark ? const Color(0xFF131B2E) : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: _results.isEmpty
              ? Center(
                  child: Text(
                    '—',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final stop = _results[index];
                    return StopListItem(
                      stop: stop,
                      onSelect: () => widget.onSelectStop(stop),
                      onStarToggled: widget.onFavoritesChanged,
                      onDelete: _query.trim().isEmpty
                          ? () => _handleDeleteRecent(stop)
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

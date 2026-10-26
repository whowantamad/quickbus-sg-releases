import 'package:flutter/material.dart';
import '../models/bus_stop.dart';
import '../services/favorites_service.dart';
import '../services/transit_db_service.dart';
import '../widgets/stop_list_item.dart';

class FavoritesScreen extends StatefulWidget {
  final ValueChanged<BusStop> onSelectStop;
  final VoidCallback onNavigateToNearby;

  const FavoritesScreen({
    super.key,
    required this.onSelectStop,
    required this.onNavigateToNearby,
  });

  @override
  State<FavoritesScreen> createState() => FavoritesScreenState();
}

class FavoritesScreenState extends State<FavoritesScreen> {
  List<FavoriteStop> _favorites = [];
  String _activeTag = 'All';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    final favs = await FavoritesService.getFavorites();
    if (mounted) {
      setState(() {
        _favorites = favs;
        _loading = false;
      });
    }
  }

  Future<void> _handleDelete(BusStop stop) async {
    await FavoritesService.removeFavorite(stop.code);
    await reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final tags = <String>{
      'All',
      ..._favorites.map((f) => f.tag.isNotEmpty ? f.tag : 'Starred'),
    }.toList();

    final filtered = _favorites.where((f) {
      if (_activeTag == 'All') return true;
      return (f.tag.isNotEmpty ? f.tag : 'Starred') == _activeTag;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              const Text(
                'Starred',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 6),
              Text(
                '(${_favorites.length})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        // Tag Filter Sub-Tabs
        if (tags.length > 2)
          SizedBox(
            height: 40,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
              scrollDirection: Axis.horizontal,
              itemCount: tags.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, idx) {
                final tag = tags[idx];
                final active = _activeTag == tag;
                return InkWell(
                  onTap: () => setState(() => _activeTag = tag),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
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
                      tag,
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

        // Favorites List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.bookmark_outline_rounded,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE11D48),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: widget.onNavigateToNearby,
                        icon: const Icon(Icons.explore_outlined, size: 16),
                        label: const Text('Nearby'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 6, bottom: 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final fav = filtered[index];
                    final stop = TransitDbService.getStopByCode(fav.code);
                    if (stop == null) return const SizedBox.shrink();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (fav.customName.isNotEmpty &&
                            fav.customName != stop.name)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(22, 6, 22, 0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  fav.customName,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFE11D48),
                                  ),
                                ),
                                if (fav.tag.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF1E293B)
                                          : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      fav.tag,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        StopListItem(
                          stop: stop,
                          onSelect: () => widget.onSelectStop(stop),
                          onStarToggled: reload,
                          onDelete: () => _handleDelete(stop),
                          confirmBeforeUnstar: true,
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

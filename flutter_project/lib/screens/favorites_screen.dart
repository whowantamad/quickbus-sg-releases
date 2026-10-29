import 'package:flutter/material.dart';
import '../models/bus_arrival.dart';
import '../models/bus_stop.dart';
import '../services/favorites_service.dart';
import '../services/lta_api_service.dart';
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
  Map<String, List<BusArrivalService>> _starredArrivalsByStop = {};
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
        if (_activeTag != 'All' &&
            !favs
                .any((f) => (f.tag.isNotEmpty ? f.tag : 'Starred') == _activeTag)) {
          _activeTag = 'All';
        }
        _loading = false;
      });
    }
    await _fetchStarredArrivals(favs);
  }

  Future<void> _fetchStarredArrivals(List<FavoriteStop> favs) async {
    final starredMap = await FavoritesService.getAllStarredServices();
    final settings = await FavoritesService.getSettings();
    final api = LtaApiService(accountKey: settings.datamallKey);

    final stopsWithStarredSvcs = favs.where((f) {
      final svcs = starredMap[f.code];
      return svcs != null && svcs.isNotEmpty;
    }).toList();

    if (stopsWithStarredSvcs.isEmpty) {
      if (mounted) {
        setState(() => _starredArrivalsByStop = {});
      }
      return;
    }

    final nextMap = <String, List<BusArrivalService>>{};
    await Future.wait(
      stopsWithStarredSvcs.map((fav) async {
        final stop = TransitDbService.getStopByCode(fav.code);
        final wantedKeys = starredMap[fav.code] ?? const [];
        if (stop == null || wantedKeys.isEmpty) return;

        final liveList = await api.getBusArrivals(
          fav.code,
          stopServices: stop.services,
        );
        final activeByNo = {for (final s in liveList) s.serviceNo: s};
        final raw = stop.services
            .map(
                (no) => activeByNo[no] ?? BusArrivalService(serviceNo: no, operator: ''))
            .toList();
        final expanded = TransitDbService.expandServicesForStop(raw, fav.code);
        final byKey = {for (final s in expanded) s.effectiveKey: s};

        final matched = <BusArrivalService>[];
        for (final k in wantedKeys) {
          final svc = byKey[k];
          if (svc != null) matched.add(svc);
        }
        if (matched.isNotEmpty) {
          nextMap[fav.code] = matched;
        }
      }),
    );

    if (mounted) {
      setState(() => _starredArrivalsByStop = nextMap);
    }
  }

  Future<void> _handleDelete(BusStop stop) async {
    await FavoritesService.removeFavorite(stop.code);
    await reload();
  }

  Future<void> _showEditFavoriteDialog(FavoriteStop fav, BusStop stop) async {
    final nameCtrl = TextEditingController(
      text: fav.customName.isNotEmpty ? fav.customName : stop.name,
    );
    final tagCtrl = TextEditingController(
      text: fav.tag.isNotEmpty ? fav.tag : 'Commute',
    );
    const presetTags = ['Commute', 'Home', 'Work', 'School'];

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF151C2E) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Text(
                'Edit Stop · ${stop.code}',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Custom Label',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: stop.name,
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Tag',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: presetTags.map((preset) {
                        final selected = tagCtrl.text.trim() == preset;
                        return ChoiceChip(
                          label: Text(
                            preset,
                            style: const TextStyle(fontSize: 11),
                          ),
                          selected: selected,
                          onSelected: (_) {
                            setDialogState(() => tagCtrl.text = preset);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: tagCtrl,
                      onChanged: (_) => setDialogState(() {}),
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Custom tag (e.g. Gym)',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE11D48),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true) {
      await FavoritesService.updateFavorite(
        fav.code,
        customName: nameCtrl.text,
        tag: tagCtrl.text.trim().isEmpty ? 'Commute' : tagCtrl.text,
      );
      await reload();
      if (mounted) {
        showAppToast(context, 'Saved label for ${stop.code}');
      }
    }
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
            height: 44,
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
                          color:
                              const Color(0xFFF59E0B).withValues(alpha: 0.14),
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
              : RefreshIndicator(
                  color: const Color(0xFFE11D48),
                  onRefresh: () async {
                    await reload();
                    if (context.mounted) {
                      showAppToast(context, 'Starred arrivals updated');
                    }
                  },
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(top: 6, bottom: 24),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final fav = filtered[index];
                      final stop = TransitDbService.getStopByCode(fav.code);
                      if (stop == null) return const SizedBox.shrink();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((fav.customName.isNotEmpty &&
                                  fav.customName != stop.name) ||
                              fav.tag.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(22, 6, 22, 0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    fav.customName.isNotEmpty &&
                                            fav.customName != stop.name
                                        ? fav.customName
                                        : '',
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
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
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
                            onEdit: () => _showEditFavoriteDialog(fav, stop),
                            starredArrivals: _starredArrivalsByStop[fav.code],
                            confirmBeforeUnstar: true,
                          ),
                        ],
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

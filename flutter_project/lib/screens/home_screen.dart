import 'package:flutter/material.dart';
import '../models/bus_stop.dart';
import '../services/favorites_service.dart';
import '../widgets/settings_sheet.dart';
import 'favorites_screen.dart';
import 'nearby_screen.dart';
import 'search_screen.dart';
import 'mrt_map_screen.dart';
import 'bus_stop_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final UserSettings settings;
  final ValueChanged<UserSettings> onSettingsUpdated;

  const HomeScreen({
    super.key,
    required this.settings,
    required this.onSettingsUpdated,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final GlobalKey<FavoritesScreenState> _favoritesKey = GlobalKey();
  final GlobalKey<SearchScreenState> _searchKey = GlobalKey();

  void _openStop(BusStop stop) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => BusStopDetailScreen(busStop: stop),
          ),
        )
        .then((_) {
          _favoritesKey.currentState?.reload();
          _searchKey.currentState?.reloadRecentOrDefault();
        });
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SettingsSheet(
        settings: widget.settings,
        onSettingsUpdated: widget.onSettingsUpdated,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // Brand Icon: Lightning Bolt (as S) + lower-aligned "G" -> "SG"
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE11D48), Color(0xFFEF4444)],
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.bolt_rounded,
                    color: Colors.white,
                    size: 15,
                  ),
                  Transform.translate(
                    offset: const Offset(-1.5, 2.0),
                    child: const Text(
                      'G',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        height: 1.0,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'QuickBus SG',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          // Settings button (Theme toggle is inside Settings)
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20),
            tooltip: 'Settings',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          FavoritesScreen(
            key: _favoritesKey,
            onSelectStop: _openStop,
            onNavigateToNearby: () => setState(() => _currentIndex = 1),
          ),
          NearbyScreen(
            onSelectStop: _openStop,
            onFavoritesChanged: () => _favoritesKey.currentState?.reload(),
          ),
          SearchScreen(
            key: _searchKey,
            onSelectStop: _openStop,
            onFavoritesChanged: () => _favoritesKey.currentState?.reload(),
          ),
          MrtMapScreen(
            onSelectStop: _openStop,
            onFavoritesChanged: () => _favoritesKey.currentState?.reload(),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) {
          setState(() => _currentIndex = idx);
          if (idx == 0) _favoritesKey.currentState?.reload();
          if (idx == 2) _searchKey.currentState?.reloadRecentOrDefault();
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.star_outline_rounded),
            selectedIcon: Icon(Icons.star_rounded, color: Color(0xFFE11D48)),
            label: 'Starred',
          ),
          NavigationDestination(
            icon: Icon(Icons.near_me_outlined),
            selectedIcon: Icon(Icons.near_me_rounded, color: Color(0xFFE11D48)),
            label: 'Nearby',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_rounded),
            selectedIcon: Icon(Icons.search_rounded, color: Color(0xFFE11D48)),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.train_outlined),
            selectedIcon: Icon(Icons.train_rounded, color: Color(0xFFE11D48)),
            label: 'MRT Map',
          ),
        ],
      ),
    );
  }
}

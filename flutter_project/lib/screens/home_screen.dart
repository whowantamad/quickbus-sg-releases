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
              child: const CustomPaint(
                size: Size(32, 32),
                painter: _QuickBusLogoPainter(),
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1E293B)
                  : const Color(0xFFF1F5F9),
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          elevation: 0,
          onDestinationSelected: (idx) {
            setState(() => _currentIndex = idx);
            if (idx == 0) _favoritesKey.currentState?.reload();
            if (idx == 2) _searchKey.currentState?.reloadRecentOrDefault();
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.star_outline_rounded),
              selectedIcon: Icon(Icons.star_rounded),
              label: 'Starred',
            ),
            NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore_rounded),
              label: 'Nearby',
            ),
            NavigationDestination(
              icon: Icon(Icons.search_rounded),
              selectedIcon: Icon(Icons.search_rounded),
              label: 'Search',
            ),
            NavigationDestination(
              icon: Icon(Icons.train_outlined),
              selectedIcon: Icon(Icons.train_rounded),
              label: 'MRT',
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders the exact SVG path and 'G' glyph from `public/icon.svg` (viewBox 0 0 512 512)
class _QuickBusLogoPainter extends CustomPainter {
  const _QuickBusLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 512.0;
    final sy = size.height / 512.0;

    // Lightning bolt ('S'): M238 116 L118 278 H216 L196 396 L316 234 H218 Z
    final boltPath = Path()
      ..moveTo(238 * sx, 116 * sy)
      ..lineTo(118 * sx, 278 * sy)
      ..lineTo(216 * sx, 278 * sy)
      ..lineTo(196 * sx, 396 * sy)
      ..lineTo(316 * sx, 234 * sy)
      ..lineTo(218 * sx, 234 * sy)
      ..close();

    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12 * sx
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(boltPath, fillPaint);
    canvas.drawPath(boltPath, strokePaint);

    // Bold 'G' aligned to the bottom of the lightning bolt (x=278, y=396, font-size=185)
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'G',
        style: TextStyle(
          color: Colors.white,
          fontSize: 185 * sy,
          fontWeight: FontWeight.w900,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(278 * sx, 396 * sy - textPainter.height * 0.82),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

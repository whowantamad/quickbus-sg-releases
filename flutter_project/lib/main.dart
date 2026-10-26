import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/favorites_service.dart';
import 'services/transit_db_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TransitDbService.init();
  await FavoritesService.getFavorites();
  final initialSettings = await FavoritesService.getSettings();
  runApp(QuickBusApp(initialSettings: initialSettings));
}

class QuickBusApp extends StatefulWidget {
  final UserSettings initialSettings;

  const QuickBusApp({super.key, required this.initialSettings});

  @override
  State<QuickBusApp> createState() => _QuickBusAppState();
}

class _QuickBusAppState extends State<QuickBusApp> {
  late UserSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
  }

  void _handleSettingsUpdated(UserSettings newSettings) {
    setState(() {
      _settings = newSettings;
    });
  }

  @override
  Widget build(BuildContext context) {
    const primaryRose = Color(0xFFE11D48);

    return MaterialApp(
      title: 'QuickBus SG',
      debugShowCheckedModeBanner: false,
      themeMode: _settings.themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryRose,
          brightness: Brightness.light,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          indicatorColor: const Color(0xFFFFF1F2),
          height: 64,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: selected
                  ? const Color(0xFFE11D48)
                  : const Color(0xFF94A3B8),
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              size: 20,
              color: selected
                  ? const Color(0xFFE11D48)
                  : const Color(0xFF94A3B8),
            );
          }),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryRose,
          brightness: Brightness.dark,
          surface: const Color(0xFF131B2E),
        ),
        scaffoldBackgroundColor: const Color(0xFF0C1220),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0C1220),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF0C1220),
          surfaceTintColor: Colors.transparent,
          indicatorColor: const Color(0xFF4C0519).withValues(alpha: 0.55),
          height: 64,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: selected
                  ? const Color(0xFFFB7185)
                  : const Color(0xFF64748B),
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              size: 20,
              color: selected
                  ? const Color(0xFFFB7185)
                  : const Color(0xFF64748B),
            );
          }),
        ),
      ),
      home: HomeScreen(
        settings: _settings,
        onSettingsUpdated: _handleSettingsUpdated,
      ),
    );
  }
}

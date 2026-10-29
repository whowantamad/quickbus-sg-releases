import 'package:flutter/material.dart';
import '../services/favorites_service.dart';
import '../services/transit_db_service.dart';

class SettingsSheet extends StatefulWidget {
  static const String appVersion = '1.0.15+16';

  final UserSettings settings;
  final ValueChanged<UserSettings> onSettingsUpdated;

  const SettingsSheet({
    super.key,
    required this.settings,
    required this.onSettingsUpdated,
  });

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late ThemeMode _themeMode;
  late int _autoRefresh;
  late double _textScale;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.settings.themeMode;
    _autoRefresh = widget.settings.autoRefreshSeconds;
    _textScale = widget.settings.textScale;
  }

  Future<void> _selectTheme(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    final updated = await FavoritesService.saveSettings(
      widget.settings.copyWith(
        themeMode: mode,
        autoRefreshSeconds: _autoRefresh,
        textScale: _textScale,
      ),
    );
    widget.onSettingsUpdated(updated);
  }

  Future<void> _selectAutoRefresh(int sec) async {
    setState(() => _autoRefresh = sec);
    final updated = await FavoritesService.saveSettings(
      widget.settings.copyWith(
        themeMode: _themeMode,
        autoRefreshSeconds: sec,
        textScale: _textScale,
      ),
    );
    widget.onSettingsUpdated(updated);
  }

  Future<void> _selectTextScale(double scale) async {
    setState(() => _textScale = scale);
    final updated = await FavoritesService.saveSettings(
      widget.settings.copyWith(
        themeMode: _themeMode,
        autoRefreshSeconds: _autoRefresh,
        textScale: scale,
      ),
    );
    widget.onSettingsUpdated(updated);
  }

  Future<void> _saveAll() async {
    final updated = await FavoritesService.saveSettings(
      widget.settings.copyWith(
        themeMode: _themeMode,
        autoRefreshSeconds: _autoRefresh,
        textScale: _textScale,
      ),
    );
    widget.onSettingsUpdated(updated);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF151C2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFE11D48).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'v${SettingsSheet.appVersion}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE11D48),
                          ),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 1. Theme Mode Selector
              const Text(
                'Theme Mode',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildThemeOption(
                    isDark,
                    mode: ThemeMode.light,
                    icon: Icons.light_mode_rounded,
                    label: 'Light',
                  ),
                  const SizedBox(width: 8),
                  _buildThemeOption(
                    isDark,
                    mode: ThemeMode.dark,
                    icon: Icons.dark_mode_rounded,
                    label: 'Dark',
                  ),
                  const SizedBox(width: 8),
                  _buildThemeOption(
                    isDark,
                    mode: ThemeMode.system,
                    icon: Icons.brightness_auto_rounded,
                    label: 'Auto',
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // 2. Text Size Selector
              const Text(
                'Text Size',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: const [
                  (scale: 1.0, label: 'Default', previewSize: 12.0),
                  (scale: 1.18, label: 'Large', previewSize: 14.5),
                  (scale: 1.35, label: 'Extra Large', previewSize: 17.0),
                ].map((opt) {
                  final active = (_textScale - opt.scale).abs() < 0.05;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: InkWell(
                        onTap: () => _selectTextScale(opt.scale),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 6,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? const Color(0xFFE11D48)
                                : (isDark
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Aa',
                                textScaler: TextScaler.noScaling,
                                style: TextStyle(
                                  fontSize: opt.previewSize,
                                  fontWeight: FontWeight.w800,
                                  color: active ? Colors.white : null,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                opt.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: active ? Colors.white : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),

              // 3. Auto-Refresh Interval
              const Text(
                'Auto-Refresh Interval',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [15, 30, 60, 0].map((sec) {
                  final active = _autoRefresh == sec;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: InkWell(
                        onTap: () => _selectAutoRefresh(sec),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: active
                                ? const Color(0xFFE11D48)
                                : (isDark
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            sec == 0 ? 'Off' : '${sec}s',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: active ? Colors.white : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),

              // 3. Offline Transit Database Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A).withValues(alpha: 0.7)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.storage_rounded,
                              size: 16,
                              color: Color(0xFF10B981),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Offline Transit Database',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Bundled Ready',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${TransitDbService.stopCount} Bus Stops · ${TransitDbService.routeCount} Routes (${TransitDbService.versionHash})',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE11D48),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _saveAll,
                  child: const Text(
                    'Save Settings',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeOption(
    bool isDark, {
    required ThemeMode mode,
    required IconData icon,
    required String label,
  }) {
    final active = _themeMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () => _selectTheme(mode),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFFE11D48)
                : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: active ? Colors.white : null,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: active ? Colors.white : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

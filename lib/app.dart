import 'package:flutter/material.dart';

import 'models/reader_settings.dart';
import 'screens/library_screen.dart';
import 'services/settings_controller.dart';

/// Makes [SettingsController] accessible anywhere in the widget tree.
class SettingsControllerScope extends InheritedNotifier<SettingsController> {
  const SettingsControllerScope({
    super.key,
    required SettingsController controller,
    required super.child,
  }) : super(notifier: controller);

  static SettingsController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<SettingsControllerScope>();
    assert(scope != null, 'No SettingsControllerScope found in widget tree');
    return scope!.notifier!;
  }
}

class BookAiApp extends StatefulWidget {
  final SettingsController? settingsController;

  const BookAiApp({super.key, this.settingsController});

  @override
  State<BookAiApp> createState() => _BookAiAppState();
}

class _BookAiAppState extends State<BookAiApp> {
  static const List<double> _nightModeColorMatrix = <double>[
    0.68,
    0.06,
    0,
    0,
    0,
    0,
    0.50,
    0,
    0,
    0,
    0,
    0,
    0.10,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
  static const ValueKey<String> _nightModeFilterKey =
      ValueKey<String>('app-night-mode-filter');

  late final SettingsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.settingsController ?? SettingsController();
    _controller.load();
  }

  @override
  void dispose() {
    if (widget.settingsController == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      useMaterial3: true,
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.indigo,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      brightness: Brightness.dark,
    );
  }

  ThemeData _buildSepiaTheme() {
    const sepiaBackground = Color(0xFFF5E6C8);
    const sepiaOnBackground = Color(0xFF3B2A1A);
    const sepiaSurface = Color(0xFFEDD9A3);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF795548),
        onPrimary: Colors.white,
        secondary: Color(0xFFA1887F),
        onSecondary: Colors.white,
        surface: sepiaSurface,
        onSurface: sepiaOnBackground,
        surfaceContainerHighest: sepiaBackground,
      ),
      scaffoldBackgroundColor: sepiaBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFD7B987),
        foregroundColor: sepiaOnBackground,
        elevation: 0,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: sepiaOnBackground),
        bodyLarge: TextStyle(color: sepiaOnBackground),
      ),
    );
  }

  ThemeMode _materialThemeMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
      case AppThemeMode.sepia:
        return ThemeMode.light;
      case AppThemeMode.dark:
      case AppThemeMode.night:
        return ThemeMode.dark;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lightTheme = _buildLightTheme();
    final darkTheme = _buildDarkTheme();

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final themeMode = _controller.themeMode;

        return SettingsControllerScope(
          controller: _controller,
          child: MaterialApp(
            title: 'BookAI',
            debugShowCheckedModeBanner: false,
            theme: themeMode == AppThemeMode.sepia
                ? _buildSepiaTheme()
                : lightTheme,
            darkTheme: darkTheme,
            themeMode: _materialThemeMode(themeMode),
            builder: (context, child) {
              final appChild = child ?? const SizedBox.shrink();
              if (themeMode != AppThemeMode.night) {
                return appChild;
              }

              return ColorFiltered(
                key: _nightModeFilterKey,
                colorFilter: const ColorFilter.matrix(_nightModeColorMatrix),
                child: appChild,
              );
            },
            home: const LibraryScreen(),
          ),
        );
      },
    );
  }
}

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

  ThemeData _buildTheme(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.dark:
        return ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.indigo,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          brightness: Brightness.dark,
        );
      case AppThemeMode.sepia:
        const sepiaBackground = Color(0xFFF5E6C8);
        const sepiaOnBackground = Color(0xFF3B2A1A);
        const sepiaSurface = Color(0xFFEDD9A3);
        return ThemeData(
          useMaterial3: true,
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
      case AppThemeMode.light:
      default:
        return ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return SettingsControllerScope(
          controller: _controller,
          child: MaterialApp(
            title: 'BookAI',
            theme: _buildTheme(_controller.themeMode),
            home: const LibraryScreen(),
          ),
        );
      },
    );
  }
}

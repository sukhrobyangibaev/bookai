import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bookai/models/reader_settings.dart';
import 'package:bookai/services/settings_service.dart';
import 'package:bookai/services/settings_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsService', () {
    test('load returns defaults when SharedPreferences is empty', () async {
      SharedPreferences.setMockInitialValues({});

      final service = SettingsService();
      final settings = await service.load();

      expect(settings.fontSize, ReaderSettings.defaults.fontSize);
      expect(settings.themeMode, ReaderSettings.defaults.themeMode);
    });

    test('load returns stored values', () async {
      SharedPreferences.setMockInitialValues({
        'reader_font_size': 24.0,
        'reader_theme_mode': 'dark',
      });

      final service = SettingsService();
      final settings = await service.load();

      expect(settings.fontSize, 24.0);
      expect(settings.themeMode, AppThemeMode.dark);
    });

    test('load falls back to default for unknown theme mode string', () async {
      SharedPreferences.setMockInitialValues({
        'reader_font_size': 20.0,
        'reader_theme_mode': 'invalid_theme',
      });

      final service = SettingsService();
      final settings = await service.load();

      expect(settings.fontSize, 20.0);
      expect(settings.themeMode, AppThemeMode.light);
    });

    test('saveFontSize persists value', () async {
      SharedPreferences.setMockInitialValues({});

      final service = SettingsService();
      await service.saveFontSize(22.0);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('reader_font_size'), 22.0);
    });

    test('saveThemeMode persists value', () async {
      SharedPreferences.setMockInitialValues({});

      final service = SettingsService();
      await service.saveThemeMode(AppThemeMode.sepia);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('reader_theme_mode'), 'sepia');
    });

    test('roundtrip save then load preserves values', () async {
      SharedPreferences.setMockInitialValues({});

      final service = SettingsService();
      await service.saveFontSize(14.0);
      await service.saveThemeMode(AppThemeMode.dark);

      final loaded = await service.load();

      expect(loaded.fontSize, 14.0);
      expect(loaded.themeMode, AppThemeMode.dark);
    });
  });

  group('SettingsController', () {
    test('starts with default settings', () {
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();

      expect(controller.fontSize, ReaderSettings.defaults.fontSize);
      expect(controller.themeMode, ReaderSettings.defaults.themeMode);
    });

    test('load() reads persisted settings and notifies', () async {
      SharedPreferences.setMockInitialValues({
        'reader_font_size': 26.0,
        'reader_theme_mode': 'sepia',
      });

      final controller = SettingsController();

      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      await controller.load();

      expect(controller.fontSize, 26.0);
      expect(controller.themeMode, AppThemeMode.sepia);
      expect(notifyCount, 1);
    });

    test('setFontSize updates value and notifies', () async {
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();

      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      await controller.setFontSize(20.0);

      expect(controller.fontSize, 20.0);
      expect(notifyCount, 1);
    });

    test('setFontSize skips if value unchanged', () async {
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();
      // Default is 18.0
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      await controller.setFontSize(18.0);

      expect(notifyCount, 0);
    });

    test('setThemeMode updates value and notifies', () async {
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();

      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      await controller.setThemeMode(AppThemeMode.dark);

      expect(controller.themeMode, AppThemeMode.dark);
      expect(notifyCount, 1);
    });

    test('setThemeMode skips if value unchanged', () async {
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();
      // Default is light
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      await controller.setThemeMode(AppThemeMode.light);

      expect(notifyCount, 0);
    });

    test('setFontSize persists value through service', () async {
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();
      await controller.setFontSize(28.0);

      // Verify it was persisted
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('reader_font_size'), 28.0);
    });

    test('setThemeMode persists value through service', () async {
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();
      await controller.setThemeMode(AppThemeMode.sepia);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('reader_theme_mode'), 'sepia');
    });

    test('settings getter returns current ReaderSettings', () async {
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();
      await controller.setFontSize(22.0);
      await controller.setThemeMode(AppThemeMode.dark);

      expect(controller.settings.fontSize, 22.0);
      expect(controller.settings.themeMode, AppThemeMode.dark);
    });
  });
}

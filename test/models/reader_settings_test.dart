import 'package:flutter_test/flutter_test.dart';
import 'package:bookai/models/reader_settings.dart';

void main() {
  group('ReaderSettings', () {
    test('defaults has expected values', () {
      expect(ReaderSettings.defaults.fontSize, 18.0);
      expect(ReaderSettings.defaults.themeMode, AppThemeMode.light);
    });

    test('toMap produces expected keys and values', () {
      const settings = ReaderSettings(
        fontSize: 22.0,
        themeMode: AppThemeMode.dark,
      );

      final map = settings.toMap();

      expect(map['fontSize'], 22.0);
      expect(map['themeMode'], 'dark');
    });

    test('toMap serializes sepia theme mode', () {
      const settings = ReaderSettings(
        fontSize: 16.0,
        themeMode: AppThemeMode.sepia,
      );

      final map = settings.toMap();

      expect(map['themeMode'], 'sepia');
    });

    test('fromMap reconstructs ReaderSettings correctly', () {
      final map = {
        'fontSize': 24.0,
        'themeMode': 'dark',
      };

      final settings = ReaderSettings.fromMap(map);

      expect(settings.fontSize, 24.0);
      expect(settings.themeMode, AppThemeMode.dark);
    });

    test('fromMap falls back to defaults for missing fontSize', () {
      final map = <String, dynamic>{
        'themeMode': 'sepia',
      };

      final settings = ReaderSettings.fromMap(map);

      expect(settings.fontSize, 18.0);
      expect(settings.themeMode, AppThemeMode.sepia);
    });

    test('fromMap falls back to defaults for null fontSize', () {
      final map = <String, dynamic>{
        'fontSize': null,
        'themeMode': 'light',
      };

      final settings = ReaderSettings.fromMap(map);

      expect(settings.fontSize, 18.0);
    });

    test('fromMap falls back to light for missing themeMode', () {
      final map = <String, dynamic>{
        'fontSize': 20.0,
      };

      final settings = ReaderSettings.fromMap(map);

      expect(settings.themeMode, AppThemeMode.light);
    });

    test('fromMap falls back to light for null themeMode', () {
      final map = <String, dynamic>{
        'fontSize': 20.0,
        'themeMode': null,
      };

      final settings = ReaderSettings.fromMap(map);

      expect(settings.themeMode, AppThemeMode.light);
    });

    test('fromMap falls back to light for unknown themeMode string', () {
      final map = <String, dynamic>{
        'fontSize': 20.0,
        'themeMode': 'unknown_theme',
      };

      final settings = ReaderSettings.fromMap(map);

      expect(settings.themeMode, AppThemeMode.light);
    });

    test('fromMap handles int fontSize via num.toDouble()', () {
      final map = <String, dynamic>{
        'fontSize': 20, // int, not double
        'themeMode': 'dark',
      };

      final settings = ReaderSettings.fromMap(map);

      expect(settings.fontSize, 20.0);
      expect(settings.fontSize, isA<double>());
    });

    test('fromMap with empty map returns all defaults', () {
      final settings = ReaderSettings.fromMap(<String, dynamic>{});

      expect(settings.fontSize, 18.0);
      expect(settings.themeMode, AppThemeMode.light);
    });

    test('roundtrip toMap -> fromMap preserves all fields', () {
      const original = ReaderSettings(
        fontSize: 14.0,
        themeMode: AppThemeMode.sepia,
      );

      final restored = ReaderSettings.fromMap(original.toMap());

      expect(restored, equals(original));
    });

    test('copyWith overrides specified fields only', () {
      const original = ReaderSettings(
        fontSize: 18.0,
        themeMode: AppThemeMode.light,
      );

      final modified = original.copyWith(themeMode: AppThemeMode.dark);

      expect(modified.themeMode, AppThemeMode.dark);
      expect(modified.fontSize, 18.0);
    });

    test('equality works correctly', () {
      const a = ReaderSettings(fontSize: 18.0, themeMode: AppThemeMode.light);
      const b = ReaderSettings(fontSize: 18.0, themeMode: AppThemeMode.light);
      const c = ReaderSettings(fontSize: 20.0, themeMode: AppThemeMode.light);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  group('AppThemeMode', () {
    test('has exactly three values', () {
      expect(AppThemeMode.values.length, 3);
    });

    test('name returns correct strings', () {
      expect(AppThemeMode.light.name, 'light');
      expect(AppThemeMode.dark.name, 'dark');
      expect(AppThemeMode.sepia.name, 'sepia');
    });
  });
}

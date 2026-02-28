import 'package:shared_preferences/shared_preferences.dart';

import '../models/reader_settings.dart';

class SettingsService {
  static const _keyFontSize = 'reader_font_size';
  static const _keyThemeMode = 'reader_theme_mode';

  Future<ReaderSettings> load() async {
    final prefs = await SharedPreferences.getInstance();

    final fontSize =
        prefs.getDouble(_keyFontSize) ?? ReaderSettings.defaults.fontSize;

    final themeModeStr = prefs.getString(_keyThemeMode);
    final themeMode = themeModeStr != null
        ? AppThemeMode.values.firstWhere(
            (e) => e.name == themeModeStr,
            orElse: () => ReaderSettings.defaults.themeMode,
          )
        : ReaderSettings.defaults.themeMode;

    return ReaderSettings(fontSize: fontSize, themeMode: themeMode);
  }

  Future<void> saveFontSize(double fontSize) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyFontSize, fontSize);
  }

  Future<void> saveThemeMode(AppThemeMode themeMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, themeMode.name);
  }
}

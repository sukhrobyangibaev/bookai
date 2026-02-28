import 'package:flutter/foundation.dart';

import '../models/reader_settings.dart';
import 'settings_service.dart';

class SettingsController extends ChangeNotifier {
  final SettingsService _service;

  ReaderSettings _settings = ReaderSettings.defaults;

  ReaderSettings get settings => _settings;
  double get fontSize => _settings.fontSize;
  AppThemeMode get themeMode => _settings.themeMode;

  SettingsController({SettingsService? service})
      : _service = service ?? SettingsService();

  Future<void> load() async {
    _settings = await _service.load();
    notifyListeners();
  }

  Future<void> setFontSize(double fontSize) async {
    if (_settings.fontSize == fontSize) return;
    _settings = _settings.copyWith(fontSize: fontSize);
    notifyListeners();
    await _service.saveFontSize(fontSize);
  }

  Future<void> setThemeMode(AppThemeMode themeMode) async {
    if (_settings.themeMode == themeMode) return;
    _settings = _settings.copyWith(themeMode: themeMode);
    notifyListeners();
    await _service.saveThemeMode(themeMode);
  }
}

import 'package:flutter/foundation.dart';

import '../models/reader_settings.dart';
import 'settings_service.dart';

class SettingsController extends ChangeNotifier {
  final SettingsService _service;

  ReaderSettings _settings = ReaderSettings.defaults;

  ReaderSettings get settings => _settings;
  double get fontSize => _settings.fontSize;
  AppThemeMode get themeMode => _settings.themeMode;
  String get openRouterApiKey => _settings.openRouterApiKey;
  String get openRouterModelId => _settings.openRouterModelId;

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

  Future<void> setOpenRouterApiKey(String apiKey) async {
    final normalized = apiKey.trim();
    if (_settings.openRouterApiKey == normalized) return;
    _settings = _settings.copyWith(openRouterApiKey: normalized);
    notifyListeners();
    await _service.saveOpenRouterApiKey(normalized);
  }

  Future<void> setOpenRouterModelId(String modelId) async {
    final normalized = modelId.trim();
    if (_settings.openRouterModelId == normalized) return;
    _settings = _settings.copyWith(openRouterModelId: normalized);
    notifyListeners();
    await _service.saveOpenRouterModelId(normalized);
  }
}

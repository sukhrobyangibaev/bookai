import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_feature_config.dart';
import '../models/reader_settings.dart';

class SettingsService {
  static const _keyFontSize = 'reader_font_size';
  static const _keyThemeMode = 'reader_theme_mode';
  static const _keyOpenRouterApiKey = 'reader_openrouter_api_key';
  static const _keyOpenRouterModelId = 'reader_openrouter_model_id';
  static const _keyAiFeatureConfigs = 'reader_ai_feature_configs';

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

    final openRouterApiKey = prefs.getString(_keyOpenRouterApiKey) ??
        ReaderSettings.defaults.openRouterApiKey;
    final openRouterModelId = prefs.getString(_keyOpenRouterModelId) ??
        ReaderSettings.defaults.openRouterModelId;
    final aiFeatureConfigs = _parseAiFeatureConfigsJson(
      prefs.getString(_keyAiFeatureConfigs),
    );

    return ReaderSettings.fromMap({
      'fontSize': fontSize,
      'themeMode': themeMode.name,
      'openRouterApiKey': openRouterApiKey,
      'openRouterModelId': openRouterModelId,
      'aiFeatureConfigs': aiFeatureConfigs,
    });
  }

  Future<void> saveFontSize(double fontSize) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyFontSize, fontSize);
  }

  Future<void> saveThemeMode(AppThemeMode themeMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, themeMode.name);
  }

  Future<void> saveOpenRouterApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyOpenRouterApiKey, apiKey);
  }

  Future<void> saveOpenRouterModelId(String modelId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyOpenRouterModelId, modelId);
  }

  Future<void> saveAiFeatureConfigs(
    Map<String, AiFeatureConfig> aiFeatureConfigs,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      aiFeatureConfigs.map((key, value) => MapEntry(key, value.toMap())),
    );
    await prefs.setString(_keyAiFeatureConfigs, encoded);
  }

  Map<String, dynamic>? _parseAiFeatureConfigsJson(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

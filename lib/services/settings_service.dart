import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_feature_config.dart';
import '../models/ai_model_selection.dart';
import '../models/ai_provider.dart';
import '../models/reader_settings.dart';

class SettingsService {
  static const _keyFontSize = 'reader_font_size';
  static const _keyThemeMode = 'reader_theme_mode';
  static const _keyFontFamily = 'reader_font_family';
  static const _keyReadingMode = 'reader_reading_mode';
  static const _keyOpenRouterApiKey = 'reader_openrouter_api_key';
  static const _keyGeminiApiKey = 'reader_gemini_api_key';
  static const _keyOpenRouterModelId = 'reader_openrouter_model_id';
  static const _keyOpenRouterFallbackModelId =
      'reader_openrouter_fallback_model_id';
  static const _keyOpenRouterImageModelId = 'reader_openrouter_image_model_id';
  static const _keyDefaultProvider = 'reader_ai_default_provider';
  static const _keyDefaultModelId = 'reader_ai_default_model_id';
  static const _keyFallbackProvider = 'reader_ai_fallback_provider';
  static const _keyFallbackModelId = 'reader_ai_fallback_model_id';
  static const _keyImageProvider = 'reader_ai_image_provider';
  static const _keyImageModelId = 'reader_ai_image_model_id';
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
    final fontFamilyStr = prefs.getString(_keyFontFamily);
    final fontFamily = fontFamilyStr != null
        ? ReaderFontFamily.values.firstWhere(
            (e) => e.name == fontFamilyStr,
            orElse: () => ReaderSettings.defaults.fontFamily,
          )
        : ReaderSettings.defaults.fontFamily;
    final readingModeStr = prefs.getString(_keyReadingMode);
    final readingMode = readingModeStr != null
        ? ReadingMode.values.firstWhere(
            (e) => e.name == readingModeStr,
            orElse: () => ReaderSettings.defaults.readingMode,
          )
        : ReaderSettings.defaults.readingMode;

    final openRouterApiKey = prefs.getString(_keyOpenRouterApiKey) ??
        ReaderSettings.defaults.openRouterApiKey;
    final geminiApiKey = prefs.getString(_keyGeminiApiKey) ??
        ReaderSettings.defaults.geminiApiKey;
    final defaultSelection = _loadSelection(
      prefs: prefs,
      providerKey: _keyDefaultProvider,
      modelIdKey: _keyDefaultModelId,
      legacyOpenRouterModelIdKey: _keyOpenRouterModelId,
    );
    final fallbackSelection = _loadSelection(
      prefs: prefs,
      providerKey: _keyFallbackProvider,
      modelIdKey: _keyFallbackModelId,
      legacyOpenRouterModelIdKey: _keyOpenRouterFallbackModelId,
    );
    final imageSelection = _loadSelection(
      prefs: prefs,
      providerKey: _keyImageProvider,
      modelIdKey: _keyImageModelId,
      legacyOpenRouterModelIdKey: _keyOpenRouterImageModelId,
    );
    final aiFeatureConfigs = _parseAiFeatureConfigsJson(
      prefs.getString(_keyAiFeatureConfigs),
    );

    return ReaderSettings.fromMap({
      'fontSize': fontSize,
      'themeMode': themeMode.name,
      'fontFamily': fontFamily.name,
      'readingMode': readingMode.name,
      'openRouterApiKey': openRouterApiKey,
      'geminiApiKey': geminiApiKey,
      'defaultModelSelection': defaultSelection.toMap(),
      'fallbackModelSelection': fallbackSelection.toMap(),
      'imageModelSelection': imageSelection.toMap(),
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

  Future<void> saveFontFamily(ReaderFontFamily fontFamily) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFontFamily, fontFamily.name);
  }

  Future<void> saveReadingMode(ReadingMode readingMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyReadingMode, readingMode.name);
  }

  Future<void> saveOpenRouterApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyOpenRouterApiKey, apiKey);
  }

  Future<void> saveGeminiApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGeminiApiKey, apiKey);
  }

  Future<void> saveOpenRouterModelId(String modelId) {
    return saveDefaultModelSelection(
      AiModelSelection.legacyOpenRouter(modelId),
    );
  }

  Future<void> saveDefaultModelSelection(AiModelSelection selection) async {
    final prefs = await SharedPreferences.getInstance();
    await _saveSelection(
      prefs: prefs,
      providerKey: _keyDefaultProvider,
      modelIdKey: _keyDefaultModelId,
      selection: selection,
    );
  }

  Future<void> saveFallbackModelSelection(AiModelSelection selection) async {
    final prefs = await SharedPreferences.getInstance();
    await _saveSelection(
      prefs: prefs,
      providerKey: _keyFallbackProvider,
      modelIdKey: _keyFallbackModelId,
      selection: selection,
    );
  }

  Future<void> saveOpenRouterFallbackModelId(String modelId) {
    return saveFallbackModelSelection(
      AiModelSelection.legacyOpenRouter(modelId),
    );
  }

  Future<void> saveImageModelSelection(AiModelSelection selection) async {
    final prefs = await SharedPreferences.getInstance();
    await _saveSelection(
      prefs: prefs,
      providerKey: _keyImageProvider,
      modelIdKey: _keyImageModelId,
      selection: selection,
    );
  }

  Future<void> saveOpenRouterImageModelId(String modelId) {
    return saveImageModelSelection(
      AiModelSelection.legacyOpenRouter(modelId),
    );
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

  AiModelSelection _loadSelection({
    required SharedPreferences prefs,
    required String providerKey,
    required String modelIdKey,
    required String legacyOpenRouterModelIdKey,
  }) {
    final provider = aiProviderFromStorage(prefs.getString(providerKey));
    final modelId = prefs.getString(modelIdKey)?.trim() ?? '';
    if (provider != null && modelId.isNotEmpty) {
      return AiModelSelection(provider: provider, modelId: modelId);
    }

    final legacyModelId =
        prefs.getString(legacyOpenRouterModelIdKey)?.trim() ?? '';
    return AiModelSelection.legacyOpenRouter(legacyModelId);
  }

  Future<void> _saveSelection({
    required SharedPreferences prefs,
    required String providerKey,
    required String modelIdKey,
    required AiModelSelection selection,
  }) async {
    final provider = selection.provider;
    final modelId = selection.normalizedModelId;

    if (provider == null || modelId.isEmpty) {
      await prefs.remove(providerKey);
      await prefs.remove(modelIdKey);
      return;
    }

    await prefs.setString(providerKey, provider.storageValue);
    await prefs.setString(modelIdKey, modelId);
  }
}

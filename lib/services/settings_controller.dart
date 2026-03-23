import 'package:flutter/foundation.dart';

import '../models/ai_feature.dart';
import '../models/ai_feature_config.dart';
import '../models/ai_model_selection.dart';
import '../models/ai_provider.dart';
import '../models/reader_settings.dart';
import 'settings_service.dart';

class SettingsController extends ChangeNotifier {
  final SettingsService _service;

  ReaderSettings _settings = ReaderSettings.defaults;

  ReaderSettings get settings => _settings;
  double get fontSize => _settings.fontSize;
  AppThemeMode get themeMode => _settings.themeMode;
  ReaderFontFamily get fontFamily => _settings.fontFamily;
  ReadingMode get readingMode => _settings.readingMode;
  String get openRouterApiKey => _settings.openRouterApiKey;
  String get geminiApiKey => _settings.geminiApiKey;
  AiModelSelection get defaultModelSelection => _settings.defaultModelSelection;
  AiModelSelection get fallbackModelSelection =>
      _settings.fallbackModelSelection;
  AiModelSelection get imageModelSelection => _settings.imageModelSelection;
  String get openRouterModelId => _settings.openRouterModelId;
  String get openRouterFallbackModelId => _settings.openRouterFallbackModelId;
  String get openRouterImageModelId => _settings.openRouterImageModelId;
  Map<String, AiFeatureConfig> get aiFeatureConfigs =>
      _settings.aiFeatureConfigs;

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

  Future<void> setFontFamily(ReaderFontFamily fontFamily) async {
    if (_settings.fontFamily == fontFamily) return;
    _settings = _settings.copyWith(fontFamily: fontFamily);
    notifyListeners();
    await _service.saveFontFamily(fontFamily);
  }

  Future<void> setReadingMode(ReadingMode readingMode) async {
    if (_settings.readingMode == readingMode) return;
    _settings = _settings.copyWith(readingMode: readingMode);
    notifyListeners();
    await _service.saveReadingMode(readingMode);
  }

  Future<void> setOpenRouterApiKey(String apiKey) async {
    final normalized = apiKey.trim();
    if (_settings.openRouterApiKey == normalized) return;
    _settings = _settings.copyWith(openRouterApiKey: normalized);
    notifyListeners();
    await _service.saveOpenRouterApiKey(normalized);
  }

  Future<void> setGeminiApiKey(String apiKey) async {
    final normalized = apiKey.trim();
    if (_settings.geminiApiKey == normalized) return;
    _settings = _settings.copyWith(geminiApiKey: normalized);
    notifyListeners();
    await _service.saveGeminiApiKey(normalized);
  }

  Future<void> setDefaultModelSelection(AiModelSelection selection) async {
    final normalized = _normalizeSelection(selection);
    if (_settings.defaultModelSelection == normalized) return;
    _settings = _settings.copyWith(defaultModelSelection: normalized);
    notifyListeners();
    await _service.saveDefaultModelSelection(normalized);
  }

  Future<void> setOpenRouterModelId(String modelId) {
    return setDefaultModelSelection(
      AiModelSelection.legacyOpenRouter(modelId),
    );
  }

  Future<void> setFallbackModelSelection(AiModelSelection selection) async {
    final normalized = _normalizeSelection(selection);
    if (_settings.fallbackModelSelection == normalized) return;
    _settings = _settings.copyWith(fallbackModelSelection: normalized);
    notifyListeners();
    await _service.saveFallbackModelSelection(normalized);
  }

  Future<void> setOpenRouterFallbackModelId(String modelId) {
    return setFallbackModelSelection(
      AiModelSelection.legacyOpenRouter(modelId),
    );
  }

  Future<void> setImageModelSelection(AiModelSelection selection) async {
    final normalized = _normalizeSelection(selection);
    if (_settings.imageModelSelection == normalized) return;
    _settings = _settings.copyWith(imageModelSelection: normalized);
    notifyListeners();
    await _service.saveImageModelSelection(normalized);
  }

  Future<void> setOpenRouterImageModelId(String modelId) {
    return setImageModelSelection(
      AiModelSelection.legacyOpenRouter(modelId),
    );
  }

  AiFeatureConfig aiFeatureConfig(String featureId) {
    return _settings.aiFeatureConfigs[featureId] ??
        defaultAiFeatureConfigs[featureId] ??
        const AiFeatureConfig(promptTemplate: '');
  }

  AiModelSelection effectiveModelSelectionForFeature(String featureId) {
    final override = aiFeatureConfig(featureId).modelOverride;
    if (override.isConfigured) return override;
    return defaultModelSelection;
  }

  String effectiveModelIdForFeature(String featureId) {
    return effectiveModelSelectionForFeature(featureId).normalizedModelId;
  }

  String apiKeyForProvider(AiProvider provider) {
    switch (provider) {
      case AiProvider.openRouter:
        return openRouterApiKey.trim();
      case AiProvider.gemini:
        return geminiApiKey.trim();
    }
  }

  Future<void> setAiFeatureConfig(
    String featureId,
    AiFeatureConfig config,
  ) async {
    final feature = aiFeatureById(featureId);
    if (feature == null) return;

    final normalizedModelOverride = _normalizeSelection(config.modelOverride);
    final promptTemplate = config.promptTemplate.trim().isEmpty
        ? feature.defaultPromptTemplate
        : config.promptTemplate;
    final nextConfig = config.copyWith(
      modelOverride: normalizedModelOverride,
      promptTemplate: promptTemplate,
    );

    final current = aiFeatureConfig(featureId);
    if (current == nextConfig) return;

    final nextConfigs = <String, AiFeatureConfig>{
      ..._settings.aiFeatureConfigs,
      featureId: nextConfig,
    };
    _settings = _settings.copyWith(aiFeatureConfigs: nextConfigs);
    notifyListeners();
    await _service.saveAiFeatureConfigs(nextConfigs);
  }

  Future<void> resetAiFeaturePromptToDefault(String featureId) async {
    final feature = aiFeatureById(featureId);
    if (feature == null) return;

    final current = aiFeatureConfig(featureId);
    final next =
        current.copyWith(promptTemplate: feature.defaultPromptTemplate);
    await setAiFeatureConfig(featureId, next);
  }

  AiModelSelection _normalizeSelection(AiModelSelection selection) {
    final modelId = selection.normalizedModelId;
    if (selection.provider == null || modelId.isEmpty) {
      return AiModelSelection.none;
    }

    return AiModelSelection(
      provider: selection.provider,
      modelId: modelId,
    );
  }
}

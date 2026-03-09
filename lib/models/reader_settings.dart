import 'ai_feature.dart';
import 'ai_feature_config.dart';
import 'ai_model_selection.dart';
import 'ai_provider.dart';

enum AppThemeMode { light, dark, sepia }

enum ReaderFontFamily { system, literata, bitter, atkinsonHyperlegible }

extension ReaderFontFamilyX on ReaderFontFamily {
  String get label {
    switch (this) {
      case ReaderFontFamily.system:
        return 'Default';
      case ReaderFontFamily.literata:
        return 'Literata';
      case ReaderFontFamily.bitter:
        return 'Bitter';
      case ReaderFontFamily.atkinsonHyperlegible:
        return 'Atkinson Hyperlegible';
    }
  }
}

class ReaderSettings {
  final double fontSize;
  final AppThemeMode themeMode;
  final ReaderFontFamily fontFamily;
  final String openRouterApiKey;
  final String geminiApiKey;
  final AiModelSelection defaultModelSelection;
  final AiModelSelection fallbackModelSelection;
  final AiModelSelection imageModelSelection;
  final Map<String, AiFeatureConfig> aiFeatureConfigs;

  const ReaderSettings({
    required this.fontSize,
    required this.themeMode,
    this.fontFamily = ReaderFontFamily.system,
    this.openRouterApiKey = '',
    this.geminiApiKey = '',
    this.defaultModelSelection = AiModelSelection.none,
    this.fallbackModelSelection = AiModelSelection.none,
    this.imageModelSelection = AiModelSelection.none,
    this.aiFeatureConfigs = defaultAiFeatureConfigs,
  });

  static const ReaderSettings defaults = ReaderSettings(
    fontSize: 18.0,
    themeMode: AppThemeMode.light,
    fontFamily: ReaderFontFamily.system,
    openRouterApiKey: '',
    geminiApiKey: '',
    defaultModelSelection: AiModelSelection.none,
    fallbackModelSelection: AiModelSelection.none,
    imageModelSelection: AiModelSelection.none,
  );

  ReaderSettings copyWith({
    double? fontSize,
    AppThemeMode? themeMode,
    ReaderFontFamily? fontFamily,
    String? openRouterApiKey,
    String? geminiApiKey,
    AiModelSelection? defaultModelSelection,
    AiModelSelection? fallbackModelSelection,
    AiModelSelection? imageModelSelection,
    Map<String, AiFeatureConfig>? aiFeatureConfigs,
  }) {
    return ReaderSettings(
      fontSize: fontSize ?? this.fontSize,
      themeMode: themeMode ?? this.themeMode,
      fontFamily: fontFamily ?? this.fontFamily,
      openRouterApiKey: openRouterApiKey ?? this.openRouterApiKey,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      defaultModelSelection:
          defaultModelSelection ?? this.defaultModelSelection,
      fallbackModelSelection:
          fallbackModelSelection ?? this.fallbackModelSelection,
      imageModelSelection: imageModelSelection ?? this.imageModelSelection,
      aiFeatureConfigs: aiFeatureConfigs ?? this.aiFeatureConfigs,
    );
  }

  String get openRouterModelId =>
      defaultModelSelection.provider == AiProvider.openRouter
          ? defaultModelSelection.normalizedModelId
          : '';

  String get openRouterFallbackModelId =>
      fallbackModelSelection.provider == AiProvider.openRouter
          ? fallbackModelSelection.normalizedModelId
          : '';

  String get openRouterImageModelId =>
      imageModelSelection.provider == AiProvider.openRouter
          ? imageModelSelection.normalizedModelId
          : '';

  Map<String, dynamic> toMap() {
    return {
      'fontSize': fontSize,
      'themeMode': themeMode.name,
      'fontFamily': fontFamily.name,
      'openRouterApiKey': openRouterApiKey,
      'geminiApiKey': geminiApiKey,
      'defaultModelSelection': defaultModelSelection.toMap(),
      'fallbackModelSelection': fallbackModelSelection.toMap(),
      'imageModelSelection': imageModelSelection.toMap(),
      'aiFeatureConfigs':
          aiFeatureConfigs.map((key, value) => MapEntry(key, value.toMap())),
    };
  }

  factory ReaderSettings.fromMap(Map<String, dynamic> map) {
    final themeModeStr = map['themeMode'] as String? ?? AppThemeMode.light.name;
    final themeMode = AppThemeMode.values.firstWhere(
      (e) => e.name == themeModeStr,
      orElse: () => AppThemeMode.light,
    );
    final fontFamilyStr =
        map['fontFamily'] as String? ?? ReaderFontFamily.system.name;
    final fontFamily = ReaderFontFamily.values.firstWhere(
      (e) => e.name == fontFamilyStr,
      orElse: () => ReaderFontFamily.system,
    );
    return ReaderSettings(
      fontSize: (map['fontSize'] as num?)?.toDouble() ?? 18.0,
      themeMode: themeMode,
      fontFamily: fontFamily,
      openRouterApiKey: map['openRouterApiKey'] as String? ?? '',
      geminiApiKey: map['geminiApiKey'] as String? ?? '',
      defaultModelSelection: _parseSelection(
        rawSelection: map['defaultModelSelection'],
        legacyModelId: map['openRouterModelId'] as String?,
      ),
      fallbackModelSelection: _parseSelection(
        rawSelection: map['fallbackModelSelection'],
        legacyModelId: map['openRouterFallbackModelId'] as String?,
      ),
      imageModelSelection: _parseSelection(
        rawSelection: map['imageModelSelection'],
        legacyModelId: map['openRouterImageModelId'] as String?,
      ),
      aiFeatureConfigs: _parseAiFeatureConfigs(map['aiFeatureConfigs']),
    );
  }

  static AiModelSelection _parseSelection({
    required dynamic rawSelection,
    required String? legacyModelId,
  }) {
    if (rawSelection is Map) {
      return AiModelSelection.fromMap(Map<String, dynamic>.from(rawSelection));
    }
    return AiModelSelection.legacyOpenRouter(legacyModelId ?? '');
  }

  static Map<String, AiFeatureConfig> _parseAiFeatureConfigs(dynamic raw) {
    final configs = <String, AiFeatureConfig>{...defaultAiFeatureConfigs};
    if (raw is! Map) return configs;

    for (final entry in raw.entries) {
      final featureId = entry.key;
      if (featureId is! String) continue;

      final feature = aiFeatureById(featureId);
      if (feature == null) continue;

      final value = entry.value;
      if (value is! Map) continue;

      final valueMap = Map<String, dynamic>.from(value);
      configs[featureId] = AiFeatureConfig.fromMap(
        valueMap,
        defaultPromptTemplate: feature.defaultPromptTemplate,
      );
    }

    return configs;
  }

  static bool _configsEqual(
    Map<String, AiFeatureConfig> a,
    Map<String, AiFeatureConfig> b,
  ) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  String toString() {
    return 'ReaderSettings(fontSize: $fontSize, themeMode: $themeMode, '
        'fontFamily: $fontFamily, '
        'openRouterApiKey: ${openRouterApiKey.isEmpty ? '<empty>' : '<redacted>'}, '
        'geminiApiKey: ${geminiApiKey.isEmpty ? '<empty>' : '<redacted>'}, '
        'defaultModelSelection: $defaultModelSelection, '
        'fallbackModelSelection: $fallbackModelSelection, '
        'imageModelSelection: $imageModelSelection, '
        'aiFeatureConfigs: ${aiFeatureConfigs.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReaderSettings &&
        other.fontSize == fontSize &&
        other.themeMode == themeMode &&
        other.fontFamily == fontFamily &&
        other.openRouterApiKey == openRouterApiKey &&
        other.geminiApiKey == geminiApiKey &&
        other.defaultModelSelection == defaultModelSelection &&
        other.fallbackModelSelection == fallbackModelSelection &&
        other.imageModelSelection == imageModelSelection &&
        _configsEqual(other.aiFeatureConfigs, aiFeatureConfigs);
  }

  @override
  int get hashCode => Object.hash(
        fontSize,
        themeMode,
        fontFamily,
        openRouterApiKey,
        geminiApiKey,
        defaultModelSelection,
        fallbackModelSelection,
        imageModelSelection,
        Object.hashAllUnordered(
          aiFeatureConfigs.entries.map(
            (entry) => Object.hash(entry.key, entry.value),
          ),
        ),
      );
}

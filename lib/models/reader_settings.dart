import 'ai_feature.dart';
import 'ai_feature_config.dart';

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
  final String openRouterModelId;
  final String openRouterFallbackModelId;
  final Map<String, AiFeatureConfig> aiFeatureConfigs;

  const ReaderSettings({
    required this.fontSize,
    required this.themeMode,
    this.fontFamily = ReaderFontFamily.system,
    this.openRouterApiKey = '',
    this.openRouterModelId = '',
    this.openRouterFallbackModelId = '',
    this.aiFeatureConfigs = defaultAiFeatureConfigs,
  });

  static const ReaderSettings defaults = ReaderSettings(
    fontSize: 18.0,
    themeMode: AppThemeMode.light,
    fontFamily: ReaderFontFamily.system,
    openRouterApiKey: '',
    openRouterModelId: '',
    openRouterFallbackModelId: '',
  );

  ReaderSettings copyWith({
    double? fontSize,
    AppThemeMode? themeMode,
    ReaderFontFamily? fontFamily,
    String? openRouterApiKey,
    String? openRouterModelId,
    String? openRouterFallbackModelId,
    Map<String, AiFeatureConfig>? aiFeatureConfigs,
  }) {
    return ReaderSettings(
      fontSize: fontSize ?? this.fontSize,
      themeMode: themeMode ?? this.themeMode,
      fontFamily: fontFamily ?? this.fontFamily,
      openRouterApiKey: openRouterApiKey ?? this.openRouterApiKey,
      openRouterModelId: openRouterModelId ?? this.openRouterModelId,
      openRouterFallbackModelId:
          openRouterFallbackModelId ?? this.openRouterFallbackModelId,
      aiFeatureConfigs: aiFeatureConfigs ?? this.aiFeatureConfigs,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fontSize': fontSize,
      'themeMode': themeMode.name,
      'fontFamily': fontFamily.name,
      'openRouterApiKey': openRouterApiKey,
      'openRouterModelId': openRouterModelId,
      'openRouterFallbackModelId': openRouterFallbackModelId,
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
      openRouterModelId: map['openRouterModelId'] as String? ?? '',
      openRouterFallbackModelId:
          map['openRouterFallbackModelId'] as String? ?? '',
      aiFeatureConfigs: _parseAiFeatureConfigs(map['aiFeatureConfigs']),
    );
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
        'openRouterModelId: $openRouterModelId, '
        'openRouterFallbackModelId: $openRouterFallbackModelId, '
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
        other.openRouterModelId == openRouterModelId &&
        other.openRouterFallbackModelId == openRouterFallbackModelId &&
        _configsEqual(other.aiFeatureConfigs, aiFeatureConfigs);
  }

  @override
  int get hashCode => Object.hash(
        fontSize,
        themeMode,
        fontFamily,
        openRouterApiKey,
        openRouterModelId,
        openRouterFallbackModelId,
        Object.hashAllUnordered(
          aiFeatureConfigs.entries.map(
            (entry) => Object.hash(entry.key, entry.value),
          ),
        ),
      );
}

import 'ai_feature.dart';
import 'ai_feature_config.dart';

enum AppThemeMode { light, dark, sepia }

class ReaderSettings {
  final double fontSize;
  final AppThemeMode themeMode;
  final String openRouterApiKey;
  final String openRouterModelId;
  final Map<String, AiFeatureConfig> aiFeatureConfigs;

  const ReaderSettings({
    required this.fontSize,
    required this.themeMode,
    this.openRouterApiKey = '',
    this.openRouterModelId = '',
    this.aiFeatureConfigs = defaultAiFeatureConfigs,
  });

  static const ReaderSettings defaults = ReaderSettings(
    fontSize: 18.0,
    themeMode: AppThemeMode.light,
    openRouterApiKey: '',
    openRouterModelId: '',
  );

  ReaderSettings copyWith({
    double? fontSize,
    AppThemeMode? themeMode,
    String? openRouterApiKey,
    String? openRouterModelId,
    Map<String, AiFeatureConfig>? aiFeatureConfigs,
  }) {
    return ReaderSettings(
      fontSize: fontSize ?? this.fontSize,
      themeMode: themeMode ?? this.themeMode,
      openRouterApiKey: openRouterApiKey ?? this.openRouterApiKey,
      openRouterModelId: openRouterModelId ?? this.openRouterModelId,
      aiFeatureConfigs: aiFeatureConfigs ?? this.aiFeatureConfigs,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fontSize': fontSize,
      'themeMode': themeMode.name,
      'openRouterApiKey': openRouterApiKey,
      'openRouterModelId': openRouterModelId,
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
    return ReaderSettings(
      fontSize: (map['fontSize'] as num?)?.toDouble() ?? 18.0,
      themeMode: themeMode,
      openRouterApiKey: map['openRouterApiKey'] as String? ?? '',
      openRouterModelId: map['openRouterModelId'] as String? ?? '',
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
        'openRouterApiKey: ${openRouterApiKey.isEmpty ? '<empty>' : '<redacted>'}, '
        'openRouterModelId: $openRouterModelId, '
        'aiFeatureConfigs: ${aiFeatureConfigs.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReaderSettings &&
        other.fontSize == fontSize &&
        other.themeMode == themeMode &&
        other.openRouterApiKey == openRouterApiKey &&
        other.openRouterModelId == openRouterModelId &&
        _configsEqual(other.aiFeatureConfigs, aiFeatureConfigs);
  }

  @override
  int get hashCode => Object.hash(
        fontSize,
        themeMode,
        openRouterApiKey,
        openRouterModelId,
        Object.hashAllUnordered(
          aiFeatureConfigs.entries.map(
            (entry) => Object.hash(entry.key, entry.value),
          ),
        ),
      );
}

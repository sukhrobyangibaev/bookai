import 'ai_model_selection.dart';

class AiFeatureConfig {
  final AiModelSelection modelOverride;
  final String promptTemplate;

  const AiFeatureConfig({
    this.modelOverride = AiModelSelection.none,
    required this.promptTemplate,
  });

  String get modelIdOverride => modelOverride.normalizedModelId;

  AiFeatureConfig copyWith({
    AiModelSelection? modelOverride,
    String? promptTemplate,
  }) {
    return AiFeatureConfig(
      modelOverride: modelOverride ?? this.modelOverride,
      promptTemplate: promptTemplate ?? this.promptTemplate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'modelOverride': modelOverride.toMap(),
      'promptTemplate': promptTemplate,
    };
  }

  factory AiFeatureConfig.fromMap(
    Map<String, dynamic> map, {
    required String defaultPromptTemplate,
  }) {
    final promptTemplate =
        (map['promptTemplate'] as String?)?.trim().isNotEmpty == true
            ? map['promptTemplate'] as String
            : defaultPromptTemplate;

    final rawModelOverride = map['modelOverride'];
    final legacyModelIdOverride =
        (map['modelIdOverride'] as String? ?? '').trim();

    return AiFeatureConfig(
      modelOverride: rawModelOverride is Map
          ? AiModelSelection.fromMap(
              Map<String, dynamic>.from(rawModelOverride))
          : AiModelSelection.legacyOpenRouter(legacyModelIdOverride),
      promptTemplate: promptTemplate,
    );
  }

  @override
  String toString() {
    return 'AiFeatureConfig(modelOverride: $modelOverride, '
        'promptTemplate: $promptTemplate)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AiFeatureConfig &&
        other.modelOverride == modelOverride &&
        other.promptTemplate == promptTemplate;
  }

  @override
  int get hashCode => Object.hash(modelOverride, promptTemplate);
}

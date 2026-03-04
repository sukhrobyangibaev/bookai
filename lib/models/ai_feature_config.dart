class AiFeatureConfig {
  final String modelIdOverride;
  final String promptTemplate;

  const AiFeatureConfig({
    this.modelIdOverride = '',
    required this.promptTemplate,
  });

  AiFeatureConfig copyWith({
    String? modelIdOverride,
    String? promptTemplate,
  }) {
    return AiFeatureConfig(
      modelIdOverride: modelIdOverride ?? this.modelIdOverride,
      promptTemplate: promptTemplate ?? this.promptTemplate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'modelIdOverride': modelIdOverride,
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

    return AiFeatureConfig(
      modelIdOverride: (map['modelIdOverride'] as String? ?? '').trim(),
      promptTemplate: promptTemplate,
    );
  }

  @override
  String toString() {
    return 'AiFeatureConfig(modelIdOverride: $modelIdOverride, '
        'promptTemplate: $promptTemplate)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AiFeatureConfig &&
        other.modelIdOverride == modelIdOverride &&
        other.promptTemplate == promptTemplate;
  }

  @override
  int get hashCode => Object.hash(modelIdOverride, promptTemplate);
}

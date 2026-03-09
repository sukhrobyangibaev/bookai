import 'ai_provider.dart';

class AiModelSelection {
  final AiProvider? provider;
  final String modelId;

  const AiModelSelection({
    this.provider,
    this.modelId = '',
  });

  static const AiModelSelection none = AiModelSelection();

  bool get isConfigured => provider != null && modelId.trim().isNotEmpty;

  String get normalizedModelId => modelId.trim();

  AiModelSelection copyWith({
    AiProvider? provider,
    bool clearProvider = false,
    String? modelId,
  }) {
    return AiModelSelection(
      provider: clearProvider ? null : (provider ?? this.provider),
      modelId: modelId ?? this.modelId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'provider': provider?.storageValue,
      'modelId': normalizedModelId,
    };
  }

  factory AiModelSelection.fromMap(Map<String, dynamic> map) {
    return AiModelSelection(
      provider: aiProviderFromStorage(map['provider'] as String?),
      modelId: (map['modelId'] as String? ?? '').trim(),
    );
  }

  factory AiModelSelection.legacyOpenRouter(String modelId) {
    final normalized = modelId.trim();
    if (normalized.isEmpty) return AiModelSelection.none;
    return AiModelSelection(
      provider: AiProvider.openRouter,
      modelId: normalized,
    );
  }

  @override
  String toString() {
    return 'AiModelSelection(provider: ${provider?.storageValue}, '
        'modelId: $modelId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AiModelSelection &&
        other.provider == provider &&
        other.normalizedModelId == normalizedModelId;
  }

  @override
  int get hashCode => Object.hash(provider, normalizedModelId);
}

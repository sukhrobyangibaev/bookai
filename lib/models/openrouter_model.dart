class OpenRouterModel {
  final String id;
  final String name;
  final String? description;
  final int? contextLength;

  const OpenRouterModel({
    required this.id,
    required this.name,
    this.description,
    this.contextLength,
  });

  String get displayName => name.trim().isEmpty ? id : name;

  factory OpenRouterModel.fromMap(Map<String, dynamic> map) {
    final id = (map['id'] as String?)?.trim();
    if (id == null || id.isEmpty) {
      throw const FormatException('OpenRouter model is missing an "id".');
    }

    final rawName = (map['name'] as String?)?.trim();
    final rawDescription = (map['description'] as String?)?.trim();
    final architecture = map['architecture'];
    final contextLengthValue = map['context_length'] ??
        (architecture is Map ? architecture['context_length'] : null);

    return OpenRouterModel(
      id: id,
      name: (rawName == null || rawName.isEmpty) ? id : rawName,
      description: (rawDescription == null || rawDescription.isEmpty)
          ? null
          : rawDescription,
      contextLength: (contextLengthValue as num?)?.toInt(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OpenRouterModel &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.contextLength == contextLength;
  }

  @override
  int get hashCode => Object.hash(id, name, description, contextLength);
}

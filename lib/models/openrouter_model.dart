class OpenRouterModel {
  final String id;
  final String name;
  final String? description;
  final int? contextLength;
  final List<String> outputModalities;

  const OpenRouterModel({
    required this.id,
    required this.name,
    this.description,
    this.contextLength,
    this.outputModalities = const <String>[],
  });

  String get displayName => name.trim().isEmpty ? id : name;
  bool get hasOutputModalityMetadata => outputModalities.isNotEmpty;
  bool get supportsImageOutput => outputModalities.contains('image');
  bool get supportsTextOutput => outputModalities.contains('text');
  bool get isLikelyImageModel {
    if (supportsImageOutput) return true;

    final searchableText =
        '$id $name ${description ?? ''}'.trim().toLowerCase();
    const imageKeywords = <String>[
      'image',
      'flux',
      'recraft',
      'seedream',
      'riverflow',
      'ideogram',
      'sourceful',
      'imagen',
      'gpt-image',
      'black-forest-labs',
      'nano banana',
    ];
    for (final keyword in imageKeywords) {
      if (searchableText.contains(keyword)) {
        return true;
      }
    }
    return false;
  }

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
    final outputModalitiesValue = map['output_modalities'] ??
        (architecture is Map ? architecture['output_modalities'] : null);

    return OpenRouterModel(
      id: id,
      name: (rawName == null || rawName.isEmpty) ? id : rawName,
      description: (rawDescription == null || rawDescription.isEmpty)
          ? null
          : rawDescription,
      contextLength: (contextLengthValue as num?)?.toInt(),
      outputModalities: _parseStringList(outputModalitiesValue),
    );
  }

  static List<String> _parseStringList(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<String>()
          .map((value) => value.trim().toLowerCase())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList(growable: false);
    }

    if (raw is String) {
      final normalized = raw.trim().toLowerCase();
      if (normalized.isEmpty) return const <String>[];
      return normalized
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList(growable: false);
    }

    return const <String>[];
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OpenRouterModel &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.contextLength == contextLength &&
        _listEquals(other.outputModalities, outputModalities);
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        description,
        contextLength,
        Object.hashAll(outputModalities),
      );

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

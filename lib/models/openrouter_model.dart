import 'ai_model_info.dart';
import 'ai_provider.dart';

enum OpenRouterModelPriceDisplayMode { textPreferred, imagePreferred }

class OpenRouterModelPricing {
  final double? prompt;
  final double? completion;
  final double? image;
  final double? request;

  const OpenRouterModelPricing({
    this.prompt,
    this.completion,
    this.image,
    this.request,
  });

  bool get hasAnyPrice =>
      prompt != null || completion != null || image != null || request != null;

  bool get hasTextPricing => prompt != null || completion != null;
  bool get hasImagePricing => image != null;

  factory OpenRouterModelPricing.fromMap(Map<String, dynamic> map) {
    return OpenRouterModelPricing(
      prompt: _parsePrice(map['prompt']),
      completion: _parsePrice(map['completion']),
      image: _parsePrice(map['image']),
      request: _parsePrice(map['request']),
    );
  }

  String? settingsLabel(OpenRouterModelPriceDisplayMode mode) {
    switch (mode) {
      case OpenRouterModelPriceDisplayMode.textPreferred:
        return _formatTextPricing() ?? _formatImagePricing();
      case OpenRouterModelPriceDisplayMode.imagePreferred:
        return _formatImagePricing() ?? _formatTextPricing();
    }
  }

  String? textPriceLabel() => _formatTextPricing();
  String? flatImagePriceLabel() => _formatImagePricing();

  String? _formatTextPricing() {
    if (!hasTextPricing) return null;

    final parts = <String>[
      if (prompt != null) 'Input: ${formatUsdPerMillionTokens(prompt!)}',
      if (completion != null)
        'Output: ${formatUsdPerMillionTokens(completion!)}',
    ];
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  String? _formatImagePricing() {
    final imagePrice = image;
    if (imagePrice == null || !_isFlatImagePrice(imagePrice)) return null;
    return 'Image: ${formatUsdPerImage(imagePrice)}';
  }

  static double? _parsePrice(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) {
      final normalized = raw.trim();
      if (normalized.isEmpty) return null;
      return double.tryParse(normalized);
    }
    return null;
  }

  static String formatUsdPerMillionTokens(double pricePerToken) {
    final pricePerMillion = pricePerToken * 1000000;
    return '\$${_formatDecimal(pricePerMillion)}/M tok';
  }

  static String formatUsdPerImage(double pricePerImage) {
    return '\$${_formatDecimal(pricePerImage)}/image';
  }

  static bool _isFlatImagePrice(double value) => value >= 0.001;

  static String _formatDecimal(double value) {
    final decimals = value >= 100
        ? 0
        : value >= 10
            ? 1
            : value >= 1
                ? 2
                : value >= 0.1
                    ? 3
                    : 4;
    return value.toStringAsFixed(decimals).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OpenRouterModelPricing &&
        other.prompt == prompt &&
        other.completion == completion &&
        other.image == image &&
        other.request == request;
  }

  @override
  int get hashCode => Object.hash(prompt, completion, image, request);
}

class OpenRouterModel {
  static const Map<String, double> _imageGenerationTokenPriceOverrides = {
    // OpenRouter model pages currently show a separate image-generation token
    // rate for these models that is not exposed by /api/v1/models.
    'google/gemini-2.5-flash-image': 0.00003,
    'google/gemini-2.5-flash-image:nitro': 0.00003,
    'google/gemini-3.1-flash-image-preview': 0.00006,
  };

  final String id;
  final String name;
  final String? description;
  final int? contextLength;
  final List<String> outputModalities;
  final OpenRouterModelPricing? pricing;

  const OpenRouterModel({
    required this.id,
    required this.name,
    this.description,
    this.contextLength,
    this.outputModalities = const <String>[],
    this.pricing,
  });

  String get displayName => name.trim().isEmpty ? id : name;
  bool get hasOutputModalityMetadata => outputModalities.isNotEmpty;
  bool get supportsImageOutput => outputModalities.contains('image');
  bool get supportsTextOutput => outputModalities.contains('text');
  String? settingsPriceLabel(OpenRouterModelPriceDisplayMode mode) {
    final pricing = this.pricing;
    if (pricing == null) return null;

    switch (mode) {
      case OpenRouterModelPriceDisplayMode.textPreferred:
        return pricing.settingsLabel(mode);
      case OpenRouterModelPriceDisplayMode.imagePreferred:
        final imageGenerationTokenPrice =
            _imageGenerationTokenPriceOverrides[id];
        if (imageGenerationTokenPrice != null) {
          return 'Image: ${OpenRouterModelPricing.formatUsdPerMillionTokens(imageGenerationTokenPrice)}';
        }

        // pricing.image in the models API is documented as image-input cost,
        // not generated-image output cost. Only show it when it looks like a
        // flat per-image price to avoid mislabeling token prices.
        final flatImagePriceLabel = pricing.flatImagePriceLabel();
        if (flatImagePriceLabel != null) return flatImagePriceLabel;

        if (supportsImageOutput) return null;
        return pricing.settingsLabel(mode);
    }
  }

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
    final pricingValue = map['pricing'];
    final pricing = pricingValue is Map
        ? OpenRouterModelPricing.fromMap(
            Map<String, dynamic>.from(pricingValue))
        : null;

    return OpenRouterModel(
      id: id,
      name: (rawName == null || rawName.isEmpty) ? id : rawName,
      description: (rawDescription == null || rawDescription.isEmpty)
          ? null
          : rawDescription,
      contextLength: (contextLengthValue as num?)?.toInt(),
      outputModalities: _parseStringList(outputModalitiesValue),
      pricing: pricing?.hasAnyPrice == true ? pricing : null,
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
        _listEquals(other.outputModalities, outputModalities) &&
        other.pricing == pricing;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        description,
        contextLength,
        Object.hashAll(outputModalities),
        pricing,
      );

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

extension OpenRouterModelX on OpenRouterModel {
  AiModelInfo toAiModelInfo() {
    return AiModelInfo(
      provider: AiProvider.openRouter,
      id: id,
      displayName: displayName,
      description: description,
      contextLength: contextLength,
      outputModalities: outputModalities,
      textPriceLabel:
          settingsPriceLabel(OpenRouterModelPriceDisplayMode.textPreferred),
      imagePriceLabel:
          settingsPriceLabel(OpenRouterModelPriceDisplayMode.imagePreferred),
    );
  }
}

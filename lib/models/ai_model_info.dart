import 'ai_provider.dart';

enum AiModelPriceDisplayMode { textPreferred, imagePreferred }

class AiModelInfo {
  final AiProvider provider;
  final String id;
  final String displayName;
  final String? description;
  final int? contextLength;
  final List<String> outputModalities;
  final String? textPriceLabel;
  final String? imagePriceLabel;

  const AiModelInfo({
    required this.provider,
    required this.id,
    required this.displayName,
    this.description,
    this.contextLength,
    this.outputModalities = const <String>[],
    this.textPriceLabel,
    this.imagePriceLabel,
  });

  bool get hasOutputModalityMetadata => outputModalities.isNotEmpty;
  bool get supportsTextOutput => outputModalities.contains('text');
  bool get supportsImageOutput => outputModalities.contains('image');

  String? settingsPriceLabel(AiModelPriceDisplayMode mode) {
    switch (mode) {
      case AiModelPriceDisplayMode.textPreferred:
        return textPriceLabel ?? imagePriceLabel;
      case AiModelPriceDisplayMode.imagePreferred:
        return imagePriceLabel ?? textPriceLabel;
    }
  }
}

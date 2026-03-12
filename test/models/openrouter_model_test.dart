import 'package:scroll/models/openrouter_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OpenRouterModel', () {
    test('fromMap parses required and optional fields', () {
      final model = OpenRouterModel.fromMap({
        'id': 'openai/gpt-4o-mini',
        'name': 'GPT-4o Mini',
        'description': 'Fast multimodal model',
        'context_length': 128000,
        'output_modalities': ['text'],
        'pricing': {
          'prompt': '0.00000015',
          'completion': '0.0000006',
        },
      });

      expect(model.id, 'openai/gpt-4o-mini');
      expect(model.name, 'GPT-4o Mini');
      expect(model.description, 'Fast multimodal model');
      expect(model.contextLength, 128000);
      expect(model.outputModalities, ['text']);
      expect(model.supportsImageOutput, isFalse);
      expect(model.pricing?.prompt, 0.00000015);
      expect(model.pricing?.completion, 0.0000006);
    });

    test('fromMap falls back to id when name is missing', () {
      final model = OpenRouterModel.fromMap({
        'id': 'anthropic/claude-3.7-sonnet',
      });

      expect(model.name, 'anthropic/claude-3.7-sonnet');
      expect(model.displayName, 'anthropic/claude-3.7-sonnet');
    });

    test('fromMap reads context length from architecture map', () {
      final model = OpenRouterModel.fromMap({
        'id': 'meta-llama/llama-3.3-70b',
        'architecture': {
          'context_length': 64000,
          'output_modalities': ['image', 'text'],
        },
      });

      expect(model.contextLength, 64000);
      expect(model.outputModalities, ['image', 'text']);
      expect(model.supportsImageOutput, isTrue);
    });

    test('fromMap reads comma-delimited output modalities', () {
      final model = OpenRouterModel.fromMap({
        'id': 'openai/gpt-image-1',
        'output_modalities': 'image, text',
      });

      expect(model.outputModalities, ['image', 'text']);
    });

    test('treats known image families as likely image models', () {
      final model = OpenRouterModel.fromMap({
        'id': 'black-forest-labs/flux.2-klein-4b',
        'name': 'FLUX.2 Klein',
      });

      expect(model.hasOutputModalityMetadata, isFalse);
      expect(model.isLikelyImageModel, isTrue);
    });

    test('fromMap reads image pricing and formats settings labels', () {
      final model = OpenRouterModel.fromMap({
        'id': 'openai/gpt-image-1',
        'output_modalities': ['image'],
        'pricing': {
          'image': '0.04',
        },
      });

      expect(model.pricing?.image, 0.04);
      expect(
        model.settingsPriceLabel(
          OpenRouterModelPriceDisplayMode.imagePreferred,
        ),
        'Image: \$0.04/image',
      );
    });

    test('image output models use curated image token price when available',
        () {
      final model = OpenRouterModel.fromMap({
        'id': 'google/gemini-3.1-flash-image-preview',
        'output_modalities': ['image', 'text'],
        'pricing': {
          'prompt': '0.0000005',
          'completion': '0.000003',
        },
      });

      expect(
        model.settingsPriceLabel(
          OpenRouterModelPriceDisplayMode.imagePreferred,
        ),
        'Image: \$60/M tok',
      );
      expect(
        model.settingsPriceLabel(
          OpenRouterModelPriceDisplayMode.textPreferred,
        ),
        'Input: \$0.5/M tok · Output: \$3/M tok',
      );
    });

    test('image output models do not fall back to text pricing in image mode',
        () {
      final model = OpenRouterModel.fromMap({
        'id': 'example/image-only-model',
        'output_modalities': ['image', 'text'],
        'pricing': {
          'prompt': '0.0000005',
          'completion': '0.000003',
          'image': '0.0000003',
        },
      });

      expect(
        model.settingsPriceLabel(
          OpenRouterModelPriceDisplayMode.imagePreferred,
        ),
        isNull,
      );
    });

    test('invalid pricing values are ignored', () {
      final model = OpenRouterModel.fromMap({
        'id': 'openai/gpt-4o-mini',
        'pricing': {
          'prompt': 'not-a-number',
          'completion': '',
        },
      });

      expect(model.pricing, isNull);
    });

    test('fromMap throws when id is missing', () {
      expect(
        () => OpenRouterModel.fromMap({'name': 'Missing ID'}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

import 'package:bookai/models/openrouter_model.dart';
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
      });

      expect(model.id, 'openai/gpt-4o-mini');
      expect(model.name, 'GPT-4o Mini');
      expect(model.description, 'Fast multimodal model');
      expect(model.contextLength, 128000);
      expect(model.outputModalities, ['text']);
      expect(model.supportsImageOutput, isFalse);
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

    test('fromMap throws when id is missing', () {
      expect(
        () => OpenRouterModel.fromMap({'name': 'Missing ID'}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

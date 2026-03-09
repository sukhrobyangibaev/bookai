import 'package:bookai/models/ai_model_selection.dart';
import 'package:bookai/models/ai_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiModelSelection', () {
    test('isConfigured requires provider and model id', () {
      expect(AiModelSelection.none.isConfigured, isFalse);
      expect(
        const AiModelSelection(provider: AiProvider.gemini).isConfigured,
        isFalse,
      );
      expect(
        const AiModelSelection(
          provider: AiProvider.gemini,
          modelId: 'gemini-2.5-flash',
        ).isConfigured,
        isTrue,
      );
    });

    test('toMap and fromMap roundtrip', () {
      const selection = AiModelSelection(
        provider: AiProvider.openRouter,
        modelId: 'openai/gpt-4o-mini',
      );

      expect(
        AiModelSelection.fromMap(selection.toMap()),
        selection,
      );
    });

    test('legacyOpenRouter creates OpenRouter selection', () {
      expect(
        AiModelSelection.legacyOpenRouter('openai/gpt-4o-mini'),
        const AiModelSelection(
          provider: AiProvider.openRouter,
          modelId: 'openai/gpt-4o-mini',
        ),
      );
    });
  });
}

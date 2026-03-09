import 'package:bookai/models/ai_feature_config.dart';
import 'package:bookai/models/ai_model_selection.dart';
import 'package:bookai/models/ai_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiFeatureConfig', () {
    test('toMap and fromMap roundtrip with provider-aware override', () {
      const config = AiFeatureConfig(
        modelOverride: AiModelSelection(
          provider: AiProvider.gemini,
          modelId: 'gemini-2.5-flash',
        ),
        promptTemplate: 'Summarize {source_text}',
      );

      final restored = AiFeatureConfig.fromMap(
        config.toMap(),
        defaultPromptTemplate: 'Default {source_text}',
      );

      expect(restored, config);
    });

    test('fromMap migrates legacy modelIdOverride values', () {
      final config = AiFeatureConfig.fromMap(
        {
          'modelIdOverride': 'openai/gpt-4o-mini',
          'promptTemplate': 'Use {source_text}',
        },
        defaultPromptTemplate: 'Default {source_text}',
      );

      expect(
        config.modelOverride,
        const AiModelSelection(
          provider: AiProvider.openRouter,
          modelId: 'openai/gpt-4o-mini',
        ),
      );
      expect(config.modelIdOverride, 'openai/gpt-4o-mini');
    });

    test('fromMap falls back to default prompt when prompt is empty', () {
      final config = AiFeatureConfig.fromMap(
        {
          'modelOverride': {
            'provider': 'gemini',
            'modelId': 'gemini-2.5-flash',
          },
          'promptTemplate': '   ',
        },
        defaultPromptTemplate: 'Default {source_text}',
      );

      expect(
        config.modelOverride,
        const AiModelSelection(
          provider: AiProvider.gemini,
          modelId: 'gemini-2.5-flash',
        ),
      );
      expect(config.promptTemplate, 'Default {source_text}');
    });
  });
}

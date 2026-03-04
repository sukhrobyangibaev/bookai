import 'package:bookai/models/ai_feature_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiFeatureConfig', () {
    test('toMap and fromMap roundtrip', () {
      const config = AiFeatureConfig(
        modelIdOverride: 'openai/gpt-4.1-mini',
        promptTemplate: 'Summarize {source_text}',
      );

      final restored = AiFeatureConfig.fromMap(
        config.toMap(),
        defaultPromptTemplate: 'Default {source_text}',
      );

      expect(restored, config);
    });

    test('fromMap falls back to default prompt when prompt is empty', () {
      final config = AiFeatureConfig.fromMap(
        {
          'modelIdOverride': 'openai/gpt-4o-mini',
          'promptTemplate': '   ',
        },
        defaultPromptTemplate: 'Default {source_text}',
      );

      expect(config.modelIdOverride, 'openai/gpt-4o-mini');
      expect(config.promptTemplate, 'Default {source_text}');
    });
  });
}

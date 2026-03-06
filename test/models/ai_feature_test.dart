import 'package:bookai/models/ai_feature.dart';
import 'package:bookai/models/ai_feature_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiFeature registry', () {
    test('registers simplify text feature', () {
      final feature = aiFeatureById(AiFeatureIds.simplifyText);

      expect(feature, isNotNull);
      expect(feature!.title, 'Simplify Text');
      expect(feature.placeholders, contains('{source_text}'));
      expect(feature.placeholders, contains('{book_title}'));
      expect(feature.placeholders, contains('{chapter_title}'));
    });

    test('provides default config for simplify text', () {
      expect(
        defaultAiFeatureConfigs[AiFeatureIds.simplifyText],
        const AiFeatureConfig(
          promptTemplate: defaultSimplifyTextPromptTemplate,
        ),
      );
    });
  });
}

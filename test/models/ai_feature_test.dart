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

    test('registers define and translate context placeholder', () {
      final feature = aiFeatureById(AiFeatureIds.defineAndTranslate);

      expect(feature, isNotNull);
      expect(feature!.placeholders, contains('{source_text}'));
      expect(feature.placeholders, contains('{context_sentence}'));
      expect(feature.placeholders, contains('{book_author}'));
    });

    test('registers ask ai feature', () {
      final feature = aiFeatureById(AiFeatureIds.askAi);

      expect(feature, isNotNull);
      expect(feature!.title, 'Ask AI');
      expect(feature.placeholders, contains('{book_title}'));
      expect(feature.placeholders, contains('{book_author}'));
      expect(feature.placeholders, contains('{chapter_title}'));
      expect(feature.placeholders, contains('{source_text}'));
      expect(feature.placeholders, contains('{user_message}'));
    });

    test('provides default config for ask ai', () {
      expect(
        defaultAiFeatureConfigs[AiFeatureIds.askAi],
        const AiFeatureConfig(
          promptTemplate: defaultAskAiPromptTemplate,
        ),
      );
    });

    test('registers generate image feature', () {
      final feature = aiFeatureById(AiFeatureIds.generateImage);

      expect(feature, isNotNull);
      expect(feature!.title, 'Generate Image');
      expect(feature.placeholders, contains('{source_text}'));
      expect(feature.placeholders, contains('{context_sentence}'));
      expect(feature.placeholders, contains('{book_author}'));
      expect(feature.placeholders, contains('{chapter_title}'));
    });

    test('provides default config for generate image', () {
      expect(
        defaultAiFeatureConfigs[AiFeatureIds.generateImage],
        const AiFeatureConfig(
          promptTemplate: defaultGenerateImagePromptTemplate,
        ),
      );
    });
  });
}

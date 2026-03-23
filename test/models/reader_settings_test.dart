import 'package:bookai/models/ai_feature.dart';
import 'package:bookai/models/ai_feature_config.dart';
import 'package:bookai/models/ai_model_selection.dart';
import 'package:bookai/models/ai_provider.dart';
import 'package:bookai/models/reader_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReaderSettings', () {
    test('defaults has expected values', () {
      expect(ReaderSettings.defaults.fontSize, 18.0);
      expect(ReaderSettings.defaults.themeMode, AppThemeMode.system);
      expect(ReaderSettings.defaults.fontFamily, ReaderFontFamily.system);
      expect(ReaderSettings.defaults.readingMode, ReadingMode.scroll);
      expect(ReaderSettings.defaults.openRouterApiKey, '');
      expect(ReaderSettings.defaults.geminiApiKey, '');
      expect(
        ReaderSettings.defaults.defaultModelSelection,
        AiModelSelection.none,
      );
      expect(
        ReaderSettings.defaults.fallbackModelSelection,
        AiModelSelection.none,
      );
      expect(
        ReaderSettings.defaults.imageModelSelection,
        AiModelSelection.none,
      );
      expect(
        ReaderSettings.defaults.aiFeatureConfigs[AiFeatureIds.resumeSummary],
        const AiFeatureConfig(
          promptTemplate: defaultResumeSummaryPromptTemplate,
        ),
      );
    });

    test('toMap produces provider-aware values', () {
      const settings = ReaderSettings(
        fontSize: 22.0,
        themeMode: AppThemeMode.dark,
        fontFamily: ReaderFontFamily.bitter,
        readingMode: ReadingMode.pageFlip,
        openRouterApiKey: 'or-key',
        geminiApiKey: 'gem-key',
        defaultModelSelection: AiModelSelection(
          provider: AiProvider.openRouter,
          modelId: 'openai/gpt-4o-mini',
        ),
        fallbackModelSelection: AiModelSelection(
          provider: AiProvider.gemini,
          modelId: 'gemini-2.5-flash',
        ),
        imageModelSelection: AiModelSelection(
          provider: AiProvider.gemini,
          modelId: 'imagen-4.0-generate-001',
        ),
      );

      final map = settings.toMap();

      expect(map['fontSize'], 22.0);
      expect(map['themeMode'], 'dark');
      expect(map['fontFamily'], 'bitter');
      expect(map['readingMode'], 'pageFlip');
      expect(map['openRouterApiKey'], 'or-key');
      expect(map['geminiApiKey'], 'gem-key');
      expect(
        map['defaultModelSelection'],
        {'provider': 'openRouter', 'modelId': 'openai/gpt-4o-mini'},
      );
      expect(
        map['fallbackModelSelection'],
        {'provider': 'gemini', 'modelId': 'gemini-2.5-flash'},
      );
      expect(
        map['imageModelSelection'],
        {'provider': 'gemini', 'modelId': 'imagen-4.0-generate-001'},
      );
    });

    test('fromMap reconstructs provider-aware settings', () {
      final settings = ReaderSettings.fromMap({
        'fontSize': 24.0,
        'themeMode': 'dark',
        'fontFamily': 'literata',
        'readingMode': 'pageFlip',
        'openRouterApiKey': 'or-key',
        'geminiApiKey': 'gem-key',
        'defaultModelSelection': {
          'provider': 'gemini',
          'modelId': 'gemini-2.5-flash',
        },
        'fallbackModelSelection': {
          'provider': 'openRouter',
          'modelId': 'anthropic/claude-3.7-sonnet',
        },
        'imageModelSelection': {
          'provider': 'gemini',
          'modelId': 'imagen-4.0-generate-001',
        },
        'aiFeatureConfigs': {
          AiFeatureIds.resumeSummary: {
            'modelOverride': {
              'provider': 'openRouter',
              'modelId': 'openai/gpt-4.1-mini',
            },
            'promptTemplate': 'Use {source_text}',
          },
        },
      });

      expect(settings.fontSize, 24.0);
      expect(settings.themeMode, AppThemeMode.dark);
      expect(settings.fontFamily, ReaderFontFamily.literata);
      expect(settings.readingMode, ReadingMode.pageFlip);
      expect(settings.openRouterApiKey, 'or-key');
      expect(settings.geminiApiKey, 'gem-key');
      expect(
        settings.defaultModelSelection,
        const AiModelSelection(
          provider: AiProvider.gemini,
          modelId: 'gemini-2.5-flash',
        ),
      );
      expect(
        settings.fallbackModelSelection,
        const AiModelSelection(
          provider: AiProvider.openRouter,
          modelId: 'anthropic/claude-3.7-sonnet',
        ),
      );
      expect(
        settings.imageModelSelection,
        const AiModelSelection(
          provider: AiProvider.gemini,
          modelId: 'imagen-4.0-generate-001',
        ),
      );
      expect(
        settings.aiFeatureConfigs[AiFeatureIds.resumeSummary],
        const AiFeatureConfig(
          modelOverride: AiModelSelection(
            provider: AiProvider.openRouter,
            modelId: 'openai/gpt-4.1-mini',
          ),
          promptTemplate: 'Use {source_text}',
        ),
      );
    });

    test('fromMap migrates legacy OpenRouter selections', () {
      final settings = ReaderSettings.fromMap({
        'openRouterApiKey': 'or-key',
        'openRouterModelId': 'openai/gpt-4o-mini',
        'openRouterFallbackModelId': 'anthropic/claude-3.7-sonnet',
        'openRouterImageModelId': 'openai/gpt-image-1',
        'aiFeatureConfigs': {
          AiFeatureIds.resumeSummary: {
            'modelIdOverride': 'openai/gpt-4.1-mini',
            'promptTemplate': 'Legacy {source_text}',
          },
        },
      });

      expect(
        settings.defaultModelSelection,
        const AiModelSelection(
          provider: AiProvider.openRouter,
          modelId: 'openai/gpt-4o-mini',
        ),
      );
      expect(
        settings.fallbackModelSelection,
        const AiModelSelection(
          provider: AiProvider.openRouter,
          modelId: 'anthropic/claude-3.7-sonnet',
        ),
      );
      expect(
        settings.imageModelSelection,
        const AiModelSelection(
          provider: AiProvider.openRouter,
          modelId: 'openai/gpt-image-1',
        ),
      );
      expect(
        settings.aiFeatureConfigs[AiFeatureIds.resumeSummary]?.modelOverride,
        const AiModelSelection(
          provider: AiProvider.openRouter,
          modelId: 'openai/gpt-4.1-mini',
        ),
      );
    });

    test('fromMap migrates the legacy ask ai default prompt', () {
      const legacyAskAiPrompt = '''
You are chatting with a reader about a book.

Book: {book_title}
Author: {book_author}
Chapter: {chapter_title}

Passage:
{source_text}

Reader question:
{user_message}

Use the provided passage as context when it is relevant, but the reader may also want to talk more generally about the book.
You may use broader knowledge about the book when it helps answer the question.
If the answer would reveal important spoilers, warn the reader before giving the spoiler-sensitive part of the answer.
Be clear, direct, and helpful.
''';

      final settings = ReaderSettings.fromMap({
        'aiFeatureConfigs': {
          AiFeatureIds.askAi: {
            'promptTemplate': legacyAskAiPrompt,
          },
        },
      });

      expect(
        settings.aiFeatureConfigs[AiFeatureIds.askAi]?.promptTemplate,
        defaultAskAiPromptTemplate,
      );
    });

    test('fromMap with empty map returns defaults', () {
      final settings = ReaderSettings.fromMap(<String, dynamic>{});

      expect(settings, ReaderSettings.defaults);
    });

    test('roundtrip toMap -> fromMap preserves all fields', () {
      const original = ReaderSettings(
        fontSize: 14.0,
        themeMode: AppThemeMode.system,
        fontFamily: ReaderFontFamily.literata,
        readingMode: ReadingMode.pageFlip,
        openRouterApiKey: 'or-key',
        geminiApiKey: 'gem-key',
        defaultModelSelection: AiModelSelection(
          provider: AiProvider.openRouter,
          modelId: 'openai/gpt-4o-mini',
        ),
        fallbackModelSelection: AiModelSelection(
          provider: AiProvider.gemini,
          modelId: 'gemini-2.5-flash',
        ),
        imageModelSelection: AiModelSelection(
          provider: AiProvider.gemini,
          modelId: 'imagen-4.0-generate-001',
        ),
      );

      final restored = ReaderSettings.fromMap(original.toMap());
      expect(restored, original);
    });

    test('copyWith overrides specified fields only', () {
      const original = ReaderSettings(
        fontSize: 18.0,
        themeMode: AppThemeMode.light,
        readingMode: ReadingMode.pageFlip,
        openRouterApiKey: 'or-key',
        geminiApiKey: 'gem-key',
        defaultModelSelection: AiModelSelection(
          provider: AiProvider.openRouter,
          modelId: 'm1',
        ),
        fallbackModelSelection: AiModelSelection(
          provider: AiProvider.gemini,
          modelId: 'fallback-1',
        ),
        imageModelSelection: AiModelSelection(
          provider: AiProvider.gemini,
          modelId: 'image-1',
        ),
      );

      final modified = original.copyWith(themeMode: AppThemeMode.dark);

      expect(modified.themeMode, AppThemeMode.dark);
      expect(modified.fontSize, 18.0);
      expect(modified.readingMode, ReadingMode.pageFlip);
      expect(modified.openRouterApiKey, 'or-key');
      expect(modified.geminiApiKey, 'gem-key');
      expect(modified.defaultModelSelection, original.defaultModelSelection);
      expect(modified.fallbackModelSelection, original.fallbackModelSelection);
      expect(modified.imageModelSelection, original.imageModelSelection);
    });

    test('equality works correctly', () {
      const a = ReaderSettings(
        fontSize: 18.0,
        themeMode: AppThemeMode.light,
        defaultModelSelection: AiModelSelection(
          provider: AiProvider.openRouter,
          modelId: 'model',
        ),
      );
      const b = ReaderSettings(
        fontSize: 18.0,
        themeMode: AppThemeMode.light,
        defaultModelSelection: AiModelSelection(
          provider: AiProvider.openRouter,
          modelId: 'model',
        ),
      );
      const c = ReaderSettings(
        fontSize: 20.0,
        themeMode: AppThemeMode.light,
        defaultModelSelection: AiModelSelection(
          provider: AiProvider.openRouter,
          modelId: 'model',
        ),
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  group('AppThemeMode', () {
    test('has exactly four values', () {
      expect(AppThemeMode.values.length, 4);
    });
  });

  group('ReaderFontFamily', () {
    test('label returns expected strings', () {
      expect(ReaderFontFamily.system.label, 'Default');
      expect(ReaderFontFamily.literata.label, 'Literata');
      expect(ReaderFontFamily.bitter.label, 'Bitter');
      expect(
        ReaderFontFamily.atkinsonHyperlegible.label,
        'Atkinson Hyperlegible',
      );
    });
  });

  group('ReadingMode', () {
    test('has exactly two values', () {
      expect(ReadingMode.values.length, 2);
    });

    test('label returns expected strings', () {
      expect(ReadingMode.scroll.label, 'Scroll');
      expect(ReadingMode.pageFlip.label, 'Page Flip');
    });
  });
}

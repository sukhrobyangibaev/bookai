import 'package:bookai/models/ai_feature.dart';
import 'package:bookai/models/ai_feature_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bookai/models/reader_settings.dart';

void main() {
  group('ReaderSettings', () {
    test('defaults has expected values', () {
      expect(ReaderSettings.defaults.fontSize, 18.0);
      expect(ReaderSettings.defaults.themeMode, AppThemeMode.light);
      expect(ReaderSettings.defaults.fontFamily, ReaderFontFamily.system);
      expect(ReaderSettings.defaults.openRouterApiKey, '');
      expect(ReaderSettings.defaults.openRouterModelId, '');
      expect(ReaderSettings.defaults.openRouterFallbackModelId, '');
      expect(
        ReaderSettings.defaults.aiFeatureConfigs[AiFeatureIds.resumeSummary],
        const AiFeatureConfig(
          promptTemplate: defaultResumeSummaryPromptTemplate,
        ),
      );
      expect(
        ReaderSettings
            .defaults.aiFeatureConfigs[AiFeatureIds.defineAndTranslate],
        const AiFeatureConfig(
          promptTemplate: defaultDefineAndTranslatePromptTemplate,
        ),
      );
      expect(
        ReaderSettings.defaults.aiFeatureConfigs[AiFeatureIds.simplifyText],
        const AiFeatureConfig(
          promptTemplate: defaultSimplifyTextPromptTemplate,
        ),
      );
    });

    test('toMap produces expected keys and values', () {
      const settings = ReaderSettings(
        fontSize: 22.0,
        themeMode: AppThemeMode.dark,
        openRouterApiKey: 'test-key',
        openRouterModelId: 'openai/gpt-4o-mini',
        openRouterFallbackModelId: 'anthropic/claude-3.7-sonnet',
      );

      final map = settings.toMap();

      expect(map['fontSize'], 22.0);
      expect(map['themeMode'], 'dark');
      expect(map['fontFamily'], 'system');
      expect(map['openRouterApiKey'], 'test-key');
      expect(map['openRouterModelId'], 'openai/gpt-4o-mini');
      expect(
        map['openRouterFallbackModelId'],
        'anthropic/claude-3.7-sonnet',
      );
      expect(
        map['aiFeatureConfigs'][AiFeatureIds.resumeSummary]['promptTemplate'],
        defaultResumeSummaryPromptTemplate,
      );
      expect(
        map['aiFeatureConfigs'][AiFeatureIds.defineAndTranslate]
            ['promptTemplate'],
        defaultDefineAndTranslatePromptTemplate,
      );
      expect(
        map['aiFeatureConfigs'][AiFeatureIds.simplifyText]['promptTemplate'],
        defaultSimplifyTextPromptTemplate,
      );
    });

    test('toMap serializes sepia theme mode', () {
      const settings = ReaderSettings(
        fontSize: 16.0,
        themeMode: AppThemeMode.sepia,
      );

      final map = settings.toMap();

      expect(map['themeMode'], 'sepia');
    });

    test('fromMap reconstructs ReaderSettings correctly', () {
      final map = {
        'fontSize': 24.0,
        'themeMode': 'dark',
        'fontFamily': 'bitter',
        'openRouterApiKey': 'abc123',
        'openRouterModelId': 'anthropic/claude-3.5-sonnet',
        'openRouterFallbackModelId': 'openai/gpt-4.1-mini',
        'aiFeatureConfigs': {
          AiFeatureIds.resumeSummary: {
            'modelIdOverride': 'openai/gpt-4.1-mini',
            'promptTemplate': 'Use {source_text}',
          },
        },
      };

      final settings = ReaderSettings.fromMap(map);

      expect(settings.fontSize, 24.0);
      expect(settings.themeMode, AppThemeMode.dark);
      expect(settings.fontFamily, ReaderFontFamily.bitter);
      expect(settings.openRouterApiKey, 'abc123');
      expect(settings.openRouterModelId, 'anthropic/claude-3.5-sonnet');
      expect(settings.openRouterFallbackModelId, 'openai/gpt-4.1-mini');
      expect(
        settings.aiFeatureConfigs[AiFeatureIds.resumeSummary],
        const AiFeatureConfig(
          modelIdOverride: 'openai/gpt-4.1-mini',
          promptTemplate: 'Use {source_text}',
        ),
      );
      expect(
        settings.aiFeatureConfigs[AiFeatureIds.defineAndTranslate],
        const AiFeatureConfig(
          promptTemplate: defaultDefineAndTranslatePromptTemplate,
        ),
      );
      expect(
        settings.aiFeatureConfigs[AiFeatureIds.simplifyText],
        const AiFeatureConfig(
          promptTemplate: defaultSimplifyTextPromptTemplate,
        ),
      );
    });

    test('fromMap falls back to defaults for missing fontSize', () {
      final map = <String, dynamic>{
        'themeMode': 'sepia',
      };

      final settings = ReaderSettings.fromMap(map);

      expect(settings.fontSize, 18.0);
      expect(settings.themeMode, AppThemeMode.sepia);
      expect(settings.fontFamily, ReaderFontFamily.system);
    });

    test('fromMap falls back to defaults for null fontSize', () {
      final map = <String, dynamic>{
        'fontSize': null,
        'themeMode': 'light',
      };

      final settings = ReaderSettings.fromMap(map);

      expect(settings.fontSize, 18.0);
    });

    test('fromMap falls back to light for missing themeMode', () {
      final map = <String, dynamic>{
        'fontSize': 20.0,
      };

      final settings = ReaderSettings.fromMap(map);

      expect(settings.themeMode, AppThemeMode.light);
    });

    test('fromMap falls back to system for unknown fontFamily string', () {
      final map = <String, dynamic>{
        'fontSize': 20.0,
        'fontFamily': 'unknown_font',
      };

      final settings = ReaderSettings.fromMap(map);

      expect(settings.fontFamily, ReaderFontFamily.system);
    });

    test('fromMap falls back to light for null themeMode', () {
      final map = <String, dynamic>{
        'fontSize': 20.0,
        'themeMode': null,
      };

      final settings = ReaderSettings.fromMap(map);

      expect(settings.themeMode, AppThemeMode.light);
    });

    test('fromMap falls back to light for unknown themeMode string', () {
      final map = <String, dynamic>{
        'fontSize': 20.0,
        'themeMode': 'unknown_theme',
      };

      final settings = ReaderSettings.fromMap(map);

      expect(settings.themeMode, AppThemeMode.light);
    });

    test('fromMap handles int fontSize via num.toDouble()', () {
      final map = <String, dynamic>{
        'fontSize': 20, // int, not double
        'themeMode': 'dark',
      };

      final settings = ReaderSettings.fromMap(map);

      expect(settings.fontSize, 20.0);
      expect(settings.fontSize, isA<double>());
    });

    test('fromMap with empty map returns all defaults', () {
      final settings = ReaderSettings.fromMap(<String, dynamic>{});

      expect(settings.fontSize, 18.0);
      expect(settings.themeMode, AppThemeMode.light);
      expect(settings.fontFamily, ReaderFontFamily.system);
      expect(settings.openRouterApiKey, '');
      expect(settings.openRouterModelId, '');
      expect(settings.openRouterFallbackModelId, '');
      expect(
        settings.aiFeatureConfigs[AiFeatureIds.resumeSummary],
        const AiFeatureConfig(
          promptTemplate: defaultResumeSummaryPromptTemplate,
        ),
      );
      expect(
        settings.aiFeatureConfigs[AiFeatureIds.defineAndTranslate],
        const AiFeatureConfig(
          promptTemplate: defaultDefineAndTranslatePromptTemplate,
        ),
      );
      expect(
        settings.aiFeatureConfigs[AiFeatureIds.simplifyText],
        const AiFeatureConfig(
          promptTemplate: defaultSimplifyTextPromptTemplate,
        ),
      );
    });

    test('roundtrip toMap -> fromMap preserves all fields', () {
      const original = ReaderSettings(
        fontSize: 14.0,
        themeMode: AppThemeMode.sepia,
        fontFamily: ReaderFontFamily.literata,
        openRouterApiKey: 'my-key',
        openRouterModelId: 'openai/gpt-4.1-mini',
        openRouterFallbackModelId: 'anthropic/claude-3.7-sonnet',
      );

      final restored = ReaderSettings.fromMap(original.toMap());

      expect(restored, equals(original));
    });

    test('copyWith overrides specified fields only', () {
      const original = ReaderSettings(
        fontSize: 18.0,
        themeMode: AppThemeMode.light,
        openRouterApiKey: 'k1',
        openRouterModelId: 'm1',
        openRouterFallbackModelId: 'fallback-1',
      );

      final modified = original.copyWith(themeMode: AppThemeMode.dark);

      expect(modified.themeMode, AppThemeMode.dark);
      expect(modified.fontSize, 18.0);
      expect(modified.fontFamily, ReaderFontFamily.system);
      expect(modified.openRouterApiKey, 'k1');
      expect(modified.openRouterModelId, 'm1');
      expect(modified.openRouterFallbackModelId, 'fallback-1');
      expect(
        modified.aiFeatureConfigs,
        original.aiFeatureConfigs,
      );
    });

    test('copyWith overrides fontFamily', () {
      const original = ReaderSettings(
        fontSize: 18.0,
        themeMode: AppThemeMode.light,
      );

      final modified = original.copyWith(
        fontFamily: ReaderFontFamily.atkinsonHyperlegible,
      );

      expect(
        modified.fontFamily,
        ReaderFontFamily.atkinsonHyperlegible,
      );
    });

    test('copyWith overrides aiFeatureConfigs', () {
      const original = ReaderSettings(
        fontSize: 18.0,
        themeMode: AppThemeMode.light,
      );

      final modified = original.copyWith(
        aiFeatureConfigs: const {
          AiFeatureIds.resumeSummary: AiFeatureConfig(
            promptTemplate: 'Custom {source_text}',
          ),
          AiFeatureIds.defineAndTranslate: AiFeatureConfig(
            promptTemplate: 'Define {source_text} and translate it.',
          ),
        },
      );

      expect(
        modified.aiFeatureConfigs[AiFeatureIds.resumeSummary],
        const AiFeatureConfig(promptTemplate: 'Custom {source_text}'),
      );
      expect(
        modified.aiFeatureConfigs[AiFeatureIds.defineAndTranslate],
        const AiFeatureConfig(
          promptTemplate: 'Define {source_text} and translate it.',
        ),
      );
    });

    test('equality works correctly', () {
      const a = ReaderSettings(
        fontSize: 18.0,
        themeMode: AppThemeMode.light,
        openRouterApiKey: 'key',
        openRouterModelId: 'model',
        openRouterFallbackModelId: 'fallback',
      );
      const b = ReaderSettings(
        fontSize: 18.0,
        themeMode: AppThemeMode.light,
        openRouterApiKey: 'key',
        openRouterModelId: 'model',
        openRouterFallbackModelId: 'fallback',
      );
      const c = ReaderSettings(
        fontSize: 20.0,
        themeMode: AppThemeMode.light,
        openRouterApiKey: 'key',
        openRouterModelId: 'model',
        openRouterFallbackModelId: 'fallback',
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  group('AppThemeMode', () {
    test('has exactly three values', () {
      expect(AppThemeMode.values.length, 3);
    });

    test('name returns correct strings', () {
      expect(AppThemeMode.light.name, 'light');
      expect(AppThemeMode.dark.name, 'dark');
      expect(AppThemeMode.sepia.name, 'sepia');
    });
  });

  group('ReaderFontFamily', () {
    test('has exactly four values', () {
      expect(ReaderFontFamily.values.length, 4);
    });

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
}

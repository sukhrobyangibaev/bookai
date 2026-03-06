import 'package:bookai/models/ai_feature.dart';
import 'package:bookai/models/ai_feature_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bookai/models/reader_settings.dart';
import 'package:bookai/services/settings_service.dart';
import 'package:bookai/services/settings_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsService', () {
    test('load returns defaults when SharedPreferences is empty', () async {
      SharedPreferences.setMockInitialValues({});

      final service = SettingsService();
      final settings = await service.load();

      expect(settings.fontSize, ReaderSettings.defaults.fontSize);
      expect(settings.themeMode, ReaderSettings.defaults.themeMode);
      expect(settings.fontFamily, ReaderSettings.defaults.fontFamily);
      expect(
          settings.openRouterApiKey, ReaderSettings.defaults.openRouterApiKey);
      expect(
        settings.openRouterModelId,
        ReaderSettings.defaults.openRouterModelId,
      );
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
    });

    test('load returns stored values', () async {
      SharedPreferences.setMockInitialValues({
        'reader_font_size': 24.0,
        'reader_theme_mode': 'dark',
        'reader_font_family': 'literata',
        'reader_openrouter_api_key': 'stored-key',
        'reader_openrouter_model_id': 'openai/gpt-4.1-mini',
        'reader_ai_feature_configs':
            '{"resume_summary":{"modelIdOverride":"openai/gpt-4o-mini","promptTemplate":"Use {source_text}"}}',
      });

      final service = SettingsService();
      final settings = await service.load();

      expect(settings.fontSize, 24.0);
      expect(settings.themeMode, AppThemeMode.dark);
      expect(settings.fontFamily, ReaderFontFamily.literata);
      expect(settings.openRouterApiKey, 'stored-key');
      expect(settings.openRouterModelId, 'openai/gpt-4.1-mini');
      expect(
        settings.aiFeatureConfigs[AiFeatureIds.resumeSummary],
        const AiFeatureConfig(
          modelIdOverride: 'openai/gpt-4o-mini',
          promptTemplate: 'Use {source_text}',
        ),
      );
      expect(
        settings.aiFeatureConfigs[AiFeatureIds.defineAndTranslate],
        const AiFeatureConfig(
          promptTemplate: defaultDefineAndTranslatePromptTemplate,
        ),
      );
    });

    test('load falls back to default for unknown theme mode string', () async {
      SharedPreferences.setMockInitialValues({
        'reader_font_size': 20.0,
        'reader_theme_mode': 'invalid_theme',
      });

      final service = SettingsService();
      final settings = await service.load();

      expect(settings.fontSize, 20.0);
      expect(settings.themeMode, AppThemeMode.light);
    });

    test('load falls back to default for unknown font family string', () async {
      SharedPreferences.setMockInitialValues({
        'reader_font_family': 'invalid_font_family',
      });

      final service = SettingsService();
      final settings = await service.load();

      expect(settings.fontFamily, ReaderFontFamily.system);
    });

    test('saveOpenRouterApiKey persists value', () async {
      SharedPreferences.setMockInitialValues({});

      final service = SettingsService();
      await service.saveOpenRouterApiKey('secret-key');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('reader_openrouter_api_key'), 'secret-key');
    });

    test('saveOpenRouterModelId persists value', () async {
      SharedPreferences.setMockInitialValues({});

      final service = SettingsService();
      await service.saveOpenRouterModelId('anthropic/claude-3.7-sonnet');

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('reader_openrouter_model_id'),
        'anthropic/claude-3.7-sonnet',
      );
    });

    test('saveAiFeatureConfigs persists JSON', () async {
      SharedPreferences.setMockInitialValues({});

      final service = SettingsService();
      await service.saveAiFeatureConfigs(const {
        AiFeatureIds.resumeSummary: AiFeatureConfig(
          modelIdOverride: 'openai/gpt-4o-mini',
          promptTemplate: 'Summarize {source_text}',
        ),
        AiFeatureIds.defineAndTranslate: AiFeatureConfig(
          promptTemplate: 'Define {source_text} and translate it into Spanish.',
        ),
      });

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('reader_ai_feature_configs');
      expect(raw, isNotNull);
      expect(raw, contains('resume_summary'));
      expect(raw, contains('define_and_translate'));
      expect(raw, contains('openai/gpt-4o-mini'));
    });

    test('saveFontSize persists value', () async {
      SharedPreferences.setMockInitialValues({});

      final service = SettingsService();
      await service.saveFontSize(22.0);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('reader_font_size'), 22.0);
    });

    test('saveThemeMode persists value', () async {
      SharedPreferences.setMockInitialValues({});

      final service = SettingsService();
      await service.saveThemeMode(AppThemeMode.sepia);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('reader_theme_mode'), 'sepia');
    });

    test('saveFontFamily persists value', () async {
      SharedPreferences.setMockInitialValues({});

      final service = SettingsService();
      await service.saveFontFamily(ReaderFontFamily.atkinsonHyperlegible);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('reader_font_family'),
        'atkinsonHyperlegible',
      );
    });

    test('roundtrip save then load preserves values', () async {
      SharedPreferences.setMockInitialValues({});

      final service = SettingsService();
      await service.saveFontSize(14.0);
      await service.saveThemeMode(AppThemeMode.dark);
      await service.saveFontFamily(ReaderFontFamily.bitter);
      await service.saveOpenRouterApiKey('key-roundtrip');
      await service.saveOpenRouterModelId('openai/gpt-4o-mini');
      await service.saveAiFeatureConfigs(const {
        AiFeatureIds.resumeSummary: AiFeatureConfig(
          modelIdOverride: 'openai/gpt-4.1-mini',
          promptTemplate: 'Roundtrip {source_text}',
        ),
      });

      final loaded = await service.load();

      expect(loaded.fontSize, 14.0);
      expect(loaded.themeMode, AppThemeMode.dark);
      expect(loaded.fontFamily, ReaderFontFamily.bitter);
      expect(loaded.openRouterApiKey, 'key-roundtrip');
      expect(loaded.openRouterModelId, 'openai/gpt-4o-mini');
      expect(
        loaded.aiFeatureConfigs[AiFeatureIds.resumeSummary],
        const AiFeatureConfig(
          modelIdOverride: 'openai/gpt-4.1-mini',
          promptTemplate: 'Roundtrip {source_text}',
        ),
      );
      expect(
        loaded.aiFeatureConfigs[AiFeatureIds.defineAndTranslate],
        const AiFeatureConfig(
          promptTemplate: defaultDefineAndTranslatePromptTemplate,
        ),
      );
    });
  });

  group('SettingsController', () {
    test('starts with default settings', () {
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();

      expect(controller.fontSize, ReaderSettings.defaults.fontSize);
      expect(controller.themeMode, ReaderSettings.defaults.themeMode);
      expect(controller.fontFamily, ReaderSettings.defaults.fontFamily);
      expect(controller.openRouterApiKey,
          ReaderSettings.defaults.openRouterApiKey);
      expect(
        controller.openRouterModelId,
        ReaderSettings.defaults.openRouterModelId,
      );
    });

    test('load() reads persisted settings and notifies', () async {
      SharedPreferences.setMockInitialValues({
        'reader_font_size': 26.0,
        'reader_theme_mode': 'sepia',
        'reader_font_family': 'atkinsonHyperlegible',
        'reader_openrouter_api_key': 'abc',
        'reader_openrouter_model_id': 'openai/gpt-4.1',
        'reader_ai_feature_configs':
            '{"resume_summary":{"modelIdOverride":"openai/gpt-4.1-mini","promptTemplate":"Loaded {source_text}"}}',
      });

      final controller = SettingsController();

      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      await controller.load();

      expect(controller.fontSize, 26.0);
      expect(controller.themeMode, AppThemeMode.sepia);
      expect(controller.fontFamily, ReaderFontFamily.atkinsonHyperlegible);
      expect(controller.openRouterApiKey, 'abc');
      expect(controller.openRouterModelId, 'openai/gpt-4.1');
      expect(
        controller.aiFeatureConfig(AiFeatureIds.resumeSummary),
        const AiFeatureConfig(
          modelIdOverride: 'openai/gpt-4.1-mini',
          promptTemplate: 'Loaded {source_text}',
        ),
      );
      expect(
        controller.aiFeatureConfig(AiFeatureIds.defineAndTranslate),
        const AiFeatureConfig(
          promptTemplate: defaultDefineAndTranslatePromptTemplate,
        ),
      );
      expect(notifyCount, 1);
    });

    test('setFontSize updates value and notifies', () async {
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();

      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      await controller.setFontSize(20.0);

      expect(controller.fontSize, 20.0);
      expect(notifyCount, 1);
    });

    test('setFontSize skips if value unchanged', () async {
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();
      // Default is 18.0
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      await controller.setFontSize(18.0);

      expect(notifyCount, 0);
    });

    test('setThemeMode updates value and notifies', () async {
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();

      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      await controller.setThemeMode(AppThemeMode.dark);

      expect(controller.themeMode, AppThemeMode.dark);
      expect(notifyCount, 1);
    });

    test('setFontFamily updates value and notifies', () async {
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();

      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      await controller.setFontFamily(ReaderFontFamily.literata);

      expect(controller.fontFamily, ReaderFontFamily.literata);
      expect(notifyCount, 1);
    });

    test('setFontFamily skips if value unchanged', () async {
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      await controller.setFontFamily(ReaderFontFamily.system);

      expect(notifyCount, 0);
    });

    test('setThemeMode skips if value unchanged', () async {
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();
      // Default is light
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      await controller.setThemeMode(AppThemeMode.light);

      expect(notifyCount, 0);
    });

    test('setOpenRouterApiKey updates value and notifies', () async {
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();

      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      await controller.setOpenRouterApiKey('abc123');

      expect(controller.openRouterApiKey, 'abc123');
      expect(notifyCount, 1);
    });

    test('setOpenRouterApiKey trims and skips unchanged', () async {
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();
      await controller.setOpenRouterApiKey('trimmed');

      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      await controller.setOpenRouterApiKey('  trimmed  ');

      expect(controller.openRouterApiKey, 'trimmed');
      expect(notifyCount, 0);
    });

    test('setOpenRouterModelId updates value and notifies', () async {
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();

      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      await controller.setOpenRouterModelId('openai/gpt-4.1-mini');

      expect(controller.openRouterModelId, 'openai/gpt-4.1-mini');
      expect(notifyCount, 1);
    });

    test('setOpenRouterModelId skips unchanged value', () async {
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();
      await controller.setOpenRouterModelId('openai/gpt-4.1-mini');

      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      await controller.setOpenRouterModelId('openai/gpt-4.1-mini');

      expect(notifyCount, 0);
    });

    test('setFontSize persists value through service', () async {
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();
      await controller.setFontSize(28.0);

      // Verify it was persisted
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('reader_font_size'), 28.0);
    });

    test('setThemeMode persists value through service', () async {
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();
      await controller.setThemeMode(AppThemeMode.sepia);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('reader_theme_mode'), 'sepia');
    });

    test('setFontFamily persists value through service', () async {
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();
      await controller.setFontFamily(ReaderFontFamily.bitter);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('reader_font_family'), 'bitter');
    });

    test('setOpenRouterApiKey persists value through service', () async {
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();
      await controller.setOpenRouterApiKey('saved-key');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('reader_openrouter_api_key'), 'saved-key');
    });

    test('setOpenRouterModelId persists value through service', () async {
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();
      await controller
          .setOpenRouterModelId('meta-llama/llama-3.3-70b-instruct');

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('reader_openrouter_model_id'),
        'meta-llama/llama-3.3-70b-instruct',
      );
    });

    test('setAiFeatureConfig updates value and persists it', () async {
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();
      await controller.setAiFeatureConfig(
        AiFeatureIds.resumeSummary,
        const AiFeatureConfig(
          modelIdOverride: 'openai/gpt-4.1-mini',
          promptTemplate: 'Custom {source_text}',
        ),
      );

      expect(
        controller.aiFeatureConfig(AiFeatureIds.resumeSummary),
        const AiFeatureConfig(
          modelIdOverride: 'openai/gpt-4.1-mini',
          promptTemplate: 'Custom {source_text}',
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('reader_ai_feature_configs');
      expect(raw, contains('openai/gpt-4.1-mini'));
      expect(raw, contains('Custom {source_text}'));
    });

    test('setAiFeatureConfig supports define and translate feature', () async {
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();
      await controller.setAiFeatureConfig(
        AiFeatureIds.defineAndTranslate,
        const AiFeatureConfig(
          modelIdOverride: 'openai/gpt-4o-mini',
          promptTemplate: 'Explain {source_text} and translate it into German.',
        ),
      );

      expect(
        controller.aiFeatureConfig(AiFeatureIds.defineAndTranslate),
        const AiFeatureConfig(
          modelIdOverride: 'openai/gpt-4o-mini',
          promptTemplate: 'Explain {source_text} and translate it into German.',
        ),
      );
    });

    test('effectiveModelIdForFeature falls back to global model', () async {
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();
      await controller.setOpenRouterModelId('openai/gpt-4o-mini');

      expect(
        controller.effectiveModelIdForFeature(AiFeatureIds.resumeSummary),
        'openai/gpt-4o-mini',
      );
    });

    test('effectiveModelIdForFeature prefers feature override', () async {
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();
      await controller.setOpenRouterModelId('openai/gpt-4o-mini');
      await controller.setAiFeatureConfig(
        AiFeatureIds.resumeSummary,
        const AiFeatureConfig(
          modelIdOverride: 'anthropic/claude-3.7-sonnet',
          promptTemplate: 'Use {source_text}',
        ),
      );

      expect(
        controller.effectiveModelIdForFeature(AiFeatureIds.resumeSummary),
        'anthropic/claude-3.7-sonnet',
      );
    });

    test('resetAiFeaturePromptToDefault restores prompt template', () async {
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();
      await controller.setAiFeatureConfig(
        AiFeatureIds.resumeSummary,
        const AiFeatureConfig(promptTemplate: 'Temporary {source_text}'),
      );

      await controller.resetAiFeaturePromptToDefault(
        AiFeatureIds.resumeSummary,
      );

      expect(
        controller.aiFeatureConfig(AiFeatureIds.resumeSummary).promptTemplate,
        defaultResumeSummaryPromptTemplate,
      );
    });

    test('settings getter returns current ReaderSettings', () async {
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();
      await controller.setFontSize(22.0);
      await controller.setThemeMode(AppThemeMode.dark);
      await controller.setFontFamily(ReaderFontFamily.literata);
      await controller.setOpenRouterApiKey('getter-key');
      await controller.setOpenRouterModelId('openai/gpt-4o-mini');

      expect(controller.settings.fontSize, 22.0);
      expect(controller.settings.themeMode, AppThemeMode.dark);
      expect(controller.settings.fontFamily, ReaderFontFamily.literata);
      expect(controller.settings.openRouterApiKey, 'getter-key');
      expect(controller.settings.openRouterModelId, 'openai/gpt-4o-mini');
      expect(
        controller.settings.aiFeatureConfigs[AiFeatureIds.resumeSummary],
        const AiFeatureConfig(
          promptTemplate: defaultResumeSummaryPromptTemplate,
        ),
      );
      expect(
        controller.settings.aiFeatureConfigs[AiFeatureIds.defineAndTranslate],
        const AiFeatureConfig(
          promptTemplate: defaultDefineAndTranslatePromptTemplate,
        ),
      );
    });
  });
}

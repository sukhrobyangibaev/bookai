import 'package:bookai/models/ai_feature.dart';
import 'package:bookai/models/ai_feature_config.dart';
import 'package:bookai/models/ai_model_selection.dart';
import 'package:bookai/models/ai_provider.dart';
import 'package:bookai/models/github_sync_settings.dart';
import 'package:bookai/models/reader_settings.dart';
import 'package:bookai/services/settings_controller.dart';
import 'package:bookai/services/settings_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsService', () {
    test('load returns defaults when SharedPreferences is empty', () async {
      SharedPreferences.setMockInitialValues({});

      final service = SettingsService();
      final settings = await service.load();

      expect(settings, ReaderSettings.defaults);
    });

    test('load returns provider-aware stored values', () async {
      SharedPreferences.setMockInitialValues({
        'reader_font_size': 24.0,
        'reader_theme_mode': 'dark',
        'reader_font_family': 'literata',
        'reader_openrouter_api_key': 'or-key',
        'reader_gemini_api_key': 'gem-key',
        'reader_ai_default_provider': 'gemini',
        'reader_ai_default_model_id': 'gemini-2.5-flash',
        'reader_ai_fallback_provider': 'openRouter',
        'reader_ai_fallback_model_id': 'openai/gpt-4o-mini',
        'reader_ai_image_provider': 'gemini',
        'reader_ai_image_model_id': 'imagen-4.0-generate-001',
        'reader_ai_feature_configs':
            '{"resume_summary":{"modelOverride":{"provider":"openRouter","modelId":"openai/gpt-4.1-mini"},"promptTemplate":"Use {source_text}"}}',
      });

      final settings = await SettingsService().load();

      expect(settings.fontSize, 24.0);
      expect(settings.themeMode, AppThemeMode.dark);
      expect(settings.fontFamily, ReaderFontFamily.literata);
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
          modelId: 'openai/gpt-4o-mini',
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

    test('load migrates legacy OpenRouter model ids and feature overrides',
        () async {
      SharedPreferences.setMockInitialValues({
        'reader_openrouter_api_key': 'legacy-key',
        'reader_openrouter_model_id': 'openai/gpt-4.1-mini',
        'reader_openrouter_fallback_model_id': 'anthropic/claude-3.7-sonnet',
        'reader_openrouter_image_model_id': 'openai/gpt-image-1',
        'reader_ai_feature_configs':
            '{"resume_summary":{"modelIdOverride":"openai/gpt-4o-mini","promptTemplate":"Legacy {source_text}"}}',
      });

      final settings = await SettingsService().load();

      expect(
        settings.defaultModelSelection,
        const AiModelSelection(
          provider: AiProvider.openRouter,
          modelId: 'openai/gpt-4.1-mini',
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
          modelId: 'openai/gpt-4o-mini',
        ),
      );
    });

    test('save provider-aware selections and keys persist through load',
        () async {
      SharedPreferences.setMockInitialValues({});

      final service = SettingsService();
      await service.saveThemeMode(AppThemeMode.system);
      await service.saveOpenRouterApiKey('or-key');
      await service.saveGeminiApiKey('gem-key');
      await service.saveDefaultModelSelection(
        const AiModelSelection(
          provider: AiProvider.gemini,
          modelId: 'gemini-2.5-flash',
        ),
      );
      await service.saveFallbackModelSelection(
        const AiModelSelection(
          provider: AiProvider.openRouter,
          modelId: 'openai/gpt-4o-mini',
        ),
      );
      await service.saveImageModelSelection(
        const AiModelSelection(
          provider: AiProvider.gemini,
          modelId: 'imagen-4.0-generate-001',
        ),
      );
      await service.saveAiFeatureConfigs(const {
        AiFeatureIds.resumeSummary: AiFeatureConfig(
          modelOverride: AiModelSelection(
            provider: AiProvider.gemini,
            modelId: 'gemini-2.5-flash',
          ),
          promptTemplate: 'Roundtrip {source_text}',
        ),
      });

      final loaded = await service.load();
      expect(loaded.themeMode, AppThemeMode.system);
      expect(loaded.openRouterApiKey, 'or-key');
      expect(loaded.geminiApiKey, 'gem-key');
      expect(
        loaded.defaultModelSelection,
        const AiModelSelection(
          provider: AiProvider.gemini,
          modelId: 'gemini-2.5-flash',
        ),
      );
      expect(
        loaded.fallbackModelSelection,
        const AiModelSelection(
          provider: AiProvider.openRouter,
          modelId: 'openai/gpt-4o-mini',
        ),
      );
      expect(
        loaded.imageModelSelection,
        const AiModelSelection(
          provider: AiProvider.gemini,
          modelId: 'imagen-4.0-generate-001',
        ),
      );
      expect(
        loaded.aiFeatureConfigs[AiFeatureIds.resumeSummary],
        const AiFeatureConfig(
          modelOverride: AiModelSelection(
            provider: AiProvider.gemini,
            modelId: 'gemini-2.5-flash',
          ),
          promptTemplate: 'Roundtrip {source_text}',
        ),
      );
    });

    test('save and load GitHub sync settings roundtrip normalized values',
        () async {
      SharedPreferences.setMockInitialValues({});

      final service = SettingsService();
      await service.saveGitHubSyncSettings(
        const GitHubSyncSettings(
          owner: '  octocat  ',
          repo: '  private-sync  ',
          filePath: ' /sync // snapshots /state.json ',
          token: '  ghp_secret  ',
        ),
      );

      final loaded = await service.loadGitHubSyncSettings();
      expect(
        loaded,
        const GitHubSyncSettings(
          owner: 'octocat',
          repo: 'private-sync',
          filePath: 'sync/snapshots/state.json',
          token: 'ghp_secret',
        ),
      );
    });

    test('save GitHub sync settings removes empty values', () async {
      SharedPreferences.setMockInitialValues({
        'github_sync_owner': 'octocat',
        'github_sync_repo': 'private-sync',
        'github_sync_file_path': 'sync/state.json',
        'github_sync_token': 'ghp_secret',
      });

      final service = SettingsService();
      await service.saveGitHubSyncSettings(GitHubSyncSettings.empty);

      final loaded = await service.loadGitHubSyncSettings();
      expect(loaded, GitHubSyncSettings.empty);
    });
  });

  group('SettingsController', () {
    test('starts with default settings', () {
      final controller = SettingsController();
      expect(controller.settings, ReaderSettings.defaults);
    });

    test('load reads persisted provider-aware settings and notifies', () async {
      SharedPreferences.setMockInitialValues({
        'reader_openrouter_api_key': 'or-key',
        'reader_gemini_api_key': 'gem-key',
        'reader_ai_default_provider': 'gemini',
        'reader_ai_default_model_id': 'gemini-2.5-flash',
        'reader_ai_fallback_provider': 'openRouter',
        'reader_ai_fallback_model_id': 'openai/gpt-4o-mini',
      });

      final controller = SettingsController();
      var notified = 0;
      controller.addListener(() => notified += 1);

      await controller.load();

      expect(notified, 1);
      expect(controller.openRouterApiKey, 'or-key');
      expect(controller.geminiApiKey, 'gem-key');
      expect(
        controller.defaultModelSelection,
        const AiModelSelection(
          provider: AiProvider.gemini,
          modelId: 'gemini-2.5-flash',
        ),
      );
      expect(
        controller.fallbackModelSelection,
        const AiModelSelection(
          provider: AiProvider.openRouter,
          modelId: 'openai/gpt-4o-mini',
        ),
      );
    });

    test('setters normalize, persist, and notify', () async {
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();
      var notified = 0;
      controller.addListener(() => notified += 1);

      await controller.setOpenRouterApiKey('  or-key  ');
      await controller.setGeminiApiKey('  gem-key  ');
      await controller.setDefaultModelSelection(
        const AiModelSelection(
          provider: AiProvider.gemini,
          modelId: ' gemini-2.5-flash ',
        ),
      );
      await controller.setFallbackModelSelection(
        const AiModelSelection(
          provider: AiProvider.openRouter,
          modelId: ' openai/gpt-4o-mini ',
        ),
      );
      await controller.setImageModelSelection(
        const AiModelSelection(
          provider: AiProvider.gemini,
          modelId: ' imagen-4.0-generate-001 ',
        ),
      );

      expect(notified, 5);
      expect(controller.openRouterApiKey, 'or-key');
      expect(controller.geminiApiKey, 'gem-key');
      expect(
        controller.defaultModelSelection,
        const AiModelSelection(
          provider: AiProvider.gemini,
          modelId: 'gemini-2.5-flash',
        ),
      );
      expect(
        controller.fallbackModelSelection,
        const AiModelSelection(
          provider: AiProvider.openRouter,
          modelId: 'openai/gpt-4o-mini',
        ),
      );
      expect(
        controller.imageModelSelection,
        const AiModelSelection(
          provider: AiProvider.gemini,
          modelId: 'imagen-4.0-generate-001',
        ),
      );
    });

    test('effectiveModelSelectionForFeature falls back to global model',
        () async {
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();
      await controller.setDefaultModelSelection(
        const AiModelSelection(
          provider: AiProvider.gemini,
          modelId: 'gemini-2.5-flash',
        ),
      );

      expect(
        controller
            .effectiveModelSelectionForFeature(AiFeatureIds.resumeSummary),
        const AiModelSelection(
          provider: AiProvider.gemini,
          modelId: 'gemini-2.5-flash',
        ),
      );
    });

    test('effectiveModelSelectionForFeature prefers feature override',
        () async {
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();
      await controller.setDefaultModelSelection(
        const AiModelSelection(
          provider: AiProvider.openRouter,
          modelId: 'openai/gpt-4o-mini',
        ),
      );
      await controller.setAiFeatureConfig(
        AiFeatureIds.resumeSummary,
        const AiFeatureConfig(
          modelOverride: AiModelSelection(
            provider: AiProvider.gemini,
            modelId: 'gemini-2.5-flash',
          ),
          promptTemplate: 'Use {source_text}',
        ),
      );

      expect(
        controller
            .effectiveModelSelectionForFeature(AiFeatureIds.resumeSummary),
        const AiModelSelection(
          provider: AiProvider.gemini,
          modelId: 'gemini-2.5-flash',
        ),
      );
    });

    test('apiKeyForProvider returns provider-specific keys', () async {
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();
      await controller.setOpenRouterApiKey('or-key');
      await controller.setGeminiApiKey('gem-key');

      expect(controller.apiKeyForProvider(AiProvider.openRouter), 'or-key');
      expect(controller.apiKeyForProvider(AiProvider.gemini), 'gem-key');
    });
  });
}

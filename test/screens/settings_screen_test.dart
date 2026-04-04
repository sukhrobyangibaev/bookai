import 'dart:convert';

import 'package:bookai/app.dart';
import 'package:bookai/models/ai_feature.dart';
import 'package:bookai/models/ai_model_info.dart';
import 'package:bookai/models/ai_model_selection.dart';
import 'package:bookai/models/ai_provider.dart';
import 'package:bookai/models/github_sync_settings.dart';
import 'package:bookai/screens/settings_screen.dart';
import 'package:bookai/services/gemini_service.dart';
import 'package:bookai/services/github_sync_service.dart';
import 'package:bookai/services/openrouter_service.dart';
import 'package:bookai/services/settings_controller.dart';
import 'package:bookai/services/sync_snapshot_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('SettingsScreen', () {
    testWidgets('uses wrapping theme chips on narrow screens', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();
      await tester.runAsync(() => controller.load());

      await tester.pumpWidget(_buildSettingsApp(controller));
      await tester.pumpAndSettle();

      expect(find.byType(ChoiceChip), findsWidgets);
      expect(find.byType(SegmentedButton), findsNothing);
      expect(find.text('System'), findsOneWidget);
    });

    testWidgets('shows theme options including system', (tester) async {
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();
      await tester.runAsync(() => controller.load());

      await tester.pumpWidget(_buildSettingsApp(controller));
      await tester.pumpAndSettle();

      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      expect(find.text('Night'), findsOneWidget);
      expect(find.text('Sepia'), findsOneWidget);

      final systemChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'System'),
      );
      expect(systemChip.showCheckmark, isFalse);
    });

    testWidgets('shows reader font options', (tester) async {
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();
      await tester.runAsync(() => controller.load());

      await tester.pumpWidget(_buildSettingsApp(controller));
      await tester.pumpAndSettle();

      expect(find.text('Font'), findsOneWidget);
      expect(find.text('Default'), findsOneWidget);
      expect(find.text('Literata'), findsOneWidget);
      expect(find.text('Bitter'), findsOneWidget);
      expect(find.text('Atkinson Hyperlegible'), findsOneWidget);
      expect(find.byType(Scrollbar), findsOneWidget);
    });

    testWidgets('shows both API key fields and provider-aware selections',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'reader_openrouter_api_key': 'or-key',
        'reader_gemini_api_key': 'gem-key',
        'reader_ai_default_provider': 'gemini',
        'reader_ai_default_model_id': 'gemini-2.5-flash',
        'reader_ai_fallback_provider': 'openRouter',
        'reader_ai_fallback_model_id': 'openai/gpt-4o-mini',
        'reader_ai_image_provider': 'gemini',
        'reader_ai_image_model_id': 'imagen-4.0-generate-001',
      });

      final controller = SettingsController();
      await tester.runAsync(() => controller.load());

      await tester.pumpWidget(_buildSettingsApp(controller));
      await tester.pumpAndSettle();

      expect(find.text('OpenRouter API Key'), findsOneWidget);
      expect(find.text('Gemini API Key'), findsOneWidget);
      expect(find.text('Gemini · gemini-2.5-flash'), findsOneWidget);
      expect(find.text('OpenRouter · openai/gpt-4o-mini'), findsOneWidget);
      expect(find.text('Gemini · imagen-4.0-generate-001'), findsOneWidget);
    });

    testWidgets('editing both API keys updates controller values',
        (tester) async {
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();
      await tester.runAsync(() => controller.load());

      await tester.pumpWidget(_buildSettingsApp(controller));
      await tester.pumpAndSettle();

      await tester.enterText(
          _textFieldWithLabel('OpenRouter API Key'), 'or-key');
      await tester.enterText(_textFieldWithLabel('Gemini API Key'), 'gem-key');
      await tester.pump();

      expect(controller.openRouterApiKey, 'or-key');
      expect(controller.geminiApiKey, 'gem-key');
    });

    testWidgets('lists Ask AI in the AI features section', (tester) async {
      await _useTallSurface(tester);
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();
      await tester.runAsync(() => controller.load());

      await tester.pumpWidget(_buildSettingsApp(controller));
      await tester.pumpAndSettle();

      final askAiFeature = find.widgetWithText(ListTile, 'Ask AI');
      await tester.ensureVisible(askAiFeature);

      expect(askAiFeature, findsOneWidget);
    });

    testWidgets('shows AI Logs entry in AI section', (tester) async {
      await _useTallSurface(tester);
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();
      await tester.runAsync(() => controller.load());

      await tester.pumpWidget(_buildSettingsApp(controller));
      await tester.pumpAndSettle();

      final logsTile = find.widgetWithText(ListTile, 'AI Logs');
      await tester.ensureVisible(logsTile);

      expect(logsTile, findsOneWidget);
      expect(
        find.text('View exact request and response records saved locally.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'default model picker is provider-first and shows OpenRouter pricing',
        (tester) async {
      await _useTallSurface(tester);
      SharedPreferences.setMockInitialValues({
        'reader_openrouter_api_key': 'or-key',
      });

      final controller = SettingsController();
      await tester.runAsync(() => controller.load());

      await tester.pumpWidget(
        _buildSettingsApp(
          controller,
          openRouterService: _FakeOpenRouterService(
            models: const [
              AiModelInfo(
                provider: AiProvider.openRouter,
                id: 'openai/gpt-4o-mini',
                displayName: 'GPT-4o Mini',
                outputModalities: ['text'],
                textPriceLabel: 'Input: \$0.15/M tok · Output: \$0.6/M tok',
              ),
              AiModelInfo(
                provider: AiProvider.openRouter,
                id: 'openai/gpt-image-1',
                displayName: 'GPT Image 1',
                outputModalities: ['image', 'text'],
                imagePriceLabel: 'Image: \$0.04/image',
              ),
              AiModelInfo(
                provider: AiProvider.openRouter,
                id: 'black-forest-labs/flux-1.1-pro',
                displayName: 'FLUX 1.1 Pro',
                outputModalities: ['image'],
                imagePriceLabel: 'Image: \$0.05/image',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final defaultModelFinder = find.widgetWithText(ListTile, 'Default Model');
      await tester.ensureVisible(defaultModelFinder);
      await tester.tap(defaultModelFinder);
      await tester.pumpAndSettle();

      expect(find.text('OpenRouter'), findsOneWidget);
      expect(find.text('Gemini'), findsOneWidget);
      expect(find.text('GPT-4o Mini'), findsOneWidget);
      expect(
        find.text('Input: \$0.15/M tok · Output: \$0.6/M tok'),
        findsOneWidget,
      );
      expect(find.text('GPT Image 1'), findsOneWidget);
      expect(find.text('FLUX 1.1 Pro'), findsNothing);

      await tester.tap(find.text('Gemini'));
      await tester.pumpAndSettle();
      expect(find.text('Add your Gemini API key first.'), findsOneWidget);
    });

    testWidgets('Gemini image picker shows Gemini image and Imagen models only',
        (tester) async {
      await _useTallSurface(tester);
      SharedPreferences.setMockInitialValues({
        'reader_openrouter_api_key': 'or-key',
        'reader_gemini_api_key': 'gem-key',
      });

      final controller = SettingsController();
      await tester.runAsync(() => controller.load());
      final geminiService = GeminiService(
        client: MockClient((request) async {
          expect(request.headers['x-goog-api-key'], 'gem-key');
          return http.Response(
            jsonEncode({
              'models': [
                {
                  'name': 'models/gemini-2.5-flash',
                  'displayName': 'Gemini 2.5 Flash',
                  'supportedGenerationMethods': ['generateContent'],
                },
                {
                  'name': 'models/gemini-3-pro-image-preview',
                  'displayName': 'Gemini 3 Pro Image Preview',
                  'supportedGenerationMethods': ['generateContent'],
                },
                {
                  'name': 'models/imagen-4.0-generate-001',
                  'displayName': 'Imagen 4',
                  'supportedGenerationMethods': ['predict'],
                },
              ],
            }),
            200,
          );
        }),
      );

      await tester.pumpWidget(
        _buildSettingsApp(
          controller,
          geminiService: geminiService,
        ),
      );
      await tester.pumpAndSettle();

      final imageModelFinder = find.widgetWithText(ListTile, 'Image Model');
      await tester.ensureVisible(imageModelFinder);
      await tester.tap(imageModelFinder);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gemini'));
      await tester.pumpAndSettle();

      expect(find.text('Gemini 3 Pro Image Preview'), findsOneWidget);
      expect(find.text('Imagen 4'), findsOneWidget);
      expect(find.text('Gemini 2.5 Flash'), findsNothing);
    });

    testWidgets('feature config sheet can save provider-aware model override',
        (tester) async {
      await _useTallSurface(tester);
      SharedPreferences.setMockInitialValues({
        'reader_openrouter_api_key': 'or-key',
        'reader_gemini_api_key': 'gem-key',
        'reader_ai_default_provider': 'openRouter',
        'reader_ai_default_model_id': 'openai/gpt-4o-mini',
      });

      final controller = SettingsController();
      await tester.runAsync(() => controller.load());

      await tester.pumpWidget(
        _buildSettingsApp(
          controller,
          geminiService: _FakeGeminiService(
            models: const [
              AiModelInfo(
                provider: AiProvider.gemini,
                id: 'gemini-2.5-flash',
                displayName: 'Gemini 2.5 Flash',
                outputModalities: ['text'],
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final featureFinder =
          find.widgetWithText(ListTile, 'Resume Here and Catch Me Up');
      await tester.ensureVisible(featureFinder);
      await tester.tap(featureFinder);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Use global default model'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Model'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gemini'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gemini 2.5 Flash'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        controller.aiFeatureConfig(AiFeatureIds.resumeSummary).modelOverride,
        const AiModelSelection(
          provider: AiProvider.gemini,
          modelId: 'gemini-2.5-flash',
        ),
      );
    });

    testWidgets('picker retry reloads models after a failure', (tester) async {
      await _useTallSurface(tester);
      SharedPreferences.setMockInitialValues({
        'reader_openrouter_api_key': 'or-key',
      });

      final controller = SettingsController();
      await tester.runAsync(() => controller.load());

      var attempts = 0;
      await tester.pumpWidget(
        _buildSettingsApp(
          controller,
          openRouterService: _FakeOpenRouterService(
            fetchModelsHandler: ({bool forceRefresh = false}) async {
              attempts += 1;
              if (attempts == 1) {
                throw Exception('temporary failure');
              }
              return const [
                AiModelInfo(
                  provider: AiProvider.openRouter,
                  id: 'openai/gpt-4o-mini',
                  displayName: 'GPT-4o Mini',
                  outputModalities: ['text'],
                  textPriceLabel: 'Input: \$0.15/M tok · Output: \$0.6/M tok',
                ),
              ];
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final defaultModelFinder = find.widgetWithText(ListTile, 'Default Model');
      await tester.ensureVisible(defaultModelFinder);
      await tester.tap(defaultModelFinder);
      await tester.pumpAndSettle();

      expect(find.text('Failed to load models'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('GPT-4o Mini'), findsOneWidget);
      expect(attempts, 2);
    });

    testWidgets('shows manual sync section and fields', (tester) async {
      await _useTallSurface(tester);
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();
      await tester.runAsync(() => controller.load());

      await tester.pumpWidget(
        _buildSettingsApp(
          controller,
          gitHubSyncService: _FakeGitHubSyncService(
            initialSettings: const GitHubSyncSettings(
              owner: 'octocat',
              repo: 'private-sync',
              filePath: 'sync/state.json',
              token: 'ghp_sync_token',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _scrollToSyncSection(tester);
      final syncHeader = find.text('Sync');

      expect(syncHeader, findsOneWidget);
      expect(find.text('GitHub Repo'), findsOneWidget);
      expect(find.text('Remote File Path'), findsOneWidget);
      expect(find.text('GitHub Token'), findsOneWidget);
      expect(find.text('Upload'), findsOneWidget);
      expect(find.text('Download'), findsOneWidget);
      expect(find.text('Include API keys in uploads'), findsOneWidget);
    });

    testWidgets('upload sync exports snapshot and uploads to GitHub',
        (tester) async {
      await _useTallSurface(tester);
      SharedPreferences.setMockInitialValues({});

      bool? exportIncludeApiKeys;
      String? uploadedJson;
      GitHubSyncSettings? uploadedSettings;

      final fakeSnapshotService = _FakeSyncSnapshotService(
        onExport: ({required bool includeApiKeys}) async {
          exportIncludeApiKeys = includeApiKeys;
          return '{"schemaVersion":1}';
        },
      );
      final fakeGitHubService = _FakeGitHubSyncService(
        initialSettings: const GitHubSyncSettings(
          owner: 'octocat',
          repo: 'private-sync',
          filePath: 'sync/state.json',
          token: 'ghp_sync_token',
        ),
        onUpload: (
          jsonContents,
          settings,
          commitMessage,
        ) async {
          uploadedJson = jsonContents;
          uploadedSettings = settings;
          return const GitHubSyncUploadResult(
            fileSha: 'sha-123',
            created: false,
          );
        },
      );

      final controller = SettingsController();
      await tester.runAsync(() => controller.load());

      await tester.pumpWidget(
        _buildSettingsApp(
          controller,
          gitHubSyncService: fakeGitHubService,
          syncSnapshotService: fakeSnapshotService,
        ),
      );
      await tester.pumpAndSettle();

      await _scrollToSyncSection(tester);

      final includeKeysToggle =
          find.widgetWithText(SwitchListTile, 'Include API keys in uploads');
      await _scrollToFinder(tester, includeKeysToggle);
      await tester.tap(includeKeysToggle);
      await tester.pumpAndSettle();

      final uploadButton = find.text('Upload');
      await _scrollToFinder(tester, uploadButton);
      await tester.tap(uploadButton);
      await tester.pumpAndSettle();

      expect(exportIncludeApiKeys, isTrue);
      expect(uploadedJson, '{"schemaVersion":1}');
      expect(uploadedSettings?.normalizedOwner, 'octocat');
      expect(uploadedSettings?.normalizedRepo, 'private-sync');
      expect(uploadedSettings?.normalizedFilePath, 'sync/state.json');
      expect(uploadedSettings?.includeApiKeysInUploads, isTrue);
      expect(find.textContaining('Upload complete.'), findsWidgets);
    });

    testWidgets('download sync confirms overwrite and imports snapshot',
        (tester) async {
      await _useTallSurface(tester);
      SharedPreferences.setMockInitialValues({});

      const downloadedJson = '{"schemaVersion":1}';
      String? importedJson;
      bool? importedWithClearMissing;

      final fakeSnapshotService = _FakeSyncSnapshotService(
        onImport: (
          json, {
          required bool clearMissingBookState,
          required bool overwriteMatchingBookState,
        }) async {
          importedJson = json;
          importedWithClearMissing = clearMissingBookState;
          return const SyncSnapshotImportResult(
            settingsApplied: true,
            matchedBooks: 1,
            skippedBooks: 0,
            importedProgressCount: 1,
            importedResumeMarkerCount: 0,
            importedHighlightCount: 1,
            replacedHighlightCount: 1,
          );
        },
      );
      final fakeGitHubService = _FakeGitHubSyncService(
        initialSettings: const GitHubSyncSettings(
          owner: 'octocat',
          repo: 'private-sync',
          filePath: 'sync/state.json',
          token: 'ghp_sync_token',
        ),
        onDownload: (settings) async => downloadedJson,
      );

      final controller = SettingsController();
      await tester.runAsync(() => controller.load());

      await tester.pumpWidget(
        _buildSettingsApp(
          controller,
          gitHubSyncService: fakeGitHubService,
          syncSnapshotService: fakeSnapshotService,
        ),
      );
      await tester.pumpAndSettle();

      await _scrollToSyncSection(tester);
      final downloadButton = find.text('Download');
      await _scrollToFinder(tester, downloadButton);
      await tester.tap(downloadButton);
      await tester.pumpAndSettle();

      expect(find.text('Download?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Download'));
      await tester.pumpAndSettle();

      expect(importedJson, downloadedJson);
      expect(importedWithClearMissing, isTrue);
      expect(find.textContaining('Matched 1 books'), findsWidgets);
    });

    testWidgets('upload validates owner/repo format', (tester) async {
      await _useTallSurface(tester);
      SharedPreferences.setMockInitialValues({});

      var exportCalls = 0;
      final fakeSnapshotService = _FakeSyncSnapshotService(
        onExport: ({required bool includeApiKeys}) async {
          exportCalls += 1;
          return '{"schemaVersion":1}';
        },
      );

      final controller = SettingsController();
      await tester.runAsync(() => controller.load());

      await tester.pumpWidget(
        _buildSettingsApp(
          controller,
          syncSnapshotService: fakeSnapshotService,
        ),
      );
      await tester.pumpAndSettle();

      await _scrollToSyncSection(tester);
      final repoField = _textFieldWithLabel('GitHub Repo');
      final filePathField = _textFieldWithLabel('Remote File Path');
      final tokenField = _textFieldWithLabel('GitHub Token');
      await _scrollToFinder(tester, repoField);
      await tester.enterText(repoField, 'octocat');
      await tester.enterText(
        filePathField,
        'sync/state.json',
      );
      await tester.enterText(
        tokenField,
        'ghp_sync_token',
      );
      await tester.pumpAndSettle();

      final uploadButton = find.text('Upload');
      await _scrollToFinder(tester, uploadButton);
      await tester.tap(uploadButton);
      await tester.pumpAndSettle();

      expect(exportCalls, 0);
      expect(
        find.text('GitHub repo must be in owner/repo format.'),
        findsOneWidget,
      );
    });
  });
}

Future<void> _useTallSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> _scrollToSyncSection(WidgetTester tester) async {
  final syncLabel = find.text('Sync');
  await _scrollToFinder(tester, syncLabel);
}

Future<void> _scrollToFinder(WidgetTester tester, Finder finder) async {
  final scrollable = find.byType(Scrollable).first;

  for (var i = 0; i < 12; i += 1) {
    if (finder.evaluate().isNotEmpty) {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      return;
    }
    await tester.drag(scrollable, const Offset(0, -260));
    await tester.pumpAndSettle();
  }

  expect(finder, findsOneWidget);
}

Finder _textFieldWithLabel(String labelText) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is TextField && widget.decoration?.labelText == labelText,
  );
}

Widget _buildSettingsApp(
  SettingsController controller, {
  OpenRouterService? openRouterService,
  GeminiService? geminiService,
  GitHubSyncService? gitHubSyncService,
  SyncSnapshotService? syncSnapshotService,
}) {
  return SettingsControllerScope(
    controller: controller,
    child: MaterialApp(
      home: SettingsScreen(
        openRouterService: openRouterService ?? _FakeOpenRouterService(),
        geminiService: geminiService ?? _FakeGeminiService(),
        gitHubSyncService: gitHubSyncService,
        syncSnapshotService: syncSnapshotService,
      ),
    ),
  );
}

class _FakeGitHubSyncService extends GitHubSyncService {
  GitHubSyncSettings _settings;
  final Future<String> Function(GitHubSyncSettings settings)? onDownload;
  final Future<GitHubSyncUploadResult> Function(
    String jsonContents,
    GitHubSyncSettings settings,
    String commitMessage,
  )? onUpload;

  _FakeGitHubSyncService({
    GitHubSyncSettings initialSettings = GitHubSyncSettings.empty,
    this.onDownload,
    this.onUpload,
  })  : _settings = initialSettings.normalized(),
        super(client: MockClient((_) async => http.Response('unused', 500)));

  @override
  Future<GitHubSyncSettings> loadSettings() async => _settings;

  @override
  Future<void> saveSettings(GitHubSyncSettings settings) async {
    _settings = settings.normalized();
  }

  @override
  Future<String> downloadSyncFileContents(
      {GitHubSyncSettings? settings}) async {
    final resolved = (settings ?? _settings).normalized();
    if (onDownload != null) {
      return onDownload!(resolved);
    }
    return '{"schemaVersion":1}';
  }

  @override
  Future<GitHubSyncUploadResult> uploadSyncFileContents(
    String jsonContents, {
    GitHubSyncSettings? settings,
    String commitMessage = 'Update BookAI sync snapshot',
  }) async {
    final resolved = (settings ?? _settings).normalized();
    if (onUpload != null) {
      return onUpload!(jsonContents, resolved, commitMessage);
    }
    return const GitHubSyncUploadResult(fileSha: 'fake-sha', created: false);
  }
}

class _FakeSyncSnapshotService extends SyncSnapshotService {
  final Future<String> Function({required bool includeApiKeys})? onExport;
  final Future<SyncSnapshotImportResult> Function(
    String json, {
    required bool clearMissingBookState,
    required bool overwriteMatchingBookState,
  })? onImport;

  _FakeSyncSnapshotService({
    this.onExport,
    this.onImport,
  });

  @override
  Future<String> exportSnapshotJson({
    bool includeApiKeys = false,
    DateTime? exportedAt,
  }) {
    if (onExport != null) {
      return onExport!(includeApiKeys: includeApiKeys);
    }
    return Future<String>.value('{"schemaVersion":1}');
  }

  @override
  Future<SyncSnapshotImportResult> importSnapshotJson(
    String json, {
    bool clearMissingBookState = false,
    bool overwriteMatchingBookState = false,
  }) {
    if (onImport != null) {
      return onImport!(
        json,
        clearMissingBookState: clearMissingBookState,
        overwriteMatchingBookState: overwriteMatchingBookState,
      );
    }
    return Future<SyncSnapshotImportResult>.value(
      const SyncSnapshotImportResult(
        settingsApplied: false,
        matchedBooks: 0,
        skippedBooks: 0,
        importedProgressCount: 0,
        importedResumeMarkerCount: 0,
        importedHighlightCount: 0,
        replacedHighlightCount: 0,
      ),
    );
  }
}

class _FakeOpenRouterService extends OpenRouterService {
  final Future<List<AiModelInfo>> Function({bool forceRefresh}) _fetchModels;

  _FakeOpenRouterService({
    List<AiModelInfo> models = const <AiModelInfo>[
      AiModelInfo(
        provider: AiProvider.openRouter,
        id: 'openai/gpt-4o-mini',
        displayName: 'GPT-4o Mini',
        outputModalities: ['text'],
        textPriceLabel: 'Input: \$0.15/M tok · Output: \$0.6/M tok',
      ),
    ],
    Future<List<AiModelInfo>> Function({bool forceRefresh})? fetchModelsHandler,
  }) : _fetchModels = fetchModelsHandler ?? _defaultHandler(models);

  static Future<List<AiModelInfo>> Function({bool forceRefresh})
      _defaultHandler(
    List<AiModelInfo> models,
  ) {
    return ({bool forceRefresh = false}) async => models;
  }

  @override
  Future<List<AiModelInfo>> fetchModelInfos({
    String? apiKey,
    bool forceRefresh = false,
  }) {
    return _fetchModels(forceRefresh: forceRefresh);
  }
}

class _FakeGeminiService extends GeminiService {
  final Future<List<AiModelInfo>> Function({bool forceRefresh}) _fetchModels;

  _FakeGeminiService({
    List<AiModelInfo> models = const <AiModelInfo>[
      AiModelInfo(
        provider: AiProvider.gemini,
        id: 'gemini-2.5-flash',
        displayName: 'Gemini 2.5 Flash',
        outputModalities: ['text'],
      ),
    ],
    Future<List<AiModelInfo>> Function({bool forceRefresh})? fetchModelsHandler,
  }) : _fetchModels = fetchModelsHandler ?? _defaultHandler(models);

  static Future<List<AiModelInfo>> Function({bool forceRefresh})
      _defaultHandler(
    List<AiModelInfo> models,
  ) {
    return ({bool forceRefresh = false}) async => models;
  }

  @override
  Future<List<AiModelInfo>> fetchModels({
    required String apiKey,
    bool forceRefresh = false,
  }) {
    return _fetchModels(forceRefresh: forceRefresh);
  }
}

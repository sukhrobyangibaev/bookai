import 'dart:convert';

import 'package:bookai/app.dart';
import 'package:bookai/models/ai_feature.dart';
import 'package:bookai/models/ai_model_info.dart';
import 'package:bookai/models/ai_model_selection.dart';
import 'package:bookai/models/ai_provider.dart';
import 'package:bookai/screens/settings_screen.dart';
import 'package:bookai/services/gemini_service.dart';
import 'package:bookai/services/openrouter_service.dart';
import 'package:bookai/services/settings_controller.dart';
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
  });
}

Future<void> _useTallSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
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
}) {
  return SettingsControllerScope(
    controller: controller,
    child: MaterialApp(
      home: SettingsScreen(
        openRouterService: openRouterService ?? _FakeOpenRouterService(),
        geminiService: geminiService ?? _FakeGeminiService(),
      ),
    ),
  );
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

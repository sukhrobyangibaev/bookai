import 'package:bookai/app.dart';
import 'package:bookai/models/openrouter_model.dart';
import 'package:bookai/models/reader_settings.dart';
import 'package:bookai/screens/settings_screen.dart';
import 'package:bookai/services/openrouter_service.dart';
import 'package:bookai/services/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('SettingsScreen', () {
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

    testWidgets('selecting font updates controller value', (tester) async {
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();
      await tester.runAsync(() => controller.load());

      await tester.pumpWidget(_buildSettingsApp(controller));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bitter'));
      await tester.pumpAndSettle();

      expect(controller.fontFamily, ReaderFontFamily.bitter);
    });

    testWidgets('shows persisted OpenRouter model id and prices',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'reader_openrouter_api_key': 'stored-key',
        'reader_openrouter_model_id': 'openai/gpt-4o-mini',
        'reader_openrouter_fallback_model_id': 'openai/gpt-4.1-mini',
        'reader_openrouter_image_model_id': 'openai/gpt-image-1',
      });

      final controller = SettingsController();
      await tester.runAsync(() => controller.load());

      await tester.pumpWidget(_buildSettingsApp(controller));
      await tester.pumpAndSettle();

      expect(find.text('AI'), findsOneWidget);
      expect(find.text('OpenRouter API Key'), findsOneWidget);
      expect(find.text('Fallback Model'), findsOneWidget);
      expect(find.text('Image Model'), findsOneWidget);
      expect(
        find.text(
            'openai/gpt-4o-mini\nInput: \$0.15/M tok · Output: \$0.6/M tok'),
        findsOneWidget,
      );
      expect(
        find.text(
            'openai/gpt-4.1-mini\nInput: \$0.4/M tok · Output: \$1.6/M tok'),
        findsOneWidget,
      );
      expect(
        find.text('openai/gpt-image-1\nImage: \$0.04/image'),
        findsOneWidget,
      );
      expect(find.text('Resume Here and Catch Me Up'), findsOneWidget);
      expect(find.text('Simplify Text'), findsOneWidget);
      expect(find.text('Define & Translate'), findsOneWidget);
      expect(find.text('Generate Image'), findsOneWidget);
    });

    testWidgets('editing API key updates controller value', (tester) async {
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();
      await tester.runAsync(() => controller.load());

      await tester.pumpWidget(_buildSettingsApp(controller));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '  test-key  ');
      await tester.pump();

      expect(controller.openRouterApiKey, 'test-key');
    });

    testWidgets('does not fetch models while API key field is being edited',
        (tester) async {
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();
      await tester.runAsync(() => controller.load());
      final openRouterService = _FakeOpenRouterService(models: _defaultModels);

      await tester.pumpWidget(
        _buildSettingsApp(
          controller,
          openRouterService: openRouterService,
        ),
      );
      await tester.pumpAndSettle();

      expect(openRouterService.fetchModelsCallCount, 0);

      await tester.enterText(find.byType(TextField).first, 'edited-key');
      await tester.pump();

      expect(controller.openRouterApiKey, 'edited-key');
      expect(openRouterService.fetchModelsCallCount, 0);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      expect(openRouterService.fetchModelsCallCount, 1);
      expect(openRouterService.fetchModelsApiKeys, ['edited-key']);
      expect(openRouterService.fetchModelsForceRefreshes, [false]);
    });

    testWidgets('shows context sentence placeholder for define and translate',
        (tester) async {
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();
      await tester.runAsync(() => controller.load());

      await tester.pumpWidget(_buildSettingsApp(controller));
      await tester.pumpAndSettle();

      final defineAndTranslateText = find.text('Define & Translate');
      await tester.ensureVisible(defineAndTranslateText);
      await tester.pumpAndSettle();
      await tester.tap(defineAndTranslateText);
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Supported placeholders: {book_title}, {book_author}, {context_sentence}, {source_text}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows generate image placeholders in feature config sheet',
        (tester) async {
      SharedPreferences.setMockInitialValues({});

      final controller = SettingsController();
      await tester.runAsync(() => controller.load());

      await tester.pumpWidget(_buildSettingsApp(controller));
      await tester.pumpAndSettle();

      final generateImageText = find.text('Generate Image');
      await tester.ensureVisible(generateImageText);
      await tester.pumpAndSettle();
      await tester.tap(generateImageText);
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Supported placeholders: {book_title}, {book_author}, {chapter_title}, {context_sentence}, {source_text}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('default model picker shows text pricing', (tester) async {
      SharedPreferences.setMockInitialValues({
        'reader_openrouter_api_key': 'stored-key',
      });

      final controller = SettingsController();
      await tester.runAsync(() => controller.load());

      await tester.pumpWidget(_buildSettingsApp(controller));
      await tester.pumpAndSettle();

      final defaultModelText = find.text('Default Model');
      await tester.ensureVisible(defaultModelText);
      await tester.pumpAndSettle();
      await tester.tap(defaultModelText);
      await tester.pumpAndSettle();

      expect(find.text('GPT-4o Mini'), findsOneWidget);
      expect(find.text('Input: \$0.15/M tok · Output: \$0.6/M tok'),
          findsOneWidget);
      expect(find.text('GPT Image 1'), findsOneWidget);
      expect(find.text('Image: \$0.04/image'), findsOneWidget);
    });

    testWidgets('image model picker only shows image-generating models',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'reader_openrouter_api_key': 'stored-key',
      });

      final controller = SettingsController();
      await tester.runAsync(() => controller.load());
      final openRouterService = _FakeOpenRouterService(
        models: const [
          OpenRouterModel(
            id: 'openai/gpt-image-1',
            name: 'GPT Image 1',
            outputModalities: ['image', 'text'],
            pricing: OpenRouterModelPricing(image: 0.04),
          ),
          OpenRouterModel(
            id: 'openai/gpt-4o-mini',
            name: 'GPT-4o Mini',
            outputModalities: ['text'],
            pricing: OpenRouterModelPricing(
              prompt: 0.00000015,
              completion: 0.0000006,
            ),
          ),
          OpenRouterModel(
            id: 'black-forest-labs/flux-1.1-pro',
            name: 'FLUX 1.1 Pro',
            outputModalities: ['image'],
            pricing: OpenRouterModelPricing(image: 0.05),
          ),
          OpenRouterModel(
            id: 'google/gemini-3.1-flash-image-preview',
            name: 'Gemini 3.1 Flash Image Preview',
            outputModalities: ['image', 'text'],
            pricing: OpenRouterModelPricing(
              prompt: 0.0000005,
              completion: 0.000003,
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        SettingsControllerScope(
          controller: controller,
          child: MaterialApp(
            home: SettingsScreen(openRouterService: openRouterService),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final imageModelText = find.text('Image Model');
      await tester.ensureVisible(imageModelText);
      await tester.pumpAndSettle();
      await tester.tap(imageModelText);
      await tester.pumpAndSettle();

      expect(find.text('GPT Image 1'), findsOneWidget);
      expect(find.text('FLUX 1.1 Pro'), findsOneWidget);
      expect(find.text('Gemini 3.1 Flash Image Preview'), findsOneWidget);
      expect(find.text('GPT-4o Mini'), findsNothing);
      expect(find.text('Image: \$0.04/image'), findsOneWidget);
      expect(find.text('Image: \$0.05/image'), findsOneWidget);
      expect(find.text('Image: \$60/M tok'), findsOneWidget);
      expect(
          find.text('Input: \$0.15/M tok · Output: \$0.6/M tok'), findsNothing);
      expect(find.text('Input: \$0.5/M tok · Output: \$3/M tok'), findsNothing);

      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.hintText == 'Search by model name or id',
        ),
        'gpt',
      );
      await tester.pumpAndSettle();

      expect(find.text('GPT Image 1'), findsOneWidget);
      expect(find.text('FLUX 1.1 Pro'), findsNothing);
      expect(find.text('GPT-4o Mini'), findsNothing);
      expect(find.text('Gemini 3.1 Flash Image Preview'), findsNothing);
    });

    testWidgets('picker retry replaces failed shared models future',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'reader_openrouter_api_key': 'stored-key',
        'reader_openrouter_model_id': 'openai/gpt-4o-mini',
      });

      final controller = SettingsController();
      await tester.runAsync(() => controller.load());
      var fetchAttempt = 0;
      final openRouterService = _FakeOpenRouterService(
        fetchModelsHandler: ({
          String? apiKey,
          bool forceRefresh = false,
        }) async {
          fetchAttempt += 1;
          if (fetchAttempt <= 2) {
            throw Exception('temporary failure');
          }
          return _defaultModels;
        },
      );

      await tester.pumpWidget(
        _buildSettingsApp(
          controller,
          openRouterService: openRouterService,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
            'openai/gpt-4o-mini\nInput: \$0.15/M tok · Output: \$0.6/M tok'),
        findsNothing,
      );

      final defaultModelText = find.text('Default Model');
      await tester.ensureVisible(defaultModelText);
      await tester.pumpAndSettle();
      await tester.tap(defaultModelText);
      await tester.pumpAndSettle();

      expect(find.text('Failed to load models'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('GPT-4o Mini'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(
        find.text(
            'openai/gpt-4o-mini\nInput: \$0.15/M tok · Output: \$0.6/M tok'),
        findsOneWidget,
      );
      expect(openRouterService.fetchModelsCallCount, 3);
      expect(
        openRouterService.fetchModelsForceRefreshes,
        [false, false, true],
      );
    });
  });
}

Widget _buildSettingsApp(
  SettingsController controller, {
  OpenRouterService? openRouterService,
}) {
  return SettingsControllerScope(
    controller: controller,
    child: MaterialApp(
      home: SettingsScreen(
        openRouterService:
            openRouterService ?? _FakeOpenRouterService(models: _defaultModels),
      ),
    ),
  );
}

const _defaultModels = <OpenRouterModel>[
  OpenRouterModel(
    id: 'openai/gpt-4o-mini',
    name: 'GPT-4o Mini',
    outputModalities: ['text'],
    pricing: OpenRouterModelPricing(
      prompt: 0.00000015,
      completion: 0.0000006,
    ),
  ),
  OpenRouterModel(
    id: 'openai/gpt-4.1-mini',
    name: 'GPT-4.1 Mini',
    outputModalities: ['text'],
    pricing: OpenRouterModelPricing(
      prompt: 0.0000004,
      completion: 0.0000016,
    ),
  ),
  OpenRouterModel(
    id: 'openai/gpt-image-1',
    name: 'GPT Image 1',
    outputModalities: ['image', 'text'],
    pricing: OpenRouterModelPricing(image: 0.04),
  ),
];

class _FakeOpenRouterService extends OpenRouterService {
  final Future<List<OpenRouterModel>> Function({
    String? apiKey,
    bool forceRefresh,
  }) _fetchModelsHandler;
  int fetchModelsCallCount = 0;
  final List<String> fetchModelsApiKeys = [];
  final List<bool> fetchModelsForceRefreshes = [];

  _FakeOpenRouterService({
    List<OpenRouterModel> models = _defaultModels,
    Future<List<OpenRouterModel>> Function({
      String? apiKey,
      bool forceRefresh,
    })? fetchModelsHandler,
  }) : _fetchModelsHandler =
            fetchModelsHandler ?? _buildFetchModelsHandler(models);

  static Future<List<OpenRouterModel>> Function({
    String? apiKey,
    bool forceRefresh,
  }) _buildFetchModelsHandler(List<OpenRouterModel> models) {
    return ({
      String? apiKey,
      bool forceRefresh = false,
    }) async =>
        models;
  }

  @override
  Future<List<OpenRouterModel>> fetchModels({
    String? apiKey,
    bool forceRefresh = false,
  }) async {
    fetchModelsCallCount += 1;
    fetchModelsApiKeys.add(apiKey ?? '');
    fetchModelsForceRefreshes.add(forceRefresh);
    return _fetchModelsHandler(
      apiKey: apiKey,
      forceRefresh: forceRefresh,
    );
  }
}

import 'dart:async';

import 'package:bookai/app.dart';
import 'package:bookai/models/book.dart';
import 'package:bookai/models/ai_feature.dart';
import 'package:bookai/models/chapter.dart';
import 'package:bookai/models/openrouter_model.dart';
import 'package:bookai/screens/reader_screen.dart';
import 'package:bookai/services/chapter_loader_service.dart';
import 'package:bookai/services/database_service.dart';
import 'package:bookai/services/openrouter_service.dart';
import 'package:bookai/services/resume_summary_service.dart';
import 'package:bookai/services/settings_controller.dart';
import 'package:bookai/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('ReaderScreen AI loading flow', () {
    testWidgets('shows a compact non-modal loading sheet while AI is pending',
        (tester) async {
      final completer = Completer<String>();
      final openRouter = _FakeOpenRouterService(
        generateTextHandler: ({
          required apiKey,
          required modelId,
          required prompt,
          temperature,
        }) =>
            completer.future,
      );

      await _pumpReaderScreen(
        tester,
        openRouterService: openRouter,
      );

      await _startDefineAndTranslate(tester);

      expect(
        find.byKey(const ValueKey<String>('reader-ai-loading-sheet')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('reader-ai-loading-progress')),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(openRouter.generateTextCallCount, 1);
      expect(find.byTooltip('Show Navigation Bar'), findsOneWidget);

      await tester.tap(find.byTooltip('Show Navigation Bar'));
      await tester.pump();

      expect(find.byTooltip('Hide Navigation Bar'), findsOneWidget);

      completer.complete('Definition: vague\nTranslation: smutny');
      await tester.pumpAndSettle();
    });

    testWidgets('opens the full result sheet automatically when AI completes',
        (tester) async {
      final completer = Completer<String>();
      final openRouter = _FakeOpenRouterService(
        generateTextHandler: ({
          required apiKey,
          required modelId,
          required prompt,
          temperature,
        }) =>
            completer.future,
      );

      await _pumpReaderScreen(
        tester,
        openRouterService: openRouter,
      );

      await _startDefineAndTranslate(tester);
      completer.complete('Definition: vague\nTranslation: neyasny');

      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('reader-ai-loading-sheet')),
        findsNothing,
      );
      expect(find.text('Define & Translate'), findsOneWidget);
      expect(find.text('Definition: vague\nTranslation: neyasny'), findsOne);
      expect(find.byTooltip('Copy'), findsOneWidget);
      expect(find.byTooltip('Regenerate with Fallback'), findsOneWidget);
      expect(find.byTooltip('Summary'), findsNothing);
      expect(find.byTooltip('Simplify Text'), findsNothing);
      expect(find.text('Copy'), findsNothing);
      expect(find.text('Regenerate with Fallback'), findsNothing);
      expect(find.text('Close'), findsNothing);
      expect(find.byType(ModalBarrier), findsWidgets);
    });

    testWidgets('AI result sheet text is justified like the main reader',
        (tester) async {
      final openRouter = _FakeOpenRouterService(
        generateTextHandler: ({
          required apiKey,
          required modelId,
          required prompt,
          temperature,
        }) async =>
            'Definition: vague\nTranslation: neyasny',
      );

      await _pumpReaderScreen(
        tester,
        openRouterService: openRouter,
      );

      await _startDefineAndTranslate(tester);
      await tester.pumpAndSettle();

      final resultText = tester.widget<SelectableText>(
        find.byWidgetPredicate(
          (widget) =>
              widget is SelectableText &&
              widget.data == 'Definition: vague\nTranslation: neyasny',
        ),
      );

      expect(resultText.textAlign, TextAlign.justify);
    });

    testWidgets('shows a scrollbar for the chapter content on Android',
        (tester) async {
      final openRouter = _FakeOpenRouterService(
        generateTextHandler: ({
          required apiKey,
          required modelId,
          required prompt,
          temperature,
        }) async =>
            'Definition: vague\nTranslation: neyasny',
      );

      await _pumpReaderScreen(
        tester,
        openRouterService: openRouter,
      );

      expect(find.byType(Scrollbar), findsOneWidget);
    });

    testWidgets('summary result sheet shows switch action for simplify text',
        (tester) async {
      final openRouter = _FakeOpenRouterService(
        generateTextHandler: ({
          required apiKey,
          required modelId,
          required prompt,
          temperature,
        }) async =>
            'Catch-up summary.',
      );

      await _pumpReaderScreen(
        tester,
        openRouterService: openRouter,
      );

      await _startCatchMeUp(tester);
      await tester.pumpAndSettle();

      expect(find.text('Summary'), findsOneWidget);
      expect(find.text('Catch-up summary.'), findsOneWidget);
      expect(find.byTooltip('Copy'), findsOneWidget);
      expect(find.byTooltip('Regenerate with Fallback'), findsOneWidget);
      expect(find.byTooltip('Simplify Text'), findsOneWidget);
    });

    testWidgets('simplify text result sheet shows switch action for summary',
        (tester) async {
      final openRouter = _FakeOpenRouterService(
        generateTextHandler: ({
          required apiKey,
          required modelId,
          required prompt,
          temperature,
        }) async =>
            'Simplified text.',
      );

      await _pumpReaderScreen(
        tester,
        openRouterService: openRouter,
      );

      await _startSimplifyText(tester);
      await tester.pumpAndSettle();

      expect(find.text('Simplified text.'), findsOneWidget);
      expect(find.byTooltip('Copy'), findsOneWidget);
      expect(find.byTooltip('Regenerate with Fallback'), findsOneWidget);
      expect(find.byTooltip('Summary'), findsOneWidget);
    });

    testWidgets('opens the result sheet in error state when AI fails',
        (tester) async {
      final completer = Completer<String>();
      final openRouter = _FakeOpenRouterService(
        generateTextHandler: ({
          required apiKey,
          required modelId,
          required prompt,
          temperature,
        }) =>
            completer.future,
      );

      await _pumpReaderScreen(
        tester,
        openRouterService: openRouter,
      );

      await _startDefineAndTranslate(tester);
      completer.completeError(const OpenRouterException('Network failed.'));

      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('reader-ai-loading-sheet')),
        findsNothing,
      );
      expect(find.text('Define & Translate'), findsOneWidget);
      expect(find.text('Network failed.'), findsOneWidget);
      expect(find.text('Regenerate with Fallback'), findsOneWidget);
      expect(find.text('Copy'), findsNothing);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('blocks starting another AI request while one is loading',
        (tester) async {
      final completer = Completer<String>();
      final openRouter = _FakeOpenRouterService(
        generateTextHandler: ({
          required apiKey,
          required modelId,
          required prompt,
          temperature,
        }) =>
            completer.future,
      );

      await _pumpReaderScreen(
        tester,
        openRouterService: openRouter,
      );

      await _startDefineAndTranslate(tester);
      expect(openRouter.generateTextCallCount, 1);

      await _startDefineAndTranslate(tester);
      await tester.pump();

      expect(openRouter.generateTextCallCount, 1);
      expect(find.text('An AI response is already loading.'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      completer.complete('Definition: vague\nTranslation: neyasny');
      await tester.pump();
      await tester.pumpAndSettle();
    });

    testWidgets('includes the extracted context sentence in the prompt',
        (tester) async {
      final spyResumeSummaryService = _SpyResumeSummaryService();
      final openRouter = _FakeOpenRouterService(
        generateTextHandler: ({
          required apiKey,
          required modelId,
          required prompt,
          temperature,
        }) async =>
            'Definition: vague\nTranslation: neyasny',
      );

      await _pumpReaderScreen(
        tester,
        openRouterService: openRouter,
        resumeSummaryService: spyResumeSummaryService,
      );

      await _startDefineAndTranslate(tester);
      await tester.pumpAndSettle();

      expect(
        spyResumeSummaryService.lastContextSentence,
        'The hero felt nebulous about the plan.',
      );
      expect(spyResumeSummaryService.lastSourceText, isNotEmpty);
      expect(
        openRouter.lastPrompt,
        contains('Context sentence:\nThe hero felt nebulous about the plan.'),
      );
    });

    testWidgets('shows both generate image source modes', (tester) async {
      final openRouter = _FakeOpenRouterService(
        generateTextHandler: ({
          required apiKey,
          required modelId,
          required prompt,
          temperature,
        }) async =>
            'A watercolor illustration of the scene.',
      );

      await _pumpReaderScreen(
        tester,
        openRouterService: openRouter,
      );

      await _startGenerateImage(tester);
      await tester.pumpAndSettle();

      expect(find.text('Generate Image'), findsWidgets);
      expect(find.text('Selected Text'), findsOneWidget);
      expect(find.text('Resume Range'), findsOneWidget);
    });

    testWidgets(
        'selected-text generate image flow opens prompt editor and calls image model',
        (tester) async {
      final openRouter = _FakeOpenRouterService(
        generateTextHandler: ({
          required apiKey,
          required modelId,
          required prompt,
          temperature,
        }) async =>
            'A quiet watercolor portrait of the hero in soft lantern light.',
        fetchModelsHandler: ({
          required apiKey,
          required forceRefresh,
        }) async =>
            const [
              OpenRouterModel(
                id: 'openai/gpt-image-1',
                name: 'GPT Image 1',
                outputModalities: ['image', 'text'],
              ),
            ],
        generateImageHandler: ({
          required apiKey,
          required modelId,
          required prompt,
          required modalities,
          temperature,
        }) async =>
            const OpenRouterImageGenerationResult(
              assistantText: 'Rendered successfully.',
              imageUrls: [
                'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO6V1xQAAAAASUVORK5CYII='
              ],
            ),
      );

      await _pumpReaderScreen(
        tester,
        openRouterService: openRouter,
      );
      await _startGenerateImage(tester);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      await tester.tap(find.text('Selected Text'));
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }

      expect(find.text('Edit Image Prompt'), findsOneWidget);
      expect(
        find.textContaining('A quiet watercolor portrait'),
        findsOneWidget,
      );

      await tester.tap(find.text('Generate'));
      await tester.pump();
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }

      expect(openRouter.generateTextCallCount, 1);
      expect(openRouter.generateImageCallCount, 1);
      expect(
        openRouter.generateImageCalls.single.modelId,
        'openai/gpt-image-1',
      );
      expect(
        openRouter.generateImageCalls.single.prompt,
        contains('watercolor portrait'),
      );
    });

    testWidgets('generate image uses image-only modalities for flux models',
        (tester) async {
      final openRouter = _FakeOpenRouterService(
        generateTextHandler: ({
          required apiKey,
          required modelId,
          required prompt,
          temperature,
        }) async =>
            'A stark monochrome illustration of the scene.',
        fetchModelsHandler: ({
          required apiKey,
          required forceRefresh,
        }) async =>
            const [
              OpenRouterModel(
                id: 'black-forest-labs/flux.2-klein-4b',
                name: 'FLUX.2 Klein',
              ),
            ],
        generateImageHandler: ({
          required apiKey,
          required modelId,
          required prompt,
          required modalities,
          temperature,
        }) async =>
            const OpenRouterImageGenerationResult(
              assistantText: '',
              imageUrls: [
                'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO6V1xQAAAAASUVORK5CYII='
              ],
            ),
      );

      await _pumpReaderScreen(
        tester,
        openRouterService: openRouter,
        imageModelId: 'black-forest-labs/flux.2-klein-4b',
      );

      await _startGenerateImage(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Selected Text'));
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }

      await tester.tap(find.text('Generate'));
      await tester.pump();
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }

      expect(openRouter.generateImageCallCount, 1);
      expect(openRouter.generateImageCalls.single.modalities, ['image']);
    });

    testWidgets(
        'regenerate with fallback reruns define and translate with same prompt',
        (tester) async {
      final firstResult = Completer<String>();
      final secondResult = Completer<String>();
      var callIndex = 0;
      final openRouter = _FakeOpenRouterService(
        generateTextHandler: ({
          required apiKey,
          required modelId,
          required prompt,
          temperature,
        }) {
          final result =
              callIndex == 0 ? firstResult.future : secondResult.future;
          callIndex += 1;
          return result;
        },
      );

      await _pumpReaderScreen(
        tester,
        openRouterService: openRouter,
      );

      await _startDefineAndTranslate(tester);
      firstResult.complete('Definition: vague\nTranslation: neyasny');

      await tester.pump();
      await tester.pumpAndSettle();

      final firstCall = openRouter.generateTextCalls.single;
      await tester.tap(find.byTooltip('Regenerate with Fallback'));
      await tester.pump();

      expect(openRouter.generateTextCallCount, 2);
      expect(openRouter.generateTextCalls[1].prompt, firstCall.prompt);
      expect(
        openRouter.generateTextCalls[1].modelId,
        'anthropic/claude-3.7-sonnet',
      );

      secondResult.complete('Definition: vague\nTranslation: neyasny 2');
      await tester.pump();
      await tester.pumpAndSettle();
    });

    testWidgets(
        'regenerate with fallback reruns simplify text with same prompt',
        (tester) async {
      final firstResult = Completer<String>();
      final secondResult = Completer<String>();
      var callIndex = 0;
      final openRouter = _FakeOpenRouterService(
        generateTextHandler: ({
          required apiKey,
          required modelId,
          required prompt,
          temperature,
        }) {
          final result =
              callIndex == 0 ? firstResult.future : secondResult.future;
          callIndex += 1;
          return result;
        },
      );

      await _pumpReaderScreen(
        tester,
        openRouterService: openRouter,
      );

      await _startSimplifyText(tester);
      firstResult.complete('Simplified text.');

      await tester.pump();
      await tester.pumpAndSettle();

      final firstCall = openRouter.generateTextCalls.single;
      await tester.tap(find.byTooltip('Regenerate with Fallback'));
      await tester.pump();

      expect(openRouter.generateTextCallCount, 2);
      expect(openRouter.generateTextCalls[1].prompt, firstCall.prompt);
      expect(
        openRouter.generateTextCalls[1].modelId,
        'anthropic/claude-3.7-sonnet',
      );

      secondResult.complete('Simplified text again.');
      await tester.pump();
      await tester.pumpAndSettle();
    });

    testWidgets(
        'switching from summary reruns simplify text with same source text',
        (tester) async {
      final firstResult = Completer<String>();
      final secondResult = Completer<String>();
      final spyResumeSummaryService = _SpyResumeSummaryService();
      var callIndex = 0;
      final openRouter = _FakeOpenRouterService(
        generateTextHandler: ({
          required apiKey,
          required modelId,
          required prompt,
          temperature,
        }) {
          final result =
              callIndex == 0 ? firstResult.future : secondResult.future;
          callIndex += 1;
          return result;
        },
      );

      await _pumpReaderScreen(
        tester,
        openRouterService: openRouter,
        resumeSummaryService: spyResumeSummaryService,
      );

      await _startCatchMeUp(tester);
      firstResult.complete('Catch-up summary.');

      await tester.pump();
      await tester.pumpAndSettle();

      expect(spyResumeSummaryService.renderCalls, hasLength(1));
      final firstRender = spyResumeSummaryService.renderCalls.first;

      await tester.tap(find.byTooltip('Simplify Text'));
      await tester.pump();

      expect(openRouter.generateTextCallCount, 2);
      expect(spyResumeSummaryService.renderCalls, hasLength(2));
      final secondRender = spyResumeSummaryService.renderCalls[1];
      expect(firstRender.sourceText, secondRender.sourceText);
      expect(firstRender.promptTemplate, defaultResumeSummaryPromptTemplate);
      expect(secondRender.promptTemplate, defaultSimplifyTextPromptTemplate);

      secondResult.complete('Simplified text.');
      await tester.pump();
      await tester.pumpAndSettle();
    });

    testWidgets(
        'switching from simplify text reruns summary with same source text',
        (tester) async {
      final firstResult = Completer<String>();
      final secondResult = Completer<String>();
      final spyResumeSummaryService = _SpyResumeSummaryService();
      var callIndex = 0;
      final openRouter = _FakeOpenRouterService(
        generateTextHandler: ({
          required apiKey,
          required modelId,
          required prompt,
          temperature,
        }) {
          final result =
              callIndex == 0 ? firstResult.future : secondResult.future;
          callIndex += 1;
          return result;
        },
      );

      await _pumpReaderScreen(
        tester,
        openRouterService: openRouter,
        resumeSummaryService: spyResumeSummaryService,
      );

      await _startSimplifyText(tester);
      firstResult.complete('Simplified text.');

      await tester.pump();
      await tester.pumpAndSettle();

      expect(spyResumeSummaryService.renderCalls, hasLength(1));
      final firstRender = spyResumeSummaryService.renderCalls.first;

      await tester.tap(find.byTooltip('Summary'));
      await tester.pump();

      expect(openRouter.generateTextCallCount, 2);
      expect(spyResumeSummaryService.renderCalls, hasLength(2));
      final secondRender = spyResumeSummaryService.renderCalls[1];
      expect(firstRender.sourceText, secondRender.sourceText);
      expect(firstRender.promptTemplate, defaultSimplifyTextPromptTemplate);
      expect(secondRender.promptTemplate, defaultResumeSummaryPromptTemplate);

      secondResult.complete('Catch-up summary.');
      await tester.pump();
      await tester.pumpAndSettle();
    });

    testWidgets(
        'shows snackbar instead of retrying when fallback model is not configured',
        (tester) async {
      final openRouter = _FakeOpenRouterService(
        generateTextHandler: ({
          required apiKey,
          required modelId,
          required prompt,
          temperature,
        }) async =>
            'Definition: vague\nTranslation: neyasny',
      );

      await _pumpReaderScreen(
        tester,
        openRouterService: openRouter,
        fallbackModelId: '',
      );

      await _startDefineAndTranslate(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Regenerate with Fallback'));
      await tester.pump();

      expect(openRouter.generateTextCallCount, 1);
      expect(
        find.text('Select a fallback AI model in Settings first.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 2));
    });
  });
}

Future<void> _pumpReaderScreen(
  WidgetTester tester, {
  required OpenRouterService openRouterService,
  ResumeSummaryService? resumeSummaryService,
  String fallbackModelId = 'anthropic/claude-3.7-sonnet',
  String imageModelId = 'openai/gpt-image-1',
  Book? savedBook,
  DatabaseService? databaseService,
  StorageService? storageService,
}) async {
  SharedPreferences.setMockInitialValues({
    'reader_openrouter_api_key': 'test-key',
    'reader_openrouter_model_id': 'openai/gpt-4o-mini',
    'reader_openrouter_fallback_model_id': fallbackModelId,
    'reader_openrouter_image_model_id': imageModelId,
  });

  final controller = SettingsController();
  await tester.runAsync(() async {
    await controller.load();
    if (databaseService != null) {
      await databaseService.database;
    }
  });

  addTearDown(controller.dispose);

  final chapterLoader = ChapterLoaderService(
    parseChapters: (_) async => [
      Chapter(
        bookId: null,
        index: 0,
        title: 'Chapter 1',
        content: List<String>.filled(120, 'Nebulous').join(' '),
      ),
    ],
    cacheChapters: (_, __) {},
  );

  await tester.pumpWidget(
    SettingsControllerScope(
      controller: controller,
      child: MaterialApp(
        home: ReaderScreen(
          book: savedBook ??
              Book(
                title: 'Test Book',
                author: 'Test Author',
                filePath: '/tmp/test.epub',
                totalChapters: 1,
                createdAt: DateTime(2024, 1, 1),
              ),
          chapterLoader: chapterLoader,
          databaseService: databaseService,
          openRouterService: openRouterService,
          resumeSummaryService: resumeSummaryService,
          storageService: storageService,
        ),
      ),
    ),
  );

  if (databaseService == null) {
    await tester.pumpAndSettle();
    return;
  }

  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
}

Future<void> _startDefineAndTranslate(WidgetTester tester) async {
  await tester.longPress(find.byType(SelectableText).first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(find.text('Define & Translate'));
  await tester.pump();
}

Future<void> _startCatchMeUp(WidgetTester tester) async {
  await tester.longPress(find.byType(SelectableText).first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(find.text('Catch Me Up'));
  await tester.pump();
}

Future<void> _startSimplifyText(WidgetTester tester) async {
  await tester.longPress(find.byType(SelectableText).first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(find.text('Simplify Text'));
  await tester.pump();
}

Future<void> _startGenerateImage(WidgetTester tester) async {
  await tester.longPress(find.byType(SelectableText).first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(find.text('Generate Image'));
  await tester.pump();
}

typedef _GenerateTextHandler = Future<String> Function({
  required String apiKey,
  required String modelId,
  required String prompt,
  double? temperature,
});

typedef _FetchModelsHandler = Future<List<OpenRouterModel>> Function({
  required String apiKey,
  required bool forceRefresh,
});

typedef _GenerateImageHandler = Future<OpenRouterImageGenerationResult> Function({
  required String apiKey,
  required String modelId,
  required String prompt,
  required List<String> modalities,
  double? temperature,
});

class _FakeOpenRouterService extends OpenRouterService {
  final _GenerateTextHandler generateTextHandler;
  final _FetchModelsHandler fetchModelsHandler;
  final _GenerateImageHandler generateImageHandler;
  int generateTextCallCount = 0;
  final List<_GenerateTextCall> generateTextCalls = [];
  int generateImageCallCount = 0;
  final List<_GenerateImageCall> generateImageCalls = [];
  String? lastPrompt;

  _FakeOpenRouterService({
    required this.generateTextHandler,
    _FetchModelsHandler? fetchModelsHandler,
    _GenerateImageHandler? generateImageHandler,
  })  : fetchModelsHandler = fetchModelsHandler ?? _defaultFetchModels,
        generateImageHandler =
            generateImageHandler ?? _defaultGenerateImage;

  static Future<List<OpenRouterModel>> _defaultFetchModels({
    required String apiKey,
    required bool forceRefresh,
  }) async {
    return const [
      OpenRouterModel(
        id: 'openai/gpt-image-1',
        name: 'GPT Image 1',
        outputModalities: ['image', 'text'],
      ),
      OpenRouterModel(
        id: 'openai/gpt-4o-mini',
        name: 'GPT-4o Mini',
        outputModalities: ['text'],
      ),
    ];
  }

  static Future<OpenRouterImageGenerationResult> _defaultGenerateImage({
    required String apiKey,
    required String modelId,
    required String prompt,
    required List<String> modalities,
    double? temperature,
  }) async {
    return const OpenRouterImageGenerationResult(
      assistantText: '',
      imageUrls: <String>[],
    );
  }

  @override
  Future<String> generateText({
    required String apiKey,
    required String modelId,
    required String prompt,
    double? temperature,
  }) {
    generateTextCallCount += 1;
    generateTextCalls.add(
      _GenerateTextCall(
        apiKey: apiKey,
        modelId: modelId,
        prompt: prompt,
      ),
    );
    lastPrompt = prompt;
    return generateTextHandler(
      apiKey: apiKey,
      modelId: modelId,
      prompt: prompt,
      temperature: temperature,
    );
  }

  @override
  Future<List<OpenRouterModel>> fetchModels({
    String? apiKey,
    bool forceRefresh = false,
  }) {
    return fetchModelsHandler(
      apiKey: apiKey ?? '',
      forceRefresh: forceRefresh,
    );
  }

  @override
  Future<OpenRouterImageGenerationResult> generateImage({
    required String apiKey,
    required String modelId,
    required String prompt,
    List<String> modalities = const <String>['image', 'text'],
    double? temperature,
  }) {
    generateImageCallCount += 1;
    generateImageCalls.add(
      _GenerateImageCall(
        apiKey: apiKey,
        modelId: modelId,
        prompt: prompt,
        modalities: List<String>.from(modalities),
      ),
    );
    return generateImageHandler(
      apiKey: apiKey,
      modelId: modelId,
      prompt: prompt,
      modalities: modalities,
      temperature: temperature,
    );
  }
}

class _GenerateTextCall {
  final String apiKey;
  final String modelId;
  final String prompt;

  const _GenerateTextCall({
    required this.apiKey,
    required this.modelId,
    required this.prompt,
  });
}

class _GenerateImageCall {
  final String apiKey;
  final String modelId;
  final String prompt;
  final List<String> modalities;

  const _GenerateImageCall({
    required this.apiKey,
    required this.modelId,
    required this.prompt,
    required this.modalities,
  });
}

class _SpyResumeSummaryService extends ResumeSummaryService {
  String? lastSourceText;
  String? lastContextSentence;
  final List<_RenderPromptCall> renderCalls = [];

  @override
  String extractContextSentence({
    required String chapterContent,
    required int selectionStart,
    required int selectionEnd,
  }) {
    return 'The hero felt nebulous about the plan.';
  }

  @override
  String renderPromptTemplate({
    required String promptTemplate,
    required String sourceText,
    required String bookTitle,
    String bookAuthor = '',
    required String chapterTitle,
    String contextSentence = '',
  }) {
    lastSourceText = sourceText;
    lastContextSentence = contextSentence;
    renderCalls.add(
      _RenderPromptCall(
        promptTemplate: promptTemplate,
        sourceText: sourceText,
        contextSentence: contextSentence,
      ),
    );
    return super.renderPromptTemplate(
      promptTemplate: promptTemplate,
      sourceText: sourceText,
      bookTitle: bookTitle,
      bookAuthor: bookAuthor,
      chapterTitle: chapterTitle,
      contextSentence: contextSentence,
    );
  }
}

class _RenderPromptCall {
  final String promptTemplate;
  final String sourceText;
  final String contextSentence;

  const _RenderPromptCall({
    required this.promptTemplate,
    required this.sourceText,
    required this.contextSentence,
  });
}

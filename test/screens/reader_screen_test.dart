import 'dart:async';

import 'package:bookai/app.dart';
import 'package:bookai/models/book.dart';
import 'package:bookai/models/chapter.dart';
import 'package:bookai/screens/reader_screen.dart';
import 'package:bookai/services/chapter_loader_service.dart';
import 'package:bookai/services/openrouter_service.dart';
import 'package:bookai/services/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

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
      expect(find.text('Copy'), findsOneWidget);
      expect(find.byType(ModalBarrier), findsWidgets);
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
      expect(find.text('Copy'), findsNothing);
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
  });
}

Future<void> _pumpReaderScreen(
  WidgetTester tester, {
  required OpenRouterService openRouterService,
}) async {
  SharedPreferences.setMockInitialValues({
    'reader_openrouter_api_key': 'test-key',
    'reader_openrouter_model_id': 'openai/gpt-4o-mini',
  });

  final controller = SettingsController();
  await tester.runAsync(() => controller.load());

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
          book: Book(
            title: 'Test Book',
            author: 'Test Author',
            filePath: '/tmp/test.epub',
            totalChapters: 1,
            createdAt: DateTime(2024, 1, 1),
          ),
          chapterLoader: chapterLoader,
          openRouterService: openRouterService,
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

Future<void> _startDefineAndTranslate(WidgetTester tester) async {
  await tester.longPress(find.byType(SelectableText).first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(find.text('Define & Translate'));
  await tester.pump();
}

typedef _GenerateTextHandler = Future<String> Function({
  required String apiKey,
  required String modelId,
  required String prompt,
  double? temperature,
});

class _FakeOpenRouterService extends OpenRouterService {
  final _GenerateTextHandler generateTextHandler;
  int generateTextCallCount = 0;

  _FakeOpenRouterService({
    required this.generateTextHandler,
  });

  @override
  Future<String> generateText({
    required String apiKey,
    required String modelId,
    required String prompt,
    double? temperature,
  }) {
    generateTextCallCount += 1;
    return generateTextHandler(
      apiKey: apiKey,
      modelId: modelId,
      prompt: prompt,
      temperature: temperature,
    );
  }
}

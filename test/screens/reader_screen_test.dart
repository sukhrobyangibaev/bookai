import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bookai/app.dart';
import 'package:bookai/models/book.dart';
import 'package:bookai/models/ai_feature.dart';
import 'package:bookai/models/ai_model_info.dart';
import 'package:bookai/models/ai_model_selection.dart';
import 'package:bookai/models/ai_provider.dart';
import 'package:bookai/models/chapter.dart';
import 'package:bookai/models/openrouter_model.dart';
import 'package:bookai/models/resume_marker.dart';
import 'package:bookai/screens/reader_screen.dart';
import 'package:bookai/services/chapter_loader_service.dart';
import 'package:bookai/services/database_service.dart';
import 'package:bookai/services/gemini_service.dart';
import 'package:bookai/services/openrouter_service.dart';
import 'package:bookai/services/resume_summary_service.dart';
import 'package:bookai/services/settings_controller.dart';
import 'package:bookai/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
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

    testWidgets('canceling the loading sheet hides it and ignores late results',
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

      await tester.tap(find.byTooltip('Cancel AI Request'));
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('reader-ai-loading-sheet')),
        findsNothing,
      );
      expect(find.text('AI request canceled.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));

      completer.complete('Definition: late\nTranslation: ignored');
      await tester.pumpAndSettle();

      expect(find.text('Define & Translate'), findsNothing);
      expect(find.text('Definition: late\nTranslation: ignored'), findsNothing);
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

    testWidgets(
        'hidden nav mode keeps chapter content below the sticky top pill',
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
        mediaQueryPadding: const EdgeInsets.only(top: 32),
      );

      final pillFinder =
          find.byKey(const ValueKey<String>('reader-hidden-nav-pill'));
      final chapterTitleFinder = find.text('Chapter 1');

      expect(pillFinder, findsOneWidget);
      expect(find.text('1 / 1'), findsOneWidget);

      final pillBottom = tester.getBottomLeft(pillFinder).dy;
      final chapterTop = tester.getTopLeft(chapterTitleFinder).dy;

      expect(chapterTop, greaterThan(32));
      expect(chapterTop, greaterThan(pillBottom));

      await tester.tap(find.byTooltip('Show Navigation Bar'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Hide Navigation Bar'), findsOneWidget);
    });

    testWidgets(
        'shows in-content chapter buttons and navigates between chapters',
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
        chapters: _buildTestChapters(count: 3),
      );

      final chapterOneTitle = find.text('Chapter 1');
      final nextChapterButton = find.text('Next Chapter');
      final chapterCatchUpButton = find.text('Chapter Catch-Up');

      expect(find.text('Previous Chapter'), findsNothing);
      expect(chapterCatchUpButton, findsOneWidget);
      expect(nextChapterButton, findsOneWidget);
      expect(
        tester.getTopLeft(nextChapterButton).dy,
        greaterThan(tester.getTopLeft(chapterOneTitle).dy),
      );

      await tester.ensureVisible(nextChapterButton);
      await tester.tap(nextChapterButton);
      await tester.pumpAndSettle();

      final previousChapterButton = find.text('Previous Chapter');
      final chapterTwoTitle = find.text('Chapter 2');

      expect(previousChapterButton, findsOneWidget);
      expect(find.text('Chapter Catch-Up'), findsOneWidget);
      expect(find.text('Next Chapter'), findsOneWidget);
      expect(
        tester.getTopLeft(previousChapterButton).dy,
        lessThan(tester.getTopLeft(chapterTwoTitle).dy),
      );

      await tester.ensureVisible(find.text('Next Chapter'));
      await tester.tap(find.text('Next Chapter'));
      await tester.pumpAndSettle();

      expect(find.text('Chapter 3'), findsOneWidget);
      expect(find.text('Chapter Catch-Up'), findsOneWidget);
      expect(find.text('Previous Chapter'), findsOneWidget);
      expect(find.text('Next Chapter'), findsNothing);
    });

    testWidgets(
        'chapter catch-up uses the entire current chapter without resume range',
        (tester) async {
      const chapterText =
          'First scene. Second scene. Final reveal of the chapter.';
      final spyResumeSummaryService = _SpyResumeSummaryService(
        forcedRange: const ResumeSummaryRange(
          startOffset: 0,
          endOffset: 11,
          sourceText: 'Forced range',
          shouldUpdateResumeMarker: true,
        ),
      );
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
        resumeSummaryService: spyResumeSummaryService,
        chapters: const [
          Chapter(
            bookId: null,
            index: 0,
            title: 'Chapter 1',
            content: chapterText,
          ),
        ],
      );

      await _startChapterCatchUp(tester);
      await tester.pumpAndSettle();

      expect(spyResumeSummaryService.computeRangeCallCount, 0);
      expect(spyResumeSummaryService.lastSourceText, chapterText);
      expect(openRouter.lastPrompt, contains('Passage:\n$chapterText'));
      expect(find.text('Summary'), findsOneWidget);
      expect(find.text('Catch-up summary.'), findsOneWidget);
      expect(find.byTooltip('Copy'), findsOneWidget);
      expect(find.byTooltip('Regenerate with Fallback'), findsOneWidget);
      expect(find.byTooltip('Simplify Text'), findsOneWidget);
    });

    testWidgets('chapter catch-up shows snackbar for blank chapters',
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
        chapters: const [
          Chapter(
            bookId: null,
            index: 0,
            title: 'Chapter 1',
            content: '   \n\t  ',
          ),
        ],
      );

      await _startChapterCatchUp(tester);
      await tester.pump();

      expect(openRouter.generateTextCallCount, 0);
      expect(
        find.text('This chapter has no text to summarize.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('chapter catch-up does not update the saved resume marker',
        (tester) async {
      final tempDir = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('bookai_reader_screen_test_'),
      ))!;
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final databaseService = DatabaseService.instance;
      final databasePath = p.join(tempDir.path, 'reader_screen_test.db');
      await tester.runAsync(
        () => databaseService.resetForTesting(databasePath: databasePath),
      );
      addTearDown(() async {
        await databaseService.resetForTesting();
      });

      final savedBook = (await tester.runAsync(
        () => databaseService.insertBook(
          Book(
            title: 'Persisted Book',
            author: 'Author',
            filePath: '/tmp/persisted-reader.epub',
            totalChapters: 1,
            createdAt: DateTime.utc(2025, 1, 1),
          ),
        ),
      ))!;
      final savedMarker = ResumeMarker(
        bookId: savedBook.id!,
        chapterIndex: 0,
        selectedText: 'Saved marker text',
        selectionStart: 2,
        selectionEnd: 8,
        scrollOffset: 0,
        createdAt: DateTime.utc(2025, 1, 2),
      );
      await tester.runAsync(
        () => databaseService.upsertResumeMarker(savedMarker),
      );

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
        databaseService: databaseService,
        savedBook: savedBook,
        chapters: const [
          Chapter(
            bookId: null,
            index: 0,
            title: 'Chapter 1',
            content: 'Stored content for summary.',
          ),
        ],
      );
      await tester.pump(const Duration(seconds: 2));

      await _startChapterCatchUp(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final markerAfterCatchUp = await tester.runAsync(
        () => databaseService.getResumeMarkerByBookId(savedBook.id!),
      );
      expect(openRouter.generateTextCallCount, 1);
      expect(markerAfterCatchUp, savedMarker);
    });

    testWidgets('does not switch chapters on horizontal drag', (tester) async {
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
        chapters: _buildTestChapters(count: 2),
      );

      expect(find.text('Chapter 1'), findsOneWidget);
      expect(find.text('Chapter 2'), findsNothing);

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(-400, 0),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chapter 1'), findsOneWidget);
      expect(find.text('Chapter 2'), findsNothing);
      expect(find.text('Next Chapter'), findsOneWidget);
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

    testWidgets('shows both summary source modes', (tester) async {
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

      await _startCatchMeUp(tester, sourceModeLabel: null);
      await tester.pumpAndSettle();

      expect(find.text('Summary'), findsWidgets);
      expect(find.text('Selected Text'), findsOneWidget);
      expect(find.text('Resume Range'), findsOneWidget);
    });

    testWidgets('shows both simplify text source modes', (tester) async {
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

      await _startSimplifyText(tester, sourceModeLabel: null);
      await tester.pumpAndSettle();

      expect(find.text('Simplify Text'), findsWidgets);
      expect(find.text('Selected Text'), findsOneWidget);
      expect(find.text('Resume Range'), findsOneWidget);
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

    testWidgets('selected-text summary flow uses only the selected text',
        (tester) async {
      const forcedRangeText = 'Forced resume range text.';
      final spyResumeSummaryService = _SpyResumeSummaryService(
        forcedRange: const ResumeSummaryRange(
          startOffset: 0,
          endOffset: 24,
          sourceText: forcedRangeText,
          shouldUpdateResumeMarker: false,
        ),
      );
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
        resumeSummaryService: spyResumeSummaryService,
        chapters: const [
          Chapter(
            bookId: null,
            index: 0,
            title: 'Chapter 1',
            content: 'Anchorword leads the sentence. More text follows here.',
          ),
        ],
      );

      await _startCatchMeUp(tester, sourceModeLabel: 'Selected Text');
      await tester.pumpAndSettle();

      expect(spyResumeSummaryService.computeRangeCallCount, 0);
      expect(spyResumeSummaryService.lastSourceText, 'Anchorword');
      expect(openRouter.lastPrompt, contains('Passage:\nAnchorword'));
      expect(openRouter.lastPrompt, isNot(contains(forcedRangeText)));
    });

    testWidgets('selected-text simplify flow uses only the selected text',
        (tester) async {
      const forcedRangeText = 'Forced resume range text.';
      final spyResumeSummaryService = _SpyResumeSummaryService(
        forcedRange: const ResumeSummaryRange(
          startOffset: 0,
          endOffset: 24,
          sourceText: forcedRangeText,
          shouldUpdateResumeMarker: false,
        ),
      );
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
        resumeSummaryService: spyResumeSummaryService,
        chapters: const [
          Chapter(
            bookId: null,
            index: 0,
            title: 'Chapter 1',
            content: 'Anchorword leads the sentence. More text follows here.',
          ),
        ],
      );

      await _startSimplifyText(tester, sourceModeLabel: 'Selected Text');
      await tester.pumpAndSettle();

      expect(spyResumeSummaryService.computeRangeCallCount, 0);
      expect(spyResumeSummaryService.lastSourceText, 'Anchorword');
      expect(openRouter.lastPrompt, contains('Passage:\nAnchorword'));
      expect(openRouter.lastPrompt, isNot(contains(forcedRangeText)));
    });

    testWidgets('resume-range summary flow still uses the computed range',
        (tester) async {
      const forcedRangeText = 'Forced resume range text.';
      final spyResumeSummaryService = _SpyResumeSummaryService(
        forcedRange: const ResumeSummaryRange(
          startOffset: 0,
          endOffset: 24,
          sourceText: forcedRangeText,
          shouldUpdateResumeMarker: false,
        ),
      );
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
        resumeSummaryService: spyResumeSummaryService,
      );

      await _startCatchMeUp(tester);
      await tester.pumpAndSettle();

      expect(spyResumeSummaryService.computeRangeCallCount, 1);
      expect(spyResumeSummaryService.lastSourceText, forcedRangeText);
      expect(openRouter.lastPrompt, contains('Passage:\n$forcedRangeText'));
    });

    testWidgets('resume-range simplify flow still uses the computed range',
        (tester) async {
      const forcedRangeText = 'Forced resume range text.';
      final spyResumeSummaryService = _SpyResumeSummaryService(
        forcedRange: const ResumeSummaryRange(
          startOffset: 0,
          endOffset: 24,
          sourceText: forcedRangeText,
          shouldUpdateResumeMarker: false,
        ),
      );
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
        resumeSummaryService: spyResumeSummaryService,
      );

      await _startSimplifyText(tester);
      await tester.pumpAndSettle();

      expect(spyResumeSummaryService.computeRangeCallCount, 1);
      expect(spyResumeSummaryService.lastSourceText, forcedRangeText);
      expect(openRouter.lastPrompt, contains('Passage:\n$forcedRangeText'));
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
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == 'Image Name (Optional)',
        ),
        findsOneWidget,
      );
      expect(find.text('Leave blank to use the book name.'), findsOneWidget);

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

    testWidgets('generate image respects image-only metadata modalities',
        (tester) async {
      final openRouter = _FakeOpenRouterService(
        generateTextHandler: ({
          required apiKey,
          required modelId,
          required prompt,
          temperature,
        }) async =>
            'A moody charcoal sketch of the scene.',
        fetchModelsHandler: ({
          required apiKey,
          required forceRefresh,
        }) async =>
            const [
          OpenRouterModel(
            id: 'example/image-only-model',
            name: 'Image Only Model',
            outputModalities: ['image'],
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
        imageModelId: 'example/image-only-model',
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
        'generate image blocks prompt-model overrides that cannot return text',
        (tester) async {
      final openRouter = _FakeOpenRouterService(
        generateTextHandler: ({
          required apiKey,
          required modelId,
          required prompt,
          temperature,
        }) async =>
            'This should never be called.',
        fetchModelsHandler: ({
          required apiKey,
          required forceRefresh,
        }) async =>
            const [
          OpenRouterModel(
            id: 'example/image-only-prompt-model',
            name: 'Image Only Prompt Model',
            outputModalities: ['image'],
          ),
          OpenRouterModel(
            id: 'openai/gpt-image-1',
            name: 'GPT Image 1',
            outputModalities: ['image', 'text'],
          ),
        ],
      );

      await _pumpReaderScreen(
        tester,
        openRouterService: openRouter,
        generateImagePromptModelIdOverride: 'example/image-only-prompt-model',
      );

      await _startGenerateImage(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Selected Text'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'The selected prompt model does not support text output. Choose a text-capable model for Generate Image in Settings.',
        ),
        findsOneWidget,
      );
      expect(openRouter.generateTextCallCount, 0);
      expect(openRouter.generateImageCallCount, 0);
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

    testWidgets('uses Gemini when the default text model provider is Gemini',
        (tester) async {
      final openRouter = _FakeOpenRouterService(
        generateTextHandler: ({
          required apiKey,
          required modelId,
          required prompt,
          temperature,
        }) async =>
            'unused',
      );
      final gemini = _FakeGeminiService(
        generateTextHandler: ({
          required apiKey,
          required modelId,
          required prompt,
          temperature,
        }) async =>
            'Definition: nebulous\nTranslation: tumannyy',
      );

      await _pumpReaderScreen(
        tester,
        openRouterService: openRouter,
        geminiService: gemini,
        openRouterApiKey: '',
        geminiApiKey: 'gem-key',
        defaultModelSelection: const AiModelSelection(
          provider: AiProvider.gemini,
          modelId: 'gemini-2.5-flash',
        ),
      );

      await _startDefineAndTranslate(tester);
      await tester.pumpAndSettle();

      expect(gemini.generateTextCallCount, 1);
      expect(openRouter.generateTextCallCount, 0);
      expect(gemini.generateTextCalls.single.apiKey, 'gem-key');
      expect(gemini.generateTextCalls.single.modelId, 'gemini-2.5-flash');
      expect(
          find.text('Definition: nebulous\nTranslation: tumannyy'), findsOne);
    });

    testWidgets('regenerate with fallback can switch from OpenRouter to Gemini',
        (tester) async {
      final openRouter = _FakeOpenRouterService(
        generateTextHandler: ({
          required apiKey,
          required modelId,
          required prompt,
          temperature,
        }) async {
          throw const OpenRouterException('Primary failed.');
        },
      );
      final gemini = _FakeGeminiService(
        generateTextHandler: ({
          required apiKey,
          required modelId,
          required prompt,
          temperature,
        }) async =>
            'Recovered from Gemini',
      );

      await _pumpReaderScreen(
        tester,
        openRouterService: openRouter,
        geminiService: gemini,
        openRouterApiKey: 'or-key',
        geminiApiKey: 'gem-key',
        defaultModelSelection: const AiModelSelection(
          provider: AiProvider.openRouter,
          modelId: 'openai/gpt-4o-mini',
        ),
        fallbackModelSelection: const AiModelSelection(
          provider: AiProvider.gemini,
          modelId: 'gemini-2.5-flash',
        ),
      );

      await _startDefineAndTranslate(tester);
      await tester.pumpAndSettle();

      expect(find.text('Primary failed.'), findsOneWidget);

      await tester.tap(find.text('Regenerate with Fallback'));
      await tester.pumpAndSettle();

      expect(openRouter.generateTextCallCount, 1);
      expect(gemini.generateTextCallCount, 1);
      expect(gemini.generateTextCalls.single.modelId, 'gemini-2.5-flash');
      expect(find.text('Recovered from Gemini'), findsOneWidget);
    });

    testWidgets('generate image can use Gemini for prompt and image generation',
        (tester) async {
      final openRouter = _FakeOpenRouterService(
        generateTextHandler: ({
          required apiKey,
          required modelId,
          required prompt,
          temperature,
        }) async =>
            'unused',
      );
      final gemini = _FakeGeminiService(
        generateTextHandler: ({
          required apiKey,
          required modelId,
          required prompt,
          temperature,
        }) async =>
            'A calm watercolor scene by moonlight.',
        fetchModelsHandler: ({
          required apiKey,
          required forceRefresh,
        }) async =>
            const [
          AiModelInfo(
            provider: AiProvider.gemini,
            id: 'gemini-2.5-flash',
            displayName: 'Gemini 2.5 Flash',
            outputModalities: ['text'],
          ),
          AiModelInfo(
            provider: AiProvider.gemini,
            id: 'gemini-3-pro-image-preview',
            displayName: 'Gemini 3 Pro Image Preview',
            outputModalities: ['image', 'text'],
          ),
        ],
        generateImageHandler: ({
          required apiKey,
          required modelId,
          required prompt,
          temperature,
        }) async =>
            const GeminiImageGenerationResult(
          assistantText: 'Gemini rendered successfully.',
          imageDataUrls: [
            'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO6V1xQAAAAASUVORK5CYII=',
          ],
        ),
      );

      await _pumpReaderScreen(
        tester,
        openRouterService: openRouter,
        geminiService: gemini,
        openRouterApiKey: '',
        geminiApiKey: 'gem-key',
        defaultModelSelection: const AiModelSelection(
          provider: AiProvider.gemini,
          modelId: 'gemini-2.5-flash',
        ),
        imageModelSelection: const AiModelSelection(
          provider: AiProvider.gemini,
          modelId: 'gemini-3-pro-image-preview',
        ),
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

      expect(gemini.generateTextCallCount, 1);
      expect(gemini.generateImageCallCount, 1);
      expect(openRouter.generateTextCallCount, 0);
      expect(openRouter.generateImageCallCount, 0);
      expect(
        gemini.generateImageCalls.single.modelId,
        'gemini-3-pro-image-preview',
      );
      expect(
        gemini.generateImageCalls.single.prompt,
        contains('watercolor scene'),
      );
    });
  });
}

Future<void> _pumpReaderScreen(
  WidgetTester tester, {
  required OpenRouterService openRouterService,
  GeminiService? geminiService,
  ResumeSummaryService? resumeSummaryService,
  String fallbackModelId = 'anthropic/claude-3.7-sonnet',
  String imageModelId = 'openai/gpt-image-1',
  String? generateImagePromptModelIdOverride,
  AiModelSelection? defaultModelSelection,
  AiModelSelection? fallbackModelSelection,
  AiModelSelection? imageModelSelection,
  AiModelSelection? generateImagePromptModelSelectionOverride,
  String openRouterApiKey = 'test-key',
  String geminiApiKey = 'gem-key',
  List<Chapter>? chapters,
  Book? savedBook,
  DatabaseService? databaseService,
  StorageService? storageService,
  EdgeInsets mediaQueryPadding = EdgeInsets.zero,
}) async {
  SharedPreferences.setMockInitialValues({
    if (openRouterApiKey.isNotEmpty)
      'reader_openrouter_api_key': openRouterApiKey,
    if (geminiApiKey.isNotEmpty) 'reader_gemini_api_key': geminiApiKey,
    if (defaultModelSelection == null)
      'reader_openrouter_model_id': 'openai/gpt-4o-mini',
    if (fallbackModelSelection == null)
      'reader_openrouter_fallback_model_id': fallbackModelId,
    if (imageModelSelection == null)
      'reader_openrouter_image_model_id': imageModelId,
    if (defaultModelSelection != null &&
        defaultModelSelection.provider != null &&
        defaultModelSelection.normalizedModelId.isNotEmpty) ...{
      'reader_ai_default_provider':
          defaultModelSelection.provider!.storageValue,
      'reader_ai_default_model_id': defaultModelSelection.normalizedModelId,
    },
    if (fallbackModelSelection != null &&
        fallbackModelSelection.provider != null &&
        fallbackModelSelection.normalizedModelId.isNotEmpty) ...{
      'reader_ai_fallback_provider':
          fallbackModelSelection.provider!.storageValue,
      'reader_ai_fallback_model_id': fallbackModelSelection.normalizedModelId,
    },
    if (imageModelSelection != null &&
        imageModelSelection.provider != null &&
        imageModelSelection.normalizedModelId.isNotEmpty) ...{
      'reader_ai_image_provider': imageModelSelection.provider!.storageValue,
      'reader_ai_image_model_id': imageModelSelection.normalizedModelId,
    },
    if (generateImagePromptModelIdOverride != null ||
        generateImagePromptModelSelectionOverride != null)
      'reader_ai_feature_configs': jsonEncode({
        AiFeatureIds.generateImage: {
          if (generateImagePromptModelIdOverride != null)
            'modelIdOverride': generateImagePromptModelIdOverride,
          if (generateImagePromptModelSelectionOverride != null)
            'modelOverride': generateImagePromptModelSelectionOverride.toMap(),
          'promptTemplate': defaultGenerateImagePromptTemplate,
        },
      }),
  });

  final controller = SettingsController();
  await tester.runAsync(() async {
    await controller.load();
    if (databaseService != null) {
      await databaseService.database;
    }
  });

  addTearDown(controller.dispose);

  final resolvedChapters = chapters ?? _buildTestChapters();
  final chapterLoader = ChapterLoaderService(
    parseChapters: (_) async => resolvedChapters,
    cacheChapters: (_, __) {},
  );

  await tester.pumpWidget(
    SettingsControllerScope(
      controller: controller,
      child: MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: mediaQueryPadding,
              viewPadding: mediaQueryPadding,
            ),
            child: ReaderScreen(
              book: savedBook ??
                  Book(
                    title: 'Test Book',
                    author: 'Test Author',
                    filePath: '/tmp/test.epub',
                    totalChapters: resolvedChapters.length,
                    createdAt: DateTime(2024, 1, 1),
                  ),
              chapterLoader: chapterLoader,
              databaseService: databaseService,
              openRouterService: openRouterService,
              geminiService: geminiService,
              resumeSummaryService: resumeSummaryService,
              storageService: storageService,
            ),
          ),
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

List<Chapter> _buildTestChapters({int count = 1}) {
  return List<Chapter>.generate(count, (index) {
    final chapterNumber = index + 1;
    final repeatedText = index == 0 ? 'Nebulous' : 'Chapter $chapterNumber';

    return Chapter(
      bookId: null,
      index: index,
      title: 'Chapter $chapterNumber',
      content: List<String>.filled(120, repeatedText).join(' '),
    );
  });
}

Future<void> _startDefineAndTranslate(WidgetTester tester) async {
  await _openReaderSelectionToolbar(tester);
  await tester.tap(find.text('Define & Translate'));
  await tester.pump();
}

Future<void> _startCatchMeUp(
  WidgetTester tester, {
  String? sourceModeLabel = 'Resume Range',
}) async {
  await _openReaderSelectionToolbar(tester);
  await tester.tap(find.text('Catch Me Up'));
  await tester.pumpAndSettle();
  if (sourceModeLabel != null) {
    final sourceModeFinder = find.text(sourceModeLabel);
    await tester.ensureVisible(sourceModeFinder);
    await tester.tap(sourceModeFinder);
    await tester.pump();
  }
}

Future<void> _startSimplifyText(
  WidgetTester tester, {
  String? sourceModeLabel = 'Resume Range',
}) async {
  await _openReaderSelectionToolbar(tester);
  await tester.tap(find.text('Simplify Text'));
  await tester.pumpAndSettle();
  if (sourceModeLabel != null) {
    final sourceModeFinder = find.text(sourceModeLabel);
    await tester.ensureVisible(sourceModeFinder);
    await tester.tap(sourceModeFinder);
    await tester.pump();
  }
}

Future<void> _startGenerateImage(WidgetTester tester) async {
  await _openReaderSelectionToolbar(tester);
  await tester.tap(find.text('Generate Image'));
  await tester.pump();
}

Future<void> _startChapterCatchUp(WidgetTester tester) async {
  final button = find.text('Chapter Catch-Up');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
}

Future<void> _openReaderSelectionToolbar(WidgetTester tester) async {
  final textFinder = find.byType(SelectableText).first;

  await tester.ensureVisible(textFinder);

  final textTopLeft = tester.getTopLeft(textFinder);
  await tester.longPressAt(textTopLeft + const Offset(32, 24));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
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

typedef _GenerateImageHandler = Future<OpenRouterImageGenerationResult>
    Function({
  required String apiKey,
  required String modelId,
  required String prompt,
  required List<String> modalities,
  double? temperature,
});

typedef _GeminiGenerateTextHandler = Future<String> Function({
  required String apiKey,
  required String modelId,
  required String prompt,
  double? temperature,
});

typedef _GeminiFetchModelsHandler = Future<List<AiModelInfo>> Function({
  required String apiKey,
  required bool forceRefresh,
});

typedef _GeminiGenerateImageHandler = Future<GeminiImageGenerationResult>
    Function({
  required String apiKey,
  required String modelId,
  required String prompt,
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
        generateImageHandler = generateImageHandler ?? _defaultGenerateImage;

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

class _FakeGeminiService extends GeminiService {
  final _GeminiGenerateTextHandler generateTextHandler;
  final _GeminiFetchModelsHandler fetchModelsHandler;
  final _GeminiGenerateImageHandler generateImageHandler;
  int generateTextCallCount = 0;
  final List<_GenerateTextCall> generateTextCalls = [];
  int generateImageCallCount = 0;
  final List<_GeminiGenerateImageCall> generateImageCalls = [];

  _FakeGeminiService({
    required this.generateTextHandler,
    _GeminiFetchModelsHandler? fetchModelsHandler,
    _GeminiGenerateImageHandler? generateImageHandler,
  })  : fetchModelsHandler = fetchModelsHandler ?? _defaultFetchModels,
        generateImageHandler = generateImageHandler ?? _defaultGenerateImage;

  static Future<List<AiModelInfo>> _defaultFetchModels({
    required String apiKey,
    required bool forceRefresh,
  }) async {
    return const [
      AiModelInfo(
        provider: AiProvider.gemini,
        id: 'gemini-2.5-flash',
        displayName: 'Gemini 2.5 Flash',
        outputModalities: ['text'],
      ),
      AiModelInfo(
        provider: AiProvider.gemini,
        id: 'gemini-2.5-flash-image',
        displayName: 'Gemini 2.5 Flash Image',
        outputModalities: ['image', 'text'],
      ),
    ];
  }

  static Future<GeminiImageGenerationResult> _defaultGenerateImage({
    required String apiKey,
    required String modelId,
    required String prompt,
    double? temperature,
  }) async {
    return const GeminiImageGenerationResult(
      assistantText: '',
      imageDataUrls: <String>[],
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
    return generateTextHandler(
      apiKey: apiKey,
      modelId: modelId,
      prompt: prompt,
      temperature: temperature,
    );
  }

  @override
  Future<List<AiModelInfo>> fetchModels({
    required String apiKey,
    bool forceRefresh = false,
  }) {
    return fetchModelsHandler(
      apiKey: apiKey,
      forceRefresh: forceRefresh,
    );
  }

  @override
  Future<GeminiImageGenerationResult> generateImage({
    required String apiKey,
    required String modelId,
    required String prompt,
    double? temperature,
  }) {
    generateImageCallCount += 1;
    generateImageCalls.add(
      _GeminiGenerateImageCall(
        apiKey: apiKey,
        modelId: modelId,
        prompt: prompt,
      ),
    );
    return generateImageHandler(
      apiKey: apiKey,
      modelId: modelId,
      prompt: prompt,
      temperature: temperature,
    );
  }
}

class _GeminiGenerateImageCall {
  final String apiKey;
  final String modelId;
  final String prompt;

  const _GeminiGenerateImageCall({
    required this.apiKey,
    required this.modelId,
    required this.prompt,
  });
}

class _SpyResumeSummaryService extends ResumeSummaryService {
  String? lastSourceText;
  String? lastContextSentence;
  final List<_RenderPromptCall> renderCalls = [];
  final ResumeSummaryRange? forcedRange;
  int computeRangeCallCount = 0;

  _SpyResumeSummaryService({
    this.forcedRange,
  });

  @override
  ResumeSummaryRange? computeRange({
    required String chapterContent,
    required int currentChapterIndex,
    required int selectionStart,
    required int selectionEnd,
    ResumeMarker? previousMarker,
  }) {
    computeRangeCallCount += 1;
    return forcedRange ??
        super.computeRange(
          chapterContent: chapterContent,
          currentChapterIndex: currentChapterIndex,
          selectionStart: selectionStart,
          selectionEnd: selectionEnd,
          previousMarker: previousMarker,
        );
  }

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

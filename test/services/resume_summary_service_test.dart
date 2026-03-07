import 'package:bookai/models/resume_marker.dart';
import 'package:bookai/services/resume_summary_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ResumeSummaryService', () {
    const service = ResumeSummaryService();

    test('computeRange uses previous marker end in same chapter', () {
      final marker = ResumeMarker(
        bookId: 1,
        chapterIndex: 2,
        selectedText: 'old',
        selectionStart: 4,
        selectionEnd: 9,
        scrollOffset: 0,
        createdAt: DateTime(2026, 1, 1),
      );

      final range = service.computeRange(
        chapterContent: '0123456789ABCDEFGHIJ',
        currentChapterIndex: 2,
        selectionStart: 12,
        selectionEnd: 16,
        previousMarker: marker,
      );

      expect(range, isNotNull);
      expect(range!.startOffset, 9);
      expect(range.endOffset, 16);
      expect(range.sourceText, '9ABCDEF');
    });

    test('computeRange resets to chapter start when marker is other chapter',
        () {
      final marker = ResumeMarker(
        bookId: 1,
        chapterIndex: 1,
        selectedText: 'old',
        selectionStart: 4,
        selectionEnd: 9,
        scrollOffset: 0,
        createdAt: DateTime(2026, 1, 1),
      );

      final range = service.computeRange(
        chapterContent: 'Chapter text content',
        currentChapterIndex: 2,
        selectionStart: 4,
        selectionEnd: 11,
        previousMarker: marker,
      );

      expect(range, isNotNull);
      expect(range!.startOffset, 0);
      expect(range.endOffset, 11);
      expect(range.sourceText, 'Chapter tex');
    });

    test('computeRange returns null for invalid bounds', () {
      final range = service.computeRange(
        chapterContent: 'abc',
        currentChapterIndex: 0,
        selectionStart: 2,
        selectionEnd: 2,
      );

      expect(range, isNull);
    });

    test('computeRange returns null when start reaches end', () {
      final marker = ResumeMarker(
        bookId: 1,
        chapterIndex: 3,
        selectedText: 'old',
        selectionStart: 1,
        selectionEnd: 6,
        scrollOffset: 0,
        createdAt: DateTime(2026, 1, 1),
      );

      final range = service.computeRange(
        chapterContent: '0123456789',
        currentChapterIndex: 3,
        selectionStart: 2,
        selectionEnd: 6,
        previousMarker: marker,
      );

      expect(range, isNull);
    });

    test('renderPromptTemplate replaces placeholders', () {
      final prompt = service.renderPromptTemplate(
        promptTemplate:
            'Book {book_title}\nAuthor {book_author}\nChapter {chapter_title}\nContext {context_sentence}\n{source_text}',
        sourceText: 'Hello',
        bookTitle: 'Book A',
        bookAuthor: 'Author A',
        chapterTitle: 'Chapter 1',
        contextSentence: 'Hello there.',
      );

      expect(
        prompt,
        'Book Book A\nAuthor Author A\nChapter Chapter 1\nContext Hello there.\nHello',
      );
    });

    test('hasRequiredPlaceholder checks source placeholder', () {
      expect(service.hasRequiredPlaceholder('Use {source_text}'), isTrue);
      expect(service.hasRequiredPlaceholder('No placeholder'), isFalse);
    });

    test('extractContextSentence returns the containing sentence', () {
      const chapterContent = 'First line. Alpha beta gamma. Last line.';

      final context = service.extractContextSentence(
        chapterContent: chapterContent,
        selectionStart: chapterContent.indexOf('beta'),
        selectionEnd: chapterContent.indexOf('beta') + 'beta'.length,
      );

      expect(context, 'Alpha beta gamma.');
    });

    test('extractContextSentence keeps closing punctuation after terminators',
        () {
      const chapterContent = 'He whispered, "Alpha beta?" Then left.';

      final context = service.extractContextSentence(
        chapterContent: chapterContent,
        selectionStart: chapterContent.indexOf('Alpha'),
        selectionEnd: chapterContent.indexOf('beta') + 'beta'.length,
      );

      expect(context, 'He whispered, "Alpha beta?"');
    });

    test('extractContextSentence treats line breaks as sentence boundaries',
        () {
      const chapterContent = 'Alpha beta\nGamma delta\nOmega';

      final context = service.extractContextSentence(
        chapterContent: chapterContent,
        selectionStart: chapterContent.indexOf('Gamma'),
        selectionEnd: chapterContent.indexOf('delta') + 'delta'.length,
      );

      expect(context, 'Gamma delta');
    });

    test('extractContextSentence falls back to the selected text', () {
      const chapterContent = 'Nebulous';

      final context = service.extractContextSentence(
        chapterContent: chapterContent,
        selectionStart: 0,
        selectionEnd: chapterContent.length,
      );

      expect(context, 'Nebulous');
    });
  });
}

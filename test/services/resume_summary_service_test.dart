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
            'Book {book_title}\nChapter {chapter_title}\n{source_text}',
        sourceText: 'Hello',
        bookTitle: 'Book A',
        chapterTitle: 'Chapter 1',
      );

      expect(prompt, 'Book Book A\nChapter Chapter 1\nHello');
    });

    test('hasRequiredPlaceholder checks source placeholder', () {
      expect(service.hasRequiredPlaceholder('Use {source_text}'), isTrue);
      expect(service.hasRequiredPlaceholder('No placeholder'), isFalse);
    });
  });
}

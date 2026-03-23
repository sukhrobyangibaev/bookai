import 'package:bookai/services/reader_pagination_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const service = ReaderPaginationService();

  group('ReaderPaginationService', () {
    test('returns a single empty page for empty text', () {
      final pagination = service.paginate(
        text: '',
        textStyle: const TextStyle(fontSize: 18, height: 1.4),
        maxWidth: 300,
        maxHeight: 400,
      );

      expect(pagination.pages, hasLength(1));
      expect(pagination.pages.single.startOffset, 0);
      expect(pagination.pages.single.endOffset, 0);
      expect(pagination.pages.single.text, isEmpty);
      expect(pagination.pageIndexForContentOffset(0), 0);
      expect(pagination.pageForContentOffset(999).text, isEmpty);
    });

    test('keeps short text on one page with full offsets', () {
      const text = 'A short chapter that comfortably fits one page.';

      final pagination = service.paginate(
        text: text,
        textStyle: const TextStyle(fontSize: 18, height: 1.4),
        maxWidth: 500,
        maxHeight: 800,
      );

      expect(pagination.pages, hasLength(1));
      expect(pagination.pages.single.startOffset, 0);
      expect(pagination.pages.single.endOffset, text.length);
      expect(pagination.pages.single.text, text);
      expect(pagination.pageIndexForContentOffset(-5), 0);
      expect(pagination.pageIndexForContentOffset(text.length), 0);
    });

    test('splits long text into contiguous measurable pages', () {
      final text = _buildLongText(paragraphs: 18, wordsPerParagraph: 26);

      final pagination = service.paginate(
        text: text,
        textStyle: const TextStyle(fontSize: 19, height: 1.45),
        maxWidth: 220,
        maxHeight: 210,
      );

      expect(pagination.pages.length, greaterThan(1));

      int expectedStart = 0;
      for (final page in pagination.pages) {
        expect(page.startOffset, expectedStart);
        expect(page.endOffset, greaterThan(page.startOffset));
        expect(page.text, text.substring(page.startOffset, page.endOffset));
        expectedStart = page.endOffset;
      }

      expect(expectedStart, text.length);
    });

    test('maps content offsets to the expected page boundaries', () {
      final text = _buildLongText(paragraphs: 14, wordsPerParagraph: 30);

      final pagination = service.paginate(
        text: text,
        textStyle: const TextStyle(fontSize: 20, height: 1.5),
        maxWidth: 230,
        maxHeight: 220,
      );

      expect(pagination.pages.length, greaterThan(1));
      expect(pagination.clampContentOffset(-1000), 0);
      expect(pagination.clampContentOffset(text.length + 1000), text.length);

      final lastPageIndex = pagination.pages.length - 1;
      for (int pageIndex = 0;
          pageIndex < pagination.pages.length;
          pageIndex++) {
        final page = pagination.pages[pageIndex];
        expect(
            pagination.pageIndexForContentOffset(page.startOffset), pageIndex);

        if (pageIndex < lastPageIndex) {
          expect(
            pagination.pageIndexForContentOffset(page.endOffset - 1),
            pageIndex,
          );
          expect(
            pagination.pageIndexForContentOffset(page.endOffset),
            pageIndex + 1,
          );
        } else {
          expect(
              pagination.pageIndexForContentOffset(page.endOffset), pageIndex);
        }
      }
    });

    test('resolves saved contentOffset after repagination changes', () {
      final text = _buildLongText(paragraphs: 22, wordsPerParagraph: 28);
      final savedContentOffset = text.length ~/ 2;

      final initialPagination = service.paginate(
        text: text,
        textStyle: const TextStyle(fontSize: 16, height: 1.35),
        maxWidth: 420,
        maxHeight: 300,
      );

      final changedPagination = service.paginate(
        text: text,
        textStyle: const TextStyle(fontSize: 28, height: 1.7),
        maxWidth: 170,
        maxHeight: 180,
      );

      expect(changedPagination.pages.length,
          isNot(initialPagination.pages.length));

      final initialPageIndex =
          initialPagination.pageIndexForContentOffset(savedContentOffset);
      final changedPageIndex =
          changedPagination.pageIndexForContentOffset(savedContentOffset);

      _expectAnchorIsInsidePage(
        pagination: initialPagination,
        pageIndex: initialPageIndex,
        anchor: savedContentOffset,
      );
      _expectAnchorIsInsidePage(
        pagination: changedPagination,
        pageIndex: changedPageIndex,
        anchor: savedContentOffset,
      );

      final initialPage = initialPagination.pages[initialPageIndex];
      final changedPage = changedPagination.pages[changedPageIndex];

      final expectedCharacter = text.substring(
        savedContentOffset,
        savedContentOffset + 1,
      );
      expect(
        initialPage.text.substring(
          savedContentOffset - initialPage.startOffset,
          savedContentOffset - initialPage.startOffset + 1,
        ),
        expectedCharacter,
      );
      expect(
        changedPage.text.substring(
          savedContentOffset - changedPage.startOffset,
          savedContentOffset - changedPage.startOffset + 1,
        ),
        expectedCharacter,
      );
    });
  });
}

String _buildLongText(
    {required int paragraphs, required int wordsPerParagraph}) {
  final buffer = StringBuffer();
  for (int paragraph = 0; paragraph < paragraphs; paragraph++) {
    buffer.write('Paragraph ${paragraph + 1}: ');
    for (int word = 0; word < wordsPerParagraph; word++) {
      buffer.write('word_${paragraph}_$word ');
    }
    buffer.writeln('end.');
    buffer.writeln();
  }
  return buffer.toString();
}

void _expectAnchorIsInsidePage({
  required ReaderPagination pagination,
  required int pageIndex,
  required int anchor,
}) {
  final page = pagination.pages[pageIndex];
  final isLastPage = pageIndex == pagination.pages.length - 1;

  expect(anchor, greaterThanOrEqualTo(page.startOffset));
  if (isLastPage) {
    expect(anchor, lessThanOrEqualTo(page.endOffset));
  } else {
    expect(anchor, lessThan(page.endOffset));
  }
}

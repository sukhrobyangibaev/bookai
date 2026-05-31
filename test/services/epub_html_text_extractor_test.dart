import 'package:bookai/models/chapter_style.dart';
import 'package:bookai/services/epub_html_text_extractor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const extractor = EpubHtmlTextExtractor();

  group('EpubHtmlTextExtractor', () {
    test('extracts nested italic and bold styles with plain-text offsets', () {
      final extracted = extractor.extract(
        '<p>Plain <em>italic <strong>bold italic</strong></em> text.</p>',
      );

      expect(extracted.content, 'Plain italic bold italic text.');

      final ranges = extracted.styledContent.ranges;
      final italicRange = ranges.singleWhere(
        (range) => range.italic && !range.bold,
      );
      final boldItalicRange = ranges.singleWhere(
        (range) => range.italic && range.bold,
      );

      expect(
        extracted.content.substring(italicRange.start, italicRange.end),
        'italic bold italic',
      );
      expect(
        extracted.content.substring(
          boldItalicRange.start,
          boldItalicRange.end,
        ),
        'bold italic',
      );
    });

    test('preserves headings, blockquotes, and basic list text', () {
      final extracted = extractor.extract('''
        <h2>Heading</h2>
        <blockquote><p>Quoted line.</p></blockquote>
        <ol><li>First</li><li><u>Second</u></li></ol>
      ''');

      expect(
        extracted.content,
        'Heading\n\nQuoted line.\n\n1. First\n2. Second',
      );

      final ranges = extracted.styledContent.ranges;
      final headingRange =
          ranges.singleWhere((range) => range.headingLevel == 2);
      final blockquoteRange = ranges.firstWhere((range) => range.blockquote);
      final underlineRange = ranges.singleWhere((range) => range.underline);

      expect(
        extracted.content.substring(headingRange.start, headingRange.end),
        'Heading',
      );
      expect(
        extracted.content.substring(
          blockquoteRange.start,
          blockquoteRange.end,
        ),
        contains('Quoted line.'),
      );
      expect(
        extracted.content.substring(
          underlineRange.start,
          underlineRange.end,
        ),
        'Second',
      );
    });

    test('extracts superscript and subscript without changing text offsets',
        () {
      final extracted =
          extractor.extract('<p>H<sub>2</sub>O x<sup>2</sup></p>');

      expect(extracted.content, 'H2O x2');

      final subscriptRange = extracted.styledContent.ranges
          .singleWhere((range) => range.subscript);
      final superscriptRange = extracted.styledContent.ranges
          .singleWhere((range) => range.superscript);

      expect(
        extracted.content.substring(subscriptRange.start, subscriptRange.end),
        '2',
      );
      expect(
        extracted.content.substring(
          superscriptRange.start,
          superscriptRange.end,
        ),
        '2',
      );
    });

    test('excludes hidden, script, style, and table content', () {
      final extracted = extractor.extract('''
        <head><title>Hidden title</title></head>
        <p>Visible<script>bad()</script><span hidden>hidden</span></p>
        <p><span style="display:none">also hidden</span>Text</p>
        <style>.x { font-style: italic; }</style>
        <table><tr><td>ignored table</td></tr></table>
      ''');

      expect(extracted.content, 'Visible\n\nText');
    });

    test('serializes style ranges for storage', () {
      final extracted = extractor.extract('<p><i>Styled</i></p>');
      final decoded = StyledChapterContent.tryDecode(
        extracted.styledContent.toJson(),
      );

      expect(decoded, isNotNull);
      expect(decoded!.ranges.single.italic, isTrue);
    });
  });
}

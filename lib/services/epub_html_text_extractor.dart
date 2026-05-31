import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../models/chapter_style.dart';

class ExtractedChapterText {
  final String content;
  final StyledChapterContent styledContent;

  const ExtractedChapterText({
    required this.content,
    required this.styledContent,
  });
}

class EpubHtmlTextExtractor {
  const EpubHtmlTextExtractor();

  ExtractedChapterText extract(String html) {
    final fragment = html_parser.parseFragment(html);
    final builder = _StyledTextBuilder();

    for (final node in fragment.nodes) {
      builder.visit(node, const _SemanticTextStyle());
    }

    return builder.build();
  }
}

class _StyledTextBuilder {
  final StringBuffer _buffer = StringBuffer();
  final List<ChapterStyleRange> _ranges = <ChapterStyleRange>[];
  final List<_ListContext> _listStack = <_ListContext>[];

  int get length => _buffer.length;

  void visit(dom.Node node, _SemanticTextStyle currentStyle) {
    if (node is dom.Text) {
      _appendText(node.data);
      return;
    }

    if (node is! dom.Element) return;

    final tag = node.localName?.toLowerCase() ?? '';
    if (_shouldSkipElement(node, tag)) return;

    if (tag == 'br') {
      _appendLineBreak();
      return;
    }

    if (tag == 'ol' || tag == 'ul') {
      _startList(ordered: tag == 'ol');
      for (final child in node.nodes) {
        visit(child, currentStyle);
      }
      _endList();
      return;
    }

    if (tag == 'li') {
      _startListItem();
      final styleStart = length;
      final elementStyle = _styleForElement(node, tag, currentStyle);
      for (final child in node.nodes) {
        visit(child, elementStyle);
      }
      _addRange(styleStart, length, elementStyle);
      _endListItem();
      return;
    }

    final isBlock = _isBlockElement(tag);
    if (isBlock) {
      _ensureParagraphBreak();
    }

    final styleStart = length;
    final elementStyle = _styleForElement(node, tag, currentStyle);
    for (final child in node.nodes) {
      visit(child, elementStyle);
    }
    _addRange(styleStart, length, elementStyle);

    if (isBlock) {
      _ensureParagraphBreak();
    }
  }

  ExtractedChapterText build() {
    final content = _buffer.toString().trimRight();
    final ranges = _ranges
        .map((range) => range.clampedTo(content.length))
        .whereType<ChapterStyleRange>()
        .toList(growable: false);

    return ExtractedChapterText(
      content: content,
      styledContent: StyledChapterContent(ranges: ranges),
    );
  }

  void _appendText(String value) {
    for (final codePoint in value.runes) {
      final char = String.fromCharCode(codePoint);
      if (RegExp(r'\s').hasMatch(char)) {
        _appendSpace();
      } else {
        _buffer.write(char);
      }
    }
  }

  void _appendSpace() {
    if (_buffer.isEmpty) return;
    final text = _buffer.toString();
    if (text.endsWith(' ') || text.endsWith('\n')) return;
    _buffer.write(' ');
  }

  void _appendLineBreak() {
    if (_buffer.isEmpty) return;
    final text = _buffer.toString();
    if (text.endsWith('\n')) return;
    _buffer.write('\n');
  }

  void _ensureParagraphBreak() {
    if (_buffer.isEmpty) return;

    final text = _trimTrailingHorizontalWhitespace(_buffer.toString());
    if (text.isEmpty) {
      _replaceBuffer('');
      return;
    }

    if (text != _buffer.toString()) {
      _replaceBuffer(text);
    }

    if (text.endsWith('\n\n')) return;
    if (text.endsWith('\n')) {
      _buffer.write('\n');
    } else {
      _buffer.write('\n\n');
    }
  }

  void _ensureLineStart() {
    if (_buffer.isEmpty) return;

    final text = _trimTrailingHorizontalWhitespace(_buffer.toString());
    if (text != _buffer.toString()) {
      _replaceBuffer(text);
    }
    if (!text.endsWith('\n')) {
      _buffer.write('\n');
    }
  }

  void _startList({required bool ordered}) {
    _ensureParagraphBreak();
    _listStack.add(_ListContext(ordered: ordered));
  }

  void _endList() {
    if (_listStack.isNotEmpty) {
      _listStack.removeLast();
    }
    _ensureParagraphBreak();
  }

  void _startListItem() {
    _ensureLineStart();
    final context = _listStack.isEmpty ? null : _listStack.last;
    if (context == null || !context.ordered) {
      _buffer.write('- ');
      return;
    }

    _buffer.write('${context.nextIndex}. ');
    context.nextIndex += 1;
  }

  void _endListItem() {
    _appendLineBreak();
  }

  void _addRange(int start, int end, _SemanticTextStyle style) {
    if (!style.hasStyle || end <= start) return;

    _ranges.add(
      ChapterStyleRange(
        start: start,
        end: end,
        bold: style.bold,
        italic: style.italic,
        underline: style.underline,
        strikethrough: style.strikethrough,
        superscript: style.superscript,
        subscript: style.subscript,
        blockquote: style.blockquote,
        headingLevel: style.headingLevel,
      ),
    );
  }

  void _replaceBuffer(String text) {
    _buffer.clear();
    _buffer.write(text);
  }

  String _trimTrailingHorizontalWhitespace(String text) {
    return text.replaceFirst(RegExp(r'[ \t]+$'), '');
  }

  bool _shouldSkipElement(dom.Element element, String tag) {
    if (_skippedTags.contains(tag)) return true;
    if (element.attributes.containsKey('hidden')) return true;
    if (element.attributes['aria-hidden']?.toLowerCase() == 'true') {
      return true;
    }

    final style = element.attributes['style']?.toLowerCase() ?? '';
    return RegExp(r'display\s*:\s*none').hasMatch(style) ||
        RegExp(r'visibility\s*:\s*hidden').hasMatch(style);
  }

  _SemanticTextStyle _styleForElement(
    dom.Element element,
    String tag,
    _SemanticTextStyle current,
  ) {
    var style = current;

    switch (tag) {
      case 'b':
      case 'strong':
        style = style.copyWith(bold: true);
      case 'i':
      case 'em':
      case 'cite':
      case 'dfn':
        style = style.copyWith(italic: true);
      case 'u':
        style = style.copyWith(underline: true);
      case 's':
      case 'strike':
      case 'del':
        style = style.copyWith(strikethrough: true);
      case 'sup':
        style = style.copyWith(superscript: true, subscript: false);
      case 'sub':
        style = style.copyWith(subscript: true, superscript: false);
      case 'blockquote':
        style = style.copyWith(blockquote: true);
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        style = style.copyWith(
          bold: true,
          headingLevel: int.parse(tag.substring(1)),
        );
    }

    return _applyInlineStyleAttribute(element.attributes['style'], style);
  }

  _SemanticTextStyle _applyInlineStyleAttribute(
    String? styleAttribute,
    _SemanticTextStyle style,
  ) {
    final css = styleAttribute?.toLowerCase() ?? '';
    if (css.isEmpty) return style;

    var next = style;
    if (RegExp(r'font-style\s*:\s*(italic|oblique)').hasMatch(css)) {
      next = next.copyWith(italic: true);
    }
    if (RegExp(r'font-weight\s*:\s*(bold|[6-9]00)').hasMatch(css)) {
      next = next.copyWith(bold: true);
    }
    if (RegExp(r'text-decoration[^;]*underline').hasMatch(css)) {
      next = next.copyWith(underline: true);
    }
    if (RegExp(r'text-decoration[^;]*(line-through|strike)').hasMatch(css)) {
      next = next.copyWith(strikethrough: true);
    }
    if (RegExp(r'vertical-align\s*:\s*super').hasMatch(css)) {
      next = next.copyWith(superscript: true, subscript: false);
    }
    if (RegExp(r'vertical-align\s*:\s*sub').hasMatch(css)) {
      next = next.copyWith(subscript: true, superscript: false);
    }

    return next;
  }

  bool _isBlockElement(String tag) {
    return _blockTags.contains(tag) || RegExp(r'^h[1-6]$').hasMatch(tag);
  }
}

class _SemanticTextStyle {
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strikethrough;
  final bool superscript;
  final bool subscript;
  final bool blockquote;
  final int? headingLevel;

  const _SemanticTextStyle({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strikethrough = false,
    this.superscript = false,
    this.subscript = false,
    this.blockquote = false,
    this.headingLevel,
  });

  bool get hasStyle =>
      bold ||
      italic ||
      underline ||
      strikethrough ||
      superscript ||
      subscript ||
      blockquote ||
      headingLevel != null;

  _SemanticTextStyle copyWith({
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strikethrough,
    bool? superscript,
    bool? subscript,
    bool? blockquote,
    int? headingLevel,
  }) {
    return _SemanticTextStyle(
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      strikethrough: strikethrough ?? this.strikethrough,
      superscript: superscript ?? this.superscript,
      subscript: subscript ?? this.subscript,
      blockquote: blockquote ?? this.blockquote,
      headingLevel: headingLevel ?? this.headingLevel,
    );
  }
}

class _ListContext {
  final bool ordered;
  int nextIndex = 1;

  _ListContext({required this.ordered});
}

const Set<String> _skippedTags = <String>{
  'head',
  'title',
  'style',
  'script',
  'noscript',
  'svg',
  'math',
  'table',
  'thead',
  'tbody',
  'tfoot',
};

const Set<String> _blockTags = <String>{
  'address',
  'article',
  'aside',
  'blockquote',
  'dd',
  'details',
  'div',
  'dt',
  'figcaption',
  'figure',
  'footer',
  'header',
  'hr',
  'main',
  'nav',
  'p',
  'pre',
  'section',
  'summary',
  'tr',
};

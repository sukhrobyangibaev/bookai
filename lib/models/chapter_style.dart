import 'dart:convert';

class StyledChapterContent {
  static const int currentVersion = 1;

  final List<ChapterStyleRange> ranges;

  const StyledChapterContent({
    this.ranges = const <ChapterStyleRange>[],
  });

  bool get isEmpty => ranges.isEmpty;

  String toJson() {
    return jsonEncode({
      'version': currentVersion,
      'ranges': ranges.map((range) => range.toMap()).toList(),
    });
  }

  static StyledChapterContent? tryDecode(String? value) {
    if (value == null || value.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic>) return null;

      final rangesValue = decoded['ranges'];
      if (rangesValue is! List) return const StyledChapterContent();

      final ranges = <ChapterStyleRange>[];
      for (final item in rangesValue) {
        if (item is! Map) continue;
        final range = ChapterStyleRange.tryFromMap(
          Map<String, dynamic>.from(item),
        );
        if (range != null) ranges.add(range);
      }

      return StyledChapterContent(ranges: List.unmodifiable(ranges));
    } catch (_) {
      return null;
    }
  }
}

class ChapterStyleRange {
  final int start;
  final int end;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strikethrough;
  final bool superscript;
  final bool subscript;
  final bool blockquote;
  final int? headingLevel;

  const ChapterStyleRange({
    required this.start,
    required this.end,
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

  Map<String, dynamic> toMap() {
    return {
      'start': start,
      'end': end,
      if (bold) 'bold': true,
      if (italic) 'italic': true,
      if (underline) 'underline': true,
      if (strikethrough) 'strikethrough': true,
      if (superscript) 'superscript': true,
      if (subscript) 'subscript': true,
      if (blockquote) 'blockquote': true,
      if (headingLevel != null) 'headingLevel': headingLevel,
    };
  }

  static ChapterStyleRange? tryFromMap(Map<String, dynamic> map) {
    final start = map['start'];
    final end = map['end'];
    if (start is! int || end is! int || end <= start) return null;

    final headingLevel = map['headingLevel'];
    final normalizedHeadingLevel =
        headingLevel is int ? headingLevel.clamp(1, 6) : null;

    final range = ChapterStyleRange(
      start: start,
      end: end,
      bold: map['bold'] == true,
      italic: map['italic'] == true,
      underline: map['underline'] == true,
      strikethrough: map['strikethrough'] == true,
      superscript: map['superscript'] == true,
      subscript: map['subscript'] == true,
      blockquote: map['blockquote'] == true,
      headingLevel: normalizedHeadingLevel,
    );

    return range.hasStyle ? range : null;
  }

  ChapterStyleRange? clampedTo(int textLength) {
    if (textLength <= 0) return null;

    final clampedStart = start.clamp(0, textLength);
    final clampedEnd = end.clamp(0, textLength);
    if (clampedEnd <= clampedStart) return null;

    return ChapterStyleRange(
      start: clampedStart,
      end: clampedEnd,
      bold: bold,
      italic: italic,
      underline: underline,
      strikethrough: strikethrough,
      superscript: superscript,
      subscript: subscript,
      blockquote: blockquote,
      headingLevel: headingLevel,
    );
  }
}

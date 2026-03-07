import '../models/resume_marker.dart';

const String sourceTextPlaceholder = '{source_text}';
const String bookTitlePlaceholder = '{book_title}';
const String bookAuthorPlaceholder = '{book_author}';
const String chapterTitlePlaceholder = '{chapter_title}';
const String contextSentencePlaceholder = '{context_sentence}';

class ResumeSummaryRange {
  final int startOffset;
  final int endOffset;
  final String sourceText;

  const ResumeSummaryRange({
    required this.startOffset,
    required this.endOffset,
    required this.sourceText,
  });
}

class ResumeSummaryService {
  const ResumeSummaryService();

  ResumeSummaryRange? computeRange({
    required String chapterContent,
    required int currentChapterIndex,
    required int selectionStart,
    required int selectionEnd,
    ResumeMarker? previousMarker,
  }) {
    if (chapterContent.isEmpty) return null;

    final boundedSelectionStart =
        selectionStart.clamp(0, chapterContent.length);
    final boundedSelectionEnd = selectionEnd.clamp(0, chapterContent.length);
    if (boundedSelectionEnd <= boundedSelectionStart) return null;

    int startOffset = 0;
    if (previousMarker != null &&
        previousMarker.chapterIndex == currentChapterIndex) {
      startOffset = previousMarker.selectionEnd.clamp(0, chapterContent.length);
    }

    if (startOffset >= boundedSelectionEnd) return null;

    final sourceText =
        chapterContent.substring(startOffset, boundedSelectionEnd).trim();
    if (sourceText.isEmpty) return null;

    return ResumeSummaryRange(
      startOffset: startOffset,
      endOffset: boundedSelectionEnd,
      sourceText: sourceText,
    );
  }

  bool hasRequiredPlaceholder(String promptTemplate) {
    return promptTemplate.contains(sourceTextPlaceholder);
  }

  String extractContextSentence({
    required String chapterContent,
    required int selectionStart,
    required int selectionEnd,
  }) {
    if (chapterContent.isEmpty) return '';

    final boundedSelectionStart =
        selectionStart.clamp(0, chapterContent.length);
    final boundedSelectionEnd = selectionEnd.clamp(0, chapterContent.length);
    if (boundedSelectionEnd <= boundedSelectionStart) return '';

    final fallbackSelection = chapterContent
        .substring(boundedSelectionStart, boundedSelectionEnd)
        .trim();
    if (fallbackSelection.isEmpty) return '';

    final sentenceStart = _findSentenceStart(
      chapterContent,
      boundedSelectionStart,
    );
    final sentenceEnd = _findSentenceEnd(chapterContent, boundedSelectionEnd);

    final sentence =
        chapterContent.substring(sentenceStart, sentenceEnd).trim();
    return sentence.isEmpty ? fallbackSelection : sentence;
  }

  String renderPromptTemplate({
    required String promptTemplate,
    required String sourceText,
    required String bookTitle,
    String bookAuthor = '',
    required String chapterTitle,
    String contextSentence = '',
  }) {
    return promptTemplate
        .replaceAll(sourceTextPlaceholder, sourceText)
        .replaceAll(bookTitlePlaceholder, bookTitle)
        .replaceAll(bookAuthorPlaceholder, bookAuthor)
        .replaceAll(chapterTitlePlaceholder, chapterTitle)
        .replaceAll(contextSentencePlaceholder, contextSentence);
  }

  int _findSentenceStart(String text, int selectionStart) {
    for (int index = selectionStart - 1; index >= 0; index--) {
      if (_isSentenceBoundary(text[index])) {
        return _skipLeadingSentenceWhitespace(text, index + 1);
      }
    }
    return _skipLeadingSentenceWhitespace(text, 0);
  }

  int _findSentenceEnd(String text, int selectionEnd) {
    for (int index = selectionEnd; index < text.length; index++) {
      final char = text[index];
      if (_isLineBreak(char)) {
        return index;
      }
      if (_isTerminalPunctuation(char)) {
        int end = index + 1;
        while (end < text.length && _isClosingPunctuation(text[end])) {
          end += 1;
        }
        return end;
      }
    }
    return text.length;
  }

  int _skipLeadingSentenceWhitespace(String text, int start) {
    int index = start;
    while (index < text.length && _isInlineWhitespace(text[index])) {
      index += 1;
    }
    return index;
  }

  bool _isSentenceBoundary(String char) {
    return _isTerminalPunctuation(char) || _isLineBreak(char);
  }

  bool _isTerminalPunctuation(String char) {
    return char == '.' || char == '!' || char == '?';
  }

  bool _isLineBreak(String char) {
    return char == '\n' || char == '\r';
  }

  bool _isInlineWhitespace(String char) {
    return char == ' ' || char == '\t' || char == '\f';
  }

  bool _isClosingPunctuation(String char) {
    return char == '"' ||
        char == '\'' ||
        char == ')' ||
        char == ']' ||
        char == '}';
  }
}

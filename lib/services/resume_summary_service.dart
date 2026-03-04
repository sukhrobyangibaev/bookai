import '../models/resume_marker.dart';

const String sourceTextPlaceholder = '{source_text}';
const String bookTitlePlaceholder = '{book_title}';
const String chapterTitlePlaceholder = '{chapter_title}';

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

  String renderPromptTemplate({
    required String promptTemplate,
    required String sourceText,
    required String bookTitle,
    required String chapterTitle,
  }) {
    return promptTemplate
        .replaceAll(sourceTextPlaceholder, sourceText)
        .replaceAll(bookTitlePlaceholder, bookTitle)
        .replaceAll(chapterTitlePlaceholder, chapterTitle);
  }
}

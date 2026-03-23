import '../models/chapter.dart';
import '../models/reading_progress.dart';
import '../models/reader_settings.dart';
import '../models/resume_marker.dart';

class ReaderLocation {
  final int chapterIndex;
  final double scrollOffset;
  final int? contentOffset;
  final bool restoredFromResumeMarker;

  const ReaderLocation({
    required this.chapterIndex,
    required this.scrollOffset,
    this.contentOffset,
    required this.restoredFromResumeMarker,
  });
}

class ReaderLocationPersistence {
  const ReaderLocationPersistence();

  ReaderLocation resolveInitialLocation({
    required ReadingMode readingMode,
    required List<Chapter> chapters,
    ReadingProgress? savedProgress,
    ResumeMarker? savedMarker,
  }) {
    final markerChapterIndex = savedMarker?.chapterIndex ?? -1;
    final markerChapterIsValid =
        markerChapterIndex >= 0 && markerChapterIndex < chapters.length;
    final progressChapterIndex = savedProgress?.chapterIndex ?? -1;
    final progressChapterIsValid =
        progressChapterIndex >= 0 && progressChapterIndex < chapters.length;

    final chapterIndex = markerChapterIsValid
        ? markerChapterIndex
        : (progressChapterIsValid ? progressChapterIndex : 0);

    final scrollOffset = markerChapterIsValid
        ? (savedMarker?.scrollOffset ?? 0.0)
        : _restoreScrollOffsetByMode(
            readingMode: readingMode,
            savedProgress: savedProgress,
          );

    final contentOffset = markerChapterIsValid
        ? savedMarker?.selectionStart
        : _restoreContentOffsetByMode(
            readingMode: readingMode,
            savedProgress: savedProgress,
          );

    return ReaderLocation(
      chapterIndex: chapterIndex,
      scrollOffset: scrollOffset,
      contentOffset: contentOffset,
      restoredFromResumeMarker: markerChapterIsValid,
    );
  }

  ReadingProgress buildProgress({
    required int bookId,
    required int chapterIndex,
    required ReadingMode readingMode,
    required double scrollOffset,
    int? contentOffset,
    int? previousContentOffset,
  }) {
    final resolvedScrollOffset = _persistScrollOffsetByMode(
        readingMode: readingMode, scrollOffset: scrollOffset);
    final resolvedContentOffset = _persistContentOffsetByMode(
      readingMode: readingMode,
      contentOffset: contentOffset,
      previousContentOffset: previousContentOffset,
    );

    return ReadingProgress(
      bookId: bookId,
      chapterIndex: chapterIndex,
      scrollOffset: resolvedScrollOffset,
      contentOffset: resolvedContentOffset,
      updatedAt: DateTime.now(),
    );
  }

  double _restoreScrollOffsetByMode({
    required ReadingMode readingMode,
    required ReadingProgress? savedProgress,
  }) {
    switch (readingMode) {
      case ReadingMode.scroll:
      case ReadingMode.pageFlip:
        return savedProgress?.scrollOffset ?? 0.0;
    }
  }

  int? _restoreContentOffsetByMode({
    required ReadingMode readingMode,
    required ReadingProgress? savedProgress,
  }) {
    switch (readingMode) {
      case ReadingMode.scroll:
      case ReadingMode.pageFlip:
        return savedProgress?.contentOffset;
    }
  }

  double _persistScrollOffsetByMode({
    required ReadingMode readingMode,
    required double scrollOffset,
  }) {
    switch (readingMode) {
      case ReadingMode.scroll:
      case ReadingMode.pageFlip:
        return scrollOffset;
    }
  }

  int? _persistContentOffsetByMode({
    required ReadingMode readingMode,
    required int? contentOffset,
    required int? previousContentOffset,
  }) {
    switch (readingMode) {
      case ReadingMode.scroll:
      case ReadingMode.pageFlip:
        return contentOffset ?? previousContentOffset;
    }
  }
}

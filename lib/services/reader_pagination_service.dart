import 'package:flutter/widgets.dart';

class ReaderPageSlice {
  final int startOffset;
  final int endOffset;
  final String text;

  const ReaderPageSlice({
    required this.startOffset,
    required this.endOffset,
    required this.text,
  })  : assert(startOffset >= 0),
        assert(endOffset >= startOffset);

  @override
  String toString() {
    return 'ReaderPageSlice(startOffset: $startOffset, endOffset: '
        '$endOffset, length: ${text.length})';
  }
}

class ReaderPagination {
  final List<ReaderPageSlice> pages;

  const ReaderPagination({required this.pages});

  int pageIndexForContentOffset(int contentOffset) {
    if (pages.isEmpty) return 0;

    final boundedOffset = clampContentOffset(contentOffset);

    for (int pageIndex = 0; pageIndex < pages.length; pageIndex++) {
      final page = pages[pageIndex];
      final isLastPage = pageIndex == pages.length - 1;
      final withinUpperBound = isLastPage
          ? boundedOffset <= page.endOffset
          : boundedOffset < page.endOffset;

      if (boundedOffset >= page.startOffset && withinUpperBound) {
        return pageIndex;
      }
    }

    return pages.length - 1;
  }

  ReaderPageSlice pageForContentOffset(int contentOffset) {
    if (pages.isEmpty) {
      return const ReaderPageSlice(startOffset: 0, endOffset: 0, text: '');
    }
    return pages[pageIndexForContentOffset(contentOffset)];
  }

  int clampContentOffset(int contentOffset) {
    if (pages.isEmpty) return 0;
    final minOffset = pages.first.startOffset;
    final maxOffset = pages.last.endOffset;
    if (contentOffset < minOffset) return minOffset;
    if (contentOffset > maxOffset) return maxOffset;
    return contentOffset;
  }
}

class ReaderPaginationService {
  const ReaderPaginationService();

  ReaderPagination paginate({
    required String text,
    required TextStyle textStyle,
    required double maxWidth,
    required double maxHeight,
    TextDirection textDirection = TextDirection.ltr,
    TextAlign textAlign = TextAlign.start,
    StrutStyle? strutStyle,
    TextScaler textScaler = TextScaler.noScaling,
    TextHeightBehavior? textHeightBehavior,
    Locale? locale,
  }) {
    if (text.isEmpty) {
      return const ReaderPagination(
        pages: <ReaderPageSlice>[
          ReaderPageSlice(startOffset: 0, endOffset: 0, text: ''),
        ],
      );
    }

    if (maxWidth <= 0 || maxHeight <= 0) {
      return ReaderPagination(
        pages: <ReaderPageSlice>[
          ReaderPageSlice(startOffset: 0, endOffset: text.length, text: text),
        ],
      );
    }

    final pages = <ReaderPageSlice>[];
    int startOffset = 0;

    while (startOffset < text.length) {
      final endOffset = _findLargestFittingEndOffset(
        text: text,
        startOffset: startOffset,
        textStyle: textStyle,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        textDirection: textDirection,
        textAlign: textAlign,
        strutStyle: strutStyle,
        textScaler: textScaler,
        textHeightBehavior: textHeightBehavior,
        locale: locale,
      );

      final safeEndOffset =
          endOffset <= startOffset ? startOffset + 1 : endOffset;
      final clampedEndOffset =
          safeEndOffset > text.length ? text.length : safeEndOffset;

      pages.add(
        ReaderPageSlice(
          startOffset: startOffset,
          endOffset: clampedEndOffset,
          text: text.substring(startOffset, clampedEndOffset),
        ),
      );

      startOffset = clampedEndOffset;
    }

    return ReaderPagination(pages: pages);
  }

  int _findLargestFittingEndOffset({
    required String text,
    required int startOffset,
    required TextStyle textStyle,
    required double maxWidth,
    required double maxHeight,
    required TextDirection textDirection,
    required TextAlign textAlign,
    required StrutStyle? strutStyle,
    required TextScaler textScaler,
    required TextHeightBehavior? textHeightBehavior,
    required Locale? locale,
  }) {
    final remainingText = text.substring(startOffset);
    final remainingFits = _fitsWithinPage(
      text: remainingText,
      textStyle: textStyle,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      textDirection: textDirection,
      textAlign: textAlign,
      strutStyle: strutStyle,
      textScaler: textScaler,
      textHeightBehavior: textHeightBehavior,
      locale: locale,
    );

    if (remainingFits) {
      return text.length;
    }

    int low = startOffset + 1;
    int high = text.length;
    int best = startOffset + 1;

    while (low <= high) {
      final mid = low + ((high - low) ~/ 2);
      final candidateFits = _fitsWithinPage(
        text: text.substring(startOffset, mid),
        textStyle: textStyle,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        textDirection: textDirection,
        textAlign: textAlign,
        strutStyle: strutStyle,
        textScaler: textScaler,
        textHeightBehavior: textHeightBehavior,
        locale: locale,
      );

      if (candidateFits) {
        best = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    return best;
  }

  bool _fitsWithinPage({
    required String text,
    required TextStyle textStyle,
    required double maxWidth,
    required double maxHeight,
    required TextDirection textDirection,
    required TextAlign textAlign,
    required StrutStyle? strutStyle,
    required TextScaler textScaler,
    required TextHeightBehavior? textHeightBehavior,
    required Locale? locale,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: textDirection,
      textAlign: textAlign,
      strutStyle: strutStyle,
      textScaler: textScaler,
      textHeightBehavior: textHeightBehavior,
      locale: locale,
    )..layout(maxWidth: maxWidth);

    return painter.height <= maxHeight + _heightTolerance;
  }

  static const double _heightTolerance = 0.001;
}

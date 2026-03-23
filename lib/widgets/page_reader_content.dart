import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/reader_pagination_service.dart';

class PageReaderContent extends StatefulWidget {
  final EdgeInsetsGeometry padding;
  final Widget? previousChapterButton;
  final String chapterTitle;
  final String chapterText;
  final TextStyle chapterTextStyle;
  final Widget chapterEndActions;
  final int? contentOffsetAnchor;
  final ReaderPaginationService paginationService;
  final TextSpan Function(ReaderPageSlice page) pageTextBuilder;
  final ValueChanged<int> onVisiblePageChanged;

  const PageReaderContent({
    super.key,
    required this.padding,
    this.previousChapterButton,
    required this.chapterTitle,
    required this.chapterText,
    required this.chapterTextStyle,
    required this.chapterEndActions,
    required this.contentOffsetAnchor,
    required this.paginationService,
    required this.pageTextBuilder,
    required this.onVisiblePageChanged,
  });

  @override
  State<PageReaderContent> createState() => _PageReaderContentState();
}

class _PageReaderContentState extends State<PageReaderContent> {
  final PageController _pageController = PageController();
  static const double _pageGap = 16.0;
  static const double _pageCornerRadius = 18.0;
  static const int _introPageAnchor = -1;

  Object? _layoutSignature;
  int? _queuedJumpPageIndex;
  int _currentPageIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resolvedPadding = widget.padding.resolve(Directionality.of(context));
    final pageStripPadding = EdgeInsets.fromLTRB(
      math.max(0.0, resolvedPadding.left - (_pageGap / 2)),
      resolvedPadding.top,
      math.max(0.0, resolvedPadding.right - (_pageGap / 2)),
      resolvedPadding.bottom,
    );

    return Padding(
      padding: pageStripPadding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pagination = widget.paginationService.paginate(
            text: widget.chapterText,
            textStyle: widget.chapterTextStyle,
            maxWidth: constraints.maxWidth - _pageGap,
            maxHeight: constraints.maxHeight,
            textDirection: Directionality.of(context),
            textAlign: TextAlign.justify,
            textScaler: MediaQuery.textScalerOf(context),
            locale: Localizations.maybeLocaleOf(context),
          );
          final pages = _buildPages(pagination);
          final targetPageIndex = _targetPageIndexForAnchor(pagination);

          _syncPageController(
            targetPageIndex: targetPageIndex,
            layoutSignature: Object.hash(
              widget.chapterTitle,
              widget.chapterText.hashCode,
              widget.chapterTextStyle.fontFamily,
              widget.chapterTextStyle.fontSize,
              widget.chapterTextStyle.height,
              constraints.maxWidth,
              constraints.maxHeight,
              pages.length,
            ),
          );

          return PageView.builder(
            key: const ValueKey<String>('reader-page-view'),
            controller: _pageController,
            itemCount: pages.length,
            onPageChanged: (pageIndex) {
              _currentPageIndex = pageIndex;
              widget.onVisiblePageChanged(
                pages[pageIndex].persistedContentOffset,
              );
            },
            itemBuilder: (context, pageIndex) {
              final page = pages[pageIndex];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: _pageGap / 2),
                child: _buildPageCard(context, page),
              );
            },
          );
        },
      ),
    );
  }

  List<_PageReaderPageData> _buildPages(ReaderPagination pagination) {
    return <_PageReaderPageData>[
      const _PageReaderPageData.intro(),
      ...pagination.pages.map(_PageReaderPageData.content),
      _PageReaderPageData.outro(widget.chapterText.length),
    ];
  }

  int _targetPageIndexForAnchor(ReaderPagination pagination) {
    final anchor = widget.contentOffsetAnchor;
    if (anchor == null || anchor < 0) {
      return 0;
    }
    if (anchor >= widget.chapterText.length) {
      return pagination.pages.length + 1;
    }
    return pagination.pageIndexForContentOffset(anchor) + 1;
  }

  Widget _buildPageCard(BuildContext context, _PageReaderPageData page) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_pageCornerRadius),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withAlpha(84),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: switch (page.kind) {
          _PageReaderPageKind.intro => _buildIntroPage(context),
          _PageReaderPageKind.content => _buildContentPage(page.pageSlice!),
          _PageReaderPageKind.outro => _buildOutroPage(),
        },
      ),
    );
  }

  Widget _buildIntroPage(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.previousChapterButton != null) ...[
          widget.previousChapterButton!,
          const SizedBox(height: 16),
        ],
        Text(
          widget.chapterTitle,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  Widget _buildContentPage(ReaderPageSlice page) {
    return Align(
      alignment: Alignment.topLeft,
      child: Text.rich(
        widget.pageTextBuilder(page),
        textAlign: TextAlign.justify,
        style: widget.chapterTextStyle,
      ),
    );
  }

  Widget _buildOutroPage() {
    return Column(
      children: [
        const Spacer(),
        widget.chapterEndActions,
      ],
    );
  }

  void _syncPageController({
    required int targetPageIndex,
    required Object layoutSignature,
  }) {
    final needsLayoutSync = _layoutSignature != layoutSignature;
    _layoutSignature = layoutSignature;

    if (needsLayoutSync || targetPageIndex != _currentPageIndex) {
      _queueJumpToPage(targetPageIndex);
    }
  }

  void _queueJumpToPage(int pageIndex) {
    if (_queuedJumpPageIndex == pageIndex) {
      return;
    }

    _queuedJumpPageIndex = pageIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      if (!_pageController.hasClients) {
        _queuedJumpPageIndex = null;
        _queueJumpToPage(pageIndex);
        return;
      }

      _queuedJumpPageIndex = null;
      final currentPage =
          (_pageController.page ?? _currentPageIndex.toDouble()).round();
      if (currentPage == pageIndex) {
        _currentPageIndex = pageIndex;
        return;
      }

      _currentPageIndex = pageIndex;
      _pageController.jumpToPage(pageIndex);
    });
  }
}

enum _PageReaderPageKind { intro, content, outro }

class _PageReaderPageData {
  final _PageReaderPageKind kind;
  final ReaderPageSlice? pageSlice;
  final int persistedContentOffset;

  const _PageReaderPageData._({
    required this.kind,
    required this.pageSlice,
    required this.persistedContentOffset,
  });

  const _PageReaderPageData.intro()
      : this._(
          kind: _PageReaderPageKind.intro,
          pageSlice: null,
          persistedContentOffset: _PageReaderContentState._introPageAnchor,
        );

  factory _PageReaderPageData.content(ReaderPageSlice pageSlice) {
    return _PageReaderPageData._(
      kind: _PageReaderPageKind.content,
      pageSlice: pageSlice,
      persistedContentOffset: pageSlice.startOffset,
    );
  }

  factory _PageReaderPageData.outro(int chapterLength) {
    return _PageReaderPageData._(
      kind: _PageReaderPageKind.outro,
      pageSlice: null,
      persistedContentOffset: chapterLength,
    );
  }
}

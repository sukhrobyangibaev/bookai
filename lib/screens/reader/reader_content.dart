part of 'package:bookai/screens/reader_screen.dart';

extension _ReaderContent on _ReaderScreenState {
  Widget _buildHiddenNavPill() {
    final theme = Theme.of(context);
    final progressText = _chapters != null && _chapters!.isNotEmpty
        ? '${_currentIndex + 1} / ${_chapters!.length}'
        : null;

    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(
            top: _ReaderScreenState._hiddenNavPillTopInset,
            right: _ReaderScreenState._hiddenNavPillSideInset,
          ),
          child: Material(
            key: _ReaderScreenState._hiddenNavPillKey,
            elevation: 2,
            color: theme.colorScheme.surface.withAlpha(228),
            shadowColor: Colors.black.withOpacity(0.1),
            shape: const StadiumBorder(),
            child: SizedBox(
              height: _ReaderScreenState._hiddenNavPillHeight,
              child: Padding(
                padding: const EdgeInsets.only(left: 4, right: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.menu),
                      iconSize: 20,
                      tooltip: 'Show Navigation Bar',
                      onPressed: _toggleNavbar,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints.tightFor(width: 36, height: 36),
                    ),
                    if (progressText != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        progressText,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildError();
    }

    if (_chapters == null || _chapters!.isEmpty) {
      return _buildEmpty();
    }

    return _buildContent();
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load book',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadChapters,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No readable content found',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final chapter = _currentChapter!;
    final settings = SettingsControllerScope.of(context);
    final settingsFontSize = settings.fontSize;
    final settingsFontFamily = settings.fontFamily;
    final topPadding = _ReaderScreenState._readerTopPadding +
        (_isNavbarVisible
            ? 0
            : _ReaderScreenState._hiddenNavPillHeight +
                _ReaderScreenState._hiddenNavPillContentGap);

    // Collect highlight texts for the current chapter to display inline
    // highlighting. Build a set for quick lookups.
    final currentHighlights =
        _highlights.where((h) => h.chapterIndex == _currentIndex).toList();
    final currentResumeMarker =
        _resumeMarker != null && _resumeMarker!.chapterIndex == _currentIndex
            ? _resumeMarker
            : null;

    return MobileScrollbar(
      controller: _scrollController,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(
          _ReaderScreenState._readerHorizontalPadding,
          topPadding,
          _ReaderScreenState._readerHorizontalPadding,
          _ReaderScreenState._readerBottomPadding + _activeAiBottomInset,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_hasPreviousChapter) ...[
              _buildChapterNavigationButton(
                label: 'Previous Chapter',
                alignment: Alignment.centerLeft,
                onPressed: () => _goToChapter(_currentIndex - 1),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              chapter.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SelectableText.rich(
              _buildHighlightedText(
                chapter.content,
                currentHighlights,
                currentResumeMarker,
              ),
              textAlign: TextAlign.justify,
              style: buildReaderContentTextStyle(
                context: context,
                fontSize: settingsFontSize,
                fontFamily: settingsFontFamily,
              ),
              contextMenuBuilder: (context, editableTextState) {
                return _buildSelectionToolbar(editableTextState);
              },
            ),
            const SizedBox(height: 24),
            _buildChapterEndActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterEndActions() {
    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.end,
        children: [
          OutlinedButton(
            onPressed: _summarizeCurrentChapter,
            child: const Text('Chapter Catch-Up'),
          ),
          if (_hasNextChapter)
            OutlinedButton(
              onPressed: () => _goToChapter(_currentIndex + 1),
              child: const Text('Next Chapter'),
            ),
        ],
      ),
    );
  }

  Widget _buildChapterNavigationButton({
    required String label,
    required Alignment alignment,
    required VoidCallback onPressed,
  }) {
    return Align(
      alignment: alignment,
      child: OutlinedButton(
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }

  /// Builds a [TextSpan] tree that highlights saved highlight texts inline.
  TextSpan _buildHighlightedText(
    String content,
    List<Highlight> currentHighlights,
    ResumeMarker? currentResumeMarker,
  ) {
    if (currentHighlights.isEmpty && currentResumeMarker == null) {
      return TextSpan(text: content);
    }

    // Build styled ranges for both regular highlights and resume marker.
    final List<_StyledRange> ranges = [];

    final highlightColor = Color(
      int.parse(
            _ReaderScreenState._defaultHighlightColorHex.replaceFirst('#', ''),
            radix: 16,
          ) |
          0xFF000000,
    ).withAlpha(100);

    final resumeColor = _ReaderScreenState._resumeMarkerColor.withAlpha(140);

    // Find all highlight ranges in the text.
    for (final hl in currentHighlights) {
      int startFrom = 0;
      // Find all occurrences of this highlight text in the content.
      while (true) {
        final idx = content.indexOf(hl.selectedText, startFrom);
        if (idx == -1) break;
        ranges.add(
          _StyledRange(
            start: idx,
            end: idx + hl.selectedText.length,
            style: TextStyle(backgroundColor: highlightColor),
            priority: 1,
          ),
        );
        startFrom = idx + hl.selectedText.length;
      }
    }

    if (currentResumeMarker != null &&
        currentResumeMarker.selectionStart >= 0 &&
        currentResumeMarker.selectionEnd > currentResumeMarker.selectionStart &&
        currentResumeMarker.selectionEnd <= content.length) {
      ranges.add(
        _StyledRange(
          start: currentResumeMarker.selectionStart,
          end: currentResumeMarker.selectionEnd,
          style: TextStyle(backgroundColor: resumeColor),
          priority: 2,
        ),
      );
    }

    if (ranges.isEmpty) {
      return TextSpan(text: content);
    }

    // Build boundaries, then style each segment by highest-priority range.
    final boundaries = <int>{0, content.length};
    for (final range in ranges) {
      boundaries.add(range.start);
      boundaries.add(range.end);
    }
    final sortedBoundaries = boundaries.toList()..sort();

    final spans = <TextSpan>[];
    for (int i = 0; i < sortedBoundaries.length - 1; i++) {
      final segStart = sortedBoundaries[i];
      final segEnd = sortedBoundaries[i + 1];
      if (segEnd <= segStart) continue;

      _StyledRange? activeRange;
      for (final range in ranges) {
        final intersects = range.start < segEnd && range.end > segStart;
        if (!intersects) continue;
        if (activeRange == null || range.priority > activeRange.priority) {
          activeRange = range;
        }
      }

      spans.add(
        TextSpan(
          text: content.substring(segStart, segEnd),
          style: activeRange?.style,
        ),
      );
    }

    return TextSpan(children: spans);
  }

  /// Custom context menu with reader actions.
  Widget _buildSelectionToolbar(EditableTextState editableTextState) {
    final items = buildReaderSelectionButtonItems(
      platformItems: editableTextState.contextMenuButtonItems,
      onCopy: () {
        editableTextState.copySelection(SelectionChangedCause.toolbar);
      },
      onHighlight: () {
        final selection = editableTextState.textEditingValue.selection;
        final text = editableTextState.textEditingValue.text;
        if (selection.isValid && !selection.isCollapsed) {
          final selected = text.substring(selection.start, selection.end);
          _saveHighlight(selected);
        }
        editableTextState.hideToolbar();
      },
      onDefineAndTranslate: () {
        _defineAndTranslateSelection(editableTextState);
      },
      onGenerateImage: () {
        _showGenerateImageModePicker(editableTextState);
      },
      onSimplifyText: () {
        _simplifyTextFromResumePoint(editableTextState);
      },
      onAskAi: () {
        _askAiAboutSelection(editableTextState);
      },
      onResumeHere: () {
        final selection = editableTextState.textEditingValue.selection;
        final text = editableTextState.textEditingValue.text;
        if (selection.isValid && !selection.isCollapsed) {
          final selected = text.substring(selection.start, selection.end);
          _saveResumeMarker(
            selectedText: selected,
            selectionStart: selection.start,
            selectionEnd: selection.end,
          );
        }
        editableTextState.hideToolbar();
      },
      onCatchMeUp: () {
        _summarizeFromResumePoint(editableTextState);
      },
    );

    return ReaderSelectionToolbar(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: items,
    );
  }
}

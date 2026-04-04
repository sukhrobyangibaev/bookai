part of 'package:bookai/screens/reader_screen.dart';

extension _ReaderOverlays on _ReaderScreenState {
  /// Shows a bottom sheet listing all highlights for the current book.
  void _showHighlights() {
    if (widget.book.id == null) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.3,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Highlights',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(${_highlights.length})',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    if (_highlights.isEmpty)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.highlight_off,
                                size: 48,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No highlights yet',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.outline,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Select text and tap "Highlight" to save',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.outline,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: MobileScrollbar(
                          controller: scrollController,
                          child: ListView.builder(
                            controller: scrollController,
                            itemCount: _highlights.length,
                            itemBuilder: (context, index) {
                              final hl = _highlights[index];
                              final chapterTitle = _chapters != null &&
                                      hl.chapterIndex >= 0 &&
                                      hl.chapterIndex < _chapters!.length
                                  ? _chapters![hl.chapterIndex].title
                                  : 'Chapter ${hl.chapterIndex + 1}';

                              return Dismissible(
                                key: ValueKey(hl.id),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  color: Theme.of(context).colorScheme.error,
                                  child: Icon(
                                    Icons.delete,
                                    color:
                                        Theme.of(context).colorScheme.onError,
                                  ),
                                ),
                                onDismissed: (_) async {
                                  final removed = _highlights[index];
                                  _setReaderState(() {
                                    _highlights.removeAt(index);
                                  });
                                  setSheetState(() {});
                                  if (removed.id != null) {
                                    await _db.deleteHighlight(removed.id!);
                                  }
                                },
                                child: ListTile(
                                  leading: Container(
                                    width: 4,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Color(
                                        int.parse(
                                              hl.colorHex.replaceFirst('#', ''),
                                              radix: 16,
                                            ) |
                                            0xFF000000,
                                      ),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  title: Text(
                                    '"${hl.selectedText}"',
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          fontStyle: FontStyle.italic,
                                        ),
                                  ),
                                  subtitle: Text(
                                    chapterTitle,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline,
                                        ),
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(
                                      Icons.delete_outline,
                                      size: 20,
                                      color:
                                          Theme.of(context).colorScheme.outline,
                                    ),
                                    onPressed: () async {
                                      final removed = _highlights[index];
                                      _setReaderState(() {
                                        _highlights.removeAt(index);
                                      });
                                      setSheetState(() {});
                                      if (removed.id != null) {
                                        await _db.deleteHighlight(removed.id!);
                                      }
                                    },
                                  ),
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    _goToChapter(hl.chapterIndex);
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showTableOfContents() {
    if (_chapters == null || _chapters!.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Table of Contents',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: MobileScrollbar(
                    controller: scrollController,
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: _chapters!.length,
                      itemBuilder: (context, index) {
                        final chapter = _chapters![index];
                        final isCurrent = index == _currentIndex;
                        return ListTile(
                          leading: Text(
                            '${index + 1}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: isCurrent
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.outline,
                                ),
                          ),
                          title: Text(
                            chapter.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: isCurrent
                                ? TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  )
                                : null,
                          ),
                          selected: isCurrent,
                          selectedTileColor: Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withAlpha(80),
                          onTap: () {
                            Navigator.of(context).pop();
                            _goToChapter(index);
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

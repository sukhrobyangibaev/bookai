import 'dart:async';

import 'package:flutter/material.dart';

import '../app.dart';
import '../models/book.dart';
import '../models/bookmark.dart';
import '../models/chapter.dart';
import '../models/highlight.dart';
import '../models/reading_progress.dart';
import '../services/database_service.dart';
import '../services/epub_service.dart';

/// Displays the content of a [Book] with chapter-by-chapter navigation.
class ReaderScreen extends StatefulWidget {
  final Book book;

  const ReaderScreen({super.key, required this.book});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final _epub = EpubService.instance;
  final _db = DatabaseService.instance;
  final _scrollController = ScrollController();

  List<Chapter>? _chapters;
  int _currentIndex = 0;
  bool _loading = true;
  String? _error;

  /// Bookmarks for the current book.
  List<Bookmark> _bookmarks = [];

  /// Highlights for the current book.
  List<Highlight> _highlights = [];

  /// Default highlight color (warm yellow).
  static const _defaultHighlightColorHex = '#FFEB3B';

  /// Debounce timer for persisting scroll offset.
  Timer? _saveTimer;

  /// Duration to debounce scroll-based progress saves.
  static const _saveDebounceDuration = Duration(seconds: 2);

  /// Minimum horizontal velocity (px/s) to trigger a chapter swipe.
  static const _swipeVelocityThreshold = 300.0;

  /// Minimum horizontal distance (px) to trigger a chapter swipe.
  static const _swipeDistanceThreshold = 50.0;

  /// Tracks the starting X position of a horizontal drag.
  double _dragStartX = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadChapters();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    // Persist final progress synchronously before disposing.
    _saveProgressNow();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // ── Chapter loading ──────────────────────────────────────────────────────

  Future<void> _loadChapters() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final chapters = await _epub.parseChapters(widget.book.filePath);
      if (!mounted) return;

      // Restore saved progress if available.
      final bookId = widget.book.id;
      ReadingProgress? saved;
      if (bookId != null) {
        saved = await _db.getProgressByBookId(bookId);
        // Load bookmarks and highlights for this book.
        _bookmarks = await _db.getBookmarksByBookId(bookId);
        _highlights = await _db.getHighlightsByBookId(bookId);
      }

      if (mounted) {
        setState(() {
          _chapters = chapters;
          if (saved != null &&
              saved.chapterIndex >= 0 &&
              saved.chapterIndex < chapters.length) {
            _currentIndex = saved.chapterIndex;
          }
          _loading = false;
        });

        // Restore scroll offset after the frame renders.
        if (saved != null && saved.scrollOffset > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              final maxScroll = _scrollController.position.maxScrollExtent;
              _scrollController
                  .jumpTo(saved!.scrollOffset.clamp(0.0, maxScroll));
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  // ── Chapter navigation ───────────────────────────────────────────────────

  void _goToChapter(int index) {
    if (_chapters == null) return;
    if (index < 0 || index >= _chapters!.length) return;

    setState(() => _currentIndex = index);

    // Reset scroll position when switching chapters.
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }

    // Save progress immediately on chapter change.
    _saveProgressNow();
  }

  Chapter? get _currentChapter {
    if (_chapters == null || _chapters!.isEmpty) return null;
    if (_currentIndex < 0 || _currentIndex >= _chapters!.length) return null;
    return _chapters![_currentIndex];
  }

  // ── Progress persistence ─────────────────────────────────────────────────

  void _onScroll() {
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDebounceDuration, _saveProgressNow);
  }

  // ── Swipe navigation ────────────────────────────────────────────────────

  void _onHorizontalDragStart(DragStartDetails details) {
    _dragStartX = details.globalPosition.dx;
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_chapters == null || _chapters!.isEmpty) return;

    final velocity = details.primaryVelocity ?? 0.0;
    final dragDistance = (details.globalPosition.dx - _dragStartX).abs();

    // Only respond to swipes that are fast enough or long enough.
    if (velocity.abs() < _swipeVelocityThreshold &&
        dragDistance < _swipeDistanceThreshold) {
      return;
    }

    if (velocity < 0) {
      // Swiped left → next chapter.
      _goToChapter(_currentIndex + 1);
    } else if (velocity > 0) {
      // Swiped right → previous chapter.
      _goToChapter(_currentIndex - 1);
    }
  }

  void _saveProgressNow() {
    _saveTimer?.cancel();
    final bookId = widget.book.id;
    if (bookId == null || _chapters == null || _chapters!.isEmpty) return;

    final offset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;

    _db.upsertProgress(
      ReadingProgress(
        bookId: bookId,
        chapterIndex: _currentIndex,
        scrollOffset: offset,
        updatedAt: DateTime.now(),
      ),
    );
  }

  // ── Bookmarks ────────────────────────────────────────────────────────────

  /// Adds a bookmark at the current reading position.
  Future<void> _addBookmark() async {
    final bookId = widget.book.id;
    if (bookId == null || _currentChapter == null) return;

    // Generate a short excerpt from the start of the current chapter content.
    final content = _currentChapter!.content;
    final excerpt = content.length > 80
        ? '${content.substring(0, 80).trim()}...'
        : content.trim();

    final bookmark = Bookmark(
      bookId: bookId,
      chapterIndex: _currentIndex,
      excerpt: excerpt,
      createdAt: DateTime.now(),
    );

    final saved = await _db.addBookmark(bookmark);
    setState(() {
      _bookmarks.insert(0, saved);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bookmarked: ${_currentChapter!.title}',
          ),
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: 'View All',
            onPressed: _showBookmarks,
          ),
        ),
      );
    }
  }

  /// Shows a bottom sheet listing all bookmarks for the current book.
  void _showBookmarks() {
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
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Text(
                            'Bookmarks',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(${_bookmarks.length})',
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
                    if (_bookmarks.isEmpty)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.bookmark_border,
                                size: 48,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No bookmarks yet',
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
                                'Tap the bookmark icon to save your position',
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
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: _bookmarks.length,
                          itemBuilder: (context, index) {
                            final bm = _bookmarks[index];
                            final chapterTitle = _chapters != null &&
                                    bm.chapterIndex >= 0 &&
                                    bm.chapterIndex < _chapters!.length
                                ? _chapters![bm.chapterIndex].title
                                : 'Chapter ${bm.chapterIndex + 1}';

                            return Dismissible(
                              key: ValueKey(bm.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                color: Theme.of(context).colorScheme.error,
                                child: Icon(
                                  Icons.delete,
                                  color: Theme.of(context).colorScheme.onError,
                                ),
                              ),
                              onDismissed: (_) async {
                                final removed = _bookmarks[index];
                                setState(() {
                                  _bookmarks.removeAt(index);
                                });
                                setSheetState(() {});
                                if (removed.id != null) {
                                  await _db.deleteBookmark(removed.id!);
                                }
                              },
                              child: ListTile(
                                leading: Icon(
                                  Icons.bookmark,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                title: Text(
                                  chapterTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  bm.excerpt,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
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
                                    final removed = _bookmarks[index];
                                    setState(() {
                                      _bookmarks.removeAt(index);
                                    });
                                    setSheetState(() {});
                                    if (removed.id != null) {
                                      await _db.deleteBookmark(removed.id!);
                                    }
                                  },
                                ),
                                onTap: () {
                                  Navigator.of(context).pop();
                                  _goToChapter(bm.chapterIndex);
                                },
                              ),
                            );
                          },
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

  // ── Highlights ───────────────────────────────────────────────────────────

  /// Saves the given selected text as a highlight.
  Future<void> _saveHighlight(String selectedText) async {
    final bookId = widget.book.id;
    if (bookId == null) return;

    final trimmed = selectedText.trim();
    if (trimmed.isEmpty) return;

    final highlight = Highlight(
      bookId: bookId,
      chapterIndex: _currentIndex,
      selectedText: trimmed,
      colorHex: _defaultHighlightColorHex,
      createdAt: DateTime.now(),
    );

    final saved = await _db.addHighlight(highlight);
    setState(() {
      _highlights.insert(0, saved);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Highlight saved'),
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: 'View All',
            onPressed: _showHighlights,
          ),
        ),
      );
    }
  }

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
                          horizontal: 16, vertical: 12),
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
                                  color: Theme.of(context).colorScheme.onError,
                                ),
                              ),
                              onDismissed: (_) async {
                                final removed = _highlights[index];
                                setState(() {
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
                                    setState(() {
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
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  // ── Table of Contents ────────────────────────────────────────────────────

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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _chapters!.length,
                    itemBuilder: (context, index) {
                      final chapter = _chapters![index];
                      final isCurrent = index == _currentIndex;
                      return ListTile(
                        leading: Text(
                          '${index + 1}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
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
                                  color: Theme.of(context).colorScheme.primary,
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
              ],
            );
          },
        );
      },
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentChapter?.title ?? widget.book.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_chapters != null && _chapters!.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.bookmark_add_outlined),
              tooltip: 'Add Bookmark',
              onPressed: _addBookmark,
            ),
            IconButton(
              icon: const Icon(Icons.bookmarks_outlined),
              tooltip: 'Bookmarks',
              onPressed: _showBookmarks,
            ),
            IconButton(
              icon: const Icon(Icons.highlight_outlined),
              tooltip: 'Highlights',
              onPressed: _showHighlights,
            ),
            IconButton(
              icon: const Icon(Icons.toc),
              tooltip: 'Table of Contents',
              onPressed: _showTableOfContents,
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  '${_currentIndex + 1} / ${_chapters!.length}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar:
          _chapters != null && _chapters!.isNotEmpty ? _buildNavBar() : null,
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
    final settingsFontSize = SettingsControllerScope.of(context).fontSize;

    // Collect highlight texts for the current chapter to display inline
    // highlighting. Build a set for quick lookups.
    final currentHighlights =
        _highlights.where((h) => h.chapterIndex == _currentIndex).toList();

    return GestureDetector(
      onHorizontalDragStart: _onHorizontalDragStart,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      behavior: HitTestBehavior.translucent,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              chapter.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SelectableText.rich(
              _buildHighlightedText(chapter.content, currentHighlights),
              contextMenuBuilder: (context, editableTextState) {
                return _buildSelectionToolbar(context, editableTextState);
              },
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: settingsFontSize,
                    height: 1.6,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a [TextSpan] tree that highlights saved highlight texts inline.
  TextSpan _buildHighlightedText(
      String content, List<Highlight> currentHighlights) {
    if (currentHighlights.isEmpty) {
      return TextSpan(text: content);
    }

    // Find all highlight ranges in the text.
    final List<_HighlightRange> ranges = [];
    for (final hl in currentHighlights) {
      int startFrom = 0;
      // Find all occurrences of this highlight text in the content.
      while (true) {
        final idx = content.indexOf(hl.selectedText, startFrom);
        if (idx == -1) break;
        ranges.add(_HighlightRange(idx, idx + hl.selectedText.length));
        startFrom = idx + hl.selectedText.length;
      }
    }

    if (ranges.isEmpty) {
      return TextSpan(text: content);
    }

    // Sort ranges by start index and merge overlaps.
    ranges.sort((a, b) => a.start.compareTo(b.start));
    final merged = <_HighlightRange>[];
    for (final r in ranges) {
      if (merged.isNotEmpty && r.start <= merged.last.end) {
        final last = merged.last;
        merged[merged.length - 1] = _HighlightRange(
          last.start,
          r.end > last.end ? r.end : last.end,
        );
      } else {
        merged.add(r);
      }
    }

    // Build spans.
    final highlightColor = Color(
      int.parse(
            _defaultHighlightColorHex.replaceFirst('#', ''),
            radix: 16,
          ) |
          0xFF000000,
    ).withAlpha(100);

    final spans = <TextSpan>[];
    int cursor = 0;
    for (final r in merged) {
      if (r.start > cursor) {
        spans.add(TextSpan(text: content.substring(cursor, r.start)));
      }
      spans.add(TextSpan(
        text: content.substring(r.start, r.end),
        style: TextStyle(backgroundColor: highlightColor),
      ));
      cursor = r.end;
    }
    if (cursor < content.length) {
      spans.add(TextSpan(text: content.substring(cursor)));
    }

    return TextSpan(children: spans);
  }

  /// Custom context menu with a "Highlight" action when text is selected.
  Widget _buildSelectionToolbar(
      BuildContext context, EditableTextState editableTextState) {
    final List<ContextMenuButtonItem> items = [
      ...editableTextState.contextMenuButtonItems,
      ContextMenuButtonItem(
        label: 'Highlight',
        onPressed: () {
          final selection = editableTextState.textEditingValue.selection;
          final text = editableTextState.textEditingValue.text;
          if (selection.isValid && !selection.isCollapsed) {
            final selected = text.substring(selection.start, selection.end);
            _saveHighlight(selected);
          }
          editableTextState.hideToolbar();
        },
      ),
    ];

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: items,
    );
  }

  Widget _buildNavBar() {
    final hasPrev = _currentIndex > 0;
    final hasNext = _currentIndex < _chapters!.length - 1;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    hasPrev ? () => _goToChapter(_currentIndex - 1) : null,
                icon: const Icon(Icons.chevron_left),
                label: const Text('Previous'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    hasNext ? () => _goToChapter(_currentIndex + 1) : null,
                icon: const Icon(Icons.chevron_right),
                label: const Text('Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper class to represent a range in text for highlighting.
class _HighlightRange {
  final int start;
  final int end;
  const _HighlightRange(this.start, this.end);
}

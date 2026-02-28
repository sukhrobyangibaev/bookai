import 'dart:async';

import 'package:flutter/material.dart';

import '../models/book.dart';
import '../models/chapter.dart';
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

  /// Debounce timer for persisting scroll offset.
  Timer? _saveTimer;

  /// Duration to debounce scroll-based progress saves.
  static const _saveDebounceDuration = Duration(seconds: 2);

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
          if (_chapters != null && _chapters!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.toc),
              tooltip: 'Table of Contents',
              onPressed: _showTableOfContents,
            ),
          if (_chapters != null && _chapters!.isNotEmpty)
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
    return SingleChildScrollView(
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
          Text(
            chapter.content,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.6,
                ),
          ),
        ],
      ),
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

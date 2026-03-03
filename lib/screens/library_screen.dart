import 'package:flutter/material.dart';

import '../models/book.dart';
import '../models/reading_progress.dart';
import '../services/database_service.dart';
import '../services/library_service.dart';
import 'reader_screen.dart';
import 'settings_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _library = LibraryService.instance;
  final _db = DatabaseService.instance;

  List<Book> _books = [];

  /// Cached progress per book id for displaying subtitle.
  Map<int, ReadingProgress> _progressMap = {};
  bool _loading = true;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    setState(() => _loading = true);
    try {
      final books = await _library.getAllBooks();

      // Load progress for each book.
      final Map<int, ReadingProgress> progressMap = {};
      for (final book in books) {
        if (book.id != null) {
          final progress = await _db.getProgressByBookId(book.id!);
          if (progress != null) {
            progressMap[book.id!] = progress;
          }
        }
      }

      if (mounted) {
        setState(() {
          _books = books;
          _progressMap = progressMap;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _importEpub() async {
    if (_importing) return;
    setState(() => _importing = true);

    try {
      final result = await _library.importEpub();

      if (!mounted) return;

      switch (result) {
        case ImportSuccess(:final book):
          await _loadBooks();
          _showSnackBar('Imported "${book.title}"');

        case ImportCancelled():
          // user dismissed the picker — nothing to do
          break;

        case ImportDuplicate(:final existing):
          _showSnackBar('"${existing.title}" is already in your library.');

        case ImportError(:final message):
          _showSnackBar('Import failed: $message', isError: true);
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _deleteBook(Book book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Book'),
        content: Text(
          'Are you sure you want to delete "${book.title}"?\n\n'
          'This will remove the book, all highlights, '
          'and reading progress permanently.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _library.deleteBook(book);
      await _loadBooks();
      if (mounted) {
        _showSnackBar('Deleted "${book.title}"');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to delete: $e', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BookAI Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _importing ? null : _importEpub,
        icon: _importing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
        label: const Text('Import EPUB'),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_books.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadBooks,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: _books.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final book = _books[index];
          final progress = book.id != null ? _progressMap[book.id!] : null;
          return _BookCard(
            book: book,
            progress: progress,
            onTap: () => _openReader(book),
            onDelete: () => _deleteBook(book),
          );
        },
      ),
    );
  }

  Future<void> _openReader(Book book) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReaderScreen(book: book)),
    );
    // Refresh library (and progress subtitles) when returning from reader.
    _loadBooks();
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 96,
              color: theme.colorScheme.primary.withOpacity(0.4),
            ),
            const SizedBox(height: 24),
            Text(
              'Your library is empty',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Import an EPUB file to start reading.\n'
              'Your books, progress, and highlights are stored locally.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _importing ? null : _importEpub,
              icon: _importing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: const Text('Import Your First Book'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Book Card ──────────────────────────────────────────────────────────────────

class _BookCard extends StatelessWidget {
  const _BookCard({
    required this.book,
    this.progress,
    this.onTap,
    this.onDelete,
  });

  final Book book;
  final ReadingProgress? progress;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  double? get _progressFraction {
    if (progress == null || book.totalChapters <= 0) return null;
    return (progress!.chapterIndex + 1) / book.totalChapters;
  }

  String _buildProgressLabel() {
    if (progress == null || book.totalChapters <= 0) return 'Not started';
    final chapterNum = progress!.chapterIndex + 1;
    final total = book.totalChapters;
    final pct = (_progressFraction! * 100).round();
    return 'Chapter $chapterNum of $total  ($pct%)';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = _progressFraction;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Book icon container
              Container(
                width: 48,
                height: 64,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  color: theme.colorScheme.onPrimaryContainer,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              // Book info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      book.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Progress indicator row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: fraction ?? 0.0,
                                  minHeight: 4,
                                  backgroundColor:
                                      theme.colorScheme.surfaceContainerHighest,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _buildProgressLabel(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Delete action
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                tooltip: 'More options',
                onSelected: (value) {
                  if (value == 'delete') {
                    onDelete?.call();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline,
                            color: theme.colorScheme.error, size: 20),
                        const SizedBox(width: 8),
                        Text('Delete',
                            style: TextStyle(color: theme.colorScheme.error)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

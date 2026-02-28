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
          return _BookTile(
            book: book,
            progress: progress,
            onTap: () => _openReader(book),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 72,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'Your library is empty',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap "Import EPUB" to add your first book.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }
}

class _BookTile extends StatelessWidget {
  const _BookTile({required this.book, this.progress, this.onTap});

  final Book book;
  final ReadingProgress? progress;
  final VoidCallback? onTap;

  String _buildSubtitle() {
    final parts = <String>[book.author];
    if (progress != null && book.totalChapters > 0) {
      final chapterNum = progress!.chapterIndex + 1;
      final total = book.totalChapters;
      final pct = ((chapterNum / total) * 100).round();
      parts.add('Chapter $chapterNum/$total ($pct%)');
    }
    return parts.join('  ·  ');
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            Icons.book_outlined,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          book.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          _buildSubtitle(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: onTap,
      ),
    );
  }
}

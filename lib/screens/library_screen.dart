import 'dart:io';

import 'package:flutter/material.dart';

import '../models/book.dart';
import '../models/generated_image.dart';
import '../models/reading_progress.dart';
import '../services/database_service.dart';
import '../services/library_service.dart';
import '../widgets/generated_image_viewer.dart';
import '../widgets/mobile_scrollbar.dart';
import 'reader_screen.dart';
import 'settings_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  final _library = LibraryService.instance;
  final _db = DatabaseService.instance;
  final _booksScrollController = ScrollController();
  final _imagesScrollController = ScrollController();

  late final TabController _tabController;

  List<Book> _books = [];
  List<GeneratedImage> _generatedImages = [];

  /// Cached progress per book id for displaying subtitle.
  Map<int, ReadingProgress> _progressMap = {};
  bool _loading = true;
  bool _importing = false;

  Map<int, Book> get _booksById => {
        for (final book in _books)
          if (book.id != null) book.id!: book,
      };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
    _loadLibraryData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _booksScrollController.dispose();
    _imagesScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLibraryData() async {
    setState(() => _loading = true);
    try {
      final booksFuture = _library.getAllBooks();
      final generatedImagesFuture = _library.getAllGeneratedImages();

      final books = await booksFuture;
      final progressEntries = await Future.wait(
        books.where((book) => book.id != null).map((book) async {
          final progress = await _db.getProgressByBookId(book.id!);
          return MapEntry(book.id!, progress);
        }),
      );
      final generatedImages = await generatedImagesFuture;

      final progressMap = <int, ReadingProgress>{};
      for (final entry in progressEntries) {
        final progress = entry.value;
        if (progress != null) {
          progressMap[entry.key] = progress;
        }
      }

      if (mounted) {
        setState(() {
          _books = books;
          _generatedImages = generatedImages;
          _progressMap = progressMap;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
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
          await _loadLibraryData();
          _showSnackBar('Imported "${book.title}"');

        case ImportCancelled():
          _showSnackBar('Import cancelled.');

        case ImportDuplicate(:final existing):
          _showSnackBar('"${existing.title}" is already in your library.');

        case ImportError(:final message):
          _showSnackBar('Import failed: $message', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  Future<void> _deleteBook(Book book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Book'),
        content: Text(
          'Are you sure you want to delete "${book.title}"?\n\n'
          'This will remove the book, all highlights, generated images, '
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
      await _loadLibraryData();
      if (mounted) {
        _showSnackBar('Deleted "${book.title}"');
      }
    } catch (error) {
      if (mounted) {
        _showSnackBar('Failed to delete: $error', isError: true);
      }
    }
  }

  Future<void> _deleteGeneratedImage(GeneratedImage generatedImage) async {
    final book = _booksById[generatedImage.bookId];
    final imageTitle = _generatedImageDisplayName(generatedImage, book);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Image'),
        content: Text(
          'Delete "$imageTitle"?\n\n'
          'The saved image file and its prompt metadata will be removed.',
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
      await _library.deleteGeneratedImage(generatedImage);
      await _loadLibraryData();
      if (mounted) {
        _showSnackBar('Deleted generated image');
      }
    } catch (error) {
      if (mounted) {
        _showSnackBar('Failed to delete image: $error', isError: true);
      }
    }
  }

  Future<void> _renameGeneratedImage(GeneratedImage generatedImage) async {
    final book = _booksById[generatedImage.bookId];
    final updatedName = await _showGeneratedImageNameEditorSheet(
      initialName: generatedImage.name,
      fallbackBookTitle: book?.title ?? '',
    );
    if (updatedName == null || !mounted) return;

    final normalizedName = _normalizeGeneratedImageName(updatedName);

    try {
      await _library.renameGeneratedImage(generatedImage, normalizedName);
      await _loadLibraryData();
      if (mounted) {
        _showSnackBar(
          normalizedName == null ? 'Image name cleared' : 'Image name updated',
        );
      }
    } catch (error) {
      if (mounted) {
        _showSnackBar('Failed to rename image: $error', isError: true);
      }
    }
  }

  void _showGeneratedImageDetail(GeneratedImage generatedImage) {
    final book = _booksById[generatedImage.bookId];
    final imageTitle = _generatedImageDisplayName(generatedImage, book);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  imageTitle,
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${_featureModeLabel(generatedImage.featureMode)} • '
                  'Chapter ${generatedImage.chapterIndex + 1}',
                  style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                        color:
                            Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 4),
                GeneratedImageFileSizeText(
                  filePath: generatedImage.filePath,
                  style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                        color:
                            Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      ZoomableGeneratedImagePreview(
                        key: const ValueKey<String>(
                          'library-generated-image-preview',
                        ),
                        filePath: generatedImage.filePath,
                        viewerTitle: imageTitle,
                        fit: BoxFit.contain,
                        height: 320,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap image to zoom',
                        style: Theme.of(sheetContext)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: Theme.of(sheetContext)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Prompt',
                        style: Theme.of(sheetContext).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      SelectableText(generatedImage.promptText),
                      const SizedBox(height: 16),
                      Text(
                        'Source Text',
                        style: Theme.of(sheetContext).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      SelectableText(generatedImage.sourceText),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: const Text('Close'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          await _renameGeneratedImage(generatedImage);
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Rename'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          await _deleteGeneratedImage(generatedImage);
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String? _normalizeGeneratedImageName(String rawName) {
    final normalizedName = rawName.trim();
    if (normalizedName.isEmpty) {
      return null;
    }

    return normalizedName;
  }

  String _generatedImageDisplayName(GeneratedImage generatedImage, Book? book) {
    return generatedImage.displayName(book?.title ?? '');
  }

  Future<String?> _showGeneratedImageNameEditorSheet({
    required String? initialName,
    required String fallbackBookTitle,
  }) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return _GeneratedImageNameEditorSheet(
          initialName: initialName,
          fallbackBookTitle: fallbackBookTitle,
        );
      },
    );
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

  bool get _showImportFab => _tabController.index == 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BookAI Library'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Books', icon: Icon(Icons.auto_stories_outlined)),
            Tab(text: 'Images', icon: Icon(Icons.image_outlined)),
          ],
        ),
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
      floatingActionButton: _showImportFab
          ? FloatingActionButton.extended(
              onPressed: _importing ? null : _importEpub,
              icon: _importing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: const Text('Import EPUB'),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildBooksTab(),
        _buildImagesTab(),
      ],
    );
  }

  Widget _buildBooksTab() {
    if (_books.isEmpty) {
      return _buildBooksEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadLibraryData,
      child: MobileScrollbar(
        controller: _booksScrollController,
        child: ListView.separated(
          controller: _booksScrollController,
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
      ),
    );
  }

  Widget _buildImagesTab() {
    if (_generatedImages.isEmpty) {
      return _buildImagesEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadLibraryData,
      child: MobileScrollbar(
        controller: _imagesScrollController,
        child: ListView.separated(
          controller: _imagesScrollController,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: _generatedImages.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final generatedImage = _generatedImages[index];
            final book = _booksById[generatedImage.bookId];
            return _GeneratedImageCard(
              generatedImage: generatedImage,
              title: _generatedImageDisplayName(generatedImage, book),
              onTap: () => _showGeneratedImageDetail(generatedImage),
              onRename: () => _renameGeneratedImage(generatedImage),
              onDelete: () => _deleteGeneratedImage(generatedImage),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openReader(Book book) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReaderScreen(book: book)),
    );
    _loadLibraryData();
  }

  Widget _buildBooksEmptyState() {
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
              'Your books, progress, highlights, and generated images are stored locally.',
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

  Widget _buildImagesEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_outlined,
              size: 96,
              color: theme.colorScheme.primary.withOpacity(0.4),
            ),
            const SizedBox(height: 24),
            Text(
              'No generated images yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Generate an image from the reader and it will appear here for the book it belongs to.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _featureModeLabel(String featureMode) {
    switch (featureMode) {
      case 'resume_range':
        return 'Resume Range';
      case 'selected_text':
        return 'Selected Text';
      default:
        return featureMode
            .replaceAll('_', ' ')
            .split(' ')
            .map((part) => part.isEmpty
                ? part
                : '${part[0].toUpperCase()}${part.substring(1)}')
            .join(' ');
    }
  }
}

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
                        Icon(
                          Icons.delete_outline,
                          color: theme.colorScheme.error,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Delete',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
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

class _GeneratedImageCard extends StatelessWidget {
  const _GeneratedImageCard({
    required this.generatedImage,
    required this.title,
    this.onTap,
    this.onRename,
    this.onDelete,
  });

  final GeneratedImage generatedImage;
  final String title;
  final VoidCallback? onTap;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _GeneratedImageThumbnail(
                  filePath: generatedImage.filePath,
                  width: 104,
                  height: 104,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      generatedImage.promptText,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Chapter ${generatedImage.chapterIndex + 1} • '
                      '${generatedImage.featureMode.replaceAll('_', ' ')}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Image options',
                onSelected: (value) {
                  if (value == 'rename') {
                    onRename?.call();
                  } else if (value == 'delete') {
                    onDelete?.call();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem<String>(
                    value: 'rename',
                    child: Text('Rename'),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Text('Delete'),
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

class _GeneratedImageNameEditorSheet extends StatefulWidget {
  const _GeneratedImageNameEditorSheet({
    required this.initialName,
    required this.fallbackBookTitle,
  });

  final String? initialName;
  final String fallbackBookTitle;

  @override
  State<_GeneratedImageNameEditorSheet> createState() =>
      _GeneratedImageNameEditorSheetState();
}

class _GeneratedImageNameEditorSheetState
    extends State<_GeneratedImageNameEditorSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rename Image',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              widget.fallbackBookTitle.trim().isEmpty
                  ? 'Leave blank to use the default generated image title.'
                  : 'Leave blank to use "${widget.fallbackBookTitle}".',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Image Name',
              ),
              onSubmitted: (value) => Navigator.of(context).pop(value),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(_controller.text),
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GeneratedImageThumbnail extends StatelessWidget {
  const _GeneratedImageThumbnail({
    required this.filePath,
    this.width,
    this.height,
  });

  final String filePath;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: width,
      height: height,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Image.file(
        File(filePath),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          );
        },
      ),
    );
  }
}

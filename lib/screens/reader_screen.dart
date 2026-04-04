import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../models/ai_chat_message.dart';
import '../models/ai_feature.dart';
import '../models/ai_model_info.dart';
import '../models/ai_model_selection.dart';
import '../models/ai_provider.dart';
import '../models/ai_text_stream_event.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import '../models/generated_image.dart';
import '../models/highlight.dart';
import '../models/reading_progress.dart';
import '../models/reader_settings.dart';
import '../models/resume_marker.dart';
import '../services/chapter_loader_service.dart';
import '../services/database_service.dart';
import '../services/gemini_service.dart';
import '../services/openrouter_service.dart';
import '../services/resume_summary_service.dart';
import '../services/settings_controller.dart';
import '../services/storage_service.dart';
import '../theme/reader_typography.dart';
import '../widgets/generated_image_viewer.dart';
import '../widgets/mobile_scrollbar.dart';
import '../widgets/reader_selection_toolbar.dart';

part 'reader/reader_overlays.dart';
part 'reader/reader_content.dart';
part 'reader/reader_ai_sheets.dart';
part 'reader/reader_ai_flow.dart';
part 'reader/reader_models.dart';

/// Displays the content of a [Book] with chapter-by-chapter navigation.
class ReaderScreen extends StatefulWidget {
  final Book book;
  final ChapterLoaderService? chapterLoader;
  final DatabaseService? databaseService;
  final OpenRouterService? openRouterService;
  final GeminiService? geminiService;
  final ResumeSummaryService? resumeSummaryService;
  final StorageService? storageService;

  const ReaderScreen({
    super.key,
    required this.book,
    this.chapterLoader,
    this.databaseService,
    this.openRouterService,
    this.geminiService,
    this.resumeSummaryService,
    this.storageService,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late final ChapterLoaderService _chapterLoader;
  late final DatabaseService _db;
  late final OpenRouterService _openRouter;
  late final GeminiService _gemini;
  late final ResumeSummaryService _resumeSummaryService;
  late final StorageService _storage;
  final _scrollController = ScrollController();

  List<Chapter>? _chapters;
  int _currentIndex = 0;
  bool _loading = true;
  String? _error;
  bool _isNavbarVisible = false;

  /// Highlights for the current book.
  List<Highlight> _highlights = [];

  /// Optional manual "resume from here" marker for this book.
  ResumeMarker? _resumeMarker;

  /// Default highlight color (warm yellow).
  static const _defaultHighlightColorHex = '#FFEB3B';

  /// Visual color for manual resume marker text.
  static const _resumeMarkerColor = Color(0xFF80DEEA);

  /// Debounce timer for persisting scroll offset.
  Timer? _saveTimer;

  /// Duration to debounce scroll-based progress saves.
  static const _saveDebounceDuration = Duration(seconds: 2);

  /// Monotonic token used to avoid stale delayed snackbar dismissals.
  int _snackBarToken = 0;

  /// Monotonic token used to ignore stale AI completions.
  int _aiRequestToken = 0;
  bool _hasBackgroundAiRequest = false;
  _InitialAiStreamPhase _initialAiStreamPhase = _InitialAiStreamPhase.idle;

  _ActiveAiRequest? _activeAiRequest;
  _ActiveAiConversationSheetState? _activeAiConversationSheet;
  final ValueNotifier<_ActiveAiConversationSheetState?>
      _activeAiConversationSheetListenable =
      ValueNotifier<_ActiveAiConversationSheetState?>(null);
  bool _isInitialAiConversationSheetVisible = false;
  Timer? _aiLoadingElapsedTimer;
  int _activeAiElapsedSeconds = 0;

  static const double _aiLoadingSheetReservedSpace = 116.0;
  static const double _readerHorizontalPadding = 20.0;
  static const double _readerTopPadding = 16.0;
  static const double _readerBottomPadding = 32.0;
  static const double _hiddenNavPillHeight = 40.0;
  static const double _hiddenNavPillTopInset = 8.0;
  static const double _hiddenNavPillSideInset = 8.0;
  static const double _hiddenNavPillContentGap = 8.0;
  static const ValueKey<String> _hiddenNavPillKey =
      ValueKey<String>('reader-hidden-nav-pill');

  static const List<AppThemeMode> _readerThemeModes = <AppThemeMode>[
    AppThemeMode.system,
    AppThemeMode.light,
    AppThemeMode.dark,
    AppThemeMode.night,
    AppThemeMode.sepia,
  ];

  @override
  void initState() {
    super.initState();
    _chapterLoader = widget.chapterLoader ?? ChapterLoaderService.instance;
    _db = widget.databaseService ?? DatabaseService.instance;
    _openRouter = widget.openRouterService ?? OpenRouterService();
    _gemini = widget.geminiService ?? GeminiService();
    _resumeSummaryService =
        widget.resumeSummaryService ?? const ResumeSummaryService();
    _storage = widget.storageService ?? StorageService.instance;
    _scrollController.addListener(_onScroll);
    _loadChapters();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _aiLoadingElapsedTimer?.cancel();
    _activeAiConversationSheetListenable.dispose();
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
      final bookId = widget.book.id;
      final chaptersFuture = _chapterLoader.loadChapters(widget.book);
      final savedStateFuture = bookId == null
          ? Future<_SavedReaderState>.value(const _SavedReaderState())
          : _loadSavedState(bookId);

      final chapters = await chaptersFuture;
      final savedState = await savedStateFuture;

      if (!mounted) return;

      if (bookId != null && chapters.length != widget.book.totalChapters) {
        unawaited(_db.updateBookTotalChapters(bookId, chapters.length));
      }

      final savedProgress = savedState.progress;
      final savedMarker = savedState.marker;
      final markerChapterIndex = savedMarker?.chapterIndex ?? -1;
      final markerChapterIsValid =
          markerChapterIndex >= 0 && markerChapterIndex < chapters.length;
      final progressChapterIndex = savedProgress?.chapterIndex ?? -1;
      final progressChapterIsValid =
          progressChapterIndex >= 0 && progressChapterIndex < chapters.length;
      final restoredFromMarker = markerChapterIsValid;

      final initialChapterIndex = markerChapterIsValid
          ? markerChapterIndex
          : (progressChapterIsValid ? progressChapterIndex : 0);
      final initialScrollOffset = markerChapterIsValid
          ? (savedMarker?.scrollOffset ?? 0.0)
          : (savedProgress?.scrollOffset ?? 0.0);

      if (mounted) {
        setState(() {
          _chapters = chapters;
          _highlights = savedState.highlights;
          _resumeMarker = savedMarker;
          _currentIndex = initialChapterIndex;
          _loading = false;
        });

        // Restore scroll offset after the frame renders.
        if (initialScrollOffset > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              final maxScroll = _scrollController.position.maxScrollExtent;
              _scrollController
                  .jumpTo(initialScrollOffset.clamp(0.0, maxScroll));
            }
          });
        }

        if (restoredFromMarker) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showAutoDismissSnackBar(
              const SnackBar(
                content: Text('Resumed from saved point'),
                duration: Duration(seconds: 2),
              ),
            );
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

  Future<_SavedReaderState> _loadSavedState(int bookId) async {
    final progressFuture = _db.getProgressByBookId(bookId);
    final markerFuture = _db.getResumeMarkerByBookId(bookId);
    final highlightsFuture = _db.getHighlightsByBookId(bookId);

    return _SavedReaderState(
      progress: await progressFuture,
      marker: await markerFuture,
      highlights: await highlightsFuture,
    );
  }

  // ── Chapter navigation ───────────────────────────────────────────────────

  void _toggleNavbar() {
    setState(() => _isNavbarVisible = !_isNavbarVisible);
  }

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

  bool get _hasPreviousChapter => _currentIndex > 0;

  bool get _hasNextChapter =>
      _chapters != null && _currentIndex < _chapters!.length - 1;

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

  // ── Resume Marker ────────────────────────────────────────────────────────

  Future<void> _saveResumeMarker({
    required String selectedText,
    required int selectionStart,
    required int selectionEnd,
  }) async {
    final bookId = widget.book.id;
    final chapter = _currentChapter;
    if (bookId == null || chapter == null) return;

    final rawSelectedText = selectedText;
    if (rawSelectedText.trim().isEmpty) return;

    if (selectionStart < 0 ||
        selectionEnd <= selectionStart ||
        selectionEnd > chapter.content.length) {
      return;
    }

    final marker = ResumeMarker(
      bookId: bookId,
      chapterIndex: _currentIndex,
      selectedText: rawSelectedText,
      selectionStart: selectionStart,
      selectionEnd: selectionEnd,
      scrollOffset:
          _scrollController.hasClients ? _scrollController.offset : 0.0,
      createdAt: DateTime.now(),
    );

    await _db.upsertResumeMarker(marker);
    if (!mounted) return;

    setState(() => _resumeMarker = marker);
    _showAutoDismissSnackBar(
      const SnackBar(
        content: Text('Resume point saved'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Shows a snackbar and guarantees auto-dismiss even when accessibility
  /// settings keep action snackbars visible indefinitely.
  void _showAutoDismissSnackBar(
    SnackBar snackBar, {
    Duration autoDismissAfter = const Duration(seconds: 2),
  }) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final token = ++_snackBarToken;
    messenger.showSnackBar(snackBar);

    Future<void>.delayed(autoDismissAfter, () {
      if (!mounted || token != _snackBarToken) return;
      messenger.hideCurrentSnackBar();
    });
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

    _showAutoDismissSnackBar(
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

  void _setReaderState(VoidCallback fn) {
    setState(fn);
  }

  // ── Build ────────────────────────────────────────────────────────────────

  Future<void> _setThemeMode(AppThemeMode mode) async {
    final settings = SettingsControllerScope.of(context);
    await settings.setThemeMode(mode);
  }

  IconData _themeModeIcon(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return Icons.brightness_auto;
      case AppThemeMode.light:
        return Icons.light_mode_outlined;
      case AppThemeMode.dark:
        return Icons.dark_mode_outlined;
      case AppThemeMode.night:
        return Icons.bedtime_outlined;
      case AppThemeMode.sepia:
        return Icons.auto_stories_outlined;
    }
  }

  String _themeModeLabel(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return 'System';
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
      case AppThemeMode.night:
        return 'Night';
      case AppThemeMode.sepia:
        return 'Sepia';
    }
  }

  double get _activeAiBottomInset {
    if (_activeAiRequest != null) {
      return _aiLoadingSheetReservedSpace;
    }

    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsControllerScope.of(context);
    final currentThemeMode = settings.themeMode;

    return Scaffold(
      appBar: _isNavbarVisible
          ? AppBar(
              title: Text(
                _currentChapter?.title ?? widget.book.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                if (_chapters != null && _chapters!.isNotEmpty) ...[
                  IconButton(
                    icon: const Icon(Icons.highlight_outlined),
                    tooltip: 'Highlights',
                    onPressed: _showHighlights,
                  ),
                  PopupMenuButton<AppThemeMode>(
                    tooltip: 'Theme',
                    initialValue: currentThemeMode,
                    onSelected: _setThemeMode,
                    itemBuilder: (context) {
                      return _readerThemeModes.map((mode) {
                        final isSelected = mode == currentThemeMode;
                        return PopupMenuItem<AppThemeMode>(
                          value: mode,
                          child: Row(
                            children: [
                              Icon(_themeModeIcon(mode), size: 20),
                              const SizedBox(width: 12),
                              Expanded(child: Text(_themeModeLabel(mode))),
                              if (isSelected) ...[
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.check,
                                  size: 18,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList();
                    },
                    icon: Icon(_themeModeIcon(currentThemeMode)),
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
                IconButton(
                  icon: const Icon(Icons.menu),
                  tooltip: 'Hide Navigation Bar',
                  onPressed: _toggleNavbar,
                ),
              ],
            )
          : null,
      body: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(
              top: !_isNavbarVisible,
              bottom: false,
              left: false,
              right: false,
              child: _buildBody(),
            ),
          ),
          if (_activeAiRequest != null &&
              _initialAiStreamPhase != _InitialAiStreamPhase.streaming)
            _AiLoadingSheet(
              loadingText: _activeAiRequest!.requestSpec.loadingText,
              elapsedSeconds: _activeAiElapsedSeconds,
              onCancel: _cancelActiveAiRequest,
            ),
          if (!_isNavbarVisible) _buildHiddenNavPill(),
        ],
      ),
    );
  }
}

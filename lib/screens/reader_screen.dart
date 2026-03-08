import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../models/ai_feature.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import '../models/generated_image.dart';
import '../models/highlight.dart';
import '../models/openrouter_model.dart';
import '../models/reading_progress.dart';
import '../models/resume_marker.dart';
import '../services/chapter_loader_service.dart';
import '../services/database_service.dart';
import '../services/openrouter_service.dart';
import '../services/resume_summary_service.dart';
import '../services/storage_service.dart';
import '../theme/reader_typography.dart';
import '../widgets/generated_image_viewer.dart';
import '../widgets/mobile_scrollbar.dart';
import '../widgets/reader_selection_toolbar.dart';

/// Displays the content of a [Book] with chapter-by-chapter navigation.
class ReaderScreen extends StatefulWidget {
  final Book book;
  final ChapterLoaderService? chapterLoader;
  final DatabaseService? databaseService;
  final OpenRouterService? openRouterService;
  final ResumeSummaryService? resumeSummaryService;
  final StorageService? storageService;

  const ReaderScreen({
    super.key,
    required this.book,
    this.chapterLoader,
    this.databaseService,
    this.openRouterService,
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

  /// Minimum horizontal velocity (px/s) to trigger a chapter swipe.
  static const _swipeVelocityThreshold = 300.0;

  /// Minimum horizontal distance (px) to trigger a chapter swipe.
  static const _swipeDistanceThreshold = 50.0;

  /// Tracks the starting X position of a horizontal drag.
  double _dragStartX = 0.0;

  /// Monotonic token used to avoid stale delayed snackbar dismissals.
  int _snackBarToken = 0;

  /// Monotonic token used to ignore stale AI completions.
  int _aiRequestToken = 0;

  _ActiveAiRequest? _activeAiRequest;

  static const double _aiLoadingSheetReservedSpace = 88.0;
  static const double _readerHorizontalPadding = 20.0;
  static const double _readerTopPadding = 16.0;
  static const double _readerBottomPadding = 32.0;
  static const double _hiddenNavPillHeight = 40.0;
  static const double _hiddenNavPillTopInset = 8.0;
  static const double _hiddenNavPillSideInset = 8.0;
  static const double _hiddenNavPillContentGap = 8.0;
  static const ValueKey<String> _hiddenNavPillKey =
      ValueKey<String>('reader-hidden-nav-pill');

  @override
  void initState() {
    super.initState();
    _chapterLoader = widget.chapterLoader ?? ChapterLoaderService.instance;
    _db = widget.databaseService ?? DatabaseService.instance;
    _openRouter = widget.openRouterService ?? OpenRouterService();
    _resumeSummaryService =
        widget.resumeSummaryService ?? const ResumeSummaryService();
    _storage = widget.storageService ?? StorageService.instance;
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

  Future<void> _summarizeFromResumePoint(
    EditableTextState editableTextState,
  ) async {
    await _runAiResumeRangeFeature(
      editableTextState: editableTextState,
      featureId: AiFeatureIds.resumeSummary,
    );
  }

  Future<void> _simplifyTextFromResumePoint(
    EditableTextState editableTextState,
  ) async {
    await _runAiResumeRangeFeature(
      editableTextState: editableTextState,
      featureId: AiFeatureIds.simplifyText,
    );
  }

  Future<void> _runAiResumeRangeFeature({
    required EditableTextState editableTextState,
    required String featureId,
  }) async {
    final chapter = _currentChapter;
    if (chapter == null) return;
    final featureSpec = _resumeRangeFeatureSpec(featureId);
    if (featureSpec == null) return;

    final selection = editableTextState.textEditingValue.selection;
    final text = editableTextState.textEditingValue.text;
    final summarySelection = _buildResumeSummarySelection(
      selection: selection,
      chapterContent: text,
      chapterTitle: chapter.title,
    );
    editableTextState.hideToolbar();

    if (summarySelection == null) {
      _showAutoDismissSnackBar(
        SnackBar(
          content: Text(
            featureSpec.invalidRangeMessage,
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final requestSpec = _buildResumeRangeRequestSpec(
      featureId: featureId,
      summarySelection: summarySelection,
    );
    if (requestSpec == null) return;

    await _startAiFeatureRequest(requestSpec);
  }

  _ResumeRangeAiFeatureSpec? _resumeRangeFeatureSpec(String featureId) {
    return switch (featureId) {
      AiFeatureIds.resumeSummary => const _ResumeRangeAiFeatureSpec(
          featureId: AiFeatureIds.resumeSummary,
          title: 'Summary',
          loadingText: 'Generating summary...',
          emptyMessage: 'Model returned an empty summary.',
          copiedMessage: 'Summary copied',
          invalidRangeMessage:
              'Unable to build a summary range for this selection.',
          invalidPromptMessage:
              'Catch-up prompt must include the {source_text} placeholder.',
          switchTargetFeatureId: AiFeatureIds.simplifyText,
          switchButtonLabel: 'Simplify Text',
        ),
      AiFeatureIds.simplifyText => const _ResumeRangeAiFeatureSpec(
          featureId: AiFeatureIds.simplifyText,
          title: 'Simplify Text',
          loadingText: 'Rewriting text...',
          emptyMessage: 'Model returned an empty rewrite.',
          copiedMessage: 'Rewrite copied',
          invalidRangeMessage:
              'Unable to build a text range for this selection.',
          invalidPromptMessage:
              'Simplify Text prompt must include the {source_text} placeholder.',
          switchTargetFeatureId: AiFeatureIds.resumeSummary,
          switchButtonLabel: 'Summary',
        ),
      _ => null,
    };
  }

  _AiRequestSpec? _buildResumeRangeRequestSpec({
    required String featureId,
    required _ResumeSummarySelection summarySelection,
  }) {
    final featureSpec = _resumeRangeFeatureSpec(featureId);
    if (featureSpec == null) return null;

    final settings = SettingsControllerScope.of(context);
    final apiKey = settings.openRouterApiKey.trim();
    if (apiKey.isEmpty) {
      _showAutoDismissSnackBar(
        const SnackBar(
          content: Text('Add your OpenRouter API key in Settings first.'),
          duration: Duration(seconds: 2),
        ),
      );
      return null;
    }

    final modelId = settings.effectiveModelIdForFeature(featureId);
    if (modelId.isEmpty) {
      _showAutoDismissSnackBar(
        const SnackBar(
          content: Text('Select a default AI model in Settings first.'),
          duration: Duration(seconds: 2),
        ),
      );
      return null;
    }

    final featureConfig = settings.aiFeatureConfig(featureId);
    final promptTemplate = featureConfig.promptTemplate;
    if (!_resumeSummaryService.hasRequiredPlaceholder(promptTemplate)) {
      _showAutoDismissSnackBar(
        SnackBar(
          content: Text(
            featureSpec.invalidPromptMessage,
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return null;
    }

    final prompt = _resumeSummaryService.renderPromptTemplate(
      promptTemplate: promptTemplate,
      sourceText: summarySelection.sourceText,
      bookTitle: widget.book.title,
      bookAuthor: widget.book.author,
      chapterTitle: summarySelection.chapterTitle,
    );
    return _AiRequestSpec(
      apiKey: apiKey,
      modelId: modelId,
      prompt: prompt,
      title: featureSpec.title,
      loadingText: featureSpec.loadingText,
      emptyMessage: featureSpec.emptyMessage,
      copiedMessage: featureSpec.copiedMessage,
      onSuccess: summarySelection.shouldUpdateResumeMarker
          ? () => _saveResumeMarker(
                selectedText: summarySelection.selectedText,
                selectionStart: summarySelection.selectionStart,
                selectionEnd: summarySelection.selectionEnd,
              )
          : null,
      featureId: featureSpec.featureId,
      resumeRangeSelection: summarySelection,
    );
  }

  Future<void> _defineAndTranslateSelection(
    EditableTextState editableTextState,
  ) async {
    final selection = editableTextState.textEditingValue.selection;
    final text = editableTextState.textEditingValue.text;
    editableTextState.hideToolbar();

    if (!selection.isValid || selection.isCollapsed) return;

    final boundedStart = selection.start.clamp(0, text.length);
    final boundedEnd = selection.end.clamp(0, text.length);
    if (boundedEnd <= boundedStart) return;

    final selectedText = text.substring(boundedStart, boundedEnd).trim();
    if (selectedText.isEmpty) return;
    final contextSentence = _resumeSummaryService.extractContextSentence(
      chapterContent: text,
      selectionStart: boundedStart,
      selectionEnd: boundedEnd,
    );

    final settings = SettingsControllerScope.of(context);
    final apiKey = settings.openRouterApiKey.trim();
    if (apiKey.isEmpty) {
      _showAutoDismissSnackBar(
        const SnackBar(
          content: Text('Add your OpenRouter API key in Settings first.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final modelId = settings.effectiveModelIdForFeature(
      AiFeatureIds.defineAndTranslate,
    );
    if (modelId.isEmpty) {
      _showAutoDismissSnackBar(
        const SnackBar(
          content: Text('Select a default AI model in Settings first.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final featureConfig = settings.aiFeatureConfig(
      AiFeatureIds.defineAndTranslate,
    );
    final promptTemplate = featureConfig.promptTemplate;
    if (!_resumeSummaryService.hasRequiredPlaceholder(promptTemplate)) {
      _showAutoDismissSnackBar(
        const SnackBar(
          content: Text(
            'Define & Translate prompt must include the {source_text} placeholder.',
          ),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final prompt = _resumeSummaryService.renderPromptTemplate(
      promptTemplate: promptTemplate,
      sourceText: selectedText,
      bookTitle: widget.book.title,
      bookAuthor: widget.book.author,
      chapterTitle: '',
      contextSentence: contextSentence,
    );
    await _startAiFeatureRequest(
      _AiRequestSpec(
        apiKey: apiKey,
        modelId: modelId,
        prompt: prompt,
        title: defineAndTranslateFeature.title,
        loadingText: 'Generating definition and translation...',
        emptyMessage: 'Model returned an empty definition or translation.',
        copiedMessage: 'Result copied',
      ),
    );
  }

  Future<void> _showGenerateImageModePicker(
    EditableTextState editableTextState,
  ) async {
    final choice = await showModalBottomSheet<_GenerateImageMode>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Generate Image',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose how the source text should be collected for the prompt.',
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.short_text),
                  title: const Text('Selected Text'),
                  subtitle: const Text(
                    'Use only the currently selected words or sentence.',
                  ),
                  onTap: () => Navigator.of(sheetContext).pop(
                    _GenerateImageMode.selectedText,
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.bookmark_outline),
                  title: const Text('Resume Range'),
                  subtitle: const Text(
                    'Use the range between the last resume point and this selection.',
                  ),
                  onTap: () => Navigator.of(sheetContext).pop(
                    _GenerateImageMode.resumeRange,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || choice == null) return;

    switch (choice) {
      case _GenerateImageMode.selectedText:
        await _generateImageFromSelectedText(editableTextState);
        break;
      case _GenerateImageMode.resumeRange:
        await _generateImageFromResumeRange(editableTextState);
        break;
    }
  }

  Future<void> _generateImageFromSelectedText(
    EditableTextState editableTextState,
  ) async {
    final chapter = _currentChapter;
    if (chapter == null) return;

    final selection = editableTextState.textEditingValue.selection;
    final text = editableTextState.textEditingValue.text;
    editableTextState.hideToolbar();

    final imageSelection = _buildSelectedTextGenerateImageSelection(
      selection: selection,
      chapterContent: text,
      chapterTitle: chapter.title,
    );
    if (imageSelection == null) {
      _showAutoDismissSnackBar(
        const SnackBar(
          content: Text('Select some text to generate an image.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    await _startGenerateImageFlow(imageSelection);
  }

  Future<void> _generateImageFromResumeRange(
    EditableTextState editableTextState,
  ) async {
    final chapter = _currentChapter;
    if (chapter == null) return;

    final selection = editableTextState.textEditingValue.selection;
    final text = editableTextState.textEditingValue.text;
    editableTextState.hideToolbar();

    final imageSelection = _buildResumeRangeGenerateImageSelection(
      selection: selection,
      chapterContent: text,
      chapterTitle: chapter.title,
    );
    if (imageSelection == null) {
      _showAutoDismissSnackBar(
        const SnackBar(
          content: Text('Unable to build an image range for this selection.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    await _startGenerateImageFlow(imageSelection);
  }

  _GenerateImageSelection? _buildSelectedTextGenerateImageSelection({
    required TextSelection selection,
    required String chapterContent,
    required String chapterTitle,
  }) {
    if (!selection.isValid || selection.isCollapsed) return null;

    final boundedStart = selection.start.clamp(0, chapterContent.length);
    final boundedEnd = selection.end.clamp(0, chapterContent.length);
    if (boundedEnd <= boundedStart) return null;

    final selectedText = chapterContent.substring(boundedStart, boundedEnd);
    final sourceText = selectedText.trim();
    if (sourceText.isEmpty) return null;

    return _GenerateImageSelection(
      featureMode: _GenerateImageFeatureModes.selectedText,
      sourceText: sourceText,
      chapterTitle: chapterTitle,
      contextSentence: _resumeSummaryService.extractContextSentence(
        chapterContent: chapterContent,
        selectionStart: boundedStart,
        selectionEnd: boundedEnd,
      ),
    );
  }

  _GenerateImageSelection? _buildResumeRangeGenerateImageSelection({
    required TextSelection selection,
    required String chapterContent,
    required String chapterTitle,
  }) {
    final summarySelection = _buildResumeSummarySelection(
      selection: selection,
      chapterContent: chapterContent,
      chapterTitle: chapterTitle,
    );
    if (summarySelection == null) return null;

    return _GenerateImageSelection(
      featureMode: _GenerateImageFeatureModes.resumeRange,
      sourceText: summarySelection.sourceText,
      chapterTitle: summarySelection.chapterTitle,
      contextSentence: '',
    );
  }

  _GenerateImagePromptRequest? _buildGenerateImagePromptRequest(
    _GenerateImageSelection selection,
  ) {
    final settings = SettingsControllerScope.of(context);
    final apiKey = settings.openRouterApiKey.trim();
    if (apiKey.isEmpty) {
      _showAutoDismissSnackBar(
        const SnackBar(
          content: Text('Add your OpenRouter API key in Settings first.'),
          duration: Duration(seconds: 2),
        ),
      );
      return null;
    }

    final promptModelId = settings.effectiveModelIdForFeature(
      AiFeatureIds.generateImage,
    );
    if (promptModelId.isEmpty) {
      _showAutoDismissSnackBar(
        const SnackBar(
          content: Text('Select a default AI model in Settings first.'),
          duration: Duration(seconds: 2),
        ),
      );
      return null;
    }

    final imageModelId = settings.openRouterImageModelId.trim();
    if (imageModelId.isEmpty) {
      _showAutoDismissSnackBar(
        const SnackBar(
          content: Text('Select an image AI model in Settings first.'),
          duration: Duration(seconds: 2),
        ),
      );
      return null;
    }

    final featureConfig = settings.aiFeatureConfig(AiFeatureIds.generateImage);
    final promptTemplate = featureConfig.promptTemplate;
    if (!_resumeSummaryService.hasRequiredPlaceholder(promptTemplate)) {
      _showAutoDismissSnackBar(
        const SnackBar(
          content: Text(
            'Generate Image prompt must include the {source_text} placeholder.',
          ),
          duration: Duration(seconds: 2),
        ),
      );
      return null;
    }

    final prompt = _resumeSummaryService.renderPromptTemplate(
      promptTemplate: promptTemplate,
      sourceText: selection.sourceText,
      bookTitle: widget.book.title,
      bookAuthor: widget.book.author,
      chapterTitle: selection.chapterTitle,
      contextSentence: selection.contextSentence,
    );

    return _GenerateImagePromptRequest(
      apiKey: apiKey,
      promptModelId: promptModelId,
      imageModelId: imageModelId,
      prompt: prompt,
      selection: selection,
    );
  }

  Future<void> _startGenerateImageFlow(
    _GenerateImageSelection selection,
  ) async {
    final request = _buildGenerateImagePromptRequest(selection);
    if (request == null) return;

    final promptModel = await _lookupOpenRouterModelMetadata(
      apiKey: request.apiKey,
      modelId: request.promptModelId,
      loadingText: 'Checking prompt model...',
    );
    if (!mounted) return;
    if (promptModel != null && _modelCannotGenerateText(promptModel)) {
      await _showAiBasicErrorSheet(
        title: 'Generate Image',
        message:
            'The selected prompt model does not support text output. Choose a text-capable model for Generate Image in Settings.',
      );
      return;
    }

    String generatedPrompt;
    try {
      final result = await _runAiLoadingTask<String>(
        loadingText: 'Generating image prompt...',
        task: () => _openRouter.generateText(
          apiKey: request.apiKey,
          modelId: request.promptModelId,
          prompt: request.prompt,
        ),
      );
      if (result == null) return;
      generatedPrompt = result.trim();
    } catch (error) {
      await _showAiBasicErrorSheet(
        title: 'Generate Image',
        message: error.toString(),
      );
      return;
    }

    if (generatedPrompt.isEmpty) {
      await _showAiBasicErrorSheet(
        title: 'Generate Image',
        message: 'Model returned an empty image prompt.',
      );
      return;
    }

    final editedPrompt = await _showImagePromptEditorSheet(
      initialPrompt: generatedPrompt,
    );
    if (!mounted || editedPrompt == null) return;

    final normalizedPrompt = editedPrompt.trim();
    if (normalizedPrompt.isEmpty) {
      _showAutoDismissSnackBar(
        const SnackBar(
          content: Text('Image prompt cannot be empty.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final imageModel = await _lookupOpenRouterModelMetadata(
      apiKey: request.apiKey,
      modelId: request.imageModelId,
      loadingText: 'Checking image model...',
    );
    if (!mounted) return;
    if (imageModel != null &&
        imageModel.hasOutputModalityMetadata &&
        !imageModel.supportsImageOutput) {
      await _showAiBasicErrorSheet(
        title: 'Generate Image',
        message:
            'The selected image model does not support image output. Choose another Image Model in Settings.',
      );
      return;
    }

    OpenRouterImageGenerationResult imageResult;
    try {
      final result = await _generateImageWithBestEffortModalities(
        apiKey: request.apiKey,
        modelId: request.imageModelId,
        prompt: normalizedPrompt,
        imageModel: imageModel,
      );
      if (result == null) return;
      imageResult = result;
    } catch (error) {
      await _showAiBasicErrorSheet(
        title: 'Generate Image',
        message: error.toString(),
      );
      return;
    }

    if (imageResult.imageUrls.isEmpty) {
      await _showAiBasicErrorSheet(
        title: 'Generate Image',
        message: 'OpenRouter did not return an image.',
      );
      return;
    }

    GeneratedImage savedImage;
    try {
      final persisted = await _persistGeneratedImage(
        selection: request.selection,
        promptText: normalizedPrompt,
        imageDataUrl: imageResult.imageUrls.first,
      );
      if (persisted == null) {
        await _showAiBasicErrorSheet(
          title: 'Generate Image',
          message:
              'This book must be saved in the library before images can be stored.',
        );
        return;
      }
      savedImage = persisted;
    } catch (error) {
      await _showAiBasicErrorSheet(
        title: 'Generate Image',
        message: error.toString(),
      );
      return;
    }

    if (!mounted) return;
    unawaited(
      _showGeneratedImageResultSheet(
        generatedImage: savedImage,
        assistantText: imageResult.assistantText,
      ),
    );
  }

  Future<OpenRouterModel?> _lookupOpenRouterModelMetadata({
    required String apiKey,
    required String modelId,
    required String loadingText,
  }) async {
    try {
      final models = await _runAiLoadingTask<List<OpenRouterModel>>(
        loadingText: loadingText,
        task: () => _openRouter.fetchModels(apiKey: apiKey),
      );
      if (models == null) return null;

      for (final model in models) {
        if (model.id == modelId) {
          return model;
        }
      }
    } catch (error) {
      // Some valid image models are not labeled consistently in the models
      // metadata, so a lookup failure should not block generation.
      return null;
    }

    return null;
  }

  bool _modelCannotGenerateText(OpenRouterModel model) {
    if (model.hasOutputModalityMetadata) {
      return !model.supportsTextOutput;
    }

    return _looksLikeImageOnlyModelId(model.id);
  }

  Future<OpenRouterImageGenerationResult?>
      _generateImageWithBestEffortModalities({
    required String apiKey,
    required String modelId,
    required String prompt,
    OpenRouterModel? imageModel,
  }) async {
    final attempts = <List<String>>[];
    final preferred = _preferredImageModalities(
      modelId: modelId,
      imageModel: imageModel,
    );
    attempts.add(preferred);

    if (imageModel == null || !imageModel.hasOutputModalityMetadata) {
      const imageOnlyModalities = <String>['image'];
      const imageAndTextModalities = <String>['image', 'text'];

      if (!_modalitiesEqual(preferred, imageOnlyModalities)) {
        attempts.add(imageOnlyModalities);
      }
      if (!_modalitiesEqual(preferred, imageAndTextModalities)) {
        attempts.add(imageAndTextModalities);
      }
    }

    Object? lastError;
    for (final modalities in attempts) {
      try {
        return await _runAiLoadingTask<OpenRouterImageGenerationResult>(
          loadingText: 'Generating image...',
          task: () => _openRouter.generateImage(
            apiKey: apiKey,
            modelId: modelId,
            prompt: prompt,
            modalities: modalities,
          ),
        );
      } catch (error) {
        lastError = error;
      }
    }

    if (lastError is Exception) throw lastError;
    if (lastError != null) throw OpenRouterException(lastError.toString());
    throw const OpenRouterException('OpenRouter did not return an image.');
  }

  List<String> _preferredImageModalities({
    required String modelId,
    OpenRouterModel? imageModel,
  }) {
    if (imageModel != null && imageModel.hasOutputModalityMetadata) {
      return imageModel.supportsTextOutput
          ? const <String>['image', 'text']
          : const <String>['image'];
    }

    return _looksLikeImageOnlyModelId(modelId)
        ? const <String>['image']
        : const <String>['image', 'text'];
  }

  bool _looksLikeImageOnlyModelId(String modelId) {
    final normalized = modelId.trim().toLowerCase();
    const imageOnlyMarkers = <String>[
      'flux',
      'recraft',
      'seedream',
      'riverflow',
      'ideogram',
      'sourceful',
      'imagen',
      'gpt-image',
      'black-forest-labs',
    ];
    for (final marker in imageOnlyMarkers) {
      if (normalized.contains(marker)) return true;
    }
    return false;
  }

  bool _modalitiesEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<GeneratedImage?> _persistGeneratedImage({
    required _GenerateImageSelection selection,
    required String promptText,
    required String imageDataUrl,
  }) async {
    final bookId = widget.book.id;
    if (bookId == null) return null;

    final savedFile = await _storage.saveGeneratedImageDataUrl(
      bookId: bookId,
      dataUrl: imageDataUrl,
    );
    try {
      return await _db.addGeneratedImage(
        GeneratedImage(
          bookId: bookId,
          chapterIndex: _currentIndex,
          featureMode: selection.featureMode,
          sourceText: selection.sourceText,
          promptText: promptText,
          filePath: savedFile.path,
          createdAt: DateTime.now(),
        ),
      );
    } catch (_) {
      await _storage.deleteGeneratedImageFile(savedFile.path);
      rethrow;
    }
  }

  Future<T?> _runAiLoadingTask<T>({
    required String loadingText,
    required Future<T> Function() task,
  }) async {
    if (!_canStartAiRequest()) return null;

    final loadingRequest = _ActiveAiRequest(
      token: ++_aiRequestToken,
      generationFuture: Future<String>.value(''),
      requestSpec: _AiRequestSpec(
        apiKey: '',
        modelId: '',
        prompt: '',
        title: '',
        loadingText: loadingText,
        emptyMessage: '',
        copiedMessage: '',
      ),
    );

    if (!mounted) return null;
    setState(() => _activeAiRequest = loadingRequest);

    try {
      final result = await task();
      if (!mounted || _activeAiRequest?.token != loadingRequest.token) {
        return null;
      }
      return result;
    } finally {
      if (mounted && _activeAiRequest?.token == loadingRequest.token) {
        setState(() => _activeAiRequest = null);
      }
    }
  }

  Future<String?> _showImagePromptEditorSheet({
    required String initialPrompt,
  }) async {
    final controller = TextEditingController(text: initialPrompt);
    final prompt = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit Image Prompt',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Review or edit the generated prompt before requesting the image.',
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLines: 10,
                  minLines: 6,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Image Prompt',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('Cancel'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(
                        controller.text,
                      ),
                      child: const Text('Generate'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    controller.dispose();
    return prompt;
  }

  Future<void> _showGeneratedImageResultSheet({
    required GeneratedImage generatedImage,
    required String assistantText,
  }) {
    return showModalBottomSheet<void>(
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
                  'Generated Image',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                GeneratedImageFileSizeText(
                  filePath: generatedImage.filePath,
                  style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                        color:
                            Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: MobileScrollbar(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ZoomableGeneratedImagePreview(
                            key: const ValueKey<String>(
                              'reader-generated-image-preview',
                            ),
                            filePath: generatedImage.filePath,
                            fit: BoxFit.contain,
                            height: 320,
                            borderRadius: BorderRadius.circular(18),
                            imageKey: const ValueKey<String>(
                              'generated-image-result',
                            ),
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
                          if (assistantText.trim().isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Notes',
                              style:
                                  Theme.of(sheetContext).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 6),
                            SelectableText(assistantText.trim()),
                          ],
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
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: generatedImage.promptText),
                          );
                          if (!sheetContext.mounted) return;
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            const SnackBar(
                              content: Text('Prompt copied'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_outlined),
                        label: const Text('Copy Prompt'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: const Text('Close'),
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

  Future<void> _showAiBasicErrorSheet({
    required String title,
    required String message,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: _AiBasicError(
              title: title,
              message: message,
              onClose: () => Navigator.of(sheetContext).pop(),
            ),
          ),
        );
      },
    );
  }

  Future<void> _startAiFeatureRequest(_AiRequestSpec requestSpec) async {
    if (!_canStartAiRequest()) return;

    final generationFuture = _openRouter.generateText(
      apiKey: requestSpec.apiKey,
      modelId: requestSpec.modelId,
      prompt: requestSpec.prompt,
    );
    final onSuccess = requestSpec.onSuccess;
    if (onSuccess != null) {
      unawaited(
        () async {
          try {
            await generationFuture;
            await onSuccess();
          } catch (_) {
            // Ignore generation and follow-up errors in background persistence.
          }
        }(),
      );
    }

    await _startAiResultFlow(
      generationFuture: generationFuture,
      requestSpec: requestSpec,
    );
  }

  Future<void> _regenerateAiRequestWithFallback(
      _AiRequestSpec requestSpec) async {
    final settings = SettingsControllerScope.of(context);
    final fallbackModelId = settings.openRouterFallbackModelId.trim();
    if (fallbackModelId.isEmpty) {
      _showAutoDismissSnackBar(
        const SnackBar(
          content: Text('Select a fallback AI model in Settings first.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    await _startAiFeatureRequest(
      requestSpec.copyWith(modelId: fallbackModelId),
    );
  }

  _ResumeSummarySelection? _buildResumeSummarySelection({
    required TextSelection selection,
    required String chapterContent,
    required String chapterTitle,
  }) {
    if (!selection.isValid || selection.isCollapsed) return null;

    final boundedStart = selection.start.clamp(0, chapterContent.length);
    final boundedEnd = selection.end.clamp(0, chapterContent.length);
    if (boundedEnd <= boundedStart) return null;

    final selectedText = chapterContent.substring(boundedStart, boundedEnd);
    if (selectedText.trim().isEmpty) return null;

    final range = _resumeSummaryService.computeRange(
      chapterContent: chapterContent,
      currentChapterIndex: _currentIndex,
      selectionStart: boundedStart,
      selectionEnd: boundedEnd,
      previousMarker: _resumeMarker,
    );
    if (range == null) return null;

    return _ResumeSummarySelection(
      sourceText: range.sourceText,
      chapterTitle: chapterTitle,
      selectedText: selectedText,
      selectionStart: boundedStart,
      selectionEnd: boundedEnd,
      shouldUpdateResumeMarker: range.shouldUpdateResumeMarker,
    );
  }

  Future<void> _startAiResultFlow({
    required Future<String> generationFuture,
    required _AiRequestSpec requestSpec,
  }) async {
    if (!_canStartAiRequest()) return;

    final request = _ActiveAiRequest(
      token: ++_aiRequestToken,
      generationFuture: generationFuture,
      requestSpec: requestSpec,
    );

    if (!mounted) return;
    setState(() => _activeAiRequest = request);
    unawaited(_completeAiResultFlow(request));
  }

  bool _canStartAiRequest() {
    if (_activeAiRequest == null) return true;

    _showAutoDismissSnackBar(
      const SnackBar(
        content: Text('An AI response is already loading.'),
        duration: Duration(seconds: 2),
      ),
    );
    return false;
  }

  Future<void> _completeAiResultFlow(_ActiveAiRequest request) async {
    Object? error;
    String? result;

    try {
      result = await request.generationFuture;
    } catch (caughtError) {
      error = caughtError;
    }

    if (!mounted || _activeAiRequest?.token != request.token) {
      return;
    }

    setState(() => _activeAiRequest = null);

    if (!mounted) return;

    final action = await _showAiCompletedResultSheet(
      title: request.requestSpec.title,
      emptyMessage: request.requestSpec.emptyMessage,
      copiedMessage: request.requestSpec.copiedMessage,
      switchFeatureLabel: _switchFeatureLabelForRequest(request.requestSpec),
      result: result,
      error: error,
    );
    if (!mounted) return;
    if (action == _AiResultSheetAction.regenerateWithFallback) {
      await _regenerateAiRequestWithFallback(request.requestSpec);
    } else if (action == _AiResultSheetAction.switchFeature) {
      await _switchResumeRangeFeature(request.requestSpec);
    }
  }

  String? _switchFeatureLabelForRequest(_AiRequestSpec requestSpec) {
    final featureId = requestSpec.featureId;
    if (featureId == null || requestSpec.resumeRangeSelection == null) {
      return null;
    }

    return _resumeRangeFeatureSpec(featureId)?.switchButtonLabel;
  }

  Future<void> _switchResumeRangeFeature(_AiRequestSpec requestSpec) async {
    final featureId = requestSpec.featureId;
    final summarySelection = requestSpec.resumeRangeSelection;
    if (featureId == null || summarySelection == null) return;

    final featureSpec = _resumeRangeFeatureSpec(featureId);
    if (featureSpec == null) return;

    final switchedRequestSpec = _buildResumeRangeRequestSpec(
      featureId: featureSpec.switchTargetFeatureId,
      summarySelection: summarySelection,
    );
    if (switchedRequestSpec == null) return;

    await _startAiFeatureRequest(switchedRequestSpec);
  }

  Future<_AiResultSheetAction?> _showAiCompletedResultSheet({
    required String title,
    required String emptyMessage,
    required String copiedMessage,
    String? switchFeatureLabel,
    String? result,
    Object? error,
  }) async {
    final settings = SettingsControllerScope.of(context);
    final resultTextStyle = buildReaderContentTextStyle(
      context: context,
      fontSize: settings.fontSize,
      fontFamily: settings.fontFamily,
    );

    return showModalBottomSheet<_AiResultSheetAction>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        void regenerateWithFallback() {
          final fallbackModelId =
              SettingsControllerScope.of(context).openRouterFallbackModelId;
          if (fallbackModelId.trim().isEmpty) {
            _showAutoDismissSnackBar(
              const SnackBar(
                content: Text('Select a fallback AI model in Settings first.'),
                duration: Duration(seconds: 2),
              ),
            );
            return;
          }

          Navigator.of(sheetContext).pop(
            _AiResultSheetAction.regenerateWithFallback,
          );
        }

        return FractionallySizedBox(
          heightFactor: 0.7,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: _buildAiResultSheetBody(
              sheetContext: sheetContext,
              title: title,
              emptyMessage: emptyMessage,
              copiedMessage: copiedMessage,
              onSwitchFeature: switchFeatureLabel == null
                  ? null
                  : () => Navigator.of(sheetContext).pop(
                        _AiResultSheetAction.switchFeature,
                      ),
              resultTextStyle: resultTextStyle,
              onRegenerateWithFallback: regenerateWithFallback,
              switchFeatureLabel: switchFeatureLabel,
              result: result,
              error: error,
            ),
          ),
        );
      },
    );
  }

  Widget _buildAiResultSheetBody({
    required BuildContext sheetContext,
    required String title,
    required String emptyMessage,
    required String copiedMessage,
    required TextStyle resultTextStyle,
    required VoidCallback onRegenerateWithFallback,
    required String? switchFeatureLabel,
    VoidCallback? onSwitchFeature,
    String? result,
    Object? error,
  }) {
    final trimmedResult = (result ?? '').trim();

    if (error != null) {
      return _AiResultError(
        title: title,
        message: error.toString(),
        onClose: () => Navigator.of(sheetContext).pop(),
        onRegenerateWithFallback: onRegenerateWithFallback,
      );
    }

    if (trimmedResult.isEmpty) {
      return _AiResultError(
        title: title,
        message: emptyMessage,
        onClose: () => Navigator.of(sheetContext).pop(),
        onRegenerateWithFallback: onRegenerateWithFallback,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: MobileScrollbar(
            child: SingleChildScrollView(
              child: SelectableText(
                trimmedResult,
                textAlign: TextAlign.justify,
                style: resultTextStyle,
                contextMenuBuilder: (context, editableTextState) {
                  return _buildDefaultSelectionToolbar(
                    context,
                    editableTextState,
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              IconButton(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: trimmedResult),
                  );
                  if (!sheetContext.mounted) return;
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    SnackBar(
                      content: Text(copiedMessage),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                tooltip: 'Copy',
                icon: const Icon(Icons.copy_outlined),
              ),
              IconButton(
                onPressed: onRegenerateWithFallback,
                tooltip: 'Regenerate with Fallback',
                icon: const Icon(Icons.refresh),
              ),
              if (onSwitchFeature != null && switchFeatureLabel != null)
                IconButton(
                  onPressed: onSwitchFeature,
                  tooltip: switchFeatureLabel,
                  icon: const Icon(Icons.swap_horiz),
                ),
            ],
          ),
        ),
      ],
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

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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
          if (_activeAiRequest != null)
            _AiLoadingSheet(
              loadingText: _activeAiRequest!.requestSpec.loadingText,
            ),
          if (!_isNavbarVisible) _buildHiddenNavPill(),
        ],
      ),
    );
  }

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
            top: _hiddenNavPillTopInset,
            right: _hiddenNavPillSideInset,
          ),
          child: Material(
            key: _hiddenNavPillKey,
            elevation: 2,
            color: theme.colorScheme.surface.withAlpha(228),
            shadowColor: Colors.black.withOpacity(0.1),
            shape: const StadiumBorder(),
            child: SizedBox(
              height: _hiddenNavPillHeight,
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
    final topPadding = _readerTopPadding +
        (_isNavbarVisible
            ? 0
            : _hiddenNavPillHeight + _hiddenNavPillContentGap);

    // Collect highlight texts for the current chapter to display inline
    // highlighting. Build a set for quick lookups.
    final currentHighlights =
        _highlights.where((h) => h.chapterIndex == _currentIndex).toList();
    final currentResumeMarker =
        _resumeMarker != null && _resumeMarker!.chapterIndex == _currentIndex
            ? _resumeMarker
            : null;

    return GestureDetector(
      onHorizontalDragStart: _onHorizontalDragStart,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      behavior: HitTestBehavior.translucent,
      child: MobileScrollbar(
        controller: _scrollController,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: EdgeInsets.fromLTRB(
            _readerHorizontalPadding,
            topPadding,
            _readerHorizontalPadding,
            _readerBottomPadding +
                (_activeAiRequest == null ? 0 : _aiLoadingSheetReservedSpace),
          ),
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
            ],
          ),
        ),
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
            _defaultHighlightColorHex.replaceFirst('#', ''),
            radix: 16,
          ) |
          0xFF000000,
    ).withAlpha(100);

    final resumeColor = _resumeMarkerColor.withAlpha(140);

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

  List<ContextMenuButtonItem> _filteredSelectionItems(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    final isAndroid = Theme.of(context).platform == TargetPlatform.android;
    return editableTextState.contextMenuButtonItems.where((item) {
      if (!isAndroid) return true;
      return item.type == ContextMenuButtonType.copy ||
          item.type == ContextMenuButtonType.selectAll;
    }).toList();
  }

  Widget _buildDefaultSelectionToolbar(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: _filteredSelectionItems(context, editableTextState),
    );
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

class _SavedReaderState {
  const _SavedReaderState({
    this.progress,
    this.marker,
    this.highlights = const [],
  });

  final ReadingProgress? progress;
  final ResumeMarker? marker;
  final List<Highlight> highlights;
}

class _StyledRange {
  final int start;
  final int end;
  final TextStyle style;
  final int priority;

  const _StyledRange({
    required this.start,
    required this.end,
    required this.style,
    required this.priority,
  });
}

class _ResumeSummarySelection {
  final String sourceText;
  final String chapterTitle;
  final String selectedText;
  final int selectionStart;
  final int selectionEnd;
  final bool shouldUpdateResumeMarker;

  const _ResumeSummarySelection({
    required this.sourceText,
    required this.chapterTitle,
    required this.selectedText,
    required this.selectionStart,
    required this.selectionEnd,
    required this.shouldUpdateResumeMarker,
  });
}

enum _GenerateImageMode {
  selectedText,
  resumeRange,
}

class _GenerateImageFeatureModes {
  static const selectedText = 'selected_text';
  static const resumeRange = 'resume_range';
}

class _GenerateImageSelection {
  final String featureMode;
  final String sourceText;
  final String chapterTitle;
  final String contextSentence;

  const _GenerateImageSelection({
    required this.featureMode,
    required this.sourceText,
    required this.chapterTitle,
    required this.contextSentence,
  });
}

class _GenerateImagePromptRequest {
  final String apiKey;
  final String promptModelId;
  final String imageModelId;
  final String prompt;
  final _GenerateImageSelection selection;

  const _GenerateImagePromptRequest({
    required this.apiKey,
    required this.promptModelId,
    required this.imageModelId,
    required this.prompt,
    required this.selection,
  });
}

class _ResumeRangeAiFeatureSpec {
  final String featureId;
  final String title;
  final String loadingText;
  final String emptyMessage;
  final String copiedMessage;
  final String invalidRangeMessage;
  final String invalidPromptMessage;
  final String switchTargetFeatureId;
  final String switchButtonLabel;

  const _ResumeRangeAiFeatureSpec({
    required this.featureId,
    required this.title,
    required this.loadingText,
    required this.emptyMessage,
    required this.copiedMessage,
    required this.invalidRangeMessage,
    required this.invalidPromptMessage,
    required this.switchTargetFeatureId,
    required this.switchButtonLabel,
  });
}

class _ActiveAiRequest {
  final int token;
  final Future<String> generationFuture;
  final _AiRequestSpec requestSpec;

  const _ActiveAiRequest({
    required this.token,
    required this.generationFuture,
    required this.requestSpec,
  });
}

class _AiRequestSpec {
  final String apiKey;
  final String modelId;
  final String prompt;
  final String title;
  final String loadingText;
  final String emptyMessage;
  final String copiedMessage;
  final String? featureId;
  final _ResumeSummarySelection? resumeRangeSelection;
  final Future<void> Function()? onSuccess;

  const _AiRequestSpec({
    required this.apiKey,
    required this.modelId,
    required this.prompt,
    required this.title,
    required this.loadingText,
    required this.emptyMessage,
    required this.copiedMessage,
    this.featureId,
    this.resumeRangeSelection,
    this.onSuccess,
  });

  _AiRequestSpec copyWith({
    String? apiKey,
    String? modelId,
    String? prompt,
    String? title,
    String? loadingText,
    String? emptyMessage,
    String? copiedMessage,
    String? featureId,
    _ResumeSummarySelection? resumeRangeSelection,
    Future<void> Function()? onSuccess,
  }) {
    return _AiRequestSpec(
      apiKey: apiKey ?? this.apiKey,
      modelId: modelId ?? this.modelId,
      prompt: prompt ?? this.prompt,
      title: title ?? this.title,
      loadingText: loadingText ?? this.loadingText,
      emptyMessage: emptyMessage ?? this.emptyMessage,
      copiedMessage: copiedMessage ?? this.copiedMessage,
      featureId: featureId ?? this.featureId,
      resumeRangeSelection: resumeRangeSelection ?? this.resumeRangeSelection,
      onSuccess: onSuccess ?? this.onSuccess,
    );
  }
}

enum _AiResultSheetAction {
  regenerateWithFallback,
  switchFeature,
}

class _AiLoadingSheet extends StatelessWidget {
  static const ValueKey<String> containerKey =
      ValueKey<String>('reader-ai-loading-sheet');
  static const ValueKey<String> progressKey =
      ValueKey<String>('reader-ai-loading-progress');

  final String loadingText;

  const _AiLoadingSheet({required this.loadingText});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Material(
            key: containerKey,
            elevation: 6,
            color: theme.colorScheme.surface,
            shadowColor: Colors.black.withOpacity(0.12),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loadingText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(
                    key: progressKey,
                    minHeight: 3,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AiResultError extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onClose;
  final VoidCallback onRegenerateWithFallback;

  const _AiResultError({
    required this.title,
    required this.message,
    required this.onClose,
    required this.onRegenerateWithFallback,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: onRegenerateWithFallback,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Regenerate with Fallback'),
                ),
                FilledButton(
                  onPressed: onClose,
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AiBasicError extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onClose;

  const _AiBasicError({
    required this.title,
    required this.message,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onClose,
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

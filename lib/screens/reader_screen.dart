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

  Future<void> _summarizeFromResumePoint(
    EditableTextState editableTextState,
  ) async {
    await _showTextAiSourceModePicker(
      editableTextState: editableTextState,
      featureId: AiFeatureIds.resumeSummary,
    );
  }

  Future<void> _simplifyTextFromResumePoint(
    EditableTextState editableTextState,
  ) async {
    await _showTextAiSourceModePicker(
      editableTextState: editableTextState,
      featureId: AiFeatureIds.simplifyText,
    );
  }

  Future<void> _askAiAboutSelection(
    EditableTextState editableTextState,
  ) async {
    await _showTextAiSourceModePicker(
      editableTextState: editableTextState,
      featureId: AiFeatureIds.askAi,
    );
  }

  Future<void> _showTextAiSourceModePicker({
    required EditableTextState editableTextState,
    required String featureId,
  }) async {
    final featureSpec = _textAiFeatureSpec(featureId);
    if (featureSpec == null) return;

    final choice = await _showAiSourceModePicker(
      title: featureSpec.title,
      description:
          'Choose how the source text should be collected for this request.',
      includeChapterStartToSelection: featureId == AiFeatureIds.resumeSummary,
    );
    if (!mounted || choice == null) return;

    switch (choice) {
      case _AiSourceMode.selectedText:
        await _runAiSelectedTextFeature(
          editableTextState: editableTextState,
          featureId: featureId,
        );
        break;
      case _AiSourceMode.resumeRange:
        await _runAiResumeRangeFeature(
          editableTextState: editableTextState,
          featureId: featureId,
        );
        break;
      case _AiSourceMode.chapterStartToSelection:
        await _runAiChapterStartToSelectionFeature(
          editableTextState: editableTextState,
          featureId: featureId,
        );
        break;
      case _AiSourceMode.wholeChapter:
        return;
    }
  }

  Future<void> _runAiSelectedTextFeature({
    required EditableTextState editableTextState,
    required String featureId,
  }) async {
    final chapter = _currentChapter;
    if (chapter == null) return;
    final featureSpec = _textAiFeatureSpec(featureId);
    if (featureSpec == null) return;

    final selection = editableTextState.textEditingValue.selection;
    final text = editableTextState.textEditingValue.text;
    final textFeatureSelection = _buildSelectedTextAiSelection(
      selection: selection,
      chapterContent: text,
      chapterTitle: chapter.title,
    );
    editableTextState.hideToolbar();

    if (textFeatureSelection == null) {
      _showAutoDismissSnackBar(
        SnackBar(
          content: Text(featureSpec.invalidSelectedTextMessage),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final initialUserMessage = await _resolveInitialUserMessage(featureSpec);
    if (!mounted || initialUserMessage == null) return;

    final requestSpec = _buildTextFeatureRequestSpec(
      featureId: featureId,
      textFeatureSelection: textFeatureSelection,
      initialUserMessage: initialUserMessage,
    );
    if (requestSpec == null) return;

    await _startAiFeatureRequest(requestSpec);
  }

  Future<void> _runAiResumeRangeFeature({
    required EditableTextState editableTextState,
    required String featureId,
  }) async {
    final chapter = _currentChapter;
    if (chapter == null) return;
    final featureSpec = _textAiFeatureSpec(featureId);
    if (featureSpec == null) return;

    final selection = editableTextState.textEditingValue.selection;
    final text = editableTextState.textEditingValue.text;
    final textFeatureSelection = _buildResumeRangeAiSelection(
      selection: selection,
      chapterContent: text,
      chapterTitle: chapter.title,
    );
    editableTextState.hideToolbar();

    if (textFeatureSelection == null) {
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

    final initialUserMessage = await _resolveInitialUserMessage(featureSpec);
    if (!mounted || initialUserMessage == null) return;

    final requestSpec = _buildTextFeatureRequestSpec(
      featureId: featureId,
      textFeatureSelection: textFeatureSelection,
      initialUserMessage: initialUserMessage,
    );
    if (requestSpec == null) return;

    await _startAiFeatureRequest(requestSpec);
  }

  Future<void> _runAiChapterStartToSelectionFeature({
    required EditableTextState editableTextState,
    required String featureId,
  }) async {
    final chapter = _currentChapter;
    if (chapter == null) return;
    final featureSpec = _textAiFeatureSpec(featureId);
    if (featureSpec == null) return;

    final selection = editableTextState.textEditingValue.selection;
    final text = editableTextState.textEditingValue.text;
    final textFeatureSelection = _buildChapterStartToSelectionAiSelection(
      selection: selection,
      chapterContent: text,
      chapterTitle: chapter.title,
    );
    editableTextState.hideToolbar();

    if (textFeatureSelection == null) {
      _showAutoDismissSnackBar(
        SnackBar(
          content: Text(featureSpec.invalidSelectedTextMessage),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final initialUserMessage = await _resolveInitialUserMessage(featureSpec);
    if (!mounted || initialUserMessage == null) return;

    final requestSpec = _buildTextFeatureRequestSpec(
      featureId: featureId,
      textFeatureSelection: textFeatureSelection,
      initialUserMessage: initialUserMessage,
    );
    if (requestSpec == null) return;

    await _startAiFeatureRequest(requestSpec);
  }

  Future<void> _summarizeCurrentChapter() async {
    final chapter = _currentChapter;
    if (chapter == null) return;

    final textFeatureSelection = _buildWholeChapterAiSelection(
      chapterContent: chapter.content,
      chapterTitle: chapter.title,
    );
    if (textFeatureSelection == null) {
      _showAutoDismissSnackBar(
        const SnackBar(
          content: Text('This chapter has no text to summarize.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final requestSpec = _buildTextFeatureRequestSpec(
      featureId: AiFeatureIds.resumeSummary,
      textFeatureSelection: textFeatureSelection,
    );
    if (requestSpec == null) return;

    await _startAiFeatureRequest(requestSpec);
  }

  _TextAiFeatureSpec? _textAiFeatureSpec(String featureId) {
    return switch (featureId) {
      AiFeatureIds.resumeSummary => const _TextAiFeatureSpec(
          featureId: AiFeatureIds.resumeSummary,
          title: 'Summary',
          loadingText: 'Generating summary...',
          emptyMessage: 'Model returned an empty summary.',
          copiedMessage: 'Summary copied',
          invalidSelectedTextMessage: 'Select some text to summarize.',
          invalidRangeMessage:
              'Unable to build a summary range for this selection.',
          invalidPromptMessage:
              'Catch-up prompt must include the {source_text} placeholder.',
          requiredPromptPlaceholders: <String>[sourceTextPlaceholder],
          followUpHintText: 'Ask a follow-up question',
          switchTargetFeatureId: AiFeatureIds.simplifyText,
          switchButtonLabel: 'Simplify Text',
        ),
      AiFeatureIds.simplifyText => const _TextAiFeatureSpec(
          featureId: AiFeatureIds.simplifyText,
          title: 'Simplify Text',
          loadingText: 'Rewriting text...',
          emptyMessage: 'Model returned an empty rewrite.',
          copiedMessage: 'Rewrite copied',
          invalidSelectedTextMessage: 'Select some text to simplify.',
          invalidRangeMessage:
              'Unable to build a text range for this selection.',
          invalidPromptMessage:
              'Simplify Text prompt must include the {source_text} placeholder.',
          requiredPromptPlaceholders: <String>[sourceTextPlaceholder],
          followUpHintText: 'Ask a follow-up question',
          switchTargetFeatureId: AiFeatureIds.resumeSummary,
          switchButtonLabel: 'Summary',
        ),
      AiFeatureIds.askAi => const _TextAiFeatureSpec(
          featureId: AiFeatureIds.askAi,
          title: 'Ask AI',
          loadingText: 'Asking AI...',
          emptyMessage: 'Model returned an empty answer.',
          copiedMessage: 'Answer copied',
          invalidSelectedTextMessage: 'Select some text to ask about.',
          invalidRangeMessage:
              'Unable to build a question range for this selection.',
          invalidPromptMessage:
              'Ask AI prompt must include the {book_title}, {book_author}, {chapter_title}, {source_text}, and {user_message} placeholders.',
          requiredPromptPlaceholders: <String>[
            bookTitlePlaceholder,
            bookAuthorPlaceholder,
            chapterTitlePlaceholder,
            sourceTextPlaceholder,
            userMessagePlaceholder,
          ],
          followUpHintText: 'Ask another question',
          initialQuestionHintText:
              'What do you want to ask about this passage?',
          initialQuestionPresets: <String>[
            'What is this?',
            'Who is this?',
          ],
        ),
      _ => null,
    };
  }

  _AiRequestSpec? _buildTextFeatureRequestSpec({
    required String featureId,
    required _TextAiSelection textFeatureSelection,
    String initialUserMessage = '',
  }) {
    final featureSpec = _textAiFeatureSpec(featureId);
    if (featureSpec == null) return null;

    final settings = SettingsControllerScope.of(context);
    final modelSelection =
        settings.effectiveModelSelectionForFeature(featureId);
    if (!modelSelection.isConfigured) {
      _showAutoDismissSnackBar(
        const SnackBar(
          content: Text('Select a default AI model in Settings first.'),
          duration: Duration(seconds: 2),
        ),
      );
      return null;
    }
    if (!_ensureApiKeyConfigured(
      settings: settings,
      selection: modelSelection,
    )) {
      return null;
    }

    final featureConfig = settings.aiFeatureConfig(featureId);
    final promptTemplate = featureConfig.promptTemplate;
    if (!_resumeSummaryService.hasRequiredPlaceholders(
      promptTemplate,
      featureSpec.requiredPromptPlaceholders,
    )) {
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
      sourceText: textFeatureSelection.sourceText,
      bookTitle: widget.book.title,
      bookAuthor: widget.book.author,
      chapterTitle: textFeatureSelection.chapterTitle,
      userMessage: initialUserMessage,
    );
    return _AiRequestSpec(
      modelSelection: modelSelection,
      prompt: prompt,
      title: featureSpec.title,
      loadingText: featureSpec.loadingText,
      emptyMessage: featureSpec.emptyMessage,
      copiedMessage: featureSpec.copiedMessage,
      followUpHintText: featureSpec.followUpHintText,
      initialConversationMessages: initialUserMessage.trim().isEmpty
          ? null
          : <_AiConversationMessage>[
              _AiConversationMessage.hiddenUser(prompt),
              _AiConversationMessage.displayOnlyUser(initialUserMessage.trim()),
            ],
      onSuccess: textFeatureSelection.shouldUpdateResumeMarker
          ? () => _saveResumeMarker(
                selectedText: textFeatureSelection.selectedText,
                selectionStart: textFeatureSelection.selectionStart,
                selectionEnd: textFeatureSelection.selectionEnd,
              )
          : null,
      featureId: featureSpec.featureId,
      textFeatureSelection: textFeatureSelection,
    );
  }

  Future<String?> _resolveInitialUserMessage(
    _TextAiFeatureSpec featureSpec,
  ) async {
    final hintText = featureSpec.initialQuestionHintText;
    if (hintText == null) return '';

    return _showAiQuestionComposerSheet(
      title: featureSpec.title,
      description:
          'Ask a question about the selected text or the chosen resume range.',
      hintText: hintText,
      presetQuestions: featureSpec.initialQuestionPresets,
    );
  }

  Future<String?> _showAiQuestionComposerSheet({
    required String title,
    required String description,
    required String hintText,
    List<String> presetQuestions = const <String>[],
  }) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return _AiQuestionComposerSheet(
          title: title,
          description: description,
          hintText: hintText,
          presetQuestions: presetQuestions,
        );
      },
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
    final modelSelection = settings.effectiveModelSelectionForFeature(
      AiFeatureIds.defineAndTranslate,
    );
    if (!modelSelection.isConfigured) {
      _showAutoDismissSnackBar(
        const SnackBar(
          content: Text('Select a default AI model in Settings first.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    if (!_ensureApiKeyConfigured(
      settings: settings,
      selection: modelSelection,
    )) {
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
        modelSelection: modelSelection,
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
    final choice = await _showAiSourceModePicker(
      title: 'Generate Image',
      description:
          'Choose how the source text should be collected for the prompt.',
    );
    if (!mounted || choice == null) return;

    switch (choice) {
      case _AiSourceMode.selectedText:
        await _generateImageFromSelectedText(editableTextState);
        break;
      case _AiSourceMode.resumeRange:
        await _generateImageFromResumeRange(editableTextState);
        break;
      case _AiSourceMode.chapterStartToSelection:
      case _AiSourceMode.wholeChapter:
        return;
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
    final summarySelection = _buildResumeRangeAiSelection(
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
    final promptModelSelection = settings.effectiveModelSelectionForFeature(
      AiFeatureIds.generateImage,
    );
    if (!promptModelSelection.isConfigured) {
      _showAutoDismissSnackBar(
        const SnackBar(
          content: Text('Select a default AI model in Settings first.'),
          duration: Duration(seconds: 2),
        ),
      );
      return null;
    }
    if (!_ensureApiKeyConfigured(
      settings: settings,
      selection: promptModelSelection,
    )) {
      return null;
    }

    final imageModelSelection = settings.imageModelSelection;
    if (!imageModelSelection.isConfigured) {
      _showAutoDismissSnackBar(
        const SnackBar(
          content: Text('Select an image AI model in Settings first.'),
          duration: Duration(seconds: 2),
        ),
      );
      return null;
    }
    if (!_ensureApiKeyConfigured(
      settings: settings,
      selection: imageModelSelection,
    )) {
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
      promptModelSelection: promptModelSelection,
      imageModelSelection: imageModelSelection,
      prompt: prompt,
      selection: selection,
    );
  }

  Future<void> _startGenerateImageFlow(
    _GenerateImageSelection selection,
  ) async {
    final request = _buildGenerateImagePromptRequest(selection);
    if (request == null) return;

    final promptModel = await _lookupModelMetadata(
      selection: request.promptModelSelection,
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
        task: () => _generateTextForSelection(
          selection: request.promptModelSelection,
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

    final latestPrompt = await _showGeneratedPromptConversationSheet(
      request: request,
      generatedPrompt: generatedPrompt,
    );
    if (!mounted || latestPrompt == null) return;

    final editedImageDraft = await _showImagePromptEditorSheet(
      initialPrompt: latestPrompt,
    );
    if (!mounted || editedImageDraft == null) return;

    final normalizedPrompt = editedImageDraft.promptText.trim();
    if (normalizedPrompt.isEmpty) {
      _showAutoDismissSnackBar(
        const SnackBar(
          content: Text('Image prompt cannot be empty.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    final normalizedName = _normalizeGeneratedImageName(
      editedImageDraft.name,
    );

    final imageModel = await _lookupModelMetadata(
      selection: request.imageModelSelection,
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

    _AiImageGenerationResult imageResult;
    try {
      final result = await _generateImageForSelection(
        selection: request.imageModelSelection,
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

    if (imageResult.imageDataUrls.isEmpty) {
      await _showAiBasicErrorSheet(
        title: 'Generate Image',
        message: 'The selected provider did not return an image.',
      );
      return;
    }

    GeneratedImage savedImage;
    try {
      final persisted = await _persistGeneratedImage(
        selection: request.selection,
        promptText: normalizedPrompt,
        name: normalizedName,
        imageDataUrl: imageResult.imageDataUrls.first,
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

  Future<AiModelInfo?> _lookupModelMetadata({
    required AiModelSelection selection,
    required String loadingText,
  }) async {
    try {
      final models = await _runAiLoadingTask<List<AiModelInfo>>(
        loadingText: loadingText,
        task: () => _fetchModelInfosForSelection(selection),
      );
      if (models == null) return null;

      for (final model in models) {
        if (model.id == selection.normalizedModelId) {
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

  bool _modelCannotGenerateText(AiModelInfo model) {
    if (model.hasOutputModalityMetadata) {
      return !model.supportsTextOutput;
    }

    return _looksLikeImageOnlyModelId(model.id);
  }

  Future<_AiImageGenerationResult?> _generateImageForSelection({
    required AiModelSelection selection,
    required String prompt,
    AiModelInfo? imageModel,
  }) async {
    final provider = selection.provider;
    final modelId = selection.normalizedModelId;
    if (provider == null || modelId.isEmpty) {
      throw const OpenRouterException('Image model is not configured.');
    }

    final settings = SettingsControllerScope.of(context);
    final apiKey = settings.apiKeyForProvider(provider);
    if (apiKey.trim().isEmpty) {
      throw _missingApiKeyExceptionForProvider(provider);
    }

    if (provider == AiProvider.gemini) {
      final result = await _runAiLoadingTask<GeminiImageGenerationResult>(
        loadingText: 'Generating image...',
        task: () => _gemini.generateImage(
          apiKey: apiKey,
          modelId: modelId,
          prompt: prompt,
        ),
      );
      if (result == null) return null;
      return _AiImageGenerationResult(
        assistantText: result.assistantText,
        imageDataUrls: result.imageDataUrls,
      );
    }

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
        final result = await _runAiLoadingTask<OpenRouterImageGenerationResult>(
          loadingText: 'Generating image...',
          task: () => _openRouter.generateImage(
            apiKey: apiKey,
            modelId: modelId,
            prompt: prompt,
            modalities: modalities,
          ),
        );
        if (result == null) return null;
        return _AiImageGenerationResult(
          assistantText: result.assistantText,
          imageDataUrls: result.imageUrls,
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
    AiModelInfo? imageModel,
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

  bool _ensureApiKeyConfigured({
    required SettingsController settings,
    required AiModelSelection selection,
  }) {
    final provider = selection.provider;
    if (provider == null) return false;
    if (settings.apiKeyForProvider(provider).trim().isNotEmpty) {
      return true;
    }

    _showAutoDismissSnackBar(
      SnackBar(
        content: Text(_missingApiKeyMessageForProvider(provider)),
        duration: const Duration(seconds: 2),
      ),
    );
    return false;
  }

  Future<List<AiModelInfo>> _fetchModelInfosForSelection(
    AiModelSelection selection,
  ) {
    final provider = selection.provider;
    if (provider == null) {
      return Future.value(const <AiModelInfo>[]);
    }

    final settings = SettingsControllerScope.of(context);
    final apiKey = settings.apiKeyForProvider(provider);
    switch (provider) {
      case AiProvider.openRouter:
        return _openRouter.fetchModelInfos(apiKey: apiKey);
      case AiProvider.gemini:
        return _gemini.fetchModels(apiKey: apiKey);
    }
  }

  Stream<AiTextStreamEvent> _streamTextForSelection({
    required AiModelSelection selection,
    required String prompt,
  }) {
    final provider = selection.provider;
    final modelId = selection.normalizedModelId;
    if (provider == null || modelId.isEmpty) {
      throw const OpenRouterException('Model is not configured.');
    }

    final settings = SettingsControllerScope.of(context);
    final apiKey = settings.apiKeyForProvider(provider);
    switch (provider) {
      case AiProvider.openRouter:
        return _openRouter.streamText(
          apiKey: apiKey,
          modelId: modelId,
          prompt: prompt,
        );
      case AiProvider.gemini:
        return _gemini.streamText(
          apiKey: apiKey,
          modelId: modelId,
          prompt: prompt,
        );
    }
  }

  Stream<AiTextStreamEvent> _streamTextForMessages({
    required AiModelSelection selection,
    required List<AiChatMessage> messages,
  }) {
    final provider = selection.provider;
    final modelId = selection.normalizedModelId;
    if (provider == null || modelId.isEmpty) {
      throw const OpenRouterException('Model is not configured.');
    }

    final settings = SettingsControllerScope.of(context);
    final apiKey = settings.apiKeyForProvider(provider);
    switch (provider) {
      case AiProvider.openRouter:
        return _openRouter.streamTextMessages(
          apiKey: apiKey,
          modelId: modelId,
          messages: messages,
        );
      case AiProvider.gemini:
        return _gemini.streamTextMessages(
          apiKey: apiKey,
          modelId: modelId,
          messages: messages,
        );
    }
  }

  Future<String> _generateTextForSelection({
    required AiModelSelection selection,
    required String prompt,
  }) {
    final provider = selection.provider;
    final modelId = selection.normalizedModelId;
    if (provider == null || modelId.isEmpty) {
      throw const OpenRouterException('Model is not configured.');
    }

    return _collectTextStream(
      provider: provider,
      stream: _streamTextForSelection(
        selection: selection,
        prompt: prompt,
      ),
    );
  }

  Future<String> _generateTextForMessages({
    required AiModelSelection selection,
    required List<AiChatMessage> messages,
  }) {
    final provider = selection.provider;
    final modelId = selection.normalizedModelId;
    if (provider == null || modelId.isEmpty) {
      throw const OpenRouterException('Model is not configured.');
    }

    return _collectTextStream(
      provider: provider,
      stream: _streamTextForMessages(
        selection: selection,
        messages: messages,
      ),
    );
  }

  Future<String> _collectTextStream({
    required AiProvider provider,
    required Stream<AiTextStreamEvent> stream,
  }) async {
    final buffer = StringBuffer();

    await for (final event in stream) {
      if (event.isDelta) {
        final deltaText = event.deltaText;
        if (deltaText != null && deltaText.isNotEmpty) {
          buffer.write(deltaText);
        }
        continue;
      }

      if (event.isError) {
        throw _streamErrorException(
          provider: provider,
          event: event,
        );
      }

      if (event.isDone) {
        break;
      }
    }

    return buffer.toString();
  }

  Exception _streamErrorException({
    required AiProvider provider,
    required AiTextStreamEvent event,
  }) {
    final message = (event.errorMessage ?? '').trim();
    final normalizedMessage =
        message.isEmpty ? 'Text stream failed before completing.' : message;

    switch (provider) {
      case AiProvider.openRouter:
        return OpenRouterException(
          normalizedMessage,
          cause: event.errorCause,
        );
      case AiProvider.gemini:
        return GeminiException(
          normalizedMessage,
          cause: event.errorCause,
        );
    }
  }

  Stream<T> _runBackgroundAiStreamTask<T>({
    required Stream<T> Function() task,
  }) async* {
    _hasBackgroundAiRequest = true;
    try {
      yield* task();
    } finally {
      _hasBackgroundAiRequest = false;
    }
  }

  String _missingApiKeyMessageForProvider(AiProvider provider) {
    return 'Add your ${provider.label} API key in Settings first.';
  }

  Exception _missingApiKeyExceptionForProvider(AiProvider provider) {
    switch (provider) {
      case AiProvider.openRouter:
        return const OpenRouterException('OpenRouter API key is required.');
      case AiProvider.gemini:
        return const GeminiException('Gemini API key is required.');
    }
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
    required String? name,
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
          name: name,
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
        modelSelection: AiModelSelection.none,
        prompt: '',
        title: '',
        loadingText: loadingText,
        emptyMessage: '',
        copiedMessage: '',
      ),
    );

    if (!mounted) return null;
    _setActiveAiRequest(loadingRequest);

    try {
      final result = await task();
      if (!mounted || _activeAiRequest?.token != loadingRequest.token) {
        return null;
      }
      return result;
    } finally {
      _clearActiveAiRequest(token: loadingRequest.token);
    }
  }

  void _cancelActiveAiRequest() {
    if (!mounted || _activeAiRequest == null) return;

    _aiLoadingElapsedTimer?.cancel();
    _aiLoadingElapsedTimer = null;
    setState(() {
      _aiRequestToken += 1;
      _activeAiRequest = null;
      _setActiveAiConversationSheetState(null);
      _initialAiStreamPhase = _InitialAiStreamPhase.idle;
      _activeAiElapsedSeconds = 0;
    });

    _showAutoDismissSnackBar(
      const SnackBar(
        content: Text('AI request canceled.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  String? _normalizeGeneratedImageName(String rawName) {
    final normalizedName = rawName.trim();
    if (normalizedName.isEmpty) {
      return null;
    }

    return normalizedName;
  }

  Future<_GeneratedImageDraft?> _showImagePromptEditorSheet({
    required String initialPrompt,
  }) async {
    final promptController = TextEditingController(text: initialPrompt);
    final nameController = TextEditingController();
    final prompt = await showModalBottomSheet<_GeneratedImageDraft>(
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
                  controller: promptController,
                  maxLines: 10,
                  minLines: 6,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Image Prompt',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Image Name (Optional)',
                    helperText: 'Leave blank to use the book name.',
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
                        _GeneratedImageDraft(
                          promptText: promptController.text,
                          name: nameController.text,
                        ),
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
    promptController.dispose();
    nameController.dispose();
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
                  generatedImage.displayName(widget.book.title),
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
                            viewerTitle: generatedImage.displayName(
                              widget.book.title,
                            ),
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

    final request = _ActiveAiRequest(
      token: ++_aiRequestToken,
      generationFuture: Future<String>.value(''),
      requestSpec: requestSpec,
    );

    if (!mounted) return;
    _setActiveAiRequest(request);
    _setInitialAiStreamPhase(_InitialAiStreamPhase.waitingForFirstChunk);
    unawaited(_runInitialAiFeatureStream(request));
  }

  Future<void> _runInitialAiFeatureStream(_ActiveAiRequest request) async {
    final requestSpec = request.requestSpec;
    final provider = requestSpec.modelSelection.provider;
    if (provider == null) {
      await _finishInitialAiFeatureStream(
        request: request,
        result: '',
        error: const OpenRouterException('Model is not configured.'),
      );
      return;
    }

    final responseBuffer = StringBuffer();
    Object? error;

    try {
      await for (final event in _streamTextForSelection(
        selection: requestSpec.modelSelection,
        prompt: requestSpec.prompt,
      )) {
        if (!mounted || _activeAiRequest?.token != request.token) {
          return;
        }

        if (event.isDelta) {
          final deltaText = event.deltaText;
          if (deltaText == null || deltaText.isEmpty) {
            continue;
          }

          responseBuffer.write(deltaText);
          _updateInitialAiConversationSheet(
            request: request,
            assistantText: responseBuffer.toString(),
          );
          continue;
        }

        if (event.isError) {
          throw _streamErrorException(
            provider: provider,
            event: event,
          );
        }

        if (event.isDone) {
          break;
        }
      }
    } catch (caughtError) {
      error = caughtError;
    }

    await _finishInitialAiFeatureStream(
      request: request,
      result: responseBuffer.toString(),
      error: error,
    );
  }

  List<_AiConversationMessage> _initialConversationMessagesForRequest(
    _AiRequestSpec requestSpec,
  ) {
    return requestSpec.initialConversationMessages ??
        <_AiConversationMessage>[
          _AiConversationMessage.hiddenUser(requestSpec.prompt),
        ];
  }

  void _setActiveAiConversationSheetState(
    _ActiveAiConversationSheetState? value,
  ) {
    _activeAiConversationSheet = value;
    _activeAiConversationSheetListenable.value = value;
  }

  void _showInitialAiConversationSheetIfNeeded({required int token}) {
    if (!mounted || _isInitialAiConversationSheetVisible) return;

    _isInitialAiConversationSheetVisible = true;
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) {
          return ValueListenableBuilder<_ActiveAiConversationSheetState?>(
            valueListenable: _activeAiConversationSheetListenable,
            builder: (context, sheetState, _) {
              if (sheetState == null) {
                return const SizedBox.shrink();
              }

              final settings = SettingsControllerScope.of(context);
              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
                  ),
                  child: FractionallySizedBox(
                    heightFactor: 0.82,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: KeyedSubtree(
                        key:
                            const ValueKey<String>('reader-ai-streaming-sheet'),
                        child: _AiConversationSheet(
                          title: sheetState.requestSpec.title,
                          copiedMessage: sheetState.requestSpec.copiedMessage,
                          emptyAssistantMessage:
                              sheetState.requestSpec.emptyMessage,
                          followUpHintText:
                              sheetState.requestSpec.followUpHintText,
                          resultTextStyle: buildReaderContentTextStyle(
                            context: context,
                            fontSize: settings.fontSize,
                            fontFamily: settings.fontFamily,
                          ),
                          initialMessages: <_AiConversationMessage>[
                            ...sheetState.initialMessages,
                            _AiConversationMessage.assistant(
                              sheetState.assistantText,
                            ),
                          ],
                          isInitialAssistantStreaming:
                              sheetState.isStreamingInitialAssistant,
                          onClose: () => Navigator.of(sheetContext).pop(),
                          onSendFollowUp: (messages) =>
                              _runBackgroundAiStreamTask(
                            task: () => _streamTextForMessages(
                              selection: sheetState.requestSpec.modelSelection,
                              messages: messages,
                            ),
                          ),
                          onRegenerateWithFallback: sheetState
                                  .isStreamingInitialAssistant
                              ? null
                              : () {
                                  Navigator.of(sheetContext).pop();
                                  unawaited(
                                    Future<void>.microtask(
                                      () => _regenerateAiRequestWithFallback(
                                        sheetState.requestSpec,
                                      ),
                                    ),
                                  );
                                },
                          switchFeatureLabel: _switchFeatureLabelForRequest(
                            sheetState.requestSpec,
                          ),
                          onSwitchFeature:
                              sheetState.isStreamingInitialAssistant
                                  ? null
                                  : () {
                                      Navigator.of(sheetContext).pop();
                                      unawaited(
                                        Future<void>.microtask(
                                          () => _switchTextFeature(
                                            sheetState.requestSpec,
                                          ),
                                        ),
                                      );
                                    },
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ).whenComplete(() {
        if (!mounted) return;

        _isInitialAiConversationSheetVisible = false;
        final currentSheet = _activeAiConversationSheet;
        if (currentSheet == null || currentSheet.token != token) {
          return;
        }

        if (currentSheet.isStreamingInitialAssistant &&
            _activeAiRequest?.token == token) {
          _cancelActiveAiRequest();
          return;
        }

        _dismissActiveAiConversationSheet();
      }),
    );
  }

  void _dismissPresentedInitialAiConversationSheet() {
    if (!_isInitialAiConversationSheetVisible || !mounted) return;
    Navigator.of(context).pop();
  }

  void _updateInitialAiConversationSheet({
    required _ActiveAiRequest request,
    required String assistantText,
  }) {
    if (!mounted || _activeAiRequest?.token != request.token) {
      return;
    }

    _aiLoadingElapsedTimer?.cancel();
    _aiLoadingElapsedTimer = null;

    final currentSheet = _activeAiConversationSheet;
    if (currentSheet == null) {
      setState(() {
        _initialAiStreamPhase = _InitialAiStreamPhase.streaming;
        _setActiveAiConversationSheetState(_ActiveAiConversationSheetState(
          token: request.token,
          requestSpec: request.requestSpec,
          initialMessages:
              _initialConversationMessagesForRequest(request.requestSpec),
          assistantText: assistantText,
          isStreamingInitialAssistant: true,
        ));
      });
      _showInitialAiConversationSheetIfNeeded(token: request.token);
      return;
    }

    if (currentSheet.token != request.token) {
      return;
    }

    setState(() {
      _initialAiStreamPhase = _InitialAiStreamPhase.streaming;
      _setActiveAiConversationSheetState(currentSheet.copyWith(
        assistantText: assistantText,
        isStreamingInitialAssistant: true,
      ));
    });
  }

  Future<void> _finishInitialAiFeatureStream({
    required _ActiveAiRequest request,
    required String result,
    Object? error,
  }) async {
    if (!mounted || _activeAiRequest?.token != request.token) {
      return;
    }

    _clearActiveAiRequest(token: request.token);
    final trimmedResult = result.trim();

    if (error == null) {
      final onSuccess = request.requestSpec.onSuccess;
      if (onSuccess != null) {
        unawaited(
          () async {
            try {
              await onSuccess();
            } catch (_) {
              // Ignore follow-up persistence errors after generation.
            }
          }(),
        );
      }
    }

    if (error == null && trimmedResult.isNotEmpty) {
      final currentSheet = _activeAiConversationSheet;
      if (currentSheet != null && currentSheet.token == request.token) {
        setState(() {
          _initialAiStreamPhase = _InitialAiStreamPhase.complete;
          _setActiveAiConversationSheetState(currentSheet.copyWith(
            assistantText: trimmedResult,
            isStreamingInitialAssistant: false,
          ));
        });
      }
      return;
    }

    _clearActiveAiConversationSheet(token: request.token);
    _dismissPresentedInitialAiConversationSheet();
    _setInitialAiStreamPhase(_InitialAiStreamPhase.failed);

    if (!mounted) return;

    final action = await _showAiCompletedResultSheet(
      title: request.requestSpec.title,
      emptyMessage: request.requestSpec.emptyMessage,
      copiedMessage: request.requestSpec.copiedMessage,
      followUpHintText: request.requestSpec.followUpHintText,
      modelSelection: request.requestSpec.modelSelection,
      prompt: request.requestSpec.prompt,
      initialConversationMessages:
          request.requestSpec.initialConversationMessages,
      switchFeatureLabel: _switchFeatureLabelForRequest(request.requestSpec),
      result: trimmedResult,
      error: error,
    );
    if (!mounted) return;

    if (action?.type == _AiResultSheetActionType.regenerateWithFallback) {
      await _regenerateAiRequestWithFallback(request.requestSpec);
    } else if (action?.type == _AiResultSheetActionType.switchFeature) {
      await _switchTextFeature(request.requestSpec);
    }

    if (!mounted || _activeAiRequest != null) {
      return;
    }

    _setInitialAiStreamPhase(_InitialAiStreamPhase.idle);
  }

  void _setInitialAiStreamPhase(_InitialAiStreamPhase phase) {
    if (!mounted || _initialAiStreamPhase == phase) return;

    setState(() {
      _initialAiStreamPhase = phase;
    });
  }

  void _dismissActiveAiConversationSheet() {
    if (!mounted) return;

    setState(() {
      _setActiveAiConversationSheetState(null);
      if (_activeAiRequest == null) {
        _initialAiStreamPhase = _InitialAiStreamPhase.idle;
      }
    });
  }

  void _clearActiveAiConversationSheet({required int token}) {
    final sheet = _activeAiConversationSheet;
    if (sheet == null || sheet.token != token || !mounted) {
      return;
    }

    setState(() {
      _setActiveAiConversationSheetState(null);
    });
  }

  Future<void> _regenerateAiRequestWithFallback(
      _AiRequestSpec requestSpec) async {
    final settings = SettingsControllerScope.of(context);
    final fallbackSelection = settings.fallbackModelSelection;
    if (!fallbackSelection.isConfigured) {
      _showAutoDismissSnackBar(
        const SnackBar(
          content: Text('Select a fallback AI model in Settings first.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    if (!_ensureApiKeyConfigured(
      settings: settings,
      selection: fallbackSelection,
    )) {
      return;
    }

    await _startAiFeatureRequest(
      requestSpec.copyWith(modelSelection: fallbackSelection),
    );
  }

  Future<_AiSourceMode?> _showAiSourceModePicker({
    required String title,
    required String description,
    bool includeChapterStartToSelection = false,
  }) {
    return showModalBottomSheet<_AiSourceMode>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
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
                    onTap: () => Navigator.of(sheetContext)
                        .pop(_AiSourceMode.selectedText),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.bookmark_outline),
                    title: const Text('Resume Range'),
                    subtitle: const Text(
                      'Use the range between the last resume point and this selection.',
                    ),
                    onTap: () => Navigator.of(sheetContext)
                        .pop(_AiSourceMode.resumeRange),
                  ),
                  if (includeChapterStartToSelection)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.first_page),
                      title: const Text('Chapter Start to Selection'),
                      subtitle: const Text(
                        'Use the current chapter from the beginning through this selection.',
                      ),
                      onTap: () => Navigator.of(sheetContext)
                          .pop(_AiSourceMode.chapterStartToSelection),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  _TextAiSelection? _buildSelectedTextAiSelection({
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

    return _TextAiSelection(
      sourceMode: _AiSourceMode.selectedText,
      sourceText: sourceText,
      chapterTitle: chapterTitle,
      selectedText: selectedText,
      selectionStart: boundedStart,
      selectionEnd: boundedEnd,
      shouldUpdateResumeMarker: false,
    );
  }

  _TextAiSelection? _buildResumeRangeAiSelection({
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

    return _TextAiSelection(
      sourceMode: _AiSourceMode.resumeRange,
      sourceText: range.sourceText,
      chapterTitle: chapterTitle,
      selectedText: selectedText,
      selectionStart: boundedStart,
      selectionEnd: boundedEnd,
      shouldUpdateResumeMarker: range.shouldUpdateResumeMarker,
    );
  }

  _TextAiSelection? _buildChapterStartToSelectionAiSelection({
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

    final sourceText = chapterContent.substring(0, boundedEnd).trim();
    if (sourceText.isEmpty) return null;

    return _TextAiSelection(
      sourceMode: _AiSourceMode.chapterStartToSelection,
      sourceText: sourceText,
      chapterTitle: chapterTitle,
      selectedText: selectedText,
      selectionStart: boundedStart,
      selectionEnd: boundedEnd,
      shouldUpdateResumeMarker: false,
    );
  }

  _TextAiSelection? _buildWholeChapterAiSelection({
    required String chapterContent,
    required String chapterTitle,
  }) {
    final sourceText = chapterContent.trim();
    if (sourceText.isEmpty) return null;

    return _TextAiSelection(
      sourceMode: _AiSourceMode.wholeChapter,
      sourceText: sourceText,
      chapterTitle: chapterTitle,
      selectedText: chapterContent,
      selectionStart: 0,
      selectionEnd: chapterContent.length,
      shouldUpdateResumeMarker: false,
    );
  }

  bool _canStartAiRequest() {
    if (_activeAiRequest == null && !_hasBackgroundAiRequest) return true;

    _showAutoDismissSnackBar(
      const SnackBar(
        content: Text('An AI response is already loading.'),
        duration: Duration(seconds: 2),
      ),
    );
    return false;
  }

  String? _switchFeatureLabelForRequest(_AiRequestSpec requestSpec) {
    final featureId = requestSpec.featureId;
    if (featureId == null || requestSpec.textFeatureSelection == null) {
      return null;
    }

    return _textAiFeatureSpec(featureId)?.switchButtonLabel;
  }

  void _setActiveAiRequest(_ActiveAiRequest request) {
    _aiLoadingElapsedTimer?.cancel();
    _aiLoadingElapsedTimer = null;

    if (!mounted) return;
    setState(() {
      _activeAiRequest = request;
      _setActiveAiConversationSheetState(null);
      _initialAiStreamPhase = _InitialAiStreamPhase.idle;
      _activeAiElapsedSeconds = 0;
    });

    _aiLoadingElapsedTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) {
      if (!mounted || _activeAiRequest?.token != request.token) {
        timer.cancel();
        if (identical(_aiLoadingElapsedTimer, timer)) {
          _aiLoadingElapsedTimer = null;
        }
        return;
      }

      setState(() => _activeAiElapsedSeconds += 1);
    });
  }

  void _clearActiveAiRequest({required int token}) {
    if (_activeAiRequest?.token != token) return;

    _aiLoadingElapsedTimer?.cancel();
    _aiLoadingElapsedTimer = null;

    if (!mounted) return;
    setState(() {
      _activeAiRequest = null;
      _activeAiElapsedSeconds = 0;
    });
  }

  Future<void> _switchTextFeature(_AiRequestSpec requestSpec) async {
    final featureId = requestSpec.featureId;
    final textFeatureSelection = requestSpec.textFeatureSelection;
    if (featureId == null || textFeatureSelection == null) return;

    final featureSpec = _textAiFeatureSpec(featureId);
    if (featureSpec == null || featureSpec.switchTargetFeatureId == null) {
      return;
    }

    final switchedRequestSpec = _buildTextFeatureRequestSpec(
      featureId: featureSpec.switchTargetFeatureId!,
      textFeatureSelection: textFeatureSelection,
    );
    if (switchedRequestSpec == null) return;

    await _startAiFeatureRequest(switchedRequestSpec);
  }

  Future<_AiResultSheetAction?> _showAiCompletedResultSheet({
    required String title,
    required String emptyMessage,
    required String copiedMessage,
    required String followUpHintText,
    required AiModelSelection modelSelection,
    required String prompt,
    List<_AiConversationMessage>? initialConversationMessages,
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
    final trimmedResult = (result ?? '').trim();

    if (error != null || trimmedResult.isEmpty) {
      return showModalBottomSheet<_AiResultSheetAction>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) {
          return FractionallySizedBox(
            heightFactor: 0.7,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: _AiResultError(
                title: title,
                message: error?.toString() ?? emptyMessage,
                onClose: () => Navigator.of(sheetContext).pop(),
                onRegenerateWithFallback: () =>
                    _popRegenerateWithFallback(sheetContext),
              ),
            ),
          );
        },
      );
    }

    return showModalBottomSheet<_AiResultSheetAction>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final initialMessages = <_AiConversationMessage>[
          ...(initialConversationMessages ??
              <_AiConversationMessage>[
                _AiConversationMessage.hiddenUser(prompt)
              ]),
          _AiConversationMessage.assistant(trimmedResult),
        ];

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: FractionallySizedBox(
              heightFactor: 0.82,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: _AiConversationSheet(
                  title: title,
                  copiedMessage: copiedMessage,
                  emptyAssistantMessage: emptyMessage,
                  followUpHintText: followUpHintText,
                  resultTextStyle: resultTextStyle,
                  initialMessages: initialMessages,
                  onSendFollowUp: (messages) => _runBackgroundAiStreamTask(
                    task: () => _streamTextForMessages(
                      selection: modelSelection,
                      messages: messages,
                    ),
                  ),
                  onRegenerateWithFallback: () =>
                      _popRegenerateWithFallback(sheetContext),
                  switchFeatureLabel: switchFeatureLabel,
                  onSwitchFeature: switchFeatureLabel == null
                      ? null
                      : () => Navigator.of(sheetContext).pop(
                            const _AiResultSheetAction.switchFeature(),
                          ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _popRegenerateWithFallback(BuildContext sheetContext) {
    final settings = SettingsControllerScope.of(context);
    final fallbackSelection = settings.fallbackModelSelection;
    if (!fallbackSelection.isConfigured) {
      _showAutoDismissSnackBar(
        const SnackBar(
          content: Text('Select a fallback AI model in Settings first.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    if (!_ensureApiKeyConfigured(
      settings: settings,
      selection: fallbackSelection,
    )) {
      return;
    }

    Navigator.of(sheetContext).pop(
      const _AiResultSheetAction.regenerateWithFallback(),
    );
  }

  Future<String?> _showGeneratedPromptConversationSheet({
    required _GenerateImagePromptRequest request,
    required String generatedPrompt,
  }) async {
    final settings = SettingsControllerScope.of(context);
    final resultTextStyle = buildReaderContentTextStyle(
      context: context,
      fontSize: settings.fontSize,
      fontFamily: settings.fontFamily,
    );

    final action = await showModalBottomSheet<_AiResultSheetAction>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: FractionallySizedBox(
              heightFactor: 0.82,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: _AiConversationSheet(
                  title: 'Generate Image',
                  copiedMessage: 'Prompt copied',
                  emptyAssistantMessage:
                      'Model returned an empty image prompt.',
                  followUpHintText: 'Refine this image prompt',
                  resultTextStyle: resultTextStyle,
                  initialMessages: <_AiConversationMessage>[
                    _AiConversationMessage.hiddenUser(request.prompt),
                    _AiConversationMessage.assistant(generatedPrompt),
                  ],
                  onSendFollowUp: (messages) => _runBackgroundAiStreamTask(
                    task: () => _streamTextForMessages(
                      selection: request.promptModelSelection,
                      messages: messages,
                    ),
                  ),
                  primaryActionLabel: 'Use Latest Prompt',
                  onPrimaryAction: (latestAssistantText) {
                    Navigator.of(sheetContext).pop(
                      _AiResultSheetAction.applyLatestAssistant(
                        latestAssistantText,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );

    if (action?.type != _AiResultSheetActionType.applyLatestAssistant) {
      return null;
    }

    return action?.assistantText?.trim();
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

    return MobileScrollbar(
      controller: _scrollController,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(
          _readerHorizontalPadding,
          topPadding,
          _readerHorizontalPadding,
          _readerBottomPadding + _activeAiBottomInset,
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

class _AiQuestionComposerSheet extends StatefulWidget {
  final String title;
  final String description;
  final String hintText;
  final List<String> presetQuestions;

  const _AiQuestionComposerSheet({
    required this.title,
    required this.description,
    required this.hintText,
    required this.presetQuestions,
  });

  @override
  State<_AiQuestionComposerSheet> createState() =>
      _AiQuestionComposerSheetState();
}

class _AiQuestionComposerSheetState extends State<_AiQuestionComposerSheet> {
  late final TextEditingController _controller;

  bool get _canSubmit => _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _fillQuestion(String question) {
    _controller.value = TextEditingValue(
      text: question,
      selection: TextSelection.collapsed(offset: question.length),
    );
    setState(() {});
  }

  void _submit() {
    if (!_canSubmit) return;
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                widget.description,
                style: theme.textTheme.bodySmall,
              ),
              if (widget.presetQuestions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Quick questions',
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.presetQuestions
                      .map(
                        (question) => ActionChip(
                          label: Text(question),
                          onPressed: () => _fillQuestion(question),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                minLines: 2,
                maxLines: 5,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: 'Question',
                  hintText: widget.hintText,
                ),
                onChanged: (value) => setState(() {}),
                onSubmitted: (value) => _submit(),
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
                    onPressed: _canSubmit ? _submit : null,
                    child: const Text('Ask'),
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

class _AiConversationSheet extends StatefulWidget {
  final String title;
  final String copiedMessage;
  final String emptyAssistantMessage;
  final String followUpHintText;
  final TextStyle resultTextStyle;
  final List<_AiConversationMessage> initialMessages;
  final Stream<AiTextStreamEvent> Function(List<AiChatMessage> messages)
      onSendFollowUp;
  final bool isInitialAssistantStreaming;
  final VoidCallback? onClose;
  final VoidCallback? onRegenerateWithFallback;
  final String? switchFeatureLabel;
  final VoidCallback? onSwitchFeature;
  final String? primaryActionLabel;
  final void Function(String latestAssistantText)? onPrimaryAction;

  const _AiConversationSheet({
    required this.title,
    required this.copiedMessage,
    required this.emptyAssistantMessage,
    required this.followUpHintText,
    required this.resultTextStyle,
    required this.initialMessages,
    required this.onSendFollowUp,
    this.isInitialAssistantStreaming = false,
    this.onClose,
    this.onRegenerateWithFallback,
    this.switchFeatureLabel,
    this.onSwitchFeature,
    this.primaryActionLabel,
    this.onPrimaryAction,
  });

  @override
  State<_AiConversationSheet> createState() => _AiConversationSheetState();
}

class _AiConversationSheetState extends State<_AiConversationSheet> {
  late final TextEditingController _controller;
  late final ScrollController _scrollController;
  final List<_AiConversationMessage> _followUpMessages =
      <_AiConversationMessage>[];

  bool _isSending = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController()..addListener(_handleComposerChanged);
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void didUpdateWidget(covariant _AiConversationSheet oldWidget) {
    super.didUpdateWidget(oldWidget);

    final initialMessagesChanged =
        oldWidget.initialMessages.length != widget.initialMessages.length ||
            _AiConversationMessage.latestAssistantText(
                  oldWidget.initialMessages,
                ) !=
                _AiConversationMessage.latestAssistantText(
                  widget.initialMessages,
                );

    if (initialMessagesChanged ||
        oldWidget.isInitialAssistantStreaming !=
            widget.isInitialAssistantStreaming) {
      _scheduleScrollToBottom();
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleComposerChanged)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<_AiConversationMessage> get _conversationMessages =>
      <_AiConversationMessage>[
        ...widget.initialMessages,
        ..._followUpMessages,
      ];

  List<_AiConversationMessage> get _visibleMessages => _conversationMessages
      .where((message) => message.isVisible)
      .toList(growable: false);

  String get _latestAssistantText =>
      _AiConversationMessage.latestAssistantText(_conversationMessages);

  bool get _canSend =>
      !_isSending &&
      !widget.isInitialAssistantStreaming &&
      _controller.text.trim().isNotEmpty;

  void _handleComposerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _scheduleScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  Future<void> _copyLatestAssistant() async {
    final latestAssistantText = _latestAssistantText;
    if (latestAssistantText.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: latestAssistantText));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.copiedMessage),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _sendFollowUp() async {
    final question = _controller.text.trim();
    if (question.isEmpty || _isSending || widget.isInitialAssistantStreaming) {
      return;
    }

    const placeholderMessage = _AiConversationMessage.assistantDraft('');

    setState(() {
      _followUpMessages.add(_AiConversationMessage.user(question));
      _followUpMessages.add(placeholderMessage);
      _controller.clear();
      _errorText = null;
      _isSending = true;
    });
    _scheduleScrollToBottom();

    final assistantMessageIndex = _followUpMessages.length - 1;
    final responseBuffer = StringBuffer();

    try {
      await for (final event in widget.onSendFollowUp(
        _AiConversationMessage.apiMessages(_conversationMessages),
      )) {
        if (!mounted) return;

        if (event.isDelta) {
          final deltaText = event.deltaText;
          if (deltaText == null || deltaText.isEmpty) {
            continue;
          }

          responseBuffer.write(deltaText);
          setState(() {
            _followUpMessages[assistantMessageIndex] =
                _AiConversationMessage.assistantDraft(
              responseBuffer.toString(),
            );
          });
          _scheduleScrollToBottom();
          continue;
        }

        if (event.isError) {
          final message = (event.errorMessage ?? '').trim();
          throw _AiFollowUpException(
            message.isEmpty ? 'Text stream failed before completing.' : message,
          );
        }

        if (event.isDone) {
          break;
        }
      }

      final trimmedResponse = responseBuffer.toString().trim();
      if (!mounted) return;

      if (trimmedResponse.isEmpty) {
        setState(() {
          _followUpMessages.removeAt(assistantMessageIndex);
          _errorText = widget.emptyAssistantMessage;
        });
        return;
      }

      setState(() {
        _followUpMessages[assistantMessageIndex] =
            _AiConversationMessage.assistant(trimmedResponse);
      });
      _scheduleScrollToBottom();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        final assistantMessage = _followUpMessages[assistantMessageIndex];
        if (assistantMessage.text.trim().isEmpty) {
          _followUpMessages.removeAt(assistantMessageIndex);
        } else {
          _followUpMessages[assistantMessageIndex] =
              _AiConversationMessage.assistant(assistantMessage.text.trim());
        }
        _errorText = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latestAssistantText = _latestAssistantText;
    final actionsDisabled = _isSending || widget.isInitialAssistantStreaming;
    final closeTooltip =
        widget.isInitialAssistantStreaming ? 'Cancel AI Request' : 'Close';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.title,
                style: theme.textTheme.titleMedium,
              ),
            ),
            IconButton(
              onPressed: actionsDisabled || latestAssistantText.isEmpty
                  ? null
                  : _copyLatestAssistant,
              tooltip: 'Copy',
              icon: const Icon(Icons.copy_outlined),
            ),
            if (widget.onRegenerateWithFallback != null)
              IconButton(
                onPressed:
                    actionsDisabled ? null : widget.onRegenerateWithFallback,
                tooltip: 'Regenerate with Fallback',
                icon: const Icon(Icons.refresh),
              ),
            if (widget.onSwitchFeature != null &&
                widget.switchFeatureLabel != null)
              IconButton(
                onPressed: actionsDisabled ? null : widget.onSwitchFeature,
                tooltip: widget.switchFeatureLabel,
                icon: const Icon(Icons.swap_horiz),
              ),
            IconButton(
              onPressed: _isSending
                  ? null
                  : (widget.onClose ?? () => Navigator.of(context).pop()),
              tooltip: closeTooltip,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        if (widget.isInitialAssistantStreaming) ...[
          const SizedBox(height: 4),
          Text(
            'Streaming...',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          const LinearProgressIndicator(minHeight: 3),
        ],
        const SizedBox(height: 8),
        Expanded(
          child: MobileScrollbar(
            controller: _scrollController,
            child: ListView.separated(
              controller: _scrollController,
              itemCount: _visibleMessages.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final message = _visibleMessages[index];
                return _AiConversationBubble(
                  message: message,
                  resultTextStyle: widget.resultTextStyle,
                );
              },
            ),
          ),
        ),
        if (_errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            _errorText!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        if (widget.primaryActionLabel != null &&
            widget.onPrimaryAction != null) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: actionsDisabled || latestAssistantText.isEmpty
                  ? null
                  : () => widget.onPrimaryAction!(latestAssistantText),
              child: Text(widget.primaryActionLabel!),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                enabled: !_isSending && !widget.isInitialAssistantStreaming,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: widget.followUpHintText,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _canSend ? _sendFollowUp : null,
              child: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send'),
            ),
          ],
        ),
      ],
    );
  }
}

class _AiConversationBubble extends StatelessWidget {
  final _AiConversationMessage message;
  final TextStyle resultTextStyle;

  const _AiConversationBubble({
    required this.message,
    required this.resultTextStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAssistant = message.role == AiChatMessageRole.assistant;
    final alignment =
        isAssistant ? Alignment.centerLeft : Alignment.centerRight;
    final backgroundColor = isAssistant
        ? theme.colorScheme.surfaceContainerHighest
        : theme.colorScheme.primaryContainer;
    final foregroundColor = isAssistant
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onPrimaryContainer;

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAssistant ? 'Assistant' : 'You',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: foregroundColor.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 6),
                if (isAssistant)
                  SelectableText(
                    message.text,
                    textAlign: TextAlign.justify,
                    style: resultTextStyle.copyWith(color: foregroundColor),
                  )
                else
                  Text(
                    message.text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: foregroundColor,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AiLoadingSheet extends StatelessWidget {
  static const ValueKey<String> containerKey =
      ValueKey<String>('reader-ai-loading-sheet');
  static const ValueKey<String> progressKey =
      ValueKey<String>('reader-ai-loading-progress');
  static const ValueKey<String> elapsedKey =
      ValueKey<String>('reader-ai-loading-elapsed');

  final String loadingText;
  final int elapsedSeconds;
  final VoidCallback onCancel;

  const _AiLoadingSheet({
    required this.loadingText,
    required this.elapsedSeconds,
    required this.onCancel,
  });

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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          loadingText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: onCancel,
                        tooltip: 'Cancel AI Request',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(
                    key: progressKey,
                    minHeight: 3,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Elapsed: ${elapsedSeconds}s',
                    key: elapsedKey,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
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
    return SingleChildScrollView(
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

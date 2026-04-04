part of 'package:bookai/screens/reader_screen.dart';

extension _ReaderAiSheets on _ReaderScreenState {
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

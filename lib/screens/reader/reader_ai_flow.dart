part of 'package:bookai/screens/reader_screen.dart';

extension _ReaderAiFlow on _ReaderScreenState {
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
    _setReaderState(() {
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

  Future<void> _startAiFeatureRequest(_AiRequestSpec requestSpec) async {
    if (!_canStartAiRequest()) return;

    final request = _ActiveAiRequest(
      token: ++_aiRequestToken,
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
      _setReaderState(() {
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

    _setReaderState(() {
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
        _setReaderState(() {
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

    _setReaderState(() {
      _initialAiStreamPhase = phase;
    });
  }

  void _dismissActiveAiConversationSheet() {
    if (!mounted) return;

    _setReaderState(() {
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

    _setReaderState(() {
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
    _setReaderState(() {
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

      _setReaderState(() => _activeAiElapsedSeconds += 1);
    });
  }

  void _clearActiveAiRequest({required int token}) {
    if (_activeAiRequest?.token != token) return;

    _aiLoadingElapsedTimer?.cancel();
    _aiLoadingElapsedTimer = null;

    if (!mounted) return;
    _setReaderState(() {
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
}

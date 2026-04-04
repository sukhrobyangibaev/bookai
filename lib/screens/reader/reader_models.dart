part of 'package:bookai/screens/reader_screen.dart';

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

class _TextAiSelection {
  final _AiSourceMode sourceMode;
  final String sourceText;
  final String chapterTitle;
  final String selectedText;
  final int selectionStart;
  final int selectionEnd;
  final bool shouldUpdateResumeMarker;

  const _TextAiSelection({
    required this.sourceMode,
    required this.sourceText,
    required this.chapterTitle,
    required this.selectedText,
    required this.selectionStart,
    required this.selectionEnd,
    required this.shouldUpdateResumeMarker,
  });
}

enum _AiSourceMode {
  selectedText,
  resumeRange,
  chapterStartToSelection,
  wholeChapter,
}

enum _InitialAiStreamPhase {
  idle,
  waitingForFirstChunk,
  streaming,
  complete,
  failed,
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
  final AiModelSelection promptModelSelection;
  final AiModelSelection imageModelSelection;
  final String prompt;
  final _GenerateImageSelection selection;

  const _GenerateImagePromptRequest({
    required this.promptModelSelection,
    required this.imageModelSelection,
    required this.prompt,
    required this.selection,
  });
}

class _GeneratedImageDraft {
  final String promptText;
  final String name;

  const _GeneratedImageDraft({
    required this.promptText,
    required this.name,
  });
}

class _TextAiFeatureSpec {
  final String featureId;
  final String title;
  final String loadingText;
  final String emptyMessage;
  final String copiedMessage;
  final String invalidSelectedTextMessage;
  final String invalidRangeMessage;
  final String invalidPromptMessage;
  final List<String> requiredPromptPlaceholders;
  final String followUpHintText;
  final String? initialQuestionHintText;
  final List<String> initialQuestionPresets;
  final String? switchTargetFeatureId;
  final String? switchButtonLabel;

  const _TextAiFeatureSpec({
    required this.featureId,
    required this.title,
    required this.loadingText,
    required this.emptyMessage,
    required this.copiedMessage,
    required this.invalidSelectedTextMessage,
    required this.invalidRangeMessage,
    required this.invalidPromptMessage,
    required this.requiredPromptPlaceholders,
    required this.followUpHintText,
    this.initialQuestionHintText,
    this.initialQuestionPresets = const <String>[],
    this.switchTargetFeatureId,
    this.switchButtonLabel,
  });
}

class _ActiveAiRequest {
  final int token;
  final _AiRequestSpec requestSpec;

  const _ActiveAiRequest({
    required this.token,
    required this.requestSpec,
  });
}

class _ActiveAiConversationSheetState {
  final int token;
  final _AiRequestSpec requestSpec;
  final List<_AiConversationMessage> initialMessages;
  final String assistantText;
  final bool isStreamingInitialAssistant;

  const _ActiveAiConversationSheetState({
    required this.token,
    required this.requestSpec,
    required this.initialMessages,
    required this.assistantText,
    required this.isStreamingInitialAssistant,
  });

  _ActiveAiConversationSheetState copyWith({
    _AiRequestSpec? requestSpec,
    List<_AiConversationMessage>? initialMessages,
    String? assistantText,
    bool? isStreamingInitialAssistant,
  }) {
    return _ActiveAiConversationSheetState(
      token: token,
      requestSpec: requestSpec ?? this.requestSpec,
      initialMessages: initialMessages ?? this.initialMessages,
      assistantText: assistantText ?? this.assistantText,
      isStreamingInitialAssistant:
          isStreamingInitialAssistant ?? this.isStreamingInitialAssistant,
    );
  }
}

class _AiRequestSpec {
  final AiModelSelection modelSelection;
  final String prompt;
  final String title;
  final String loadingText;
  final String emptyMessage;
  final String copiedMessage;
  final String followUpHintText;
  final List<_AiConversationMessage>? initialConversationMessages;
  final String? featureId;
  final _TextAiSelection? textFeatureSelection;
  final Future<void> Function()? onSuccess;

  const _AiRequestSpec({
    required this.modelSelection,
    required this.prompt,
    required this.title,
    required this.loadingText,
    required this.emptyMessage,
    required this.copiedMessage,
    this.followUpHintText = 'Ask a follow-up question',
    this.initialConversationMessages,
    this.featureId,
    this.textFeatureSelection,
    this.onSuccess,
  });

  _AiRequestSpec copyWith({
    AiModelSelection? modelSelection,
    String? prompt,
    String? title,
    String? loadingText,
    String? emptyMessage,
    String? copiedMessage,
    String? followUpHintText,
    List<_AiConversationMessage>? initialConversationMessages,
    String? featureId,
    _TextAiSelection? textFeatureSelection,
    Future<void> Function()? onSuccess,
  }) {
    return _AiRequestSpec(
      modelSelection: modelSelection ?? this.modelSelection,
      prompt: prompt ?? this.prompt,
      title: title ?? this.title,
      loadingText: loadingText ?? this.loadingText,
      emptyMessage: emptyMessage ?? this.emptyMessage,
      copiedMessage: copiedMessage ?? this.copiedMessage,
      followUpHintText: followUpHintText ?? this.followUpHintText,
      initialConversationMessages:
          initialConversationMessages ?? this.initialConversationMessages,
      featureId: featureId ?? this.featureId,
      textFeatureSelection: textFeatureSelection ?? this.textFeatureSelection,
      onSuccess: onSuccess ?? this.onSuccess,
    );
  }
}

class _AiImageGenerationResult {
  final String assistantText;
  final List<String> imageDataUrls;

  const _AiImageGenerationResult({
    required this.assistantText,
    required this.imageDataUrls,
  });
}

enum _AiResultSheetActionType {
  regenerateWithFallback,
  switchFeature,
  applyLatestAssistant,
}

class _AiResultSheetAction {
  final _AiResultSheetActionType type;
  final String? assistantText;

  const _AiResultSheetAction._({
    required this.type,
    this.assistantText,
  });

  const _AiResultSheetAction.regenerateWithFallback()
      : this._(type: _AiResultSheetActionType.regenerateWithFallback);

  const _AiResultSheetAction.switchFeature()
      : this._(type: _AiResultSheetActionType.switchFeature);

  const _AiResultSheetAction.applyLatestAssistant(String assistantText)
      : this._(
          type: _AiResultSheetActionType.applyLatestAssistant,
          assistantText: assistantText,
        );
}

class _AiFollowUpException implements Exception {
  final String message;

  const _AiFollowUpException(this.message);

  @override
  String toString() => message;
}

class _AiConversationMessage {
  final AiChatMessageRole role;
  final String text;
  final bool isVisible;
  final bool includeInApi;

  const _AiConversationMessage._({
    required this.role,
    required this.text,
    required this.isVisible,
    required this.includeInApi,
  });

  const _AiConversationMessage.hiddenUser(String value)
      : this._(
          role: AiChatMessageRole.user,
          text: value,
          isVisible: false,
          includeInApi: true,
        );

  const _AiConversationMessage.user(String value)
      : this._(
          role: AiChatMessageRole.user,
          text: value,
          isVisible: true,
          includeInApi: true,
        );

  const _AiConversationMessage.displayOnlyUser(String value)
      : this._(
          role: AiChatMessageRole.user,
          text: value,
          isVisible: true,
          includeInApi: false,
        );

  const _AiConversationMessage.assistant(String value)
      : this._(
          role: AiChatMessageRole.assistant,
          text: value,
          isVisible: true,
          includeInApi: true,
        );

  const _AiConversationMessage.assistantDraft(String value)
      : this._(
          role: AiChatMessageRole.assistant,
          text: value,
          isVisible: true,
          includeInApi: false,
        );

  AiChatMessage toApiMessage() => AiChatMessage(
        role: role,
        content: text,
      );

  static String latestAssistantText(Iterable<_AiConversationMessage> messages) {
    for (final message in messages.toList().reversed) {
      if (message.role == AiChatMessageRole.assistant &&
          message.text.trim().isNotEmpty) {
        return message.text.trim();
      }
    }
    return '';
  }

  static List<AiChatMessage> apiMessages(
    Iterable<_AiConversationMessage> messages,
  ) {
    return messages
        .where((message) => message.includeInApi)
        .map((message) => message.toApiMessage())
        .toList(growable: false);
  }
}

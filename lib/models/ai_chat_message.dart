enum AiChatMessageRole {
  user,
  assistant,
}

class AiChatMessage {
  final AiChatMessageRole role;
  final String content;

  const AiChatMessage({
    required this.role,
    required this.content,
  });

  const AiChatMessage.user(String text)
      : role = AiChatMessageRole.user,
        content = text;

  const AiChatMessage.assistant(String text)
      : role = AiChatMessageRole.assistant,
        content = text;

  String get normalizedContent => content.trim();
}

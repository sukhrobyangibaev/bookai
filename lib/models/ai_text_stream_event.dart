enum AiTextStreamEventType {
  delta,
  done,
  error,
}

class AiTextStreamEvent {
  final AiTextStreamEventType type;
  final String? deltaText;
  final String? errorMessage;
  final Object? errorCause;

  const AiTextStreamEvent._({
    required this.type,
    this.deltaText,
    this.errorMessage,
    this.errorCause,
  });

  const AiTextStreamEvent.delta(String text)
      : this._(
          type: AiTextStreamEventType.delta,
          deltaText: text,
        );

  const AiTextStreamEvent.done()
      : this._(
          type: AiTextStreamEventType.done,
        );

  const AiTextStreamEvent.error(
    String message, {
    Object? cause,
  }) : this._(
          type: AiTextStreamEventType.error,
          errorMessage: message,
          errorCause: cause,
        );

  bool get isDelta => type == AiTextStreamEventType.delta;
  bool get isDone => type == AiTextStreamEventType.done;
  bool get isError => type == AiTextStreamEventType.error;
}

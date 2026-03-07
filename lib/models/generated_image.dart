class GeneratedImage {
  final int? id;
  final int bookId;
  final int chapterIndex;
  final String featureMode;
  final String sourceText;
  final String promptText;
  final String filePath;
  final DateTime createdAt;

  const GeneratedImage({
    this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.featureMode,
    required this.sourceText,
    required this.promptText,
    required this.filePath,
    required this.createdAt,
  });

  GeneratedImage copyWith({
    int? id,
    int? bookId,
    int? chapterIndex,
    String? featureMode,
    String? sourceText,
    String? promptText,
    String? filePath,
    DateTime? createdAt,
  }) {
    return GeneratedImage(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      featureMode: featureMode ?? this.featureMode,
      sourceText: sourceText ?? this.sourceText,
      promptText: promptText ?? this.promptText,
      filePath: filePath ?? this.filePath,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'bookId': bookId,
      'chapterIndex': chapterIndex,
      'featureMode': featureMode,
      'sourceText': sourceText,
      'promptText': promptText,
      'filePath': filePath,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory GeneratedImage.fromMap(Map<String, dynamic> map) {
    return GeneratedImage(
      id: map['id'] as int?,
      bookId: map['bookId'] as int,
      chapterIndex: map['chapterIndex'] as int,
      featureMode: map['featureMode'] as String,
      sourceText: map['sourceText'] as String,
      promptText: map['promptText'] as String,
      filePath: map['filePath'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GeneratedImage &&
        other.id == id &&
        other.bookId == bookId &&
        other.chapterIndex == chapterIndex &&
        other.featureMode == featureMode &&
        other.sourceText == sourceText &&
        other.promptText == promptText &&
        other.filePath == filePath &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        bookId,
        chapterIndex,
        featureMode,
        sourceText,
        promptText,
        filePath,
        createdAt,
      );
}

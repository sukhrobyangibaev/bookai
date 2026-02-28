class ReadingProgress {
  final int bookId;
  final int chapterIndex;
  final double scrollOffset;
  final DateTime updatedAt;

  const ReadingProgress({
    required this.bookId,
    required this.chapterIndex,
    required this.scrollOffset,
    required this.updatedAt,
  });

  ReadingProgress copyWith({
    int? bookId,
    int? chapterIndex,
    double? scrollOffset,
    DateTime? updatedAt,
  }) {
    return ReadingProgress(
      bookId: bookId ?? this.bookId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      scrollOffset: scrollOffset ?? this.scrollOffset,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bookId': bookId,
      'chapterIndex': chapterIndex,
      'scrollOffset': scrollOffset,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ReadingProgress.fromMap(Map<String, dynamic> map) {
    return ReadingProgress(
      bookId: map['bookId'] as int,
      chapterIndex: map['chapterIndex'] as int,
      scrollOffset: (map['scrollOffset'] as num).toDouble(),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  @override
  String toString() {
    return 'ReadingProgress(bookId: $bookId, chapterIndex: $chapterIndex, '
        'scrollOffset: $scrollOffset, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReadingProgress && other.bookId == bookId;
  }

  @override
  int get hashCode => bookId.hashCode;
}

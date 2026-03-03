class ResumeMarker {
  final int bookId;
  final int chapterIndex;
  final String selectedText;
  final int selectionStart;
  final int selectionEnd;
  final double scrollOffset;
  final DateTime createdAt;

  const ResumeMarker({
    required this.bookId,
    required this.chapterIndex,
    required this.selectedText,
    required this.selectionStart,
    required this.selectionEnd,
    required this.scrollOffset,
    required this.createdAt,
  });

  ResumeMarker copyWith({
    int? bookId,
    int? chapterIndex,
    String? selectedText,
    int? selectionStart,
    int? selectionEnd,
    double? scrollOffset,
    DateTime? createdAt,
  }) {
    return ResumeMarker(
      bookId: bookId ?? this.bookId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      selectedText: selectedText ?? this.selectedText,
      selectionStart: selectionStart ?? this.selectionStart,
      selectionEnd: selectionEnd ?? this.selectionEnd,
      scrollOffset: scrollOffset ?? this.scrollOffset,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bookId': bookId,
      'chapterIndex': chapterIndex,
      'selectedText': selectedText,
      'selectionStart': selectionStart,
      'selectionEnd': selectionEnd,
      'scrollOffset': scrollOffset,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ResumeMarker.fromMap(Map<String, dynamic> map) {
    return ResumeMarker(
      bookId: map['bookId'] as int,
      chapterIndex: map['chapterIndex'] as int,
      selectedText: map['selectedText'] as String,
      selectionStart: map['selectionStart'] as int,
      selectionEnd: map['selectionEnd'] as int,
      scrollOffset: (map['scrollOffset'] as num).toDouble(),
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  @override
  String toString() {
    return 'ResumeMarker(bookId: $bookId, chapterIndex: $chapterIndex, '
        'selectedText: $selectedText, selectionStart: $selectionStart, '
        'selectionEnd: $selectionEnd, scrollOffset: $scrollOffset, '
        'createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ResumeMarker &&
        other.bookId == bookId &&
        other.chapterIndex == chapterIndex &&
        other.selectedText == selectedText &&
        other.selectionStart == selectionStart &&
        other.selectionEnd == selectionEnd &&
        other.scrollOffset == scrollOffset &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode =>
      bookId.hashCode ^
      chapterIndex.hashCode ^
      selectedText.hashCode ^
      selectionStart.hashCode ^
      selectionEnd.hashCode ^
      scrollOffset.hashCode ^
      createdAt.hashCode;
}

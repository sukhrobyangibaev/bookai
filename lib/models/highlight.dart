class Highlight {
  final int? id;
  final int bookId;
  final int chapterIndex;
  final String selectedText;
  final String colorHex;
  final DateTime createdAt;

  const Highlight({
    this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.selectedText,
    required this.colorHex,
    required this.createdAt,
  });

  Highlight copyWith({
    int? id,
    int? bookId,
    int? chapterIndex,
    String? selectedText,
    String? colorHex,
    DateTime? createdAt,
  }) {
    return Highlight(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      selectedText: selectedText ?? this.selectedText,
      colorHex: colorHex ?? this.colorHex,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'bookId': bookId,
      'chapterIndex': chapterIndex,
      'selectedText': selectedText,
      'colorHex': colorHex,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Highlight.fromMap(Map<String, dynamic> map) {
    return Highlight(
      id: map['id'] as int?,
      bookId: map['bookId'] as int,
      chapterIndex: map['chapterIndex'] as int,
      selectedText: map['selectedText'] as String,
      colorHex: map['colorHex'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  @override
  String toString() {
    return 'Highlight(id: $id, bookId: $bookId, chapterIndex: $chapterIndex, '
        'selectedText: $selectedText, colorHex: $colorHex, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Highlight &&
        other.id == id &&
        other.bookId == bookId &&
        other.chapterIndex == chapterIndex &&
        other.selectedText == selectedText;
  }

  @override
  int get hashCode =>
      id.hashCode ^
      bookId.hashCode ^
      chapterIndex.hashCode ^
      selectedText.hashCode;
}

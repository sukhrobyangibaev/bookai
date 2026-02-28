class Bookmark {
  final int? id;
  final int bookId;
  final int chapterIndex;
  final String excerpt;
  final DateTime createdAt;

  const Bookmark({
    this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.excerpt,
    required this.createdAt,
  });

  Bookmark copyWith({
    int? id,
    int? bookId,
    int? chapterIndex,
    String? excerpt,
    DateTime? createdAt,
  }) {
    return Bookmark(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      excerpt: excerpt ?? this.excerpt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'bookId': bookId,
      'chapterIndex': chapterIndex,
      'excerpt': excerpt,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Bookmark.fromMap(Map<String, dynamic> map) {
    return Bookmark(
      id: map['id'] as int?,
      bookId: map['bookId'] as int,
      chapterIndex: map['chapterIndex'] as int,
      excerpt: map['excerpt'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  @override
  String toString() {
    return 'Bookmark(id: $id, bookId: $bookId, chapterIndex: $chapterIndex, '
        'excerpt: $excerpt, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Bookmark &&
        other.id == id &&
        other.bookId == bookId &&
        other.chapterIndex == chapterIndex;
  }

  @override
  int get hashCode => id.hashCode ^ bookId.hashCode ^ chapterIndex.hashCode;
}

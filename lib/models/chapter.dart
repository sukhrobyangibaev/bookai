class Chapter {
  final int? id;
  final int? bookId;
  final int index;
  final String title;
  final String content;

  const Chapter({
    this.id,
    this.bookId,
    required this.index,
    required this.title,
    required this.content,
  });

  Chapter copyWith({
    int? id,
    int? bookId,
    int? index,
    String? title,
    String? content,
  }) {
    return Chapter(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      index: index ?? this.index,
      title: title ?? this.title,
      content: content ?? this.content,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (bookId != null) 'bookId': bookId,
      'index': index,
      'title': title,
      'content': content,
    };
  }

  factory Chapter.fromMap(Map<String, dynamic> map) {
    return Chapter(
      id: map['id'] as int?,
      bookId: map['bookId'] as int?,
      index: map['index'] as int,
      title: map['title'] as String,
      content: map['content'] as String,
    );
  }

  @override
  String toString() {
    return 'Chapter(id: $id, bookId: $bookId, index: $index, title: $title)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Chapter &&
        other.id == id &&
        other.bookId == bookId &&
        other.index == index;
  }

  @override
  int get hashCode => id.hashCode ^ bookId.hashCode ^ index.hashCode;
}

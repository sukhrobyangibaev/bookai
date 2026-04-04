class Book {
  final int? id;
  final String? syncKey;
  final String title;
  final String author;
  final String filePath;
  final String? coverPath;
  final int totalChapters;
  final DateTime createdAt;

  const Book({
    this.id,
    this.syncKey,
    required this.title,
    required this.author,
    required this.filePath,
    this.coverPath,
    required this.totalChapters,
    required this.createdAt,
  });

  Book copyWith({
    int? id,
    String? syncKey,
    String? title,
    String? author,
    String? filePath,
    String? coverPath,
    int? totalChapters,
    DateTime? createdAt,
  }) {
    return Book(
      id: id ?? this.id,
      syncKey: syncKey ?? this.syncKey,
      title: title ?? this.title,
      author: author ?? this.author,
      filePath: filePath ?? this.filePath,
      coverPath: coverPath ?? this.coverPath,
      totalChapters: totalChapters ?? this.totalChapters,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'syncKey': syncKey,
      'title': title,
      'author': author,
      'filePath': filePath,
      'coverPath': coverPath,
      'totalChapters': totalChapters,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'] as int?,
      syncKey: map['syncKey'] as String?,
      title: map['title'] as String,
      author: map['author'] as String,
      filePath: map['filePath'] as String,
      coverPath: map['coverPath'] as String?,
      totalChapters: map['totalChapters'] as int,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  @override
  String toString() {
    return 'Book(id: $id, syncKey: $syncKey, title: $title, author: $author, '
        'filePath: $filePath, coverPath: $coverPath, '
        'totalChapters: $totalChapters, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Book &&
        other.id == id &&
        other.title == title &&
        other.author == author &&
        other.filePath == filePath;
  }

  @override
  int get hashCode =>
      id.hashCode ^ title.hashCode ^ author.hashCode ^ filePath.hashCode;
}

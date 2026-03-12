import 'package:flutter_test/flutter_test.dart';
import 'package:scroll/models/book.dart';

void main() {
  group('Book', () {
    final now = DateTime(2025, 1, 15, 10, 30);

    test('toMap produces expected keys and values', () {
      final book = Book(
        id: 1,
        title: 'Test Book',
        author: 'Test Author',
        filePath: '/path/to/book.epub',
        coverPath: '/path/to/cover.jpg',
        totalChapters: 10,
        createdAt: now,
      );

      final map = book.toMap();

      expect(map['id'], 1);
      expect(map['title'], 'Test Book');
      expect(map['author'], 'Test Author');
      expect(map['filePath'], '/path/to/book.epub');
      expect(map['coverPath'], '/path/to/cover.jpg');
      expect(map['totalChapters'], 10);
      expect(map['createdAt'], now.toIso8601String());
    });

    test('toMap omits id when null', () {
      final book = Book(
        title: 'No ID Book',
        author: 'Author',
        filePath: '/path.epub',
        totalChapters: 5,
        createdAt: now,
      );

      final map = book.toMap();

      expect(map.containsKey('id'), isFalse);
    });

    test('toMap includes null coverPath', () {
      final book = Book(
        title: 'Book',
        author: 'Author',
        filePath: '/path.epub',
        totalChapters: 1,
        createdAt: now,
      );

      final map = book.toMap();

      expect(map.containsKey('coverPath'), isTrue);
      expect(map['coverPath'], isNull);
    });

    test('fromMap reconstructs Book correctly', () {
      final map = {
        'id': 42,
        'title': 'Restored Book',
        'author': 'Restored Author',
        'filePath': '/restored.epub',
        'coverPath': '/cover.png',
        'totalChapters': 20,
        'createdAt': now.toIso8601String(),
      };

      final book = Book.fromMap(map);

      expect(book.id, 42);
      expect(book.title, 'Restored Book');
      expect(book.author, 'Restored Author');
      expect(book.filePath, '/restored.epub');
      expect(book.coverPath, '/cover.png');
      expect(book.totalChapters, 20);
      expect(book.createdAt, now);
    });

    test('fromMap handles null coverPath', () {
      final map = {
        'id': 1,
        'title': 'Book',
        'author': 'Author',
        'filePath': '/path.epub',
        'coverPath': null,
        'totalChapters': 5,
        'createdAt': now.toIso8601String(),
      };

      final book = Book.fromMap(map);

      expect(book.coverPath, isNull);
    });

    test('roundtrip toMap -> fromMap preserves all fields', () {
      final original = Book(
        id: 7,
        title: 'Roundtrip',
        author: 'RT Author',
        filePath: '/rt.epub',
        coverPath: '/rt-cover.jpg',
        totalChapters: 15,
        createdAt: now,
      );

      final restored = Book.fromMap(original.toMap());

      expect(restored, equals(original));
      expect(restored.coverPath, original.coverPath);
      expect(restored.totalChapters, original.totalChapters);
      expect(restored.createdAt, original.createdAt);
    });

    test('copyWith overrides specified fields only', () {
      final original = Book(
        id: 1,
        title: 'Original',
        author: 'Author',
        filePath: '/file.epub',
        totalChapters: 5,
        createdAt: now,
      );

      final modified = original.copyWith(title: 'Modified', totalChapters: 10);

      expect(modified.title, 'Modified');
      expect(modified.totalChapters, 10);
      expect(modified.id, original.id);
      expect(modified.author, original.author);
      expect(modified.filePath, original.filePath);
      expect(modified.createdAt, original.createdAt);
    });

    test('equality is based on id, title, author, filePath', () {
      final book1 = Book(
        id: 1,
        title: 'Same',
        author: 'Author',
        filePath: '/same.epub',
        totalChapters: 5,
        createdAt: now,
      );
      final book2 = Book(
        id: 1,
        title: 'Same',
        author: 'Author',
        filePath: '/same.epub',
        totalChapters: 99, // different but not part of equality
        createdAt: DateTime(2020),
      );

      expect(book1, equals(book2));
    });
  });
}

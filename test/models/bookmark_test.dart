import 'package:flutter_test/flutter_test.dart';
import 'package:bookai/models/bookmark.dart';

void main() {
  group('Bookmark', () {
    final now = DateTime(2025, 6, 1, 8, 15);

    test('toMap produces expected keys and values', () {
      final bookmark = Bookmark(
        id: 1,
        bookId: 10,
        chapterIndex: 3,
        excerpt: 'The quick brown fox...',
        createdAt: now,
      );

      final map = bookmark.toMap();

      expect(map['id'], 1);
      expect(map['bookId'], 10);
      expect(map['chapterIndex'], 3);
      expect(map['excerpt'], 'The quick brown fox...');
      expect(map['createdAt'], now.toIso8601String());
    });

    test('toMap omits id when null', () {
      final bookmark = Bookmark(
        bookId: 5,
        chapterIndex: 0,
        excerpt: 'Some text',
        createdAt: now,
      );

      final map = bookmark.toMap();

      expect(map.containsKey('id'), isFalse);
    });

    test('fromMap reconstructs Bookmark correctly', () {
      final map = {
        'id': 42,
        'bookId': 7,
        'chapterIndex': 1,
        'excerpt': 'Restored excerpt',
        'createdAt': now.toIso8601String(),
      };

      final bookmark = Bookmark.fromMap(map);

      expect(bookmark.id, 42);
      expect(bookmark.bookId, 7);
      expect(bookmark.chapterIndex, 1);
      expect(bookmark.excerpt, 'Restored excerpt');
      expect(bookmark.createdAt, now);
    });

    test('fromMap handles null id', () {
      final map = {
        'id': null,
        'bookId': 1,
        'chapterIndex': 0,
        'excerpt': 'Text',
        'createdAt': now.toIso8601String(),
      };

      final bookmark = Bookmark.fromMap(map);

      expect(bookmark.id, isNull);
    });

    test('roundtrip toMap -> fromMap preserves all fields', () {
      final original = Bookmark(
        id: 3,
        bookId: 10,
        chapterIndex: 4,
        excerpt: 'Roundtrip excerpt.',
        createdAt: now,
      );

      final restored = Bookmark.fromMap(original.toMap());

      expect(restored, equals(original));
      expect(restored.excerpt, original.excerpt);
      expect(restored.createdAt, original.createdAt);
    });

    test('copyWith overrides specified fields only', () {
      final original = Bookmark(
        id: 1,
        bookId: 2,
        chapterIndex: 3,
        excerpt: 'Original',
        createdAt: now,
      );

      final modified = original.copyWith(excerpt: 'Updated', chapterIndex: 9);

      expect(modified.excerpt, 'Updated');
      expect(modified.chapterIndex, 9);
      expect(modified.id, original.id);
      expect(modified.bookId, original.bookId);
      expect(modified.createdAt, original.createdAt);
    });
  });
}

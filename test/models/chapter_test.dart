import 'package:flutter_test/flutter_test.dart';
import 'package:bookai/models/chapter.dart';

void main() {
  group('Chapter', () {
    test('toMap produces expected keys and values', () {
      const chapter = Chapter(
        id: 1,
        bookId: 10,
        index: 0,
        title: 'Chapter One',
        content: 'Once upon a time...',
      );

      final map = chapter.toMap();

      expect(map['id'], 1);
      expect(map['bookId'], 10);
      expect(map['index'], 0);
      expect(map['title'], 'Chapter One');
      expect(map['content'], 'Once upon a time...');
    });

    test('toMap omits id and bookId when null', () {
      const chapter = Chapter(
        index: 3,
        title: 'Chapter Four',
        content: 'Content here.',
      );

      final map = chapter.toMap();

      expect(map.containsKey('id'), isFalse);
      expect(map.containsKey('bookId'), isFalse);
    });

    test('fromMap reconstructs Chapter correctly', () {
      final map = {
        'id': 5,
        'bookId': 20,
        'index': 2,
        'title': 'Restored Chapter',
        'content': 'Restored content.',
      };

      final chapter = Chapter.fromMap(map);

      expect(chapter.id, 5);
      expect(chapter.bookId, 20);
      expect(chapter.index, 2);
      expect(chapter.title, 'Restored Chapter');
      expect(chapter.content, 'Restored content.');
    });

    test('fromMap handles null id and bookId', () {
      final map = {
        'id': null,
        'bookId': null,
        'index': 0,
        'title': 'Title',
        'content': 'Content',
      };

      final chapter = Chapter.fromMap(map);

      expect(chapter.id, isNull);
      expect(chapter.bookId, isNull);
    });

    test('roundtrip toMap -> fromMap preserves all fields', () {
      const original = Chapter(
        id: 3,
        bookId: 7,
        index: 1,
        title: 'Roundtrip',
        content: 'Full content text.',
      );

      final restored = Chapter.fromMap(original.toMap());

      expect(restored, equals(original));
      expect(restored.content, original.content);
      expect(restored.title, original.title);
    });

    test('copyWith overrides specified fields only', () {
      const original = Chapter(
        id: 1,
        bookId: 2,
        index: 0,
        title: 'Original',
        content: 'Original content',
      );

      final modified =
          original.copyWith(title: 'Modified', content: 'New content');

      expect(modified.title, 'Modified');
      expect(modified.content, 'New content');
      expect(modified.id, original.id);
      expect(modified.bookId, original.bookId);
      expect(modified.index, original.index);
    });
  });
}

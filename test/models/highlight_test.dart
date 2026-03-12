import 'package:flutter_test/flutter_test.dart';
import 'package:scroll/models/highlight.dart';

void main() {
  group('Highlight', () {
    final now = DateTime(2025, 4, 20, 16, 45);

    test('toMap produces expected keys and values', () {
      final highlight = Highlight(
        id: 1,
        bookId: 10,
        chapterIndex: 2,
        selectedText: 'Important passage',
        colorHex: '#FFEB3B',
        createdAt: now,
      );

      final map = highlight.toMap();

      expect(map['id'], 1);
      expect(map['bookId'], 10);
      expect(map['chapterIndex'], 2);
      expect(map['selectedText'], 'Important passage');
      expect(map['colorHex'], '#FFEB3B');
      expect(map['createdAt'], now.toIso8601String());
    });

    test('toMap omits id when null', () {
      final highlight = Highlight(
        bookId: 5,
        chapterIndex: 0,
        selectedText: 'Text',
        colorHex: '#FF0000',
        createdAt: now,
      );

      final map = highlight.toMap();

      expect(map.containsKey('id'), isFalse);
    });

    test('fromMap reconstructs Highlight correctly', () {
      final map = {
        'id': 99,
        'bookId': 7,
        'chapterIndex': 5,
        'selectedText': 'Restored highlight',
        'colorHex': '#00FF00',
        'createdAt': now.toIso8601String(),
      };

      final highlight = Highlight.fromMap(map);

      expect(highlight.id, 99);
      expect(highlight.bookId, 7);
      expect(highlight.chapterIndex, 5);
      expect(highlight.selectedText, 'Restored highlight');
      expect(highlight.colorHex, '#00FF00');
      expect(highlight.createdAt, now);
    });

    test('fromMap handles null id', () {
      final map = {
        'id': null,
        'bookId': 1,
        'chapterIndex': 0,
        'selectedText': 'Text',
        'colorHex': '#AABB00',
        'createdAt': now.toIso8601String(),
      };

      final highlight = Highlight.fromMap(map);

      expect(highlight.id, isNull);
    });

    test('roundtrip toMap -> fromMap preserves all fields', () {
      final original = Highlight(
        id: 8,
        bookId: 3,
        chapterIndex: 1,
        selectedText: 'Roundtrip text',
        colorHex: '#FFEB3B',
        createdAt: now,
      );

      final restored = Highlight.fromMap(original.toMap());

      expect(restored, equals(original));
      expect(restored.colorHex, original.colorHex);
      expect(restored.createdAt, original.createdAt);
    });

    test('copyWith overrides specified fields only', () {
      final original = Highlight(
        id: 1,
        bookId: 2,
        chapterIndex: 0,
        selectedText: 'Original',
        colorHex: '#FFEB3B',
        createdAt: now,
      );

      final modified =
          original.copyWith(selectedText: 'Updated', colorHex: '#0000FF');

      expect(modified.selectedText, 'Updated');
      expect(modified.colorHex, '#0000FF');
      expect(modified.id, original.id);
      expect(modified.bookId, original.bookId);
      expect(modified.chapterIndex, original.chapterIndex);
      expect(modified.createdAt, original.createdAt);
    });

    test('equality includes selectedText', () {
      final h1 = Highlight(
        id: 1,
        bookId: 1,
        chapterIndex: 0,
        selectedText: 'Text A',
        colorHex: '#FFEB3B',
        createdAt: now,
      );
      final h2 = Highlight(
        id: 1,
        bookId: 1,
        chapterIndex: 0,
        selectedText: 'Text B',
        colorHex: '#FFEB3B',
        createdAt: now,
      );

      expect(h1, isNot(equals(h2)));
    });
  });
}

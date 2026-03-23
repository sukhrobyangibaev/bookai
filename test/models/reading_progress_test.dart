import 'package:flutter_test/flutter_test.dart';
import 'package:bookai/models/reading_progress.dart';

void main() {
  group('ReadingProgress', () {
    final now = DateTime(2025, 3, 10, 14, 0);

    test('toMap produces expected keys and values', () {
      final progress = ReadingProgress(
        bookId: 1,
        chapterIndex: 5,
        scrollOffset: 123.45,
        contentOffset: 321,
        updatedAt: now,
      );

      final map = progress.toMap();

      expect(map['bookId'], 1);
      expect(map['chapterIndex'], 5);
      expect(map['scrollOffset'], 123.45);
      expect(map['contentOffset'], 321);
      expect(map['updatedAt'], now.toIso8601String());
    });

    test('fromMap reconstructs ReadingProgress correctly', () {
      final map = {
        'bookId': 42,
        'chapterIndex': 3,
        'scrollOffset': 200.0,
        'contentOffset': 700,
        'updatedAt': now.toIso8601String(),
      };

      final progress = ReadingProgress.fromMap(map);

      expect(progress.bookId, 42);
      expect(progress.chapterIndex, 3);
      expect(progress.scrollOffset, 200.0);
      expect(progress.contentOffset, 700);
      expect(progress.updatedAt, now);
    });

    test('fromMap supports null contentOffset', () {
      final map = {
        'bookId': 42,
        'chapterIndex': 3,
        'scrollOffset': 200.0,
        'contentOffset': null,
        'updatedAt': now.toIso8601String(),
      };

      final progress = ReadingProgress.fromMap(map);

      expect(progress.contentOffset, isNull);
    });

    test('fromMap handles int scrollOffset via num.toDouble()', () {
      final map = {
        'bookId': 1,
        'chapterIndex': 0,
        'scrollOffset': 100, // int, not double
        'contentOffset': 150,
        'updatedAt': now.toIso8601String(),
      };

      final progress = ReadingProgress.fromMap(map);

      expect(progress.scrollOffset, 100.0);
      expect(progress.scrollOffset, isA<double>());
      expect(progress.contentOffset, 150);
    });

    test('roundtrip toMap -> fromMap preserves all fields', () {
      final original = ReadingProgress(
        bookId: 7,
        chapterIndex: 2,
        scrollOffset: 456.78,
        contentOffset: 912,
        updatedAt: now,
      );

      final restored = ReadingProgress.fromMap(original.toMap());

      expect(restored.bookId, original.bookId);
      expect(restored.chapterIndex, original.chapterIndex);
      expect(restored.scrollOffset, original.scrollOffset);
      expect(restored.contentOffset, original.contentOffset);
      expect(restored.updatedAt, original.updatedAt);
    });

    test('copyWith overrides specified fields only', () {
      final original = ReadingProgress(
        bookId: 1,
        chapterIndex: 0,
        scrollOffset: 50.0,
        contentOffset: 75,
        updatedAt: now,
      );

      final modified = original.copyWith(
          chapterIndex: 3, scrollOffset: 999.0, contentOffset: 1000);

      expect(modified.chapterIndex, 3);
      expect(modified.scrollOffset, 999.0);
      expect(modified.contentOffset, 1000);
      expect(modified.bookId, original.bookId);
      expect(modified.updatedAt, original.updatedAt);
    });

    test('copyWith can explicitly clear contentOffset to null', () {
      final original = ReadingProgress(
        bookId: 3,
        chapterIndex: 1,
        scrollOffset: 25.0,
        contentOffset: 180,
        updatedAt: now,
      );

      final modified = original.copyWith(contentOffset: null);

      expect(modified.contentOffset, isNull);
      expect(modified.bookId, original.bookId);
      expect(modified.chapterIndex, original.chapterIndex);
      expect(modified.scrollOffset, original.scrollOffset);
      expect(modified.updatedAt, original.updatedAt);
    });

    test('equality is based on bookId only', () {
      final p1 = ReadingProgress(
        bookId: 1,
        chapterIndex: 0,
        scrollOffset: 0,
        contentOffset: null,
        updatedAt: now,
      );
      final p2 = ReadingProgress(
        bookId: 1,
        chapterIndex: 5,
        scrollOffset: 999,
        contentOffset: 500,
        updatedAt: DateTime(2020),
      );

      expect(p1, equals(p2));
    });
  });
}

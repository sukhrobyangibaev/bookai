import 'package:bookai/models/resume_marker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ResumeMarker', () {
    final now = DateTime(2025, 5, 1, 9, 30);

    test('toMap produces expected keys and values', () {
      final marker = ResumeMarker(
        bookId: 2,
        chapterIndex: 4,
        selectedText: 'Key sentence',
        selectionStart: 120,
        selectionEnd: 132,
        scrollOffset: 480.75,
        createdAt: now,
      );

      final map = marker.toMap();

      expect(map['bookId'], 2);
      expect(map['chapterIndex'], 4);
      expect(map['selectedText'], 'Key sentence');
      expect(map['selectionStart'], 120);
      expect(map['selectionEnd'], 132);
      expect(map['scrollOffset'], 480.75);
      expect(map['createdAt'], now.toIso8601String());
    });

    test('fromMap reconstructs ResumeMarker correctly', () {
      final map = {
        'bookId': 3,
        'chapterIndex': 7,
        'selectedText': 'Resume from this phrase',
        'selectionStart': 44,
        'selectionEnd': 68,
        'scrollOffset': 310.5,
        'createdAt': now.toIso8601String(),
      };

      final marker = ResumeMarker.fromMap(map);

      expect(marker.bookId, 3);
      expect(marker.chapterIndex, 7);
      expect(marker.selectedText, 'Resume from this phrase');
      expect(marker.selectionStart, 44);
      expect(marker.selectionEnd, 68);
      expect(marker.scrollOffset, 310.5);
      expect(marker.createdAt, now);
    });

    test('fromMap handles int scrollOffset via num.toDouble()', () {
      final map = {
        'bookId': 1,
        'chapterIndex': 0,
        'selectedText': 'Text',
        'selectionStart': 1,
        'selectionEnd': 5,
        'scrollOffset': 42,
        'createdAt': now.toIso8601String(),
      };

      final marker = ResumeMarker.fromMap(map);

      expect(marker.scrollOffset, 42.0);
      expect(marker.scrollOffset, isA<double>());
    });

    test('roundtrip toMap -> fromMap preserves all fields', () {
      final original = ResumeMarker(
        bookId: 9,
        chapterIndex: 1,
        selectedText: 'Roundtrip',
        selectionStart: 10,
        selectionEnd: 19,
        scrollOffset: 99.9,
        createdAt: now,
      );

      final restored = ResumeMarker.fromMap(original.toMap());

      expect(restored, equals(original));
    });

    test('copyWith overrides specified fields only', () {
      final original = ResumeMarker(
        bookId: 5,
        chapterIndex: 3,
        selectedText: 'Original',
        selectionStart: 50,
        selectionEnd: 58,
        scrollOffset: 100.0,
        createdAt: now,
      );

      final modified = original.copyWith(
        chapterIndex: 4,
        selectedText: 'Updated',
        scrollOffset: 222.2,
      );

      expect(modified.bookId, original.bookId);
      expect(modified.chapterIndex, 4);
      expect(modified.selectedText, 'Updated');
      expect(modified.selectionStart, original.selectionStart);
      expect(modified.selectionEnd, original.selectionEnd);
      expect(modified.scrollOffset, 222.2);
      expect(modified.createdAt, original.createdAt);
    });
  });
}

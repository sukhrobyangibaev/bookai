import 'package:scroll/models/generated_image.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GeneratedImage', () {
    final now = DateTime(2025, 1, 15, 10, 30);

    GeneratedImage buildImage({
      int? id = 7,
      String? name = 'Lantern Portrait',
    }) {
      return GeneratedImage(
        id: id,
        bookId: 1,
        chapterIndex: 2,
        featureMode: 'selected_text',
        sourceText: 'Lanterns flickered over the harbor.',
        promptText: 'A quiet watercolor portrait in lantern light.',
        name: name,
        filePath: '/tmp/generated.png',
        createdAt: now,
      );
    }

    test('toMap includes name', () {
      final image = buildImage();

      final map = image.toMap();

      expect(map['id'], 7);
      expect(map['name'], 'Lantern Portrait');
      expect(
          map['promptText'], 'A quiet watercolor portrait in lantern light.');
    });

    test('toMap preserves null name', () {
      final image = buildImage(name: null);

      final map = image.toMap();

      expect(map.containsKey('name'), isTrue);
      expect(map['name'], isNull);
    });

    test('fromMap reconstructs nullable name', () {
      final image = GeneratedImage.fromMap({
        'id': 7,
        'bookId': 1,
        'chapterIndex': 2,
        'featureMode': 'selected_text',
        'sourceText': 'Lanterns flickered over the harbor.',
        'promptText': 'A quiet watercolor portrait in lantern light.',
        'name': null,
        'filePath': '/tmp/generated.png',
        'createdAt': now.toIso8601String(),
      });

      expect(image.name, isNull);
      expect(image.createdAt, now);
    });

    test('copyWith can rename and clear name', () {
      final original = buildImage();

      final renamed = original.copyWith(name: 'Moonlit Harbor');
      final cleared = original.copyWith(name: null);

      expect(renamed.name, 'Moonlit Harbor');
      expect(cleared.name, isNull);
      expect(cleared.promptText, original.promptText);
    });

    test('displayName uses custom name before fallback book title', () {
      final named = buildImage(name: 'Moonlit Harbor');
      final unnamed = buildImage(name: null);

      expect(named.displayName('Book Title'), 'Moonlit Harbor');
      expect(unnamed.displayName('Book Title'), 'Book Title');
      expect(unnamed.displayName('   '), 'Generated Image');
    });

    test('roundtrip toMap -> fromMap preserves equality', () {
      final original = buildImage();

      final restored = GeneratedImage.fromMap(original.toMap());

      expect(restored, equals(original));
    });
  });
}

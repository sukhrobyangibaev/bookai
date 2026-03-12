import 'dart:io';

import 'package:scroll/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late Directory tempDir;
  final service = StorageService.instance;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('scroll_storage_test_');
  });

  tearDown(() async {
    await service.resetForTesting();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('saveGeneratedImageDataUrl stores base64 data urls', () async {
    await service.resetForTesting(
      documentsDirectoryProvider: () async => tempDir,
    );

    final file = await service.saveGeneratedImageDataUrl(
      bookId: 1,
      dataUrl:
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO6V1xQAAAAASUVORK5CYII=',
    );

    expect(await file.exists(), isTrue);
    expect(file.path, endsWith('.png'));
    expect(await file.length(), greaterThan(0));
  });

  test('saveGeneratedImageDataUrl downloads hosted image urls', () async {
    final client = MockClient((request) async {
      expect(request.url.toString(), 'https://example.com/generated-image.webp');
      return http.Response.bytes(
        <int>[0, 1, 2, 3],
        200,
        headers: const {'content-type': 'image/webp'},
      );
    });

    await service.resetForTesting(
      documentsDirectoryProvider: () async => tempDir,
      httpClient: client,
    );

    final file = await service.saveGeneratedImageDataUrl(
      bookId: 7,
      dataUrl: 'https://example.com/generated-image.webp',
    );

    expect(await file.exists(), isTrue);
    expect(file.path, endsWith('.webp'));
    expect(await file.readAsBytes(), <int>[0, 1, 2, 3]);
  });
}

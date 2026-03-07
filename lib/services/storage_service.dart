import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Handles file-system operations for epub storage.
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  Future<Directory> Function()? _documentsDirectoryProviderOverride;
  http.Client? _httpClientOverride;

  Future<Directory> _getDocumentsDirectory() {
    final override = _documentsDirectoryProviderOverride;
    if (override != null) {
      return override();
    }
    return getApplicationDocumentsDirectory();
  }

  Future<void> resetForTesting({
    Future<Directory> Function()? documentsDirectoryProvider,
    http.Client? httpClient,
  }) async {
    _documentsDirectoryProviderOverride = documentsDirectoryProvider;
    _httpClientOverride = httpClient;
  }

  /// Returns (and creates if needed) the `<documents>/books/` directory.
  Future<Directory> getBooksDirectory() async {
    final docs = await _getDocumentsDirectory();
    final booksDir = Directory(p.join(docs.path, 'books'));
    if (!await booksDir.exists()) {
      await booksDir.create(recursive: true);
    }
    return booksDir;
  }

  /// Copies [sourceFile] into the books directory.
  ///
  /// Returns the destination [File].
  /// If a file with the same name already exists it is overwritten only when
  /// [overwrite] is `true`; otherwise the existing file is returned as-is.
  Future<File> copyEpubToStorage(
    File sourceFile, {
    bool overwrite = false,
  }) async {
    final booksDir = await getBooksDirectory();
    final fileName = p.basename(sourceFile.path);
    final destination = File(p.join(booksDir.path, fileName));

    if (await destination.exists() && !overwrite) {
      return destination;
    }

    return sourceFile.copy(destination.path);
  }

  /// Deletes the file at [filePath] from storage if it exists.
  Future<void> deleteBookFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<Directory> getGeneratedImagesRootDirectory() async {
    final docs = await _getDocumentsDirectory();
    final imagesDir = Directory(p.join(docs.path, 'generated_images'));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    return imagesDir;
  }

  Future<Directory> getGeneratedImagesDirectoryForBook(int bookId) async {
    final root = await getGeneratedImagesRootDirectory();
    final imagesDir = Directory(p.join(root.path, 'book_$bookId'));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    return imagesDir;
  }

  Future<File> saveGeneratedImageDataUrl({
    required int bookId,
    required String dataUrl,
  }) async {
    final normalizedValue = dataUrl.trim();
    final match = RegExp(
      r'^data:image/([a-zA-Z0-9.+-]+);base64,(.+)$',
      dotAll: true,
    ).firstMatch(normalizedValue);
    if (match != null) {
      final mimeSubtype = match.group(1)!.toLowerCase();
      final base64Payload = match.group(2)!;
      final bytes = base64Decode(base64Payload);
      return _saveGeneratedImageBytes(
        bookId: bookId,
        bytes: bytes,
        extension: _extensionForMimeSubtype(mimeSubtype),
      );
    }

    return _downloadAndSaveGeneratedImage(
      bookId: bookId,
      imageUrl: normalizedValue,
    );
  }

  Future<File> _saveGeneratedImageBytes({
    required int bookId,
    required List<int> bytes,
    required String extension,
  }) async {
    final directory = await getGeneratedImagesDirectoryForBook(bookId);
    final fileName =
        'generated_${DateTime.now().microsecondsSinceEpoch}.${extension.toLowerCase()}';
    final file = File(p.join(directory.path, fileName));
    return file.writeAsBytes(bytes, flush: true);
  }

  Future<File> _downloadAndSaveGeneratedImage({
    required int bookId,
    required String imageUrl,
  }) async {
    final uri = Uri.tryParse(imageUrl);
    if (uri == null || !uri.hasScheme) {
      throw const FormatException(
        'Generated image must be a base64 data URL or an http(s) URL.',
      );
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw const FormatException(
        'Generated image must use an http(s) URL when it is not embedded as base64.',
      );
    }

    final client = _httpClientOverride ?? http.Client();
    final shouldCloseClient = _httpClientOverride == null;

    try {
      final response = await client.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Failed to download generated image ($imageUrl): '
          'HTTP ${response.statusCode}.',
          uri: uri,
        );
      }
      if (response.bodyBytes.isEmpty) {
        throw const FormatException('Downloaded generated image was empty.');
      }

      return _saveGeneratedImageBytes(
        bookId: bookId,
        bytes: response.bodyBytes,
        extension: _extensionForHostedImage(
          uri: uri,
          contentType: response.headers['content-type'],
        ),
      );
    } finally {
      if (shouldCloseClient) {
        client.close();
      }
    }
  }

  String _extensionForHostedImage({
    required Uri uri,
    String? contentType,
  }) {
    final pathExtension = p.extension(uri.path).replaceFirst('.', '').trim();
    if (_isSupportedImageExtension(pathExtension)) {
      return pathExtension.toLowerCase();
    }

    final mimeSubtype = _mimeSubtypeFromContentType(contentType);
    if (mimeSubtype != null) {
      return _extensionForMimeSubtype(mimeSubtype);
    }

    return 'png';
  }

  String _extensionForMimeSubtype(String mimeSubtype) {
    return switch (mimeSubtype.toLowerCase()) {
      'jpeg' || 'jpg' || 'pjpeg' => 'jpg',
      'webp' => 'webp',
      'gif' => 'gif',
      'bmp' => 'bmp',
      'svg+xml' => 'svg',
      _ => 'png',
    };
  }

  String? _mimeSubtypeFromContentType(String? contentType) {
    if (contentType == null || contentType.trim().isEmpty) return null;
    final normalized = contentType.toLowerCase();
    final match = RegExp(r'image/([^;\s]+)').firstMatch(normalized);
    return match?.group(1);
  }

  bool _isSupportedImageExtension(String extension) {
    return switch (extension.toLowerCase()) {
      'png' || 'jpg' || 'jpeg' || 'webp' || 'gif' || 'bmp' || 'svg' => true,
      _ => false,
    };
  }

  Future<void> deleteGeneratedImageFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> deleteGeneratedImagesForBook(int bookId) async {
    final directory = Directory(
      p.join((await getGeneratedImagesRootDirectory()).path, 'book_$bookId'),
    );
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}

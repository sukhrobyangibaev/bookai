import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Handles file-system operations for epub storage.
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  Future<Directory> Function()? _documentsDirectoryProviderOverride;

  Future<Directory> _getDocumentsDirectory() {
    final override = _documentsDirectoryProviderOverride;
    if (override != null) {
      return override();
    }
    return getApplicationDocumentsDirectory();
  }

  Future<void> resetForTesting({
    Future<Directory> Function()? documentsDirectoryProvider,
  }) async {
    _documentsDirectoryProviderOverride = documentsDirectoryProvider;
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
    final match = RegExp(
      r'^data:image/([a-zA-Z0-9.+-]+);base64,(.+)$',
      dotAll: true,
    ).firstMatch(dataUrl.trim());
    if (match == null) {
      throw const FormatException('Generated image must be a base64 data URL.');
    }

    final mimeSubtype = match.group(1)!.toLowerCase();
    final base64Payload = match.group(2)!;
    final bytes = base64Decode(base64Payload);
    final extension = switch (mimeSubtype) {
      'jpeg' || 'jpg' || 'pjpeg' => 'jpg',
      'webp' => 'webp',
      'gif' => 'gif',
      _ => 'png',
    };

    final directory = await getGeneratedImagesDirectoryForBook(bookId);
    final fileName =
        'generated_${DateTime.now().microsecondsSinceEpoch}.$extension';
    final file = File(p.join(directory.path, fileName));
    return file.writeAsBytes(bytes, flush: true);
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

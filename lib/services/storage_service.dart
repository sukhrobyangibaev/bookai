import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Handles file-system operations for epub storage.
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  /// Returns (and creates if needed) the `<documents>/books/` directory.
  Future<Directory> getBooksDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
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
}

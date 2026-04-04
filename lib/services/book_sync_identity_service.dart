import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// Computes stable per-book sync identities from local EPUB files.
class BookSyncIdentityService {
  BookSyncIdentityService._();
  static final BookSyncIdentityService instance = BookSyncIdentityService._();

  String computeSyncKeyForBytes(List<int> bytes) {
    return 'epub-sha256:${sha256.convert(bytes)}';
  }

  Future<String?> computeSyncKeyForFilePath(String filePath) async {
    if (!canComputeSyncKeyForPath(filePath)) {
      return null;
    }

    final file = File(filePath);
    if (!await file.exists()) {
      return null;
    }

    final bytes = await file.readAsBytes();
    return computeSyncKeyForBytes(bytes);
  }

  bool canComputeSyncKeyForPath(String filePath) {
    return p.extension(filePath).toLowerCase() == '.epub';
  }
}

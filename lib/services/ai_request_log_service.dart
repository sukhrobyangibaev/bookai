import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ai_request_log_entry.dart';
import 'database_service.dart';

class AiRequestLogKinds {
  static const String modelList = 'model_list';
  static const String textGeneration = 'text_generation';
  static const String chatGeneration = 'chat_generation';
  static const String imageGeneration = 'image_generation';
}

class AiRequestLogService {
  static const int defaultKeepLatest = 1000;

  final DatabaseService _databaseService;
  final DateTime Function() _clock;
  final int _keepLatest;

  AiRequestLogService({
    DatabaseService? databaseService,
    DateTime Function()? clock,
    int keepLatest = defaultKeepLatest,
  })  : _databaseService = databaseService ?? DatabaseService.instance,
        _clock = clock ?? DateTime.now,
        _keepLatest = keepLatest;

  Future<void> logExchange({
    required String provider,
    required String requestKind,
    required int attempt,
    required String method,
    required Uri uri,
    String? modelId,
    required Map<String, String> requestHeaders,
    String? requestBody,
    http.Response? response,
    Object? error,
    required Duration duration,
  }) async {
    final responseMetadataOnly =
        requestKind == AiRequestLogKinds.imageGeneration;
    final normalizedModelId = modelId?.trim();

    final entry = AiRequestLogEntry(
      createdAt: _clock(),
      provider: provider.trim().toLowerCase(),
      requestKind: requestKind,
      attempt: attempt,
      method: method.trim().toUpperCase(),
      url: uri.toString(),
      modelId: normalizedModelId == null || normalizedModelId.isEmpty
          ? null
          : normalizedModelId,
      requestHeaders: _redactRequestHeaders(requestHeaders),
      requestBody: requestBody,
      responseStatusCode: response?.statusCode,
      responseHeaders:
          response == null ? null : Map<String, String>.from(response.headers),
      responseBody: response == null
          ? null
          : (responseMetadataOnly
              ? _buildImageResponseMetadataOnlyBody(response.body)
              : response.body),
      responseMetadataOnly: responseMetadataOnly,
      durationMs: duration.inMilliseconds,
      errorMessage: error?.toString(),
    );

    try {
      await _databaseService.addAiRequestLogEntry(entry);
      await _databaseService.trimAiRequestLogEntries(
        keepLatest: _keepLatest,
      );
    } catch (_) {
      // Logging should never fail the user-facing AI flow.
    }
  }

  Map<String, String> _redactRequestHeaders(Map<String, String> headers) {
    final redacted = <String, String>{};

    for (final entry in headers.entries) {
      final key = entry.key;
      final normalized = key.trim().toLowerCase();
      final shouldRedact =
          normalized == 'authorization' || normalized == 'x-goog-api-key';
      redacted[key] = shouldRedact ? '<redacted>' : entry.value;
    }

    return redacted;
  }

  String _buildImageResponseMetadataOnlyBody(String body) {
    final trimmedBody = body.trim();
    if (trimmedBody.isEmpty) {
      return jsonEncode(<String, dynamic>{
        'metadataOnly': true,
        'note': 'Empty response body.',
      });
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(trimmedBody);
    } catch (_) {
      return jsonEncode(<String, dynamic>{
        'metadataOnly': true,
        'note': 'Non-JSON image response body omitted.',
        'originalBodyLength': trimmedBody.length,
      });
    }

    return jsonEncode(<String, dynamic>{
      'metadataOnly': true,
      'payload': _sanitizeImagePayloadNode(decoded),
    });
  }

  dynamic _sanitizeImagePayloadNode(dynamic value, {String? keyHint}) {
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final result = <String, dynamic>{};
      for (final entry in map.entries) {
        result[entry.key] = _sanitizeImagePayloadNode(
          entry.value,
          keyHint: entry.key,
        );
      }
      return result;
    }

    if (value is List) {
      return value
          .map(
            (item) => _sanitizeImagePayloadNode(item, keyHint: keyHint),
          )
          .toList(growable: false);
    }

    if (value is String) {
      return _sanitizeImageString(value, keyHint: keyHint);
    }

    return value;
  }

  String _sanitizeImageString(String value, {String? keyHint}) {
    final trimmed = value.trim();
    final normalizedKey = keyHint?.trim().toLowerCase() ?? '';

    if (trimmed.isEmpty) {
      return value;
    }

    if (trimmed.toLowerCase().startsWith('data:image/')) {
      return '<redacted-image-data-url>';
    }

    if (normalizedKey == 'url' || normalizedKey == 'image_url') {
      if (_looksLikeUrl(trimmed)) {
        return '<redacted-image-url>';
      }
    }

    if (_isImageBytesKey(normalizedKey) && _looksLikeBase64(trimmed)) {
      return '<redacted-image-bytes>';
    }

    if (trimmed.length > 1200) {
      return '${trimmed.substring(0, 320)}...<truncated>';
    }

    return value;
  }

  bool _isImageBytesKey(String key) {
    return key == 'data' ||
        key == 'bytesbase64encoded' ||
        key == 'bytes_base64_encoded' ||
        key == 'imagebytes';
  }

  bool _looksLikeUrl(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }

  bool _looksLikeBase64(String value) {
    final compact = value.replaceAll(RegExp(r'\s+'), '');
    if (compact.length < 64) return false;
    if (compact.length % 4 != 0) return false;
    return RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(compact);
  }
}

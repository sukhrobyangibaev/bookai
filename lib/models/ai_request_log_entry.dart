import 'dart:convert';

class AiRequestLogEntry {
  final int? id;
  final DateTime createdAt;
  final String provider;
  final String requestKind;
  final int attempt;
  final String method;
  final String url;
  final String? modelId;
  final Map<String, String> requestHeaders;
  final String? requestBody;
  final int? responseStatusCode;
  final Map<String, String>? responseHeaders;
  final String? responseBody;
  final bool responseMetadataOnly;
  final int? durationMs;
  final String? errorMessage;

  const AiRequestLogEntry({
    this.id,
    required this.createdAt,
    required this.provider,
    required this.requestKind,
    required this.attempt,
    required this.method,
    required this.url,
    this.modelId,
    required this.requestHeaders,
    this.requestBody,
    this.responseStatusCode,
    this.responseHeaders,
    this.responseBody,
    this.responseMetadataOnly = false,
    this.durationMs,
    this.errorMessage,
  });

  AiRequestLogEntry copyWith({
    int? id,
    DateTime? createdAt,
    String? provider,
    String? requestKind,
    int? attempt,
    String? method,
    String? url,
    Object? modelId = _aiRequestLogEntryModelIdUnset,
    Map<String, String>? requestHeaders,
    Object? requestBody = _aiRequestLogEntryRequestBodyUnset,
    Object? responseStatusCode = _aiRequestLogEntryResponseStatusCodeUnset,
    Object? responseHeaders = _aiRequestLogEntryResponseHeadersUnset,
    Object? responseBody = _aiRequestLogEntryResponseBodyUnset,
    bool? responseMetadataOnly,
    Object? durationMs = _aiRequestLogEntryDurationMsUnset,
    Object? errorMessage = _aiRequestLogEntryErrorMessageUnset,
  }) {
    return AiRequestLogEntry(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      provider: provider ?? this.provider,
      requestKind: requestKind ?? this.requestKind,
      attempt: attempt ?? this.attempt,
      method: method ?? this.method,
      url: url ?? this.url,
      modelId: identical(modelId, _aiRequestLogEntryModelIdUnset)
          ? this.modelId
          : modelId as String?,
      requestHeaders: requestHeaders ?? this.requestHeaders,
      requestBody: identical(requestBody, _aiRequestLogEntryRequestBodyUnset)
          ? this.requestBody
          : requestBody as String?,
      responseStatusCode: identical(
              responseStatusCode, _aiRequestLogEntryResponseStatusCodeUnset)
          ? this.responseStatusCode
          : responseStatusCode as int?,
      responseHeaders:
          identical(responseHeaders, _aiRequestLogEntryResponseHeadersUnset)
              ? this.responseHeaders
              : responseHeaders as Map<String, String>?,
      responseBody: identical(responseBody, _aiRequestLogEntryResponseBodyUnset)
          ? this.responseBody
          : responseBody as String?,
      responseMetadataOnly: responseMetadataOnly ?? this.responseMetadataOnly,
      durationMs: identical(durationMs, _aiRequestLogEntryDurationMsUnset)
          ? this.durationMs
          : durationMs as int?,
      errorMessage: identical(errorMessage, _aiRequestLogEntryErrorMessageUnset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'createdAt': createdAt.toIso8601String(),
      'provider': provider,
      'requestKind': requestKind,
      'attempt': attempt,
      'method': method,
      'url': url,
      'modelId': modelId,
      'requestHeaders': jsonEncode(requestHeaders),
      'requestBody': requestBody,
      'responseStatusCode': responseStatusCode,
      'responseHeaders':
          responseHeaders == null ? null : jsonEncode(responseHeaders),
      'responseBody': responseBody,
      'responseMetadataOnly': responseMetadataOnly ? 1 : 0,
      'durationMs': durationMs,
      'errorMessage': errorMessage,
    };
  }

  factory AiRequestLogEntry.fromMap(Map<String, dynamic> map) {
    return AiRequestLogEntry(
      id: map['id'] as int?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      provider: map['provider'] as String,
      requestKind: map['requestKind'] as String,
      attempt: (map['attempt'] as num?)?.toInt() ?? 1,
      method: map['method'] as String,
      url: map['url'] as String,
      modelId: map['modelId'] as String?,
      requestHeaders: _decodeHeaders(map['requestHeaders']),
      requestBody: map['requestBody'] as String?,
      responseStatusCode: (map['responseStatusCode'] as num?)?.toInt(),
      responseHeaders: _decodeNullableHeaders(map['responseHeaders']),
      responseBody: map['responseBody'] as String?,
      responseMetadataOnly:
          ((map['responseMetadataOnly'] as num?)?.toInt() ?? 0) != 0,
      durationMs: (map['durationMs'] as num?)?.toInt(),
      errorMessage: map['errorMessage'] as String?,
    );
  }

  static Map<String, String> _decodeHeaders(dynamic raw) {
    if (raw is! String || raw.trim().isEmpty) return const <String, String>{};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(
            key.toString(),
            value.toString(),
          ),
        );
      }
    } catch (_) {
      return const <String, String>{};
    }

    return const <String, String>{};
  }

  static Map<String, String>? _decodeNullableHeaders(dynamic raw) {
    if (raw == null) return null;
    final decoded = _decodeHeaders(raw);
    if (decoded.isEmpty) {
      final rawString = raw is String ? raw.trim() : raw.toString().trim();
      if (rawString.isEmpty) return null;
    }
    return decoded;
  }
}

const Object _aiRequestLogEntryModelIdUnset = Object();
const Object _aiRequestLogEntryRequestBodyUnset = Object();
const Object _aiRequestLogEntryResponseStatusCodeUnset = Object();
const Object _aiRequestLogEntryResponseHeadersUnset = Object();
const Object _aiRequestLogEntryResponseBodyUnset = Object();
const Object _aiRequestLogEntryDurationMsUnset = Object();
const Object _aiRequestLogEntryErrorMessageUnset = Object();

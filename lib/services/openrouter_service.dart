import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/openrouter_model.dart';

class OpenRouterException implements Exception {
  final String message;
  final Object? cause;

  const OpenRouterException(this.message, {this.cause});

  @override
  String toString() => message;
}

class OpenRouterService {
  static final Uri _modelsUri =
      Uri.parse('https://openrouter.ai/api/v1/models');

  final http.Client _client;
  final DateTime Function() _clock;
  final Duration _cacheTtl;

  List<OpenRouterModel>? _cachedModels;
  DateTime? _cachedAt;
  String? _cachedForApiKey;

  OpenRouterService({
    http.Client? client,
    DateTime Function()? clock,
    Duration cacheTtl = const Duration(minutes: 10),
  })  : _client = client ?? http.Client(),
        _clock = clock ?? DateTime.now,
        _cacheTtl = cacheTtl;

  Future<List<OpenRouterModel>> fetchModels({
    String? apiKey,
    bool forceRefresh = false,
  }) async {
    final normalizedApiKey = apiKey?.trim() ?? '';
    final now = _clock();
    final isCacheValid = _cachedModels != null &&
        _cachedAt != null &&
        _cachedForApiKey == normalizedApiKey &&
        now.difference(_cachedAt!) < _cacheTtl;

    if (!forceRefresh && isCacheValid) {
      return _cachedModels!;
    }

    final headers = <String, String>{'Accept': 'application/json'};
    if (normalizedApiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $normalizedApiKey';
    }

    final http.Response response;
    try {
      response = await _client.get(_modelsUri, headers: headers);
    } catch (error) {
      throw OpenRouterException(
        'Failed to connect to OpenRouter.',
        cause: error,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OpenRouterException(
        'OpenRouter returned ${response.statusCode} while loading models.',
      );
    }

    final decoded = _decodePayload(response.body);
    final rawData = decoded['data'];
    if (rawData is! List) {
      throw const OpenRouterException(
        'OpenRouter response is missing the "data" models list.',
      );
    }

    final models = rawData.map((item) {
      if (item is! Map) {
        throw const OpenRouterException(
          'OpenRouter response contains an invalid model entry.',
        );
      }
      return OpenRouterModel.fromMap(Map<String, dynamic>.from(item));
    }).toList(growable: false);

    models.sort((a, b) {
      final byName = a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          );
      if (byName != 0) return byName;
      return a.id.toLowerCase().compareTo(b.id.toLowerCase());
    });

    _cachedModels = List.unmodifiable(models);
    _cachedAt = now;
    _cachedForApiKey = normalizedApiKey;
    return _cachedModels!;
  }

  void clearCache() {
    _cachedModels = null;
    _cachedAt = null;
    _cachedForApiKey = null;
  }

  Map<String, dynamic> _decodePayload(String body) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (error) {
      throw OpenRouterException(
        'OpenRouter returned malformed JSON.',
        cause: error,
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const OpenRouterException(
        'OpenRouter response must be a JSON object.',
      );
    }

    return decoded;
  }
}

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
  static final Uri _chatCompletionsUri =
      Uri.parse('https://openrouter.ai/api/v1/chat/completions');

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

  Future<String> generateText({
    required String apiKey,
    required String modelId,
    required String prompt,
    double? temperature,
  }) async {
    final normalizedApiKey = apiKey.trim();
    final normalizedModelId = modelId.trim();
    final normalizedPrompt = prompt.trim();

    if (normalizedApiKey.isEmpty) {
      throw const OpenRouterException('OpenRouter API key is required.');
    }
    if (normalizedModelId.isEmpty) {
      throw const OpenRouterException('OpenRouter model id is required.');
    }
    if (normalizedPrompt.isEmpty) {
      throw const OpenRouterException('Prompt cannot be empty.');
    }

    final payload = <String, dynamic>{
      'model': normalizedModelId,
      'messages': <Map<String, String>>[
        {'role': 'user', 'content': normalizedPrompt},
      ],
    };
    if (temperature != null) {
      payload['temperature'] = temperature;
    }

    final http.Response response;
    try {
      response = await _client.post(
        _chatCompletionsUri,
        headers: <String, String>{
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $normalizedApiKey',
        },
        body: jsonEncode(payload),
      );
    } catch (error) {
      throw OpenRouterException(
        'Failed to connect to OpenRouter.',
        cause: error,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OpenRouterException(
        'OpenRouter returned ${response.statusCode} while generating text.',
      );
    }

    final decoded = _decodePayload(response.body);
    return _extractGeneratedText(decoded);
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

  String _extractGeneratedText(Map<String, dynamic> payload) {
    final rawChoices = payload['choices'];
    if (rawChoices is! List || rawChoices.isEmpty) {
      throw const OpenRouterException(
        'OpenRouter response is missing generated choices.',
      );
    }

    final firstChoice = rawChoices.first;
    if (firstChoice is! Map) {
      throw const OpenRouterException(
        'OpenRouter response contains an invalid generated choice.',
      );
    }

    final choice = Map<String, dynamic>.from(firstChoice);
    final rawMessage = choice['message'];
    if (rawMessage is Map) {
      final message = Map<String, dynamic>.from(rawMessage);
      final extracted = _extractTextFromMessageContent(message['content']);
      if (extracted.isNotEmpty) return extracted;
    }

    final fallbackText = choice['text'];
    if (fallbackText is String && fallbackText.trim().isNotEmpty) {
      return fallbackText.trim();
    }

    throw const OpenRouterException(
      'OpenRouter response did not include generated text.',
    );
  }

  String _extractTextFromMessageContent(dynamic content) {
    if (content is String) {
      return content.trim();
    }

    if (content is List) {
      final parts = <String>[];
      for (final item in content) {
        if (item is! Map) continue;
        final value = item['text'];
        if (value is String && value.trim().isNotEmpty) {
          parts.add(value.trim());
        }
      }
      return parts.join('\n').trim();
    }

    return '';
  }
}

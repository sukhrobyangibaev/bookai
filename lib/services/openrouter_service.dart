import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/ai_model_info.dart';
import '../models/ai_chat_message.dart';
import '../models/openrouter_model.dart';

class OpenRouterException implements Exception {
  final String message;
  final Object? cause;

  const OpenRouterException(this.message, {this.cause});

  @override
  String toString() => message;
}

class OpenRouterImageGenerationResult {
  final String assistantText;
  final List<String> imageUrls;

  const OpenRouterImageGenerationResult({
    required this.assistantText,
    required this.imageUrls,
  });
}

class OpenRouterService {
  static final Uri _modelsUri =
      Uri.parse('https://openrouter.ai/api/v1/models');
  static final Uri _chatCompletionsUri =
      Uri.parse('https://openrouter.ai/api/v1/chat/completions');
  static const String _appReferer = 'https://bookai.app';
  static const String _appTitle = 'BookAI';

  final http.Client _client;
  final DateTime Function() _clock;
  final Duration _cacheTtl;
  final Duration _requestTimeout;

  List<OpenRouterModel>? _cachedModels;
  DateTime? _cachedAt;
  String? _cachedForApiKey;

  OpenRouterService({
    http.Client? client,
    DateTime Function()? clock,
    Duration cacheTtl = const Duration(minutes: 10),
    Duration requestTimeout = const Duration(seconds: 75),
  })  : _client = client ?? http.Client(),
        _clock = clock ?? DateTime.now,
        _cacheTtl = cacheTtl,
        _requestTimeout = requestTimeout;

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

    final http.Response response;
    try {
      response = await _client
          .get(
            _modelsUri,
            headers: _buildHeaders(apiKey: normalizedApiKey),
          )
          .timeout(_requestTimeout);
    } on TimeoutException catch (error) {
      throw OpenRouterException(
        'OpenRouter timed out while loading models. Please try again.',
        cause: error,
      );
    } catch (error) {
      throw OpenRouterException(
        'Failed to connect to OpenRouter.',
        cause: error,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OpenRouterException(
        _buildStatusErrorMessage(
          statusCode: response.statusCode,
          action: 'loading models',
          responseBody: response.body,
        ),
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

  Future<List<AiModelInfo>> fetchModelInfos({
    String? apiKey,
    bool forceRefresh = false,
  }) async {
    final models = await fetchModels(
      apiKey: apiKey,
      forceRefresh: forceRefresh,
    );
    return models.map((model) => model.toAiModelInfo()).toList(growable: false);
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
    return generateTextMessages(
      apiKey: apiKey,
      modelId: modelId,
      messages: <AiChatMessage>[
        AiChatMessage.user(prompt),
      ],
      temperature: temperature,
    );
  }

  Future<String> generateTextMessages({
    required String apiKey,
    required String modelId,
    required List<AiChatMessage> messages,
    double? temperature,
  }) async {
    final decoded = await _sendChatCompletion(
      apiKey: apiKey,
      modelId: modelId,
      messages: messages,
      temperature: temperature,
      action: 'generating text',
    );
    return _extractGeneratedText(decoded);
  }

  Future<OpenRouterImageGenerationResult> generateImage({
    required String apiKey,
    required String modelId,
    required String prompt,
    List<String> modalities = const <String>['image', 'text'],
    double? temperature,
  }) async {
    final normalizedModalities = modalities
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (normalizedModalities.isEmpty) {
      throw const OpenRouterException(
        'At least one response modality is required.',
      );
    }

    final decoded = await _sendChatCompletion(
      apiKey: apiKey,
      modelId: modelId,
      prompt: prompt,
      temperature: temperature,
      action: 'generating images',
      modalities: normalizedModalities,
    );
    return _extractGeneratedImages(decoded);
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

  Future<Map<String, dynamic>> _sendChatCompletion({
    required String apiKey,
    required String modelId,
    required String action,
    String? prompt,
    List<AiChatMessage>? messages,
    List<String>? modalities,
    double? temperature,
  }) async {
    final normalizedApiKey = apiKey.trim();
    final normalizedModelId = modelId.trim();

    if (normalizedApiKey.isEmpty) {
      throw const OpenRouterException('OpenRouter API key is required.');
    }
    if (normalizedModelId.isEmpty) {
      throw const OpenRouterException('OpenRouter model id is required.');
    }

    final payloadMessages = _normalizeMessages(
      prompt: prompt,
      messages: messages,
    );

    final payload = <String, dynamic>{
      'model': normalizedModelId,
      'messages': payloadMessages
          .map((message) => <String, String>{
                'role': message.role == AiChatMessageRole.user
                    ? 'user'
                    : 'assistant',
                'content': message.normalizedContent,
              })
          .toList(growable: false),
    };
    if (modalities != null && modalities.isNotEmpty) {
      payload['modalities'] = modalities;
    }
    if (temperature != null) {
      payload['temperature'] = temperature;
    }

    final http.Response response;
    try {
      if (kDebugMode) {
        _debugLog('Request payload: ${jsonEncode(payload)}');
      }
      response = await _client
          .post(
            _chatCompletionsUri,
            headers: _buildHeaders(
              apiKey: normalizedApiKey,
              includeJsonContentType: true,
            ),
            body: jsonEncode(payload),
          )
          .timeout(_requestTimeout);
    } on TimeoutException catch (error) {
      throw OpenRouterException(
        'OpenRouter timed out while $action. Please try again.',
        cause: error,
      );
    } catch (error) {
      throw OpenRouterException(
        'Failed to connect to OpenRouter.',
        cause: error,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OpenRouterException(
        _buildStatusErrorMessage(
          statusCode: response.statusCode,
          action: action,
          responseBody: response.body,
        ),
      );
    }

    return _decodePayload(response.body);
  }

  List<AiChatMessage> _normalizeMessages({
    String? prompt,
    List<AiChatMessage>? messages,
  }) {
    if (messages != null) {
      final normalizedMessages = messages
          .map(
            (message) => AiChatMessage(
              role: message.role,
              content: message.normalizedContent,
            ),
          )
          .where((message) => message.content.isNotEmpty)
          .toList(growable: false);
      if (normalizedMessages.isEmpty) {
        throw const OpenRouterException('At least one message is required.');
      }
      return normalizedMessages;
    }

    final normalizedPrompt = prompt?.trim() ?? '';
    if (normalizedPrompt.isEmpty) {
      throw const OpenRouterException('Prompt cannot be empty.');
    }
    return <AiChatMessage>[AiChatMessage.user(normalizedPrompt)];
  }

  String _extractGeneratedText(Map<String, dynamic> payload) {
    final choice = _extractFirstChoice(payload);
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

  OpenRouterImageGenerationResult _extractGeneratedImages(
    Map<String, dynamic> payload,
  ) {
    final choice = _extractFirstChoice(payload);
    final rawMessage = choice['message'];
    if (rawMessage is! Map) {
      throw const OpenRouterException(
        'OpenRouter response did not include a valid assistant message.',
      );
    }

    final message = Map<String, dynamic>.from(rawMessage);
    final imageUrls = _extractImageUrls(
      content: message['content'],
      images: message['images'],
    );

    if (imageUrls.isEmpty) {
      throw const OpenRouterException(
        'OpenRouter response did not include generated images.',
      );
    }

    return OpenRouterImageGenerationResult(
      assistantText: _extractTextFromMessageContent(message['content']),
      imageUrls: imageUrls,
    );
  }

  Map<String, dynamic> _extractFirstChoice(Map<String, dynamic> payload) {
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

    return Map<String, dynamic>.from(firstChoice);
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

  List<String> _extractImageUrls({
    required dynamic content,
    required dynamic images,
  }) {
    final results = <String>[];

    if (images is List) {
      for (final item in images) {
        final url = _extractImageUrl(item);
        if (url.isNotEmpty) {
          results.add(url);
        }
      }
    }

    if (content is List) {
      for (final item in content) {
        final url = _extractImageUrl(item);
        if (url.isNotEmpty) {
          results.add(url);
        }
      }
    }

    return results.toSet().toList(growable: false);
  }

  String _extractImageUrl(dynamic item) {
    if (item is! Map) return '';

    final map = Map<String, dynamic>.from(item);
    final directUrl = map['url'];
    if (directUrl is String && directUrl.trim().isNotEmpty) {
      return directUrl.trim();
    }

    final imageUrl = map['image_url'];
    if (imageUrl is String && imageUrl.trim().isNotEmpty) {
      return imageUrl.trim();
    }
    if (imageUrl is Map) {
      final nestedUrl = imageUrl['url'];
      if (nestedUrl is String && nestedUrl.trim().isNotEmpty) {
        return nestedUrl.trim();
      }
    }

    return '';
  }

  void _debugLog(String message) {
    const chunkSize = 800;
    for (var i = 0; i < message.length; i += chunkSize) {
      debugPrint(
        '[OpenRouter] ${message.substring(i, i + chunkSize > message.length ? message.length : i + chunkSize)}',
      );
    }
  }

  Map<String, String> _buildHeaders({
    String? apiKey,
    bool includeJsonContentType = false,
  }) {
    final headers = <String, String>{
      'Accept': 'application/json',
      'HTTP-Referer': _appReferer,
      'X-Title': _appTitle,
    };

    final normalizedApiKey = apiKey?.trim() ?? '';
    if (normalizedApiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $normalizedApiKey';
    }

    if (includeJsonContentType) {
      headers['Content-Type'] = 'application/json';
    }

    return headers;
  }

  String _buildStatusErrorMessage({
    required int statusCode,
    required String action,
    required String responseBody,
  }) {
    final detail = _extractErrorDetail(responseBody);
    if (detail.isEmpty) {
      return 'OpenRouter returned $statusCode while $action.';
    }
    return 'OpenRouter returned $statusCode while $action: $detail';
  }

  String _extractErrorDetail(String body) {
    final trimmedBody = body.trim();
    if (trimmedBody.isEmpty) return '';

    dynamic decoded;
    try {
      decoded = jsonDecode(trimmedBody);
    } catch (_) {
      return _truncateErrorDetail(trimmedBody);
    }

    if (decoded is! Map) {
      return _truncateErrorDetail(trimmedBody);
    }

    final payload = Map<String, dynamic>.from(decoded);
    final candidates = <String>[
      _extractString(payload['message']),
      _extractString(payload['error_message']),
      _extractString(payload['detail']),
    ];

    final rawError = payload['error'];
    if (rawError is String) {
      candidates.add(rawError);
    } else if (rawError is Map) {
      final errorMap = Map<String, dynamic>.from(rawError);
      candidates.add(_extractString(errorMap['message']));
      candidates.add(_extractString(errorMap['detail']));
      candidates.add(_extractString(errorMap['code']));
    }

    for (final candidate in candidates) {
      final normalized = _normalizeErrorDetail(candidate);
      if (normalized.isNotEmpty) {
        return _truncateErrorDetail(normalized);
      }
    }

    return _truncateErrorDetail(trimmedBody);
  }

  String _extractString(Object? value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }

  String _normalizeErrorDetail(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _truncateErrorDetail(String value) {
    if (value.length <= 240) return value;
    return '${value.substring(0, 237)}...';
  }
}

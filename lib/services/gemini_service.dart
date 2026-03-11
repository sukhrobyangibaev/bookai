import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../models/ai_model_info.dart';
import '../models/ai_chat_message.dart';
import '../models/ai_provider.dart';

class GeminiException implements Exception {
  final String message;
  final Object? cause;

  const GeminiException(this.message, {this.cause});

  @override
  String toString() => message;
}

class GeminiImageGenerationResult {
  final String assistantText;
  final List<String> imageDataUrls;

  const GeminiImageGenerationResult({
    required this.assistantText,
    required this.imageDataUrls,
  });
}

class GeminiService {
  static final Uri _modelsUri =
      Uri.parse('https://generativelanguage.googleapis.com/v1beta/models');
  static const Duration _defaultRequestTimeout = Duration(seconds: 120);
  static const Duration _previewImageRequestTimeout = Duration(minutes: 10);
  static const List<Map<String, String>> _relaxedSafetySettings =
      <Map<String, String>>[
    {
      'category': 'HARM_CATEGORY_HARASSMENT',
      'threshold': 'BLOCK_NONE',
    },
    {
      'category': 'HARM_CATEGORY_HATE_SPEECH',
      'threshold': 'BLOCK_NONE',
    },
    {
      'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
      'threshold': 'BLOCK_NONE',
    },
    {
      'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
      'threshold': 'BLOCK_NONE',
    },
  ];

  final http.Client _client;
  final DateTime Function() _clock;
  final Duration _cacheTtl;
  final Duration _requestTimeout;
  final Duration _retryBaseDelay;
  final Future<void> Function(Duration) _sleep;
  final math.Random _random;

  static const int _maxAttempts = 2;

  List<AiModelInfo>? _cachedModels;
  DateTime? _cachedAt;
  String? _cachedForApiKey;

  GeminiService({
    http.Client? client,
    DateTime Function()? clock,
    Duration cacheTtl = const Duration(minutes: 10),
    Duration requestTimeout = _defaultRequestTimeout,
    Duration retryBaseDelay = const Duration(milliseconds: 250),
    Future<void> Function(Duration)? sleep,
    math.Random? random,
  })  : _client = client ?? http.Client(),
        _clock = clock ?? DateTime.now,
        _cacheTtl = cacheTtl,
        _requestTimeout = requestTimeout,
        _retryBaseDelay = retryBaseDelay,
        _sleep = sleep ?? Future<void>.delayed,
        _random = random ?? math.Random();

  Future<List<AiModelInfo>> fetchModels({
    required String apiKey,
    bool forceRefresh = false,
  }) async {
    final normalizedApiKey = apiKey.trim();
    if (normalizedApiKey.isEmpty) {
      throw const GeminiException('Gemini API key is required.');
    }

    final now = _clock();
    final isCacheValid = _cachedModels != null &&
        _cachedAt != null &&
        _cachedForApiKey == normalizedApiKey &&
        now.difference(_cachedAt!) < _cacheTtl;

    if (!forceRefresh && isCacheValid) {
      return _cachedModels!;
    }

    final models = <AiModelInfo>[];
    String? nextPageToken;

    do {
      final queryParameters = <String, String>{
        'pageSize': '1000',
        if (nextPageToken != null && nextPageToken.isNotEmpty)
          'pageToken': nextPageToken,
      };

      final response = await _sendRequest(
        action: 'loading models',
        send: () => _client.get(
          _modelsUri.replace(queryParameters: queryParameters),
          headers: _buildHeaders(apiKey: normalizedApiKey),
        ),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw GeminiException(
          _buildStatusErrorMessage(
            statusCode: response.statusCode,
            action: 'loading models',
            responseBody: response.body,
          ),
        );
      }

      final decoded = _decodePayload(response.body);
      final rawModels = decoded['models'];
      if (rawModels is! List) {
        throw const GeminiException(
          'Gemini response is missing the "models" list.',
        );
      }

      for (final item in rawModels) {
        if (item is! Map) {
          throw const GeminiException(
            'Gemini response contains an invalid model entry.',
          );
        }

        models.add(
          _parseModelInfo(Map<String, dynamic>.from(item)),
        );
      }

      nextPageToken = (decoded['nextPageToken'] as String?)?.trim();
    } while (nextPageToken != null && nextPageToken.isNotEmpty);

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
    final decoded = await _generateContent(
      apiKey: apiKey,
      modelId: modelId,
      messages: messages,
      temperature: temperature,
      action: 'generating text',
      thinkingConfig: _thinkingConfigForTextModel(modelId),
      safetySettings: _safetySettingsForTextModel(modelId),
    );
    final text = _extractText(decoded);
    if (text.isEmpty) {
      throw const GeminiException(
        'Gemini response did not include generated text.',
      );
    }
    return text;
  }

  Future<GeminiImageGenerationResult> generateImage({
    required String apiKey,
    required String modelId,
    required String prompt,
    double? temperature,
  }) async {
    final normalizedModelId = modelId.trim();
    if (_isImagenModelId(normalizedModelId)) {
      return _predictImagen(
        apiKey: apiKey,
        modelId: normalizedModelId,
        prompt: prompt,
      );
    }

    final decoded = await _generateContent(
      apiKey: apiKey,
      modelId: normalizedModelId,
      prompt: prompt,
      temperature: temperature,
      action: 'generating images',
      responseModalities: _responseModalitiesForImageModel(normalizedModelId),
      requestTimeout: _requestTimeoutForImageModel(normalizedModelId),
      maxAttempts: _maxAttemptsForImageModel(normalizedModelId),
    );
    final assistantText = _extractText(decoded);
    final imageDataUrls = _extractInlineImageDataUrls(decoded);
    if (imageDataUrls.isEmpty) {
      if (assistantText.isNotEmpty) {
        throw GeminiException(assistantText);
      }
      throw const GeminiException(
          'Gemini response did not include generated images.');
    }

    return GeminiImageGenerationResult(
      assistantText: assistantText,
      imageDataUrls: imageDataUrls,
    );
  }

  Future<Map<String, dynamic>> _generateContent({
    required String apiKey,
    required String modelId,
    required String action,
    String? prompt,
    List<AiChatMessage>? messages,
    List<String>? responseModalities,
    double? temperature,
    Map<String, dynamic>? thinkingConfig,
    Map<String, dynamic>? imageConfig,
    List<Map<String, String>>? safetySettings,
    Duration? requestTimeout,
    int? maxAttempts,
  }) async {
    final normalizedApiKey = apiKey.trim();
    final normalizedModelId = modelId.trim();

    if (normalizedApiKey.isEmpty) {
      throw const GeminiException('Gemini API key is required.');
    }
    if (normalizedModelId.isEmpty) {
      throw const GeminiException('Gemini model id is required.');
    }

    final payload = <String, dynamic>{
      'contents': _normalizeMessages(
        prompt: prompt,
        messages: messages,
      )
          .map(
            (message) => <String, dynamic>{
              'role': message.role == AiChatMessageRole.user ? 'user' : 'model',
              'parts': <Map<String, String>>[
                {'text': message.normalizedContent},
              ],
            },
          )
          .toList(growable: false),
    };

    final generationConfig = <String, dynamic>{};
    if (responseModalities != null && responseModalities.isNotEmpty) {
      generationConfig['responseModalities'] = responseModalities;
    }
    if (temperature != null) {
      generationConfig['temperature'] = temperature;
    }
    if (thinkingConfig != null && thinkingConfig.isNotEmpty) {
      generationConfig['thinkingConfig'] = thinkingConfig;
    }
    if (imageConfig != null && imageConfig.isNotEmpty) {
      generationConfig['imageConfig'] = imageConfig;
    }
    if (generationConfig.isNotEmpty) {
      payload['generationConfig'] = generationConfig;
    }
    if (safetySettings != null && safetySettings.isNotEmpty) {
      payload['safetySettings'] = safetySettings;
    }

    final response = await _sendRequest(
      action: action,
      requestTimeout: requestTimeout,
      maxAttempts: maxAttempts,
      send: () => _client.post(
        _contentUri(modelId: normalizedModelId),
        headers: _buildHeaders(
          apiKey: normalizedApiKey,
          includeJsonContentType: true,
        ),
        body: jsonEncode(payload),
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GeminiException(
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
        throw const GeminiException('At least one message is required.');
      }
      return normalizedMessages;
    }

    final normalizedPrompt = prompt?.trim() ?? '';
    if (normalizedPrompt.isEmpty) {
      throw const GeminiException('Prompt cannot be empty.');
    }
    return <AiChatMessage>[AiChatMessage.user(normalizedPrompt)];
  }

  Future<GeminiImageGenerationResult> _predictImagen({
    required String apiKey,
    required String modelId,
    required String prompt,
  }) async {
    final normalizedApiKey = apiKey.trim();
    final normalizedPrompt = prompt.trim();
    if (normalizedApiKey.isEmpty) {
      throw const GeminiException('Gemini API key is required.');
    }
    if (modelId.trim().isEmpty) {
      throw const GeminiException('Gemini model id is required.');
    }
    if (normalizedPrompt.isEmpty) {
      throw const GeminiException('Prompt cannot be empty.');
    }

    final payload = <String, dynamic>{
      'instances': <Map<String, String>>[
        {'prompt': normalizedPrompt},
      ],
      'parameters': <String, dynamic>{
        'sampleCount': 1,
      },
    };

    final response = await _sendRequest(
      action: 'generating images',
      send: () => _client.post(
        _predictUri(modelId: modelId),
        headers: _buildHeaders(
          apiKey: normalizedApiKey,
          includeJsonContentType: true,
        ),
        body: jsonEncode(payload),
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GeminiException(
        _buildStatusErrorMessage(
          statusCode: response.statusCode,
          action: 'generating images',
          responseBody: response.body,
        ),
      );
    }

    final decoded = _decodePayload(response.body);
    final imageDataUrls = _extractPredictedImageDataUrls(decoded);
    if (imageDataUrls.isEmpty) {
      throw const GeminiException(
        'Gemini response did not include generated images.',
      );
    }

    return GeminiImageGenerationResult(
      assistantText: '',
      imageDataUrls: imageDataUrls,
    );
  }

  AiModelInfo _parseModelInfo(Map<String, dynamic> map) {
    final rawName = (map['name'] as String? ?? '').trim();
    final baseModelId = (map['baseModelId'] as String? ?? '').trim();
    final id =
        baseModelId.isNotEmpty ? baseModelId : _stripModelsPrefix(rawName);
    if (id.isEmpty) {
      throw const GeminiException('Gemini model is missing an identifier.');
    }

    final methods = _parseStringList(map['supportedGenerationMethods']);
    final outputModalities = _inferOutputModalities(
      id: id,
      supportedGenerationMethods: methods,
    );

    return AiModelInfo(
      provider: AiProvider.gemini,
      id: id,
      displayName: (map['displayName'] as String?)?.trim().isNotEmpty == true
          ? (map['displayName'] as String).trim()
          : id,
      description: (map['description'] as String?)?.trim().isNotEmpty == true
          ? (map['description'] as String).trim()
          : null,
      contextLength: (map['inputTokenLimit'] as num?)?.toInt(),
      outputModalities: outputModalities,
    );
  }

  Uri _contentUri({required String modelId}) {
    return Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$modelId:generateContent',
    );
  }

  Uri _predictUri({required String modelId}) {
    return Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$modelId:predict',
    );
  }

  Future<http.Response> _sendRequest({
    required String action,
    Duration? requestTimeout,
    int? maxAttempts,
    required Future<http.Response> Function() send,
  }) async {
    final effectiveTimeout = requestTimeout ?? _requestTimeout;
    final effectiveMaxAttempts = math.max(1, maxAttempts ?? _maxAttempts);

    for (var attempt = 1; attempt <= effectiveMaxAttempts; attempt++) {
      try {
        final response = await send().timeout(effectiveTimeout);
        if (_isRetriableStatusCode(response.statusCode) &&
            attempt < effectiveMaxAttempts) {
          await _sleepBeforeRetry(
            attempt: attempt,
            requestTimeout: effectiveTimeout,
          );
          continue;
        }
        return response;
      } on TimeoutException catch (error) {
        if (attempt < effectiveMaxAttempts) {
          await _sleepBeforeRetry(
            attempt: attempt,
            requestTimeout: effectiveTimeout,
          );
          continue;
        }
        throw GeminiException(
          'Gemini timed out while $action. Please try again.',
          cause: error,
        );
      } catch (error) {
        throw GeminiException(
          'Failed to connect to Gemini.',
          cause: error,
        );
      }
    }

    throw GeminiException('Gemini timed out while $action. Please try again.');
  }

  bool _isRetriableStatusCode(int statusCode) {
    return statusCode == 429 || statusCode >= 500;
  }

  Future<void> _sleepBeforeRetry({
    required int attempt,
    required Duration requestTimeout,
  }) async {
    final baseDelayMs = _retryBaseDelay.inMilliseconds;
    if (baseDelayMs <= 0) return;

    final exponentialMultiplier = 1 << (attempt - 1);
    final jitterFactor = 0.85 + (_random.nextDouble() * 0.3);
    final rawDelayMs =
        (baseDelayMs * exponentialMultiplier * jitterFactor).round();
    final cappedDelayMs = math.min(
      rawDelayMs,
      math.max(1, requestTimeout.inMilliseconds ~/ 4),
    );
    if (cappedDelayMs <= 0) return;

    await _sleep(Duration(milliseconds: cappedDelayMs));
  }

  Map<String, dynamic>? _thinkingConfigForTextModel(String modelId) {
    final normalized = modelId.trim().toLowerCase();
    if (_isGemini25FlashTextModelId(normalized)) {
      return const <String, dynamic>{'thinkingBudget': 0};
    }
    if (_isGemini3FlashPreviewTextModelId(normalized)) {
      return const <String, dynamic>{'thinkingLevel': 'minimal'};
    }
    if (_isGemini31ProPreviewTextModelId(normalized)) {
      return const <String, dynamic>{'thinkingLevel': 'low'};
    }
    return null;
  }

  List<Map<String, String>>? _safetySettingsForTextModel(String modelId) {
    final normalized = modelId.trim().toLowerCase();
    if (_isGemini3FlashPreviewTextModelId(normalized) ||
        _isGemini31ProPreviewTextModelId(normalized)) {
      return _relaxedSafetySettings;
    }
    return null;
  }

  List<String>? _responseModalitiesForImageModel(String modelId) {
    final normalized = modelId.trim().toLowerCase();
    if (_isGemini31FlashImagePreviewModelId(normalized)) {
      // Keep the preview-model request as close as possible to the
      // documented direct Gemini examples.
      return null;
    }
    return const <String>['TEXT', 'IMAGE'];
  }

  Duration? _requestTimeoutForImageModel(String modelId) {
    final normalized = modelId.trim().toLowerCase();
    if (_isGemini31FlashImagePreviewModelId(normalized) &&
        _requestTimeout == _defaultRequestTimeout) {
      return _previewImageRequestTimeout;
    }
    return null;
  }

  int? _maxAttemptsForImageModel(String modelId) {
    final normalized = modelId.trim().toLowerCase();
    if (_isGemini31FlashImagePreviewModelId(normalized)) {
      return 1;
    }
    return null;
  }

  Map<String, dynamic> _decodePayload(String body) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (error) {
      throw GeminiException(
        'Gemini returned malformed JSON.',
        cause: error,
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const GeminiException(
        'Gemini response must be a JSON object.',
      );
    }

    return decoded;
  }

  String _extractText(Map<String, dynamic> payload) {
    final parts = _extractCandidateParts(payload);
    final buffer = <String>[];
    for (final part in parts) {
      final text = part['text'];
      if (text is String && text.trim().isNotEmpty) {
        buffer.add(text.trim());
      }
    }
    return buffer.join('\n').trim();
  }

  List<String> _extractInlineImageDataUrls(Map<String, dynamic> payload) {
    final parts = _extractCandidateParts(payload);
    final results = <String>[];
    for (final part in parts) {
      final imageData = _dataUrlFromInlineData(part['inlineData']);
      if (imageData.isNotEmpty) {
        results.add(imageData);
      }
    }
    return results.toSet().toList(growable: false);
  }

  List<String> _extractPredictedImageDataUrls(Map<String, dynamic> payload) {
    final rawPredictions = payload['predictions'];
    if (rawPredictions is! List) {
      return const <String>[];
    }

    final results = <String>[];
    for (final item in rawPredictions) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final directDataUrl = _predictionDataUrl(map);
      if (directDataUrl.isNotEmpty) {
        results.add(directDataUrl);
      }

      final generatedImages = map['generatedImages'];
      if (generatedImages is List) {
        for (final generated in generatedImages) {
          if (generated is! Map) continue;
          final generatedMap = Map<String, dynamic>.from(generated);
          final nestedDataUrl = _predictionDataUrl(generatedMap);
          if (nestedDataUrl.isNotEmpty) {
            results.add(nestedDataUrl);
          }

          final imageValue = generatedMap['image'];
          if (imageValue is Map) {
            final imageDataUrl = _predictionDataUrl(
              Map<String, dynamic>.from(imageValue),
            );
            if (imageDataUrl.isNotEmpty) {
              results.add(imageDataUrl);
            }
          }
        }
      }
    }

    return results.toSet().toList(growable: false);
  }

  String _predictionDataUrl(Map<String, dynamic> map) {
    final base64Data = _extractBase64(map);
    if (base64Data.isEmpty) return '';

    final mimeType = (map['mimeType'] as String?)?.trim().isNotEmpty == true
        ? (map['mimeType'] as String).trim()
        : 'image/png';
    return 'data:$mimeType;base64,$base64Data';
  }

  String _extractBase64(Map<String, dynamic> map) {
    final direct = _extractString(map['bytesBase64Encoded']);
    if (direct.isNotEmpty) return direct;

    final snakeCase = _extractString(map['bytes_base64_encoded']);
    if (snakeCase.isNotEmpty) return snakeCase;

    final imageBytes = _extractString(map['imageBytes']);
    if (imageBytes.isNotEmpty) return imageBytes;

    final rawInlineData = map['inlineData'];
    if (rawInlineData is Map) {
      final inlineDataUrl = _dataUrlFromInlineData(
        Map<String, dynamic>.from(rawInlineData),
      );
      if (inlineDataUrl.isNotEmpty) {
        return inlineDataUrl.split(',').last;
      }
    }

    final image = map['image'];
    if (image is Map) {
      return _extractBase64(Map<String, dynamic>.from(image));
    }

    return '';
  }

  List<Map<String, dynamic>> _extractCandidateParts(
      Map<String, dynamic> payload) {
    final rawCandidates = payload['candidates'];
    if (rawCandidates is! List || rawCandidates.isEmpty) {
      return const <Map<String, dynamic>>[];
    }

    final firstCandidate = rawCandidates.first;
    if (firstCandidate is! Map) return const <Map<String, dynamic>>[];
    final candidate = Map<String, dynamic>.from(firstCandidate);
    final rawContent = candidate['content'];
    if (rawContent is! Map) return const <Map<String, dynamic>>[];
    final content = Map<String, dynamic>.from(rawContent);
    final rawParts = content['parts'];
    if (rawParts is! List) return const <Map<String, dynamic>>[];

    return rawParts
        .whereType<Map>()
        .map((part) => Map<String, dynamic>.from(part))
        .toList(growable: false);
  }

  String _dataUrlFromInlineData(dynamic inlineData) {
    if (inlineData is! Map) return '';

    final map = Map<String, dynamic>.from(inlineData);
    final data = _extractString(map['data']);
    if (data.isEmpty) return '';

    final mimeType = _extractString(map['mimeType']).isEmpty
        ? 'image/png'
        : _extractString(map['mimeType']);
    return 'data:$mimeType;base64,$data';
  }

  Map<String, String> _buildHeaders({
    required String apiKey,
    bool includeJsonContentType = false,
  }) {
    final headers = <String, String>{
      'Accept': 'application/json',
      'x-goog-api-key': apiKey,
    };

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
      return 'Gemini returned $statusCode while $action.';
    }
    return 'Gemini returned $statusCode while $action: $detail';
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
    final rawError = payload['error'];
    if (rawError is Map) {
      final errorMap = Map<String, dynamic>.from(rawError);
      final message = _extractString(errorMap['message']);
      if (message.isNotEmpty) {
        return _truncateErrorDetail(message);
      }
    }

    return _truncateErrorDetail(trimmedBody);
  }

  List<String> _parseStringList(dynamic raw) {
    if (raw is! List) return const <String>[];
    return raw
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  List<String> _inferOutputModalities({
    required String id,
    required List<String> supportedGenerationMethods,
  }) {
    if (_isImagenModelId(id)) {
      return const <String>['image'];
    }

    if (_isGeminiImageModelId(id)) {
      return const <String>['image', 'text'];
    }

    if (_supportsGenerateContent(supportedGenerationMethods)) {
      return const <String>['text'];
    }

    return const <String>[];
  }

  bool _supportsGenerateContent(List<String> supportedGenerationMethods) {
    for (final method in supportedGenerationMethods) {
      final normalized = method.toLowerCase();
      if (normalized == 'generatecontent' ||
          normalized == 'streamgeneratecontent') {
        return true;
      }
    }
    return false;
  }

  bool _isGeminiImageModelId(String id) {
    final normalized = id.trim().toLowerCase();
    return normalized.contains('flash-image') ||
        normalized.contains('image-generation') ||
        normalized.contains('image-preview');
  }

  bool _isGemini25FlashTextModelId(String id) {
    final normalized = id.trim().toLowerCase();
    return normalized.startsWith('gemini-2.5-flash') &&
        !normalized.contains('flash-lite') &&
        !_isGeminiImageModelId(normalized);
  }

  bool _isGemini3FlashPreviewTextModelId(String id) {
    final normalized = id.trim().toLowerCase();
    return normalized.startsWith('gemini-3-flash-preview') &&
        !_isGeminiImageModelId(normalized);
  }

  bool _isGemini31ProPreviewTextModelId(String id) {
    final normalized = id.trim().toLowerCase();
    return (normalized.startsWith('gemini-3.1-pro-preview') ||
            normalized.startsWith('gemini-3-pro-preview')) &&
        !_isGeminiImageModelId(normalized);
  }

  bool _isGemini31FlashImagePreviewModelId(String id) {
    return id.trim().toLowerCase().startsWith('gemini-3.1-flash-image-preview');
  }

  bool _isImagenModelId(String id) {
    return id.trim().toLowerCase().startsWith('imagen-');
  }

  String _stripModelsPrefix(String value) {
    if (value.startsWith('models/')) {
      return value.substring('models/'.length).trim();
    }
    return value.trim();
  }

  String _extractString(Object? value) {
    if (value == null) return '';
    if (value is String) return value.trim();
    return value.toString().trim();
  }

  String _truncateErrorDetail(String value) {
    if (value.length <= 240) return value;
    return '${value.substring(0, 237)}...';
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:bookai/models/ai_model_info.dart';
import 'package:bookai/models/ai_provider.dart';
import 'package:bookai/services/gemini_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('GeminiService', () {
    const relaxedSafetySettings = <Map<String, String>>[
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

    test('fetchModels paginates and parses provider metadata', () async {
      final requests = <Uri>[];
      final client = MockClient((request) async {
        requests.add(request.url);
        expect(request.headers['x-goog-api-key'], 'test-key');

        final pageToken = request.url.queryParameters['pageToken'];
        if (pageToken == null || pageToken.isEmpty) {
          return http.Response(
            jsonEncode({
              'models': [
                {
                  'name': 'models/gemini-2.5-flash',
                  'displayName': 'Gemini 2.5 Flash',
                  'inputTokenLimit': 1048576,
                  'supportedGenerationMethods': ['generateContent'],
                },
                {
                  'name': 'models/gemini-3-pro-image-preview',
                  'displayName': 'Gemini 3 Pro Image Preview',
                  'supportedGenerationMethods': ['generateContent'],
                },
              ],
              'nextPageToken': 'page-2',
            }),
            200,
          );
        }

        return http.Response(
          jsonEncode({
            'models': [
              {
                'name': 'models/imagen-4.0-generate-001',
                'displayName': 'Imagen 4',
                'supportedGenerationMethods': ['predict'],
              },
            ],
          }),
          200,
        );
      });

      final service = GeminiService(client: client);
      final models = await service.fetchModels(apiKey: 'test-key');

      expect(requests, hasLength(2));
      expect(
        models,
        contains(
          isA<AiModelInfo>()
              .having((model) => model.provider, 'provider', AiProvider.gemini)
              .having((model) => model.id, 'id', 'gemini-2.5-flash')
              .having((model) => model.supportsTextOutput, 'text', isTrue),
        ),
      );
      expect(
        models,
        contains(
          isA<AiModelInfo>()
              .having(
                (model) => model.id,
                'id',
                'gemini-3-pro-image-preview',
              )
              .having((model) => model.supportsTextOutput, 'text', isTrue)
              .having((model) => model.supportsImageOutput, 'image', isTrue),
        ),
      );
      expect(
        models,
        contains(
          isA<AiModelInfo>()
              .having((model) => model.id, 'id', 'imagen-4.0-generate-001')
              .having((model) => model.supportsImageOutput, 'image', isTrue),
        ),
      );
    });

    test('generateText parses text content from generateContent', () async {
      final client = MockClient((request) async {
        expect(request.url.path,
            '/v1beta/models/gemini-2.5-flash:generateContent');
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'Generated answer'},
                  ],
                },
              },
            ],
          }),
          200,
        );
      });

      final service = GeminiService(client: client);
      final text = await service.generateText(
        apiKey: 'test-key',
        modelId: 'gemini-2.5-flash',
        prompt: 'Hello',
      );

      expect(text, 'Generated answer');
    });

    test('generateText sends Gemini 3 Flash Preview defaults', () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final contents = body['contents'] as List<dynamic>;
        expect(contents.single['role'], 'user');
        final generationConfig =
            body['generationConfig'] as Map<String, dynamic>;
        expect(
          generationConfig['thinkingConfig'],
          {'thinkingLevel': 'minimal'},
        );
        expect(body['safetySettings'], relaxedSafetySettings);
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'Generated answer'},
                  ],
                },
              },
            ],
          }),
          200,
        );
      });

      final service = GeminiService(client: client);
      final text = await service.generateText(
        apiKey: 'test-key',
        modelId: 'gemini-3-flash-preview',
        prompt: 'Hello',
      );

      expect(text, 'Generated answer');
    });

    test('generateText sends Gemini 3.1 Pro Preview defaults', () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final contents = body['contents'] as List<dynamic>;
        expect(contents.single['role'], 'user');
        final generationConfig =
            body['generationConfig'] as Map<String, dynamic>;
        expect(
          generationConfig['thinkingConfig'],
          {'thinkingLevel': 'low'},
        );
        expect(body['safetySettings'], relaxedSafetySettings);
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'Generated answer'},
                  ],
                },
              },
            ],
          }),
          200,
        );
      });

      final service = GeminiService(client: client);
      final text = await service.generateText(
        apiKey: 'test-key',
        modelId: 'gemini-3.1-pro-preview',
        prompt: 'Hello',
      );

      expect(text, 'Generated answer');
    });

    test('generateText disables thinking for Gemini 2.5 Flash models',
        () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final generationConfig =
            body['generationConfig'] as Map<String, dynamic>;
        expect(
          generationConfig['thinkingConfig'],
          {'thinkingBudget': 0},
        );
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'Generated answer'},
                  ],
                },
              },
            ],
          }),
          200,
        );
      });

      final service = GeminiService(client: client);
      final text = await service.generateText(
        apiKey: 'test-key',
        modelId: 'gemini-2.5-flash',
        prompt: 'Hello',
      );

      expect(text, 'Generated answer');
    });

    test('generateText leaves overrides unset for other Gemini 3 models',
        () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body.containsKey('generationConfig'), isFalse);
        expect(body.containsKey('safetySettings'), isFalse);
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'Generated answer'},
                  ],
                },
              },
            ],
          }),
          200,
        );
      });

      final service = GeminiService(client: client);
      final text = await service.generateText(
        apiKey: 'test-key',
        modelId: 'gemini-3.1-flash-lite-preview',
        prompt: 'Hello',
      );

      expect(text, 'Generated answer');
    });

    test('generateImage sends Nano Banana defaults', () async {
      final client = MockClient((request) async {
        expect(
          request.url.path,
          '/v1beta/models/gemini-3.1-flash-image-preview:generateContent',
        );
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final contents = body['contents'] as List<dynamic>;
        expect(contents.single['role'], 'user');
        final generationConfig =
            body['generationConfig'] as Map<String, dynamic>;
        expect(
          generationConfig['responseModalities'],
          ['IMAGE', 'TEXT'],
        );
        expect(
          generationConfig['thinkingConfig'],
          {'thinkingLevel': 'minimal'},
        );
        expect(
          generationConfig['imageConfig'],
          {'imageSize': '1K'},
        );
        expect(body.containsKey('safetySettings'), isFalse);
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'Here is your image.'},
                    {
                      'inlineData': {
                        'mimeType': 'image/png',
                        'data': 'abc123',
                      },
                    },
                  ],
                },
              },
            ],
          }),
          200,
        );
      });

      final service = GeminiService(client: client);
      final result = await service.generateImage(
        apiKey: 'test-key',
        modelId: 'gemini-3.1-flash-image-preview',
        prompt: 'Draw a castle',
      );

      expect(result.assistantText, 'Here is your image.');
      expect(result.imageDataUrls, ['data:image/png;base64,abc123']);
    });

    test('generateImage parses inlineData from Gemini image models', () async {
      final client = MockClient((request) async {
        expect(
          request.url.path,
          '/v1beta/models/gemini-2.5-flash-image:generateContent',
        );
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(
          body['generationConfig']['responseModalities'],
          ['TEXT', 'IMAGE'],
        );
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'Here is your image.'},
                    {
                      'inlineData': {
                        'mimeType': 'image/png',
                        'data': 'abc123',
                      },
                    },
                  ],
                },
              },
            ],
          }),
          200,
        );
      });

      final service = GeminiService(client: client);
      final result = await service.generateImage(
        apiKey: 'test-key',
        modelId: 'gemini-2.5-flash-image',
        prompt: 'Draw a castle',
      );

      expect(result.assistantText, 'Here is your image.');
      expect(result.imageDataUrls, ['data:image/png;base64,abc123']);
    });

    test('generateImage surfaces Gemini text-only refusals to the caller',
        () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'text':
                          "I can't generate an image of a woman collapsing onto desert sand.",
                    },
                  ],
                  'role': 'model',
                },
                'finishReason': 'STOP',
              },
            ],
          }),
          200,
        );
      });

      final service = GeminiService(client: client);

      await expectLater(
        service.generateImage(
          apiKey: 'test-key',
          modelId: 'gemini-3-pro-image-preview',
          prompt: 'Draw the scene',
        ),
        throwsA(
          isA<GeminiException>().having(
            (error) => error.message,
            'message',
            "I can't generate an image of a woman collapsing onto desert sand.",
          ),
        ),
      );
    });

    test('generateImage parses Imagen predict responses', () async {
      final client = MockClient((request) async {
        expect(
          request.url.path,
          '/v1beta/models/imagen-4.0-generate-001:predict',
        );
        return http.Response(
          jsonEncode({
            'predictions': [
              {
                'mimeType': 'image/png',
                'bytesBase64Encoded': 'xyz789',
              },
            ],
          }),
          200,
        );
      });

      final service = GeminiService(client: client);
      final result = await service.generateImage(
        apiKey: 'test-key',
        modelId: 'imagen-4.0-generate-001',
        prompt: 'Draw a forest',
      );

      expect(result.assistantText, isEmpty);
      expect(result.imageDataUrls, ['data:image/png;base64,xyz789']);
    });

    test('returns provider-specific error messages on non-2xx responses',
        () async {
      var attempts = 0;
      final client = MockClient((request) async {
        attempts += 1;
        return http.Response(
          jsonEncode({
            'error': {'message': 'Bad request'},
          }),
          400,
        );
      });

      final service = GeminiService(client: client);

      await expectLater(
        service.generateText(
          apiKey: 'test-key',
          modelId: 'gemini-2.5-flash',
          prompt: 'Hello',
        ),
        throwsA(
          isA<GeminiException>().having(
            (error) => error.message,
            'message',
            contains('Bad request'),
          ),
        ),
      );
      expect(attempts, 1);
    });

    test('retries a timed out text request once before succeeding', () async {
      var attempts = 0;
      final client = MockClient((request) {
        attempts += 1;
        if (attempts == 1) {
          return Completer<http.Response>().future;
        }
        return Future.value(
          http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'Generated answer'},
                    ],
                  },
                },
              ],
            }),
            200,
          ),
        );
      });
      final service = GeminiService(
        client: client,
        requestTimeout: const Duration(milliseconds: 10),
        retryBaseDelay: Duration.zero,
      );

      final text = await service.generateText(
        apiKey: 'test-key',
        modelId: 'gemini-3-flash-preview',
        prompt: 'Hello',
      );

      expect(text, 'Generated answer');
      expect(attempts, 2);
    });

    test('retries a transient 429 response once before succeeding', () async {
      var attempts = 0;
      final client = MockClient((request) async {
        attempts += 1;
        if (attempts == 1) {
          return http.Response(
            jsonEncode({
              'error': {'message': 'Rate limited'},
            }),
            429,
          );
        }
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'Generated answer'},
                  ],
                },
              },
            ],
          }),
          200,
        );
      });
      final service = GeminiService(
        client: client,
        retryBaseDelay: Duration.zero,
      );

      final text = await service.generateText(
        apiKey: 'test-key',
        modelId: 'gemini-3-flash-preview',
        prompt: 'Hello',
      );

      expect(text, 'Generated answer');
      expect(attempts, 2);
    });

    test('fetchModels retries one transient 5xx response', () async {
      var attempts = 0;
      final client = MockClient((request) async {
        attempts += 1;
        if (attempts == 1) {
          return http.Response(
            jsonEncode({
              'error': {'message': 'Temporary backend issue'},
            }),
            503,
          );
        }
        return http.Response(
          jsonEncode({
            'models': [
              {
                'name': 'models/gemini-2.5-flash',
                'displayName': 'Gemini 2.5 Flash',
                'supportedGenerationMethods': ['generateContent'],
              },
            ],
          }),
          200,
        );
      });
      final service = GeminiService(
        client: client,
        retryBaseDelay: Duration.zero,
      );

      final models = await service.fetchModels(apiKey: 'test-key');

      expect(models, hasLength(1));
      expect(models.single.id, 'gemini-2.5-flash');
      expect(attempts, 2);
    });

    test('surfaces the final transient error after retries are exhausted',
        () async {
      var attempts = 0;
      final client = MockClient((request) async {
        attempts += 1;
        return http.Response(
          jsonEncode({
            'error': {'message': 'Service unavailable'},
          }),
          503,
        );
      });
      final service = GeminiService(
        client: client,
        retryBaseDelay: Duration.zero,
      );

      await expectLater(
        service.generateText(
          apiKey: 'test-key',
          modelId: 'gemini-3-flash-preview',
          prompt: 'Hello',
        ),
        throwsA(
          isA<GeminiException>().having(
            (error) => error.message,
            'message',
            contains('Service unavailable'),
          ),
        ),
      );
      expect(attempts, 2);
    });

    test('times out hung requests with a Gemini-specific message', () async {
      var attempts = 0;
      final completer = Completer<http.Response>();
      final client = MockClient((request) {
        attempts += 1;
        return completer.future;
      });
      final service = GeminiService(
        client: client,
        requestTimeout: const Duration(milliseconds: 10),
        retryBaseDelay: Duration.zero,
      );

      await expectLater(
        service.generateImage(
          apiKey: 'test-key',
          modelId: 'gemini-3-pro-image-preview',
          prompt: 'Draw a lighthouse',
        ),
        throwsA(
          isA<GeminiException>().having(
            (error) => error.message,
            'message',
            contains('timed out while generating images'),
          ),
        ),
      );
      expect(attempts, 2);
    });
  });
}

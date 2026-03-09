import 'dart:convert';

import 'package:bookai/models/ai_model_info.dart';
import 'package:bookai/models/ai_provider.dart';
import 'package:bookai/services/gemini_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('GeminiService', () {
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
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {'message': 'Bad request'},
          }),
          400,
        );
      });

      final service = GeminiService(client: client);

      expect(
        () => service.generateText(
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
    });
  });
}

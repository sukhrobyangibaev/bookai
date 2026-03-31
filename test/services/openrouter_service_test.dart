import 'dart:async';
import 'dart:convert';

import 'package:bookai/models/ai_chat_message.dart';
import 'package:bookai/models/openrouter_model.dart';
import 'package:bookai/services/openrouter_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('OpenRouterService', () {
    test('fetchModels parses and sorts models', () async {
      final client = MockClient((request) async {
        expect(
          request.url.toString(),
          'https://openrouter.ai/api/v1/models',
        );
        expect(request.headers['accept'], 'application/json');
        expect(request.headers['http-referer'], 'https://bookai.app');
        expect(request.headers['x-title'], 'BookAI');
        expect(request.headers['authorization'], 'Bearer test-key');

        return http.Response(
          jsonEncode({
            'data': [
              {
                'id': 'openai/gpt-4o-mini',
                'name': 'GPT-4o Mini',
                'description': 'OpenAI model',
                'context_length': 128000,
                'output_modalities': ['text'],
                'pricing': {
                  'prompt': '0.00000015',
                  'completion': '0.0000006',
                },
              },
              {
                'id': 'anthropic/claude-3.7-sonnet',
                'name': 'Claude 3.7 Sonnet',
                'output_modalities': ['image', 'text'],
                'pricing': {
                  'prompt': '0.000003',
                  'completion': '0.000015',
                },
              },
            ],
          }),
          200,
        );
      });

      final service = OpenRouterService(client: client);
      final models = await service.fetchModels(apiKey: 'test-key');

      expect(models.length, 2);
      expect(models.first.id, 'anthropic/claude-3.7-sonnet');
      expect(models.last.id, 'openai/gpt-4o-mini');
      expect(models.last.contextLength, 128000);
      expect(models.first.supportsImageOutput, isTrue);
      expect(models.last.pricing?.prompt, 0.00000015);
      expect(
        models.last.pricing?.settingsLabel(
          OpenRouterModelPriceDisplayMode.textPreferred,
        ),
        'Input: \$0.15/M tok · Output: \$0.6/M tok',
      );
    });

    test('fetchModels throws on non-2xx status', () async {
      final client = MockClient((_) async => http.Response('forbidden', 403));
      final service = OpenRouterService(client: client);

      await expectLater(
        service.fetchModels(),
        throwsA(
          isA<OpenRouterException>().having(
            (e) => e.message,
            'message',
            contains('403'),
          ),
        ),
      );
    });

    test('fetchModels throws on malformed json', () async {
      final client = MockClient((_) async => http.Response('not-json', 200));
      final service = OpenRouterService(client: client);

      await expectLater(
        service.fetchModels(),
        throwsA(
          isA<OpenRouterException>().having(
            (e) => e.message,
            'message',
            contains('malformed JSON'),
          ),
        ),
      );
    });

    test('fetchModels throws when payload misses data list', () async {
      final client = MockClient(
        (_) async => http.Response(jsonEncode({'unexpected': []}), 200),
      );
      final service = OpenRouterService(client: client);

      await expectLater(
        service.fetchModels(),
        throwsA(
          isA<OpenRouterException>().having(
            (e) => e.message,
            'message',
            contains('"data"'),
          ),
        ),
      );
    });

    test('fetchModels caches within TTL', () async {
      int requestCount = 0;
      DateTime now = DateTime(2026, 1, 1, 0, 0, 0);
      final client = MockClient((_) async {
        requestCount++;
        return http.Response(
          jsonEncode({
            'data': [
              {'id': 'openai/gpt-4o-mini'}
            ],
          }),
          200,
        );
      });

      final service = OpenRouterService(
        client: client,
        clock: () => now,
        cacheTtl: const Duration(minutes: 10),
      );

      await service.fetchModels();
      await service.fetchModels();
      expect(requestCount, 1);

      now = now.add(const Duration(minutes: 11));
      await service.fetchModels();
      expect(requestCount, 2);
    });

    test('fetchModels refreshes cache when api key changes', () async {
      int requestCount = 0;
      final client = MockClient((_) async {
        requestCount++;
        return http.Response(
          jsonEncode({
            'data': [
              {'id': 'openai/gpt-4o-mini'}
            ],
          }),
          200,
        );
      });

      final service = OpenRouterService(client: client);

      await service.fetchModels(apiKey: 'key-one');
      await service.fetchModels(apiKey: 'key-two');

      expect(requestCount, 2);
    });

    test('generateText sends chat completion payload and parses content',
        () async {
      final client = MockClient((request) async {
        expect(
          request.url.toString(),
          'https://openrouter.ai/api/v1/chat/completions',
        );
        expect(request.method, 'POST');
        expect(request.headers['authorization'], 'Bearer test-key');
        expect(request.headers['content-type'], 'application/json');
        expect(request.headers['http-referer'], 'https://bookai.app');
        expect(request.headers['x-title'], 'BookAI');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], 'openai/gpt-4.1-mini');
        final messages = body['messages'] as List<dynamic>;
        expect(messages, hasLength(1));
        expect(messages.first['role'], 'user');
        expect(messages.first['content'], 'Summarize this.');
        expect(body['temperature'], 0.2);

        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'Short summary'}
              }
            ],
          }),
          200,
        );
      });

      final service = OpenRouterService(client: client);
      final text = await service.generateText(
        apiKey: 'test-key',
        modelId: 'openai/gpt-4.1-mini',
        prompt: 'Summarize this.',
        temperature: 0.2,
      );

      expect(text, 'Short summary');
    });

    test('generateText supports list-style message content', () async {
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': [
                    {'type': 'text', 'text': 'Line 1'},
                    {'type': 'text', 'text': 'Line 2'},
                  ],
                },
              }
            ],
          }),
          200,
        );
      });

      final service = OpenRouterService(client: client);
      final text = await service.generateText(
        apiKey: 'k',
        modelId: 'm',
        prompt: 'p',
      );

      expect(text, 'Line 1\nLine 2');
    });

    test('generateTextMessages sends a multi-turn payload', () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final messages = body['messages'] as List<dynamic>;
        expect(messages, hasLength(3));
        expect(messages[0], {
          'role': 'user',
          'content': 'Summarize this scene.',
        });
        expect(messages[1], {
          'role': 'assistant',
          'content': 'It is a stormy reunion.',
        });
        expect(messages[2], {
          'role': 'user',
          'content': 'Explain why in simpler words.',
        });

        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'They meet again during a storm.'}
              }
            ],
          }),
          200,
        );
      });

      final service = OpenRouterService(client: client);
      final text = await service.generateTextMessages(
        apiKey: 'k',
        modelId: 'm',
        messages: const <AiChatMessage>[
          AiChatMessage.user('Summarize this scene.'),
          AiChatMessage.assistant('It is a stormy reunion.'),
          AiChatMessage.user('Explain why in simpler words.'),
        ],
      );

      expect(text, 'They meet again during a storm.');
    });

    test('streamTextMessages emits ordered deltas and done', () async {
      final client = MockClient.streaming((request, bodyStream) async {
        expect(
          request.url.toString(),
          'https://openrouter.ai/api/v1/chat/completions',
        );
        expect(request.method, 'POST');
        expect(request.headers['authorization'], 'Bearer test-key');
        expect(request.headers['content-type'], 'application/json');
        expect(request.headers['accept'], 'text/event-stream');
        expect(request.headers['http-referer'], 'https://bookai.app');
        expect(request.headers['x-title'], 'BookAI');

        final requestBody = await bodyStream.bytesToString();
        final body = jsonDecode(requestBody) as Map<String, dynamic>;
        expect(body['model'], 'openai/gpt-4.1-mini');
        expect(body['temperature'], 0.2);
        expect(body['stream'], isTrue);

        final messages = body['messages'] as List<dynamic>;
        expect(messages, hasLength(2));
        expect(messages[0], {
          'role': 'user',
          'content': 'Summarize this scene.',
        });
        expect(messages[1], {
          'role': 'assistant',
          'content': 'It is a stormy reunion.',
        });

        final chunks = <List<int>>[
          utf8.encode(
            'data: {"choices":[{"delta":{"content":"They meet again "}}]}\n\n',
          ),
          utf8.encode(
            'data: {"choices":[{"delta":{"content":"during a storm."}}]}\n\n',
          ),
          utf8.encode('data: [DONE]\n\n'),
        ];
        return http.StreamedResponse(
          Stream<List<int>>.fromIterable(chunks),
          200,
          headers: <String, String>{
            'content-type': 'text/event-stream',
          },
          request: request,
        );
      });

      final service = OpenRouterService(client: client);
      final events = await service.streamTextMessages(
        apiKey: 'test-key',
        modelId: 'openai/gpt-4.1-mini',
        temperature: 0.2,
        messages: const <AiChatMessage>[
          AiChatMessage.user('Summarize this scene.'),
          AiChatMessage.assistant('It is a stormy reunion.'),
        ],
      ).toList();

      expect(events, hasLength(3));
      expect(events[0].isDelta, isTrue);
      expect(events[0].deltaText, 'They meet again ');
      expect(events[1].isDelta, isTrue);
      expect(events[1].deltaText, 'during a storm.');
      expect(events[2].isDone, isTrue);
    });

    test('streamText emits error event when stream payload has error',
        () async {
      final client = MockClient.streaming((request, bodyStream) async {
        final requestBody = await bodyStream.bytesToString();
        final body = jsonDecode(requestBody) as Map<String, dynamic>;
        expect(body['stream'], isTrue);

        final chunks = <List<int>>[
          utf8.encode('data: {"choices":[{"delta":{"content":"Hi"}}]}\n\n'),
          utf8.encode(
            'data: {"error":{"message":"Model overload"}}\n\n',
          ),
          utf8.encode('data: [DONE]\n\n'),
        ];
        return http.StreamedResponse(
          Stream<List<int>>.fromIterable(chunks),
          200,
          headers: <String, String>{
            'content-type': 'text/event-stream',
          },
          request: request,
        );
      });

      final service = OpenRouterService(client: client);
      final events = await service
          .streamText(
            apiKey: 'test-key',
            modelId: 'openai/gpt-4.1-mini',
            prompt: 'Say hi',
          )
          .toList();

      expect(events, hasLength(2));
      expect(events[0].isDelta, isTrue);
      expect(events[0].deltaText, 'Hi');
      expect(events[1].isError, isTrue);
      expect(events[1].errorMessage, contains('Model overload'));
    });

    test('generateText throws on non-2xx status', () async {
      final client = MockClient((_) async => http.Response('fail', 429));
      final service = OpenRouterService(client: client);

      await expectLater(
        service.generateText(apiKey: 'k', modelId: 'm', prompt: 'p'),
        throwsA(
          isA<OpenRouterException>().having(
            (e) => e.message,
            'message',
            contains('429'),
          ),
        ),
      );
    });

    test('generateText includes OpenRouter error details on non-2xx status',
        () async {
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode({
            'error': {
              'message': 'This model is not available for your account.',
            },
          }),
          403,
        );
      });
      final service = OpenRouterService(client: client);

      await expectLater(
        service.generateText(apiKey: 'k', modelId: 'm', prompt: 'p'),
        throwsA(
          isA<OpenRouterException>()
              .having((e) => e.message, 'message', contains('403'))
              .having(
                (e) => e.message,
                'message',
                contains('not available for your account'),
              ),
        ),
      );
    });

    test('times out hung requests with an OpenRouter-specific message',
        () async {
      final completer = Completer<http.Response>();
      final client = MockClient((request) => completer.future);
      final service = OpenRouterService(
        client: client,
        requestTimeout: const Duration(milliseconds: 10),
      );

      await expectLater(
        service.generateImage(
          apiKey: 'test-key',
          modelId: 'openai/gpt-image-1',
          prompt: 'Draw a lighthouse',
        ),
        throwsA(
          isA<OpenRouterException>().having(
            (error) => error.message,
            'message',
            contains('timed out while generating images'),
          ),
        ),
      );
    });

    test('generateText throws when choices list is missing', () async {
      final client = MockClient(
        (_) async => http.Response(jsonEncode({'id': 'abc'}), 200),
      );
      final service = OpenRouterService(client: client);

      await expectLater(
        service.generateText(apiKey: 'k', modelId: 'm', prompt: 'p'),
        throwsA(
          isA<OpenRouterException>().having(
            (e) => e.message,
            'message',
            contains('choices'),
          ),
        ),
      );
    });

    test('generateImage sends modalities and parses assistant images',
        () async {
      final client = MockClient((request) async {
        expect(
          request.url.toString(),
          'https://openrouter.ai/api/v1/chat/completions',
        );
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], 'openai/gpt-image-1');
        expect(body['modalities'], ['image', 'text']);
        expect(body['messages'][0]['content'], 'Illustrate the storm.');

        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': 'Generated one image.',
                  'images': [
                    {
                      'image_url': {
                        'url': 'data:image/png;base64,abc123',
                      },
                    },
                  ],
                },
              }
            ],
          }),
          200,
        );
      });

      final service = OpenRouterService(client: client);
      final result = await service.generateImage(
        apiKey: 'test-key',
        modelId: 'openai/gpt-image-1',
        prompt: 'Illustrate the storm.',
      );

      expect(result.assistantText, 'Generated one image.');
      expect(result.imageUrls, ['data:image/png;base64,abc123']);
    });

    test('generateImage reads image urls from content parts', () async {
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': [
                    {'type': 'text', 'text': 'Done.'},
                    {
                      'type': 'image_url',
                      'image_url': {
                        'url': 'data:image/png;base64,from-content',
                      },
                    },
                  ],
                },
              }
            ],
          }),
          200,
        );
      });

      final service = OpenRouterService(client: client);
      final result = await service.generateImage(
        apiKey: 'k',
        modelId: 'm',
        prompt: 'p',
        modalities: const ['image'],
      );

      expect(result.assistantText, 'Done.');
      expect(result.imageUrls, ['data:image/png;base64,from-content']);
    });

    test('generateImage throws when no image payload is returned', () async {
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'Only text here.'}
              }
            ],
          }),
          200,
        );
      });
      final service = OpenRouterService(client: client);

      await expectLater(
        service.generateImage(apiKey: 'k', modelId: 'm', prompt: 'p'),
        throwsA(
          isA<OpenRouterException>().having(
            (e) => e.message,
            'message',
            contains('generated images'),
          ),
        ),
      );
    });
  });
}

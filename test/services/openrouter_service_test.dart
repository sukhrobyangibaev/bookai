import 'dart:convert';

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
        expect(request.headers['authorization'], 'Bearer test-key');

        return http.Response(
          jsonEncode({
            'data': [
              {
                'id': 'openai/gpt-4o-mini',
                'name': 'GPT-4o Mini',
                'description': 'OpenAI model',
                'context_length': 128000,
              },
              {
                'id': 'anthropic/claude-3.7-sonnet',
                'name': 'Claude 3.7 Sonnet',
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
  });
}

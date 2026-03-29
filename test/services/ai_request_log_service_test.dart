import 'dart:io';
import 'dart:convert';

import 'package:bookai/services/ai_request_log_service.dart';
import 'package:bookai/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDir;
  late String databasePath;
  final databaseService = DatabaseService.instance;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('bookai_ai_log_test_');
    databasePath = p.join(tempDir.path, 'bookai.db');
    await databaseService.resetForTesting(databasePath: databasePath);
  });

  tearDown(() async {
    await databaseService.resetForTesting();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('redacts auth headers and stores full text response payload', () async {
    var now = DateTime.utc(2026, 3, 29, 12, 0, 0);
    final logService = AiRequestLogService(
      databaseService: databaseService,
      clock: () => now,
      keepLatest: 1000,
    );

    final response = http.Response(
      jsonEncode({
        'choices': [
          {
            'message': {'content': 'Short answer'}
          }
        ]
      }),
      200,
      headers: const {
        'content-type': 'application/json',
      },
    );

    await logService.logExchange(
      provider: 'openrouter',
      requestKind: AiRequestLogKinds.textGeneration,
      attempt: 1,
      method: 'POST',
      uri: Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
      modelId: 'openai/gpt-4o-mini',
      requestHeaders: const {
        'Authorization': 'Bearer secret-key',
        'HTTP-Referer': 'https://bookai.app',
        'Content-Type': 'application/json',
      },
      requestBody: '{"model":"openai/gpt-4o-mini"}',
      response: response,
      duration: const Duration(milliseconds: 325),
    );

    final logs = await databaseService.getAiRequestLogEntries(limit: 10);
    expect(logs, hasLength(1));

    final saved = logs.single;
    expect(saved.createdAt, now);
    expect(saved.requestKind, AiRequestLogKinds.textGeneration);
    expect(saved.requestHeaders['Authorization'], '<redacted>');
    expect(saved.requestHeaders['HTTP-Referer'], 'https://bookai.app');
    expect(saved.responseStatusCode, 200);
    expect(saved.responseMetadataOnly, isFalse);
    expect(saved.responseBody, contains('Short answer'));

    now = now.add(const Duration(seconds: 1));
    await logService.logExchange(
      provider: 'gemini',
      requestKind: AiRequestLogKinds.textGeneration,
      attempt: 1,
      method: 'POST',
      uri: Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent',
      ),
      requestHeaders: const {
        'x-goog-api-key': 'AIza-secret',
      },
      requestBody: '{}',
      error: const SocketException('offline'),
      duration: const Duration(milliseconds: 99),
    );

    final withGemini = await databaseService.getAiRequestLogEntries(limit: 10);
    expect(withGemini, hasLength(2));
    expect(withGemini.first.provider, 'gemini');
    expect(withGemini.first.requestHeaders['x-goog-api-key'], '<redacted>');
    expect(withGemini.first.errorMessage, contains('SocketException'));
  });

  test('stores metadata-only payload for image responses', () async {
    final logService = AiRequestLogService(
      databaseService: databaseService,
    );
    final longBase64 = List.filled(128, 'A').join();
    final response = http.Response(
      jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'text': 'Here is your image.',
                },
                {
                  'inlineData': {
                    'mimeType': 'image/png',
                    'data': longBase64,
                  },
                },
                {
                  'image_url': {
                    'url': 'https://cdn.example.com/generated.png',
                  },
                },
                {
                  'url': 'https://cdn.example.com/generated-2.png',
                },
                {
                  'raw_data_url': 'data:image/png;base64,$longBase64',
                },
              ],
            },
          },
        ],
      }),
      200,
      headers: const {
        'content-type': 'application/json',
      },
    );

    await logService.logExchange(
      provider: 'gemini',
      requestKind: AiRequestLogKinds.imageGeneration,
      attempt: 1,
      method: 'POST',
      uri: Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent',
      ),
      requestHeaders: const {
        'x-goog-api-key': 'AIza-secret',
      },
      requestBody: '{"contents":[]}',
      response: response,
      duration: const Duration(milliseconds: 450),
    );

    final logs = await databaseService.getAiRequestLogEntries(limit: 10);
    expect(logs, hasLength(1));
    final saved = logs.single;
    expect(saved.responseMetadataOnly, isTrue);
    expect(saved.responseBody, isNotNull);

    final decoded = jsonDecode(saved.responseBody!) as Map<String, dynamic>;
    expect(decoded['metadataOnly'], isTrue);

    final serialized = saved.responseBody!;
    expect(serialized, isNot(contains('cdn.example.com')));
    expect(serialized, isNot(contains(longBase64)));
    expect(serialized, contains('<redacted-image-url>'));
    expect(serialized, contains('<redacted-image-bytes>'));
    expect(serialized, contains('<redacted-image-data-url>'));
  });

  test('keeps only the latest configured log entries', () async {
    var now = DateTime.utc(2026, 3, 29, 13, 0, 0);
    final logService = AiRequestLogService(
      databaseService: databaseService,
      clock: () => now,
      keepLatest: 2,
    );

    Future<void> addLog(int index) async {
      await logService.logExchange(
        provider: 'openrouter',
        requestKind: AiRequestLogKinds.chatGeneration,
        attempt: 1,
        method: 'POST',
        uri: Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        requestHeaders: const {'Authorization': 'Bearer secret'},
        requestBody: '{"i":$index}',
        response: http.Response('{"ok":true,"i":$index}', 200),
        duration: const Duration(milliseconds: 1),
      );
      now = now.add(const Duration(seconds: 1));
    }

    await addLog(1);
    await addLog(2);
    await addLog(3);

    final logs = await databaseService.getAiRequestLogEntries(limit: 10);
    expect(logs, hasLength(2));
    expect(logs[0].requestBody, '{"i":3}');
    expect(logs[1].requestBody, '{"i":2}');
  });
}

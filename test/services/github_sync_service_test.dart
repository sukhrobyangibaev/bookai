import 'dart:async';
import 'dart:convert';

import 'package:bookai/models/github_sync_settings.dart';
import 'package:bookai/services/github_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('GitHubSyncService', () {
    const configuredSettings = GitHubSyncSettings(
      owner: 'octocat',
      repo: 'private-sync',
      filePath: 'sync/state.json',
      token: 'ghp_secret',
    );

    test('downloadSyncFileContents requests GitHub contents and decodes base64',
        () async {
      final client = MockClient((request) async {
        expect(
          request.url.toString(),
          'https://api.github.com/repos/octocat/private-sync/contents/sync/state.json',
        );
        expect(request.method, 'GET');
        expect(request.headers['accept'], 'application/vnd.github+json');
        expect(request.headers['authorization'], 'Bearer ghp_secret');
        expect(request.headers['x-github-api-version'], '2022-11-28');
        expect(request.headers['user-agent'], 'BookAI');

        return http.Response(
          jsonEncode({
            'encoding': 'base64',
            'sha': 'abc123',
            'content': base64Encode(utf8.encode('{"schemaVersion":1}')),
          }),
          200,
        );
      });

      final service = GitHubSyncService(client: client);
      final downloaded = await service.downloadSyncFileContents(
        settings: configuredSettings,
      );

      expect(downloaded, '{"schemaVersion":1}');
    });

    test('downloadSyncFileContents reports missing file with clear message',
        () async {
      var requestCount = 0;
      final client = MockClient((request) async {
        requestCount += 1;
        final path = request.url.path;
        if (path == '/repos/octocat/private-sync/contents/sync/state.json') {
          return http.Response(jsonEncode({'message': 'Not Found'}), 404);
        }
        if (path == '/repos/octocat/private-sync') {
          return http.Response(jsonEncode({'id': 1}), 200);
        }
        return http.Response('unexpected', 500);
      });

      final service = GitHubSyncService(client: client);

      await expectLater(
        service.downloadSyncFileContents(settings: configuredSettings),
        throwsA(
          isA<GitHubSyncException>().having(
            (error) => error.message,
            'message',
            contains('sync/state.json'),
          ),
        ),
      );

      expect(requestCount, 2);
    });

    test('downloadSyncFileContents reports missing repository clearly',
        () async {
      final client = MockClient((request) async {
        final path = request.url.path;
        if (path == '/repos/octocat/private-sync/contents/sync/state.json') {
          return http.Response(jsonEncode({'message': 'Not Found'}), 404);
        }
        if (path == '/repos/octocat/private-sync') {
          return http.Response(jsonEncode({'message': 'Not Found'}), 404);
        }
        return http.Response('unexpected', 500);
      });

      final service = GitHubSyncService(client: client);

      await expectLater(
        service.downloadSyncFileContents(settings: configuredSettings),
        throwsA(
          isA<GitHubSyncException>().having(
            (error) => error.message,
            'message',
            contains('octocat/private-sync'),
          ),
        ),
      );
    });

    test('downloadSyncFileContents reports bad token', () async {
      final client = MockClient(
        (_) async =>
            http.Response(jsonEncode({'message': 'Bad credentials'}), 401),
      );

      final service = GitHubSyncService(client: client);

      await expectLater(
        service.downloadSyncFileContents(settings: configuredSettings),
        throwsA(
          isA<GitHubSyncException>().having(
            (error) => error.message,
            'message',
            contains('invalid or lacks access'),
          ),
        ),
      );
    });

    test('uploadSyncFileContents creates missing file with put payload',
        () async {
      final seenRequests = <http.Request>[];
      final client = MockClient((request) async {
        seenRequests.add(request);
        final path = request.url.path;
        if (request.method == 'GET' &&
            path == '/repos/octocat/private-sync/contents/sync/state.json') {
          return http.Response(jsonEncode({'message': 'Not Found'}), 404);
        }
        if (request.method == 'GET' && path == '/repos/octocat/private-sync') {
          return http.Response(jsonEncode({'id': 1}), 200);
        }
        if (request.method == 'PUT' &&
            path == '/repos/octocat/private-sync/contents/sync/state.json') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['message'], 'Upload snapshot');
          expect(body.containsKey('sha'), isFalse);
          expect(
            utf8.decode(base64Decode(body['content'] as String)),
            '{"schemaVersion":1}',
          );
          return http.Response(
            jsonEncode({
              'content': {'sha': 'new-sha-123'},
            }),
            201,
          );
        }
        return http.Response('unexpected', 500);
      });

      final service = GitHubSyncService(client: client);
      final result = await service.uploadSyncFileContents(
        '{"schemaVersion":1}',
        settings: configuredSettings,
        commitMessage: 'Upload snapshot',
      );

      expect(result.created, isTrue);
      expect(result.fileSha, 'new-sha-123');
      expect(
        seenRequests.any((request) => request.method == 'PUT'),
        isTrue,
      );
    });

    test('uploadSyncFileContents updates existing file using existing sha',
        () async {
      final client = MockClient((request) async {
        final path = request.url.path;
        if (request.method == 'GET' &&
            path == '/repos/octocat/private-sync/contents/sync/state.json') {
          return http.Response(
            jsonEncode({
              'sha': 'current-sha',
              'encoding': 'base64',
              'content': base64Encode(utf8.encode('{"old":true}')),
            }),
            200,
          );
        }
        if (request.method == 'PUT' &&
            path == '/repos/octocat/private-sync/contents/sync/state.json') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['sha'], 'current-sha');
          return http.Response(
            jsonEncode({
              'content': {'sha': 'updated-sha'},
            }),
            200,
          );
        }
        return http.Response('unexpected', 500);
      });

      final service = GitHubSyncService(client: client);
      final result = await service.uploadSyncFileContents(
        '{"schemaVersion":2}',
        settings: configuredSettings,
      );

      expect(result.created, isFalse);
      expect(result.fileSha, 'updated-sha');
    });

    test('uploadSyncFileContents retries once on 409 conflict', () async {
      var getCount = 0;
      var putCount = 0;

      final client = MockClient((request) async {
        final path = request.url.path;
        if (request.method == 'GET' &&
            path == '/repos/octocat/private-sync/contents/sync/state.json') {
          getCount += 1;
          final sha = getCount == 1 ? 'sha-before' : 'sha-after';
          return http.Response(
            jsonEncode({
              'sha': sha,
              'encoding': 'base64',
              'content': base64Encode(utf8.encode('{"old":true}')),
            }),
            200,
          );
        }
        if (request.method == 'PUT' &&
            path == '/repos/octocat/private-sync/contents/sync/state.json') {
          putCount += 1;
          if (putCount == 1) {
            return http.Response(
              jsonEncode({'message': 'sha does not match'}),
              409,
            );
          }
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['sha'], 'sha-after');
          return http.Response(
            jsonEncode({
              'content': {'sha': 'final-sha'},
            }),
            200,
          );
        }
        return http.Response('unexpected', 500);
      });

      final service = GitHubSyncService(client: client);
      final result = await service.uploadSyncFileContents(
        '{"schemaVersion":3}',
        settings: configuredSettings,
      );

      expect(getCount, 2);
      expect(putCount, 2);
      expect(result.fileSha, 'final-sha');
      expect(result.created, isFalse);
    });

    test('uploadSyncFileContents reports network failures clearly', () async {
      final completer = Completer<http.Response>();
      final client = MockClient((_) => completer.future);
      final service = GitHubSyncService(
        client: client,
        requestTimeout: const Duration(milliseconds: 10),
      );

      await expectLater(
        service.uploadSyncFileContents(
          '{"schemaVersion":1}',
          settings: configuredSettings,
        ),
        throwsA(
          isA<GitHubSyncException>().having(
            (error) => error.message,
            'message',
            contains('timed out'),
          ),
        ),
      );
    });
  });
}

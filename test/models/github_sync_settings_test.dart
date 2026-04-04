import 'package:bookai/models/github_sync_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GitHubSyncSettings', () {
    test('normalizes owner, repo, file path, and token', () {
      const settings = GitHubSyncSettings(
        owner: '  octocat  ',
        repo: '  private-sync  ',
        filePath: ' /sync // snapshots /state.json ',
        token: '  ghp_secret  ',
      );

      final normalized = settings.normalized();

      expect(normalized.normalizedOwner, 'octocat');
      expect(normalized.normalizedRepo, 'private-sync');
      expect(normalized.normalizedFilePath, 'sync/snapshots/state.json');
      expect(normalized.normalizedToken, 'ghp_secret');
      expect(normalized.isConfigured, isTrue);
    });

    test('toMap and fromMap roundtrip with normalized values', () {
      const settings = GitHubSyncSettings(
        owner: 'octocat',
        repo: 'private-sync',
        filePath: 'sync/state.json',
        token: 'ghp_secret',
      );

      expect(
        GitHubSyncSettings.fromMap(settings.toMap()),
        settings,
      );
    });

    test('isConfigured requires all fields', () {
      expect(GitHubSyncSettings.empty.isConfigured, isFalse);
      expect(
        const GitHubSyncSettings(
          owner: 'octocat',
          repo: 'private-sync',
          filePath: 'sync/state.json',
        ).isConfigured,
        isFalse,
      );
    });
  });
}

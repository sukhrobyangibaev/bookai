import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/github_sync_settings.dart';
import 'settings_service.dart';

class GitHubSyncException implements Exception {
  final String message;
  final Object? cause;

  const GitHubSyncException(this.message, {this.cause});

  @override
  String toString() => message;
}

class GitHubSyncUploadResult {
  final String fileSha;
  final bool created;

  const GitHubSyncUploadResult({
    required this.fileSha,
    required this.created,
  });
}

class GitHubSyncService {
  static const Duration _defaultRequestTimeout = Duration(seconds: 30);
  static const String _apiHost = 'api.github.com';
  static const String _acceptHeader = 'application/vnd.github+json';
  static const String _apiVersionHeader = '2022-11-28';
  static const String _userAgent = 'BookAI';

  final SettingsService _settingsService;
  final http.Client _client;
  final Duration _requestTimeout;

  GitHubSyncService({
    SettingsService? settingsService,
    http.Client? client,
    Duration requestTimeout = _defaultRequestTimeout,
  })  : _settingsService = settingsService ?? SettingsService(),
        _client = client ?? http.Client(),
        _requestTimeout = requestTimeout;

  Future<GitHubSyncSettings> loadSettings() {
    return _settingsService.loadGitHubSyncSettings();
  }

  Future<void> saveSettings(GitHubSyncSettings settings) {
    return _settingsService.saveGitHubSyncSettings(settings.normalized());
  }

  Future<String> downloadSyncFileContents({
    GitHubSyncSettings? settings,
  }) async {
    final resolved = await _resolveSettings(settings);
    final response = await _send(
      () => _client.get(
        _fileUri(resolved),
        headers: _buildHeaders(token: resolved.normalizedToken),
      ),
    );

    if (response.statusCode == 200) {
      return _decodeFileContents(response.body);
    }
    if (_isBadTokenStatus(response.statusCode)) {
      throw _badTokenException(response);
    }
    if (response.statusCode == 404) {
      final repoExists = await _repositoryExists(resolved);
      if (!repoExists) {
        throw _missingRepositoryException(resolved);
      }
      throw _missingFileException(resolved);
    }

    throw GitHubSyncException(
      _buildStatusErrorMessage(
        action: 'downloading sync file',
        statusCode: response.statusCode,
        responseBody: response.body,
      ),
    );
  }

  Future<GitHubSyncUploadResult> uploadSyncFileContents(
    String jsonContents, {
    GitHubSyncSettings? settings,
    String commitMessage = 'Update BookAI sync snapshot',
  }) async {
    final resolved = await _resolveSettings(settings);
    final normalizedCommitMessage = commitMessage.trim().isEmpty
        ? 'Update BookAI sync snapshot'
        : commitMessage.trim();

    final initialSha = await _fetchCurrentFileShaOrNull(resolved);
    final firstAttempt = await _putFileContents(
      settings: resolved,
      fileSha: initialSha,
      commitMessage: normalizedCommitMessage,
      jsonContents: jsonContents,
    );
    if (firstAttempt.statusCode == 200 || firstAttempt.statusCode == 201) {
      final uploadedSha = _extractUploadedSha(firstAttempt.body);
      return GitHubSyncUploadResult(
        fileSha: uploadedSha,
        created: firstAttempt.statusCode == 201,
      );
    }

    if (firstAttempt.statusCode == 409) {
      final retrySha = await _fetchCurrentFileShaOrNull(resolved);
      final retryAttempt = await _putFileContents(
        settings: resolved,
        fileSha: retrySha,
        commitMessage: normalizedCommitMessage,
        jsonContents: jsonContents,
      );
      if (retryAttempt.statusCode == 200 || retryAttempt.statusCode == 201) {
        final uploadedSha = _extractUploadedSha(retryAttempt.body);
        return GitHubSyncUploadResult(
          fileSha: uploadedSha,
          created: retryAttempt.statusCode == 201,
        );
      }
      if (_isBadTokenStatus(retryAttempt.statusCode)) {
        throw _badTokenException(retryAttempt);
      }
      throw GitHubSyncException(
        _buildStatusErrorMessage(
          action: 'uploading sync file',
          statusCode: retryAttempt.statusCode,
          responseBody: retryAttempt.body,
        ),
      );
    }

    if (_isBadTokenStatus(firstAttempt.statusCode)) {
      throw _badTokenException(firstAttempt);
    }
    if (firstAttempt.statusCode == 404) {
      final repoExists = await _repositoryExists(resolved);
      if (!repoExists) {
        throw _missingRepositoryException(resolved);
      }
    }

    throw GitHubSyncException(
      _buildStatusErrorMessage(
        action: 'uploading sync file',
        statusCode: firstAttempt.statusCode,
        responseBody: firstAttempt.body,
      ),
    );
  }

  Future<GitHubSyncSettings> _resolveSettings(
    GitHubSyncSettings? provided,
  ) async {
    final settings =
        (provided ?? await _settingsService.loadGitHubSyncSettings())
            .normalized();

    if (settings.normalizedOwner.isEmpty) {
      throw const GitHubSyncException('GitHub sync owner is not configured.');
    }
    if (settings.normalizedRepo.isEmpty) {
      throw const GitHubSyncException(
          'GitHub sync repository is not configured.');
    }
    if (settings.normalizedFilePath.isEmpty) {
      throw const GitHubSyncException(
          'GitHub sync file path is not configured.');
    }
    if (settings.normalizedToken.isEmpty) {
      throw const GitHubSyncException('GitHub sync token is not configured.');
    }

    return settings;
  }

  Future<String?> _fetchCurrentFileShaOrNull(
      GitHubSyncSettings settings) async {
    final response = await _send(
      () => _client.get(
        _fileUri(settings),
        headers: _buildHeaders(token: settings.normalizedToken),
      ),
    );

    if (response.statusCode == 200) {
      return _extractFileSha(response.body);
    }
    if (_isBadTokenStatus(response.statusCode)) {
      throw _badTokenException(response);
    }
    if (response.statusCode == 404) {
      final repoExists = await _repositoryExists(settings);
      if (!repoExists) {
        throw _missingRepositoryException(settings);
      }
      return null;
    }

    throw GitHubSyncException(
      _buildStatusErrorMessage(
        action: 'checking remote sync file state',
        statusCode: response.statusCode,
        responseBody: response.body,
      ),
    );
  }

  Future<bool> _repositoryExists(GitHubSyncSettings settings) async {
    final response = await _send(
      () => _client.get(
        _repositoryUri(settings),
        headers: _buildHeaders(token: settings.normalizedToken),
      ),
    );

    if (response.statusCode == 200) {
      return true;
    }
    if (response.statusCode == 404) {
      return false;
    }
    if (_isBadTokenStatus(response.statusCode)) {
      throw _badTokenException(response);
    }

    throw GitHubSyncException(
      _buildStatusErrorMessage(
        action: 'checking repository access',
        statusCode: response.statusCode,
        responseBody: response.body,
      ),
    );
  }

  Future<http.Response> _putFileContents({
    required GitHubSyncSettings settings,
    required String? fileSha,
    required String commitMessage,
    required String jsonContents,
  }) {
    final payload = <String, dynamic>{
      'message': commitMessage,
      'content': base64Encode(utf8.encode(jsonContents)),
      if (fileSha != null && fileSha.trim().isNotEmpty) 'sha': fileSha.trim(),
    };

    return _send(
      () => _client.put(
        _fileUri(settings),
        headers: _buildHeaders(
          token: settings.normalizedToken,
          includeJsonContentType: true,
        ),
        body: jsonEncode(payload),
      ),
    );
  }

  Future<http.Response> _send(Future<http.Response> Function() send) async {
    try {
      return await send().timeout(_requestTimeout);
    } on TimeoutException catch (error) {
      throw GitHubSyncException(
        'GitHub request timed out. Please try again.',
        cause: error,
      );
    } on SocketException catch (error) {
      throw GitHubSyncException(
        'Network failure while connecting to GitHub.',
        cause: error,
      );
    } on http.ClientException catch (error) {
      throw GitHubSyncException(
        'Network failure while connecting to GitHub.',
        cause: error,
      );
    } catch (error) {
      throw GitHubSyncException(
        'Unexpected error while connecting to GitHub.',
        cause: error,
      );
    }
  }

  Uri _repositoryUri(GitHubSyncSettings settings) {
    final owner = Uri.encodeComponent(settings.normalizedOwner);
    final repo = Uri.encodeComponent(settings.normalizedRepo);
    return Uri.https(_apiHost, '/repos/$owner/$repo');
  }

  Uri _fileUri(GitHubSyncSettings settings) {
    final owner = Uri.encodeComponent(settings.normalizedOwner);
    final repo = Uri.encodeComponent(settings.normalizedRepo);
    final encodedPath = settings.normalizedFilePath
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .map(Uri.encodeComponent)
        .join('/');

    return Uri.https(_apiHost, '/repos/$owner/$repo/contents/$encodedPath');
  }

  Map<String, String> _buildHeaders({
    required String token,
    bool includeJsonContentType = false,
  }) {
    return {
      'Accept': _acceptHeader,
      'Authorization': 'Bearer $token',
      'X-GitHub-Api-Version': _apiVersionHeader,
      'User-Agent': _userAgent,
      if (includeJsonContentType) 'Content-Type': 'application/json',
    };
  }

  String _decodeFileContents(String responseBody) {
    final payload = _decodePayload(responseBody);
    final encoding =
        (payload['encoding'] as String? ?? '').trim().toLowerCase();
    if (encoding != 'base64') {
      throw const GitHubSyncException(
        'GitHub sync file response used an unsupported encoding.',
      );
    }

    final rawContent = payload['content'];
    if (rawContent is! String || rawContent.trim().isEmpty) {
      throw const GitHubSyncException(
        'GitHub sync file response is missing file content.',
      );
    }

    try {
      final normalizedBase64 = rawContent.replaceAll(RegExp(r'\s+'), '');
      final bytes = base64Decode(normalizedBase64);
      return utf8.decode(bytes);
    } catch (error) {
      throw GitHubSyncException(
        'GitHub returned malformed file content.',
        cause: error,
      );
    }
  }

  String _extractFileSha(String responseBody) {
    final payload = _decodePayload(responseBody);
    final sha = (payload['sha'] as String? ?? '').trim();
    if (sha.isEmpty) {
      throw const GitHubSyncException(
        'GitHub file metadata did not include a file SHA.',
      );
    }
    return sha;
  }

  String _extractUploadedSha(String responseBody) {
    final payload = _decodePayload(responseBody);
    final rawContent = payload['content'];
    if (rawContent is! Map) {
      throw const GitHubSyncException(
        'GitHub upload response did not include updated file metadata.',
      );
    }
    final sha = (rawContent['sha'] as String? ?? '').trim();
    if (sha.isEmpty) {
      throw const GitHubSyncException(
        'GitHub upload response did not include updated file SHA.',
      );
    }
    return sha;
  }

  Map<String, dynamic> _decodePayload(String responseBody) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(responseBody);
    } catch (error) {
      throw GitHubSyncException(
        'GitHub returned malformed JSON.',
        cause: error,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const GitHubSyncException('GitHub response must be a JSON object.');
    }
    return decoded;
  }

  String _buildStatusErrorMessage({
    required String action,
    required int statusCode,
    required String responseBody,
  }) {
    final detail = _extractErrorDetail(responseBody);
    if (detail.isEmpty) {
      return 'GitHub returned $statusCode while $action.';
    }
    return 'GitHub returned $statusCode while $action: $detail';
  }

  String _extractErrorDetail(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        final message = (decoded['message'] as String? ?? '').trim();
        if (message.isNotEmpty) {
          return _truncateErrorDetail(message);
        }
      }
    } catch (_) {
      return _truncateErrorDetail(trimmed);
    }

    return _truncateErrorDetail(trimmed);
  }

  String _truncateErrorDetail(String value) {
    if (value.length <= 240) {
      return value;
    }
    return '${value.substring(0, 237)}...';
  }

  bool _isBadTokenStatus(int statusCode) {
    return statusCode == 401 || statusCode == 403;
  }

  GitHubSyncException _badTokenException(http.Response response) {
    final detail = _extractErrorDetail(response.body);
    if (detail.isNotEmpty) {
      return GitHubSyncException(
        'GitHub token is invalid or lacks access: $detail',
      );
    }
    return const GitHubSyncException(
      'GitHub token is invalid or lacks access to the repository.',
    );
  }

  GitHubSyncException _missingRepositoryException(GitHubSyncSettings settings) {
    return GitHubSyncException(
      'GitHub repository ${settings.normalizedOwner}/${settings.normalizedRepo} '
      'was not found.',
    );
  }

  GitHubSyncException _missingFileException(GitHubSyncSettings settings) {
    return GitHubSyncException(
      'GitHub sync file ${settings.normalizedFilePath} was not found in '
      '${settings.normalizedOwner}/${settings.normalizedRepo}.',
    );
  }
}

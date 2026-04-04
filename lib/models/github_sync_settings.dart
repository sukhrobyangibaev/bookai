class GitHubSyncSettings {
  final String owner;
  final String repo;
  final String filePath;
  final String token;

  const GitHubSyncSettings({
    this.owner = '',
    this.repo = '',
    this.filePath = '',
    this.token = '',
  });

  static const empty = GitHubSyncSettings();

  String get normalizedOwner => owner.trim();

  String get normalizedRepo => repo.trim();

  String get normalizedFilePath => _normalizeFilePath(filePath);

  String get normalizedToken => token.trim();

  bool get isConfigured {
    return normalizedOwner.isNotEmpty &&
        normalizedRepo.isNotEmpty &&
        normalizedFilePath.isNotEmpty &&
        normalizedToken.isNotEmpty;
  }

  GitHubSyncSettings normalized() {
    return GitHubSyncSettings(
      owner: normalizedOwner,
      repo: normalizedRepo,
      filePath: normalizedFilePath,
      token: normalizedToken,
    );
  }

  GitHubSyncSettings copyWith({
    String? owner,
    String? repo,
    String? filePath,
    String? token,
  }) {
    return GitHubSyncSettings(
      owner: owner ?? this.owner,
      repo: repo ?? this.repo,
      filePath: filePath ?? this.filePath,
      token: token ?? this.token,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'owner': normalizedOwner,
      'repo': normalizedRepo,
      'filePath': normalizedFilePath,
      'token': normalizedToken,
    };
  }

  factory GitHubSyncSettings.fromMap(Map<String, dynamic> map) {
    return GitHubSyncSettings(
      owner: (map['owner'] as String? ?? '').trim(),
      repo: (map['repo'] as String? ?? '').trim(),
      filePath: _normalizeFilePath(map['filePath'] as String? ?? ''),
      token: (map['token'] as String? ?? '').trim(),
    );
  }

  @override
  String toString() {
    return 'GitHubSyncSettings('
        'owner: $normalizedOwner, '
        'repo: $normalizedRepo, '
        'filePath: $normalizedFilePath, '
        'token: ${normalizedToken.isEmpty ? '<empty>' : '<redacted>'}'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GitHubSyncSettings &&
        other.normalizedOwner == normalizedOwner &&
        other.normalizedRepo == normalizedRepo &&
        other.normalizedFilePath == normalizedFilePath &&
        other.normalizedToken == normalizedToken;
  }

  @override
  int get hashCode => Object.hash(
        normalizedOwner,
        normalizedRepo,
        normalizedFilePath,
        normalizedToken,
      );
}

String _normalizeFilePath(String rawPath) {
  final trimmed = rawPath.trim();
  if (trimmed.isEmpty) {
    return '';
  }

  final segments = trimmed
      .replaceFirst(RegExp(r'^/+'), '')
      .split('/')
      .map((segment) => segment.trim())
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);

  return segments.join('/');
}

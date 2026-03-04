enum AppThemeMode { light, dark, sepia }

class ReaderSettings {
  final double fontSize;
  final AppThemeMode themeMode;
  final String openRouterApiKey;
  final String openRouterModelId;

  const ReaderSettings({
    required this.fontSize,
    required this.themeMode,
    this.openRouterApiKey = '',
    this.openRouterModelId = '',
  });

  static const ReaderSettings defaults = ReaderSettings(
    fontSize: 18.0,
    themeMode: AppThemeMode.light,
    openRouterApiKey: '',
    openRouterModelId: '',
  );

  ReaderSettings copyWith({
    double? fontSize,
    AppThemeMode? themeMode,
    String? openRouterApiKey,
    String? openRouterModelId,
  }) {
    return ReaderSettings(
      fontSize: fontSize ?? this.fontSize,
      themeMode: themeMode ?? this.themeMode,
      openRouterApiKey: openRouterApiKey ?? this.openRouterApiKey,
      openRouterModelId: openRouterModelId ?? this.openRouterModelId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fontSize': fontSize,
      'themeMode': themeMode.name,
      'openRouterApiKey': openRouterApiKey,
      'openRouterModelId': openRouterModelId,
    };
  }

  factory ReaderSettings.fromMap(Map<String, dynamic> map) {
    final themeModeStr = map['themeMode'] as String? ?? AppThemeMode.light.name;
    final themeMode = AppThemeMode.values.firstWhere(
      (e) => e.name == themeModeStr,
      orElse: () => AppThemeMode.light,
    );
    return ReaderSettings(
      fontSize: (map['fontSize'] as num?)?.toDouble() ?? 18.0,
      themeMode: themeMode,
      openRouterApiKey: map['openRouterApiKey'] as String? ?? '',
      openRouterModelId: map['openRouterModelId'] as String? ?? '',
    );
  }

  @override
  String toString() {
    return 'ReaderSettings(fontSize: $fontSize, themeMode: $themeMode, '
        'openRouterApiKey: ${openRouterApiKey.isEmpty ? '<empty>' : '<redacted>'}, '
        'openRouterModelId: $openRouterModelId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReaderSettings &&
        other.fontSize == fontSize &&
        other.themeMode == themeMode &&
        other.openRouterApiKey == openRouterApiKey &&
        other.openRouterModelId == openRouterModelId;
  }

  @override
  int get hashCode =>
      Object.hash(fontSize, themeMode, openRouterApiKey, openRouterModelId);
}

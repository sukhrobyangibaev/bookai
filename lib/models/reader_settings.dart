enum AppThemeMode { light, dark, sepia }

class ReaderSettings {
  final double fontSize;
  final AppThemeMode themeMode;

  const ReaderSettings({
    required this.fontSize,
    required this.themeMode,
  });

  static const ReaderSettings defaults = ReaderSettings(
    fontSize: 18.0,
    themeMode: AppThemeMode.light,
  );

  ReaderSettings copyWith({
    double? fontSize,
    AppThemeMode? themeMode,
  }) {
    return ReaderSettings(
      fontSize: fontSize ?? this.fontSize,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fontSize': fontSize,
      'themeMode': themeMode.name,
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
    );
  }

  @override
  String toString() {
    return 'ReaderSettings(fontSize: $fontSize, themeMode: $themeMode)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReaderSettings &&
        other.fontSize == fontSize &&
        other.themeMode == themeMode;
  }

  @override
  int get hashCode => fontSize.hashCode ^ themeMode.hashCode;
}

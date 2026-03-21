final class LauncherSession {
  final String accessToken;
  final String tokenType;
  final DateTime? expiresAt;

  const LauncherSession({
    required this.accessToken,
    required this.tokenType,
    required this.expiresAt,
  });

  factory LauncherSession.fromJson(Map<String, dynamic> json) {
    return LauncherSession(
      accessToken: json['access_token'] as String? ?? '',
      tokenType: json['token_type'] as String? ?? 'Bearer',
      expiresAt: _parseDateTime(json['expires_at'] as String?),
    );
  }

  static DateTime? _parseDateTime(String? rawValue) {
    if (rawValue == null || rawValue.isEmpty) {
      return null;
    }

    return DateTime.tryParse(rawValue);
  }
}

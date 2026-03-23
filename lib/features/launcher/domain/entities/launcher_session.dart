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

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'access_token': accessToken,
      'token_type': tokenType,
      'expires_at': expiresAt?.toIso8601String(),
    };
  }

  bool get hasAccessToken => accessToken.trim().isNotEmpty;

  bool get isExpired {
    final expiresAt = this.expiresAt;
    if (expiresAt == null) {
      return false;
    }

    return !expiresAt.toUtc().isAfter(DateTime.now().toUtc());
  }

  static DateTime? _parseDateTime(String? rawValue) {
    if (rawValue == null || rawValue.isEmpty) {
      return null;
    }

    return DateTime.tryParse(rawValue);
  }
}

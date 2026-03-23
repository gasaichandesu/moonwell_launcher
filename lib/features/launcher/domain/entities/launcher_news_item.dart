final class LauncherNewsItem {
  final int id;
  final String title;
  final String body;
  final String? imageUrl;
  final DateTime? createdAt;

  const LauncherNewsItem({
    required this.id,
    required this.title,
    required this.body,
    required this.imageUrl,
    required this.createdAt,
  });

  factory LauncherNewsItem.fromJson(Map<String, dynamic> json) {
    return LauncherNewsItem(
      id: (json['id'] as num? ?? 0).toInt(),
      title: (json['title'] as String? ?? '').trim(),
      body: (json['body'] as String? ?? '').trim(),
      imageUrl: _parseImageUrl(json['image_url'] as String?),
      createdAt: _parseDateTime(json['created_at'] as String?),
    );
  }

  static String? _parseImageUrl(String? rawValue) {
    if (rawValue == null || rawValue.trim().isEmpty) {
      return null;
    }

    return rawValue.trim();
  }

  static DateTime? _parseDateTime(String? rawValue) {
    if (rawValue == null || rawValue.trim().isEmpty) {
      return null;
    }

    return DateTime.tryParse(rawValue);
  }
}

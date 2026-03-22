import 'package:flutter_test/flutter_test.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/launcher_news_item.dart';

void main() {
  group('LauncherNewsItem', () {
    test('parses news payload with optional image and createdAt', () {
      final item = LauncherNewsItem.fromJson({
        'id': 42,
        'title': 'Update 1.2',
        'body': 'New raid is now available.',
        'image_url': 'https://moon-well.online/news/update.jpg',
        'created_at': '2026-03-22T10:30:00Z',
      });

      expect(item.id, 42);
      expect(item.title, 'Update 1.2');
      expect(item.body, 'New raid is now available.');
      expect(item.imageUrl, 'https://moon-well.online/news/update.jpg');
      expect(
        item.createdAt?.toUtc().toIso8601String(),
        '2026-03-22T10:30:00.000Z',
      );
    });

    test('treats empty image and date as null', () {
      final item = LauncherNewsItem.fromJson({
        'id': 1,
        'title': 'Hotfix',
        'body': 'Minor fixes.',
        'image_url': '',
        'created_at': '',
      });

      expect(item.imageUrl, isNull);
      expect(item.createdAt, isNull);
    });
  });
}

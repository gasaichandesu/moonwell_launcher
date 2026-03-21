import 'package:flutter_test/flutter_test.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/client_hash_entry.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/local_client_file.dart';

void main() {
  group('client hash entry helpers', () {
    test('normalizeClientPath normalizes slashes and strips leading dot', () {
      expect(normalizeClientPath(r'.\Data\common.MPQ'), 'Data/common.MPQ');
      expect(normalizeClientPath('./Wow.exe'), 'Wow.exe');
    });

    test('computeBuildHash is deterministic and order independent', () {
      final left = [
        const LocalClientFile(
          path: r'.\Data\common.MPQ',
          size: 12,
          sha256: 'ABCDEF',
        ),
        const LocalClientFile(path: 'Wow.exe', size: 34, sha256: '123456'),
      ];
      final right = [
        const LocalClientFile(path: 'Wow.exe', size: 34, sha256: '123456'),
        const LocalClientFile(
          path: 'Data/common.MPQ',
          size: 12,
          sha256: 'abcdef',
        ),
      ];

      expect(computeBuildHash(left), computeBuildHash(right));
    });
  });
}

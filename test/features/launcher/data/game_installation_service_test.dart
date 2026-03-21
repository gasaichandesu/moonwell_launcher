import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moonwell_launcher/config.dart';
import 'package:moonwell_launcher/features/launcher/data/game_installation_service.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/client_hash_entry.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/launcher_exception.dart';

void main() {
  group('GameInstallationService', () {
    late Directory rootDirectory;
    late GameInstallationService service;

    setUp(() async {
      service = GameInstallationService();
      rootDirectory = await Directory.systemTemp.createTemp(
        'moonwell_launcher_',
      );

      await File(
        '${rootDirectory.path}${Platform.pathSeparator}Wow.exe',
      ).writeAsString('wow');
      await Directory(
        '${rootDirectory.path}${Platform.pathSeparator}Data',
      ).create(recursive: true);
      await File(
        '${rootDirectory.path}${Platform.pathSeparator}Data${Platform.pathSeparator}common.MPQ',
      ).writeAsString('data');

      await Directory(
        '${rootDirectory.path}${Platform.pathSeparator}Cache',
      ).create(recursive: true);
      await File(
        '${rootDirectory.path}${Platform.pathSeparator}Cache${Platform.pathSeparator}cache.bin',
      ).writeAsString('cache');

      await Directory(
        '${rootDirectory.path}${Platform.pathSeparator}Logs',
      ).create(recursive: true);
      await File(
        '${rootDirectory.path}${Platform.pathSeparator}Logs${Platform.pathSeparator}launcher.log',
      ).writeAsString('log');
    });

    tearDown(() async {
      if (await rootDirectory.exists()) {
        await rootDirectory.delete(recursive: true);
      }
    });

    test('scanInstallation ignores excluded directories', () async {
      final snapshot = await service.scanInstallation(rootDirectory.path);
      final paths = snapshot.files.map((file) => file.path).toList()..sort();

      expect(paths, ['Data/common.MPQ', 'Wow.exe']);
      expect(snapshot.buildHash, computeBuildHash(snapshot.files));
    });

    test(
      'scanInstallation creates launcher hash cache outside verification set',
      () async {
        await service.scanInstallation(rootDirectory.path);

        final cacheFile = File(service.getHashCachePath(rootDirectory.path));
        expect(await cacheFile.exists(), isTrue);

        final secondSnapshot = await service.scanInstallation(
          rootDirectory.path,
        );
        final paths = secondSnapshot.files.map((file) => file.path).toList()
          ..sort();

        expect(paths, ['Data/common.MPQ', 'Wow.exe']);
        expect(
          await Directory(
            '${rootDirectory.path}${Platform.pathSeparator}${Config.launcherMetadataDirectoryName}',
          ).exists(),
          isTrue,
        );
      },
    );

    test(
      'scanInstallation reuses cached hash when file metadata did not change',
      () async {
        await service.scanInstallation(rootDirectory.path);

        final cacheFile = File(service.getHashCachePath(rootDirectory.path));
        final cacheJson =
            jsonDecode(await cacheFile.readAsString()) as Map<String, dynamic>;
        final entries = (cacheJson['entries'] as Map).cast<String, dynamic>();

        entries['Wow.exe'] = {
          'size': 3,
          'modifiedMs': await File(
            '${rootDirectory.path}${Platform.pathSeparator}Wow.exe',
          ).lastModified().then((value) => value.millisecondsSinceEpoch),
          'sha256': 'cached-wow-hash',
        };

        await cacheFile.writeAsString(
          jsonEncode({'version': 1, 'entries': entries}),
          flush: true,
        );

        final snapshot = await service.scanInstallation(rootDirectory.path);
        final wowFile = snapshot.files.firstWhere(
          (file) => file.path == 'Wow.exe',
        );

        expect(wowFile.sha256, 'cached-wow-hash');
      },
    );

    test('clearCache recreates an empty cache directory', () async {
      await service.clearCache(rootDirectory.path);

      final cacheDirectory = Directory(
        '${rootDirectory.path}${Platform.pathSeparator}Cache',
      );

      expect(await cacheDirectory.exists(), isTrue);
      expect(await cacheDirectory.list().isEmpty, isTrue);
    });

    test('ensureParentDirectoryExists creates nested directories', () async {
      final tempPath =
          '${rootDirectory.path}${Platform.pathSeparator}Data${Platform.pathSeparator}patches${Platform.pathSeparator}common-2.MPQ.moonwell.part';

      await service.ensureParentDirectoryExists(tempPath);

      expect(
        await Directory(
          '${rootDirectory.path}${Platform.pathSeparator}Data${Platform.pathSeparator}patches',
        ).exists(),
        isTrue,
      );
    });

    test('preserveFailedDownload renames temp file to failed artifact', () async {
      final temporaryPath =
          '${rootDirectory.path}${Platform.pathSeparator}Data${Platform.pathSeparator}broken.MPQ.moonwell.part';
      final temporaryFile = File(temporaryPath);
      await temporaryFile.parent.create(recursive: true);
      await temporaryFile.writeAsString('broken');

      final preservedPath = await service.preserveFailedDownload(temporaryPath);

      expect(preservedPath, '$temporaryPath.failed');
      expect(await temporaryFile.exists(), isFalse);
      expect(await File('$temporaryPath.failed').exists(), isTrue);
    });

    test('resolveClientPath rejects path traversal', () {
      expect(
        () => service.resolveClientPath(rootDirectory.path, '../evil.txt'),
        throwsA(isA<LauncherSyncException>()),
      );
    });
  });
}

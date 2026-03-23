import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:injectable/injectable.dart';
import 'package:moonwell_launcher/config.dart';
import 'package:moonwell_launcher/features/downloader/domain/entities/download_exceptions.dart';
import 'package:moonwell_launcher/features/downloader/domain/entities/download_progress.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/client_installation_snapshot.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/launcher_exception.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/local_client_file.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/client_hash_entry.dart';
import 'package:path/path.dart' as p;

typedef InstallationScanProgressCallback =
    void Function(
      DownloadProgress progress,
      String currentPath,
      int processedFiles,
      int totalFiles,
    );

@lazySingleton
class GameInstallationService {
  Future<ClientInstallationSnapshot> scanInstallation(
    String installationDir, {
    InstallationScanProgressCallback? onProgress,
    FutureOr<bool> Function()? isCancelled,
  }) async {
    final rootDirectory = Directory(installationDir);
    if (!await rootDirectory.exists()) {
      return ClientInstallationSnapshot.fromFiles(const []);
    }

    final receivePort = ReceivePort();
    final errorPort = ReceivePort();
    final exitPort = ReceivePort();
    final files = <LocalClientFile>[];
    final completer = Completer<ClientInstallationSnapshot>();
    final hashCachePath = getHashCachePath(installationDir);
    final cachedHashes = await loadHashCache(installationDir);
    Isolate? isolate;
    StreamSubscription<dynamic>? receiveSubscription;
    StreamSubscription<dynamic>? errorSubscription;
    StreamSubscription<dynamic>? exitSubscription;
    Timer? cancellationTimer;

    Future<void> cleanup({bool killIsolate = true}) async {
      cancellationTimer?.cancel();
      await receiveSubscription?.cancel();
      await errorSubscription?.cancel();
      await exitSubscription?.cancel();
      receivePort.close();
      errorPort.close();
      exitPort.close();
      if (killIsolate) {
        isolate?.kill(priority: Isolate.immediate);
      }
    }

    receiveSubscription = receivePort.listen((message) async {
      if (completer.isCompleted || message is! Map) {
        return;
      }

      final type = message['type'];
      if (type == 'progress') {
        final file = LocalClientFile(
          path: message['path'] as String,
          size: (message['size'] as num).toInt(),
          sha256: message['sha256'] as String,
        );
        files.add(file);

        onProgress?.call(
          DownloadProgress(
            speed: 0,
            downloaded: (message['processedBytes'] as num).toInt(),
            total: (message['totalBytes'] as num).toInt(),
            eta: Duration.zero,
          ),
          file.path,
          (message['processedFiles'] as num).toInt(),
          (message['totalFiles'] as num).toInt(),
        );
        return;
      }

      if (type == 'done') {
        final snapshot = ClientInstallationSnapshot.fromFiles(files);
        completer.complete(snapshot);
        await cleanup(killIsolate: false);
      }
    });

    errorSubscription = errorPort.listen((message) async {
      if (completer.isCompleted) {
        return;
      }

      completer.completeError(
        LauncherSyncException('Failed to scan installation files.'),
      );
      await cleanup(killIsolate: false);
    });

    exitSubscription = exitPort.listen((_) async {
      if (completer.isCompleted) {
        return;
      }

      completer.completeError(
        LauncherSyncException('Hash scan worker exited unexpectedly.'),
      );
      await cleanup(killIsolate: false);
    });

    isolate = await Isolate.spawn<Map<String, Object?>>(
      _scanInstallationIsolateMain,
      <String, Object?>{
        'sendPort': receivePort.sendPort,
        'installationDir': installationDir,
        'hashCachePath': hashCachePath,
        'cachedHashes': cachedHashes,
        'ignoredDirectories': Config.ignoredVerificationDirectories.toList(),
      },
      onError: errorPort.sendPort,
      onExit: exitPort.sendPort,
    );

    if (isCancelled != null) {
      cancellationTimer = Timer.periodic(const Duration(milliseconds: 200), (
        _,
      ) async {
        if (completer.isCompleted) {
          return;
        }

        if (await isCancelled()) {
          completer.completeError(const CancelledException());
          await cleanup();
        }
      });
    }

    return completer.future;
  }

  Future<String> computeSha256(String filePath) async {
    final digest = await sha256.bind(File(filePath).openRead()).first;
    return digest.toString();
  }

  Future<bool> verifySha256(String filePath, String expectedHash) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return false;
    }

    final actualHash = await computeSha256(filePath);
    return actualHash.toLowerCase() == expectedHash.toLowerCase();
  }

  Future<void> deleteRelativeFile(
    String installationDir,
    String relativePath,
  ) async {
    final file = File(resolveClientPath(installationDir, relativePath));
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> ensureParentDirectoryExists(String filePath) {
    return File(filePath).parent.create(recursive: true);
  }

  Future<void> replaceFile({
    required String temporaryPath,
    required String destinationPath,
  }) async {
    final destinationFile = File(destinationPath);
    await destinationFile.parent.create(recursive: true);

    if (await destinationFile.exists()) {
      await destinationFile.delete();
    }

    await File(temporaryPath).rename(destinationPath);
  }

  Future<void> deleteFileIfExists(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> clearCache(String installationDir) async {
    final cacheDirectory = Directory(
      p.join(installationDir, Config.cacheDirectoryName),
    );
    if (await cacheDirectory.exists()) {
      await cacheDirectory.delete(recursive: true);
    }

    await cacheDirectory.create(recursive: true);
  }

  Future<void> launchGame(String installationDir) async {
    final executablePath = getExecutablePath(installationDir);
    final executable = File(executablePath);

    if (!await executable.exists()) {
      throw const LauncherSyncException(
        'Wow.exe was not found in the selected folder.',
      );
    }

    await Process.start(
      executablePath,
      const <String>[],
      workingDirectory: installationDir,
      mode: ProcessStartMode.detached,
    );
  }

  Future<bool> hasClientExecutable(String installationDir) async {
    return File(getExecutablePath(installationDir)).exists();
  }

  String getLauncherMetadataDirectoryPath(String installationDir) {
    return p.join(installationDir, Config.launcherMetadataDirectoryName);
  }

  String getHashCachePath(String installationDir) {
    return p.join(
      getLauncherMetadataDirectoryPath(installationDir),
      Config.hashCacheFileName,
    );
  }

  String getLauncherLogPath(String installationDir) {
    return p.join(
      getLauncherMetadataDirectoryPath(installationDir),
      Config.launcherLogFileName,
    );
  }

  String getExecutablePath(String installationDir) {
    return p.join(installationDir, Config.gameExecutableName);
  }

  String resolveClientPath(String installationDir, String relativePath) {
    final normalizedPath = normalizeClientPath(relativePath);
    final pathSegments = p.posix
        .split(normalizedPath)
        .where((segment) => segment.isNotEmpty && segment != '.')
        .toList();

    if (pathSegments.isEmpty ||
        pathSegments.any((segment) => segment == '..') ||
        p.posix.isAbsolute(normalizedPath)) {
      throw LauncherSyncException('Invalid client file path: $relativePath');
    }

    return p.joinAll([installationDir, ...pathSegments]);
  }

  Future<Map<String, Object?>> loadHashCache(String installationDir) async {
    final cacheFile = File(getHashCachePath(installationDir));
    if (!await cacheFile.exists()) {
      return const <String, Object?>{};
    }

    try {
      final rawJson = await cacheFile.readAsString();
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map) {
        return const <String, Object?>{};
      }

      final entries = decoded['entries'];
      if (entries is! Map) {
        return const <String, Object?>{};
      }

      return entries.map((key, value) => MapEntry(key.toString(), value));
    } catch (_) {
      return const <String, Object?>{};
    }
  }

  Future<int?> getFileSizeIfExists(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return null;
    }

    return file.stat().then((stat) => stat.size);
  }

  Future<String?> preserveFailedDownload(String temporaryPath) async {
    final temporaryFile = File(temporaryPath);
    if (!await temporaryFile.exists()) {
      return null;
    }

    final preservedPath = '$temporaryPath.failed';
    final preservedFile = File(preservedPath);
    await preservedFile.parent.create(recursive: true);

    if (await preservedFile.exists()) {
      await preservedFile.delete();
    }

    await temporaryFile.rename(preservedPath);
    return preservedPath;
  }
}

Future<void> _scanInstallationIsolateMain(Map<String, Object?> message) async {
  final sendPort = message['sendPort'] as SendPort;
  final installationDir = message['installationDir'] as String;
  final hashCachePath = message['hashCachePath'] as String;
  final cachedHashes = (message['cachedHashes'] as Map<Object?, Object?>).map(
    (key, value) => MapEntry(key.toString(), value),
  );
  final ignoredDirectories = (message['ignoredDirectories'] as List<Object?>)
      .whereType<String>()
      .map((entry) => entry.toLowerCase())
      .toSet();

  final rootDirectory = Directory(installationDir);
  if (!await rootDirectory.exists()) {
    sendPort.send(<String, Object?>{'type': 'done'});
    return;
  }

  final pendingFiles = <_SerializablePendingFile>[];
  await _collectFilesInIsolate(
    rootDirectory,
    rootDirectory.path,
    pendingFiles,
    ignoredDirectories,
  );

  pendingFiles.sort(
    (left, right) => left.relativePath.compareTo(right.relativePath),
  );

  final totalBytes = pendingFiles.fold<int>(
    0,
    (sum, pendingFile) => sum + pendingFile.size,
  );
  final updatedCacheEntries = <String, Map<String, Object?>>{};

  var processedBytes = 0;
  var processedFiles = 0;

  for (final pendingFile in pendingFiles) {
    final digest = await _resolveFileHash(pendingFile, cachedHashes);
    processedBytes += pendingFile.size;
    processedFiles += 1;
    updatedCacheEntries[pendingFile.relativePath] = <String, Object?>{
      'size': pendingFile.size,
      'modifiedMs': pendingFile.modifiedMs,
      'sha256': digest,
    };

    sendPort.send(<String, Object?>{
      'type': 'progress',
      'path': pendingFile.relativePath,
      'size': pendingFile.size,
      'sha256': digest,
      'processedBytes': processedBytes,
      'totalBytes': totalBytes,
      'processedFiles': processedFiles,
      'totalFiles': pendingFiles.length,
    });
  }

  await _writeHashCache(hashCachePath, updatedCacheEntries);
  sendPort.send(<String, Object?>{'type': 'done'});
}

Future<String> _resolveFileHash(
  _SerializablePendingFile pendingFile,
  Map<String, Object?> cachedHashes,
) async {
  final cachedEntry = cachedHashes[pendingFile.relativePath];
  if (cachedEntry is Map) {
    final cachedSize = (cachedEntry['size'] as num?)?.toInt();
    final cachedModifiedMs = (cachedEntry['modifiedMs'] as num?)?.toInt();
    final cachedSha256 = cachedEntry['sha256'] as String?;

    if (cachedSize == pendingFile.size &&
        cachedModifiedMs == pendingFile.modifiedMs &&
        cachedSha256 != null &&
        cachedSha256.isNotEmpty) {
      return cachedSha256;
    }
  }

  final digest = await sha256.bind(File(pendingFile.path).openRead()).first;
  return digest.toString();
}

Future<void> _collectFilesInIsolate(
  Directory directory,
  String rootPath,
  List<_SerializablePendingFile> pendingFiles,
  Set<String> ignoredDirectories,
) async {
  await for (final entity in directory.list(followLinks: false)) {
    final relativePath = normalizeClientPath(
      p.relative(entity.path, from: rootPath),
    );

    if (relativePath.isEmpty || relativePath == '.') {
      continue;
    }

    final segments = p.posix.split(relativePath);
    if (segments.isNotEmpty &&
        ignoredDirectories.contains(segments.first.toLowerCase())) {
      continue;
    }

    if (entity is Directory) {
      await _collectFilesInIsolate(
        entity,
        rootPath,
        pendingFiles,
        ignoredDirectories,
      );
      continue;
    }

    if (entity is! File) {
      continue;
    }

    final stat = await entity.stat();
    pendingFiles.add(
      _SerializablePendingFile(
        path: entity.path,
        relativePath: relativePath,
        size: stat.size,
        modifiedMs: stat.modified.millisecondsSinceEpoch,
      ),
    );
  }
}

Future<void> _writeHashCache(
  String hashCachePath,
  Map<String, Map<String, Object?>> entries,
) async {
  final cacheFile = File(hashCachePath);
  await cacheFile.parent.create(recursive: true);

  final tempFile = File('$hashCachePath.tmp');
  final payload = jsonEncode(<String, Object?>{
    'version': 1,
    'entries': entries,
  });

  await tempFile.writeAsString(payload, flush: true);
  if (await cacheFile.exists()) {
    await cacheFile.delete();
  }
  await tempFile.rename(hashCachePath);
}

final class _SerializablePendingFile {
  final String path;
  final String relativePath;
  final int size;
  final int modifiedMs;

  const _SerializablePendingFile({
    required this.path,
    required this.relativePath,
    required this.size,
    required this.modifiedMs,
  });
}

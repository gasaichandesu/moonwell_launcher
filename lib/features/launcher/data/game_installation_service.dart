import 'dart:async';
import 'dart:io';

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

    final pendingFiles = <_PendingFile>[];
    await _collectFiles(
      rootDirectory,
      rootDirectory.path,
      pendingFiles,
      isCancelled: isCancelled,
    );

    pendingFiles.sort(
      (left, right) => left.relativePath.compareTo(right.relativePath),
    );

    final totalBytes = pendingFiles.fold<int>(
      0,
      (sum, pendingFile) => sum + pendingFile.size,
    );

    final files = <LocalClientFile>[];
    var processedBytes = 0;
    var processedFiles = 0;

    for (final pendingFile in pendingFiles) {
      await _throwIfCancelled(isCancelled);

      final sha256 = await computeSha256(pendingFile.file.path);
      processedBytes += pendingFile.size;
      processedFiles += 1;

      files.add(
        LocalClientFile(
          path: pendingFile.relativePath,
          size: pendingFile.size,
          sha256: sha256,
        ),
      );

      onProgress?.call(
        DownloadProgress(
          speed: 0,
          downloaded: processedBytes,
          total: totalBytes,
          eta: Duration.zero,
        ),
        pendingFile.relativePath,
        processedFiles,
        pendingFiles.length,
      );
    }

    return ClientInstallationSnapshot.fromFiles(files);
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

  Future<void> _collectFiles(
    Directory directory,
    String rootPath,
    List<_PendingFile> pendingFiles, {
    FutureOr<bool> Function()? isCancelled,
  }) async {
    await for (final entity in directory.list(followLinks: false)) {
      await _throwIfCancelled(isCancelled);

      final relativePath = normalizeClientPath(
        p.relative(entity.path, from: rootPath),
      );

      if (relativePath.isEmpty || relativePath == '.') {
        continue;
      }

      if (_isExcludedPath(relativePath)) {
        continue;
      }

      if (entity is Directory) {
        await _collectFiles(
          entity,
          rootPath,
          pendingFiles,
          isCancelled: isCancelled,
        );
        continue;
      }

      if (entity is! File) {
        continue;
      }

      final stat = await entity.stat();
      pendingFiles.add(
        _PendingFile(file: entity, relativePath: relativePath, size: stat.size),
      );
    }
  }

  bool _isExcludedPath(String relativePath) {
    final segments = p.posix.split(normalizeClientPath(relativePath));
    if (segments.isEmpty) {
      return false;
    }

    return Config.ignoredVerificationDirectories.contains(
      segments.first.toLowerCase(),
    );
  }

  Future<void> _throwIfCancelled(FutureOr<bool> Function()? isCancelled) async {
    if (isCancelled != null && await isCancelled()) {
      throw const CancelledException();
    }
  }
}

final class _PendingFile {
  final File file;
  final String relativePath;
  final int size;

  const _PendingFile({
    required this.file,
    required this.relativePath,
    required this.size,
  });
}

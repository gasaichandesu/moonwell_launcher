import 'dart:async';
import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:moonwell_launcher/core/use_case.dart';
import 'package:moonwell_launcher/features/downloader/domain/entities/download_exceptions.dart';
import 'package:moonwell_launcher/features/downloader/domain/entities/download_progress.dart';
import 'package:moonwell_launcher/features/launcher/data/game_installation_service.dart';
import 'package:moonwell_launcher/features/launcher/data/launcher_api_client.dart';
import 'package:moonwell_launcher/features/launcher/data/launcher_log_service.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/client_installation_snapshot.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/client_manifest.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/client_manifest_file.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/client_sync_status.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/launcher_exception.dart';

final class ClientSyncRequest {
  final String installationDir;
  final String accessToken;
  final ClientManifest? manifest;

  const ClientSyncRequest({
    required this.installationDir,
    required this.accessToken,
    this.manifest,
  });
}

final class ClientSyncUseCaseInput {
  final ClientSyncRequest request;
  final FutureOr<bool> Function()? isCancelled;

  const ClientSyncUseCaseInput({required this.request, this.isCancelled});
}

@lazySingleton
class ClientSyncUseCase
    implements StreamUseCase<ClientSyncUseCaseInput, ClientSyncStatus> {
  ClientSyncUseCase({
    required LauncherApiClient launcherApiClient,
    required GameInstallationService installationService,
    LauncherLogService? launcherLogService,
  }) : _launcherApiClient = launcherApiClient,
       _installationService = installationService,
       _launcherLogService = launcherLogService ?? LauncherLogService();

  final LauncherApiClient _launcherApiClient;
  final GameInstallationService _installationService;
  final LauncherLogService _launcherLogService;

  @override
  Stream<ClientSyncStatus> call(ClientSyncUseCaseInput input) {
    final controller = StreamController<ClientSyncStatus>();
    unawaited(_run(input, controller));
    return controller.stream;
  }

  Future<void> _run(
    ClientSyncUseCaseInput input,
    StreamController<ClientSyncStatus> controller,
  ) async {
    String? remoteBuildHash;

    try {
      await _launcherLogService.info(
        'Starting client sync.',
        installationDir: input.request.installationDir,
        details: <String, Object?>{
          'installationDir': input.request.installationDir,
          'manifestProvided': input.request.manifest != null,
        },
      );

      await _throwIfCancelled(input.isCancelled);

      _emit(
        controller,
        ClientSyncStatus(
          stage: ClientSyncStage.fetchingManifest,
          progress: const DownloadProgress.initial(),
          message: 'Loading client manifest...',
          currentPath: null,
          localBuildHash: null,
          remoteBuildHash: null,
          processedFiles: 0,
          totalFiles: 0,
        ),
      );

      final manifest =
          input.request.manifest ??
          await _launcherApiClient.fetchManifest(input.request.accessToken);
      remoteBuildHash = manifest.buildHash;

      final localSnapshot = await _installationService.scanInstallation(
        input.request.installationDir,
        isCancelled: input.isCancelled,
        onProgress: (progress, currentPath, processedFiles, totalFiles) {
          _emit(
            controller,
            ClientSyncStatus(
              stage: ClientSyncStage.scanningLocalFiles,
              progress: progress,
              message: 'Hashing local files...',
              currentPath: currentPath,
              localBuildHash: null,
              remoteBuildHash: remoteBuildHash,
              processedFiles: processedFiles,
              totalFiles: totalFiles,
            ),
          );
        },
      );

      await _throwIfCancelled(input.isCancelled);

      final filesToDownload = _resolveFilesToDownload(manifest, localSnapshot);
      final staleFiles = _resolveStaleFiles(manifest, localSnapshot);

      _emit(
        controller,
        ClientSyncStatus(
          stage: ClientSyncStage.comparingFiles,
          progress: DownloadProgress(
            speed: 0,
            downloaded: localSnapshot.files.length,
            total: manifest.files.length,
            eta: Duration.zero,
          ),
          message: _buildComparisonMessage(
            localSnapshot: localSnapshot,
            remoteBuildHash: remoteBuildHash,
            filesToDownload: filesToDownload.length,
            staleFiles: staleFiles.length,
          ),
          currentPath: null,
          localBuildHash: localSnapshot.buildHash,
          remoteBuildHash: remoteBuildHash,
          processedFiles: localSnapshot.files.length,
          totalFiles: manifest.files.length,
        ),
      );

      if (localSnapshot.buildHash == remoteBuildHash &&
          filesToDownload.isEmpty &&
          staleFiles.isEmpty) {
        _emit(
          controller,
          ClientSyncStatus(
            stage: ClientSyncStage.completed,
            progress: _fullProgress(manifest),
            message: 'Client is up to date.',
            currentPath: null,
            localBuildHash: localSnapshot.buildHash,
            remoteBuildHash: remoteBuildHash,
            processedFiles: manifest.files.length,
            totalFiles: manifest.files.length,
          ),
        );
        return;
      }

      if (staleFiles.isNotEmpty) {
        await _removeStaleFiles(
          controller: controller,
          installationDir: input.request.installationDir,
          staleFiles: staleFiles,
          remoteBuildHash: remoteBuildHash,
          isCancelled: input.isCancelled,
        );
      }

      if (filesToDownload.isNotEmpty) {
        await _downloadChangedFiles(
          controller: controller,
          manifest: manifest,
          accessToken: input.request.accessToken,
          installationDir: input.request.installationDir,
          filesToDownload: filesToDownload,
          remoteBuildHash: remoteBuildHash,
          isCancelled: input.isCancelled,
        );
      }

      final verifiedSnapshot = await _installationService.scanInstallation(
        input.request.installationDir,
        isCancelled: input.isCancelled,
        onProgress: (progress, currentPath, processedFiles, totalFiles) {
          _emit(
            controller,
            ClientSyncStatus(
              stage: ClientSyncStage.verifyingInstallation,
              progress: progress,
              message: 'Verifying updated client...',
              currentPath: currentPath,
              localBuildHash: null,
              remoteBuildHash: remoteBuildHash,
              processedFiles: processedFiles,
              totalFiles: totalFiles,
            ),
          );
        },
      );

      await _throwIfCancelled(input.isCancelled);
      _ensureVerificationPassed(
        manifest: manifest,
        snapshot: verifiedSnapshot,
        installationDir: input.request.installationDir,
        remoteBuildHash: remoteBuildHash,
      );

      await _launcherLogService.info(
        'Client sync completed successfully.',
        installationDir: input.request.installationDir,
        details: <String, Object?>{
          'localBuildHash': verifiedSnapshot.buildHash,
          'remoteBuildHash': remoteBuildHash,
          'fileCount': manifest.files.length,
        },
      );

      _emit(
        controller,
        ClientSyncStatus(
          stage: ClientSyncStage.completed,
          progress: _fullProgress(manifest),
          message: 'Client is ready to play.',
          currentPath: null,
          localBuildHash: verifiedSnapshot.buildHash,
          remoteBuildHash: remoteBuildHash,
          processedFiles: manifest.files.length,
          totalFiles: manifest.files.length,
        ),
      );
    } catch (error, stackTrace) {
      if (error is CancelledException) {
        await _launcherLogService.info(
          'Client sync cancelled.',
          installationDir: input.request.installationDir,
          details: <String, Object?>{'remoteBuildHash': remoteBuildHash},
        );
      } else {
        await _launcherLogService.error(
          'Client sync failed.',
          installationDir: input.request.installationDir,
          details: <String, Object?>{'remoteBuildHash': remoteBuildHash},
          error: error,
          stackTrace: stackTrace,
        );
      }

      if (!controller.isClosed) {
        controller.addError(error, stackTrace);
      }
    } finally {
      await controller.close();
    }
  }

  List<ClientManifestFile> _resolveFilesToDownload(
    ClientManifest manifest,
    ClientInstallationSnapshot snapshot,
  ) {
    final localFilesByPath = snapshot.filesByPath;

    return manifest.files.where((remoteFile) {
      final localFile = localFilesByPath[remoteFile.path];
      return localFile == null ||
          localFile.sha256 != remoteFile.sha256 ||
          localFile.size != remoteFile.size;
    }).toList();
  }

  List<String> _resolveStaleFiles(
    ClientManifest manifest,
    ClientInstallationSnapshot snapshot,
  ) {
    final remoteFiles = manifest.filesByPath;

    return snapshot.files
        .where((localFile) => !remoteFiles.containsKey(localFile.path))
        .map((file) => file.path)
        .toList();
  }

  Future<void> _removeStaleFiles({
    required StreamController<ClientSyncStatus> controller,
    required String installationDir,
    required List<String> staleFiles,
    required String remoteBuildHash,
    required FutureOr<bool> Function()? isCancelled,
  }) async {
    var removedFiles = 0;

    for (final relativePath in staleFiles) {
      await _throwIfCancelled(isCancelled);
      await _installationService.deleteRelativeFile(
        installationDir,
        relativePath,
      );
      removedFiles += 1;

      _emit(
        controller,
        ClientSyncStatus(
          stage: ClientSyncStage.removingStaleFiles,
          progress: DownloadProgress(
            speed: 0,
            downloaded: removedFiles,
            total: staleFiles.length,
            eta: Duration.zero,
          ),
          message: 'Removing obsolete files...',
          currentPath: relativePath,
          localBuildHash: null,
          remoteBuildHash: remoteBuildHash,
          processedFiles: removedFiles,
          totalFiles: staleFiles.length,
        ),
      );
    }
  }

  Future<void> _downloadChangedFiles({
    required StreamController<ClientSyncStatus> controller,
    required ClientManifest manifest,
    required String accessToken,
    required String installationDir,
    required List<ClientManifestFile> filesToDownload,
    required String remoteBuildHash,
    required FutureOr<bool> Function()? isCancelled,
  }) async {
    final totalBytes = filesToDownload.fold<int>(
      0,
      (sum, file) => sum + file.size,
    );
    final stopwatch = Stopwatch()..start();
    var downloadedBytes = 0;
    var bytesSinceLastTick = 0;
    var processedFiles = 0;
    String? currentPath;

    void emitProgress() {
      final elapsedMs = stopwatch.elapsedMilliseconds;
      final speed = elapsedMs == 0
          ? 0
          : (bytesSinceLastTick * 1000) ~/ elapsedMs;
      final remainingBytes = totalBytes - downloadedBytes;
      final eta = speed > 0
          ? Duration(seconds: remainingBytes ~/ speed)
          : Duration.zero;

      _emit(
        controller,
        ClientSyncStatus(
          stage: ClientSyncStage.downloadingFiles,
          progress: DownloadProgress(
            speed: speed,
            downloaded: downloadedBytes,
            total: totalBytes,
            eta: eta,
          ),
          message: 'Downloading changed files...',
          currentPath: currentPath,
          localBuildHash: null,
          remoteBuildHash: remoteBuildHash,
          processedFiles: processedFiles,
          totalFiles: filesToDownload.length,
        ),
      );

      bytesSinceLastTick = 0;
      stopwatch
        ..reset()
        ..start();
    }

    final ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => emitProgress(),
    );

    try {
      for (final file in filesToDownload) {
        await _throwIfCancelled(isCancelled);

        currentPath = file.path;
        final destinationPath = _installationService.resolveClientPath(
          installationDir,
          file.path,
        );
        final temporaryPath = '$destinationPath.moonwell.part';

        try {
          await _installationService.ensureParentDirectoryExists(temporaryPath);
          await _installationService.deleteFileIfExists(temporaryPath);

          await _launcherApiClient.downloadFile(
            installationDir: installationDir,
            accessToken: accessToken,
            file: file,
            destinationPath: temporaryPath,
            isCancelled: isCancelled,
            onChunkReceived: (chunkBytes) {
              downloadedBytes += chunkBytes;
              bytesSinceLastTick += chunkBytes;
            },
          );

          await _verifyDownloadedFile(
            installationDir: installationDir,
            file: file,
            temporaryPath: temporaryPath,
          );

          await _installationService.replaceFile(
            temporaryPath: temporaryPath,
            destinationPath: destinationPath,
          );

          processedFiles += 1;
          emitProgress();
        } on FileSystemException catch (error, stackTrace) {
          await _launcherLogService.error(
            'Local file operation failed during sync.',
            installationDir: installationDir,
            details: <String, Object?>{
              'filePath': file.path,
              'destinationPath': destinationPath,
              'temporaryPath': temporaryPath,
            },
            error: error,
            stackTrace: stackTrace,
          );
          throw LauncherSyncException(
            'Failed to update local file: ${file.path}. '
            'See ${_launcherLogService.logHint(installationDir)}.',
          );
        }
      }
    } finally {
      ticker.cancel();
    }
  }

  void _ensureVerificationPassed({
    required ClientManifest manifest,
    required ClientInstallationSnapshot snapshot,
    required String installationDir,
    required String remoteBuildHash,
  }) {
    final localFilesByPath = snapshot.filesByPath;

    final mismatchedFiles = manifest.files.where((remoteFile) {
      final localFile = localFilesByPath[remoteFile.path];
      return localFile == null ||
          localFile.sha256 != remoteFile.sha256 ||
          localFile.size != remoteFile.size;
    }).toList();

    final extraFiles = snapshot.files
        .where((localFile) => !manifest.filesByPath.containsKey(localFile.path))
        .toList();

    if (snapshot.buildHash != remoteBuildHash ||
        mismatchedFiles.isNotEmpty ||
        extraFiles.isNotEmpty) {
      unawaited(
        _launcherLogService.error(
          'Final client verification failed after update.',
          installationDir: installationDir,
          details: <String, Object?>{
            'localBuildHash': snapshot.buildHash,
            'remoteBuildHash': remoteBuildHash,
            'mismatchedFiles': mismatchedFiles
                .map((file) => file.path)
                .take(10)
                .toList(),
            'extraFiles': extraFiles.map((file) => file.path).take(10).toList(),
          },
        ),
      );

      final firstProblemPath = mismatchedFiles.isNotEmpty
          ? mismatchedFiles.first.path
          : extraFiles.first.path;
      throw LauncherSyncException(
        'Client verification failed after update: $firstProblemPath. '
        'See ${_launcherLogService.logHint(installationDir)}.',
      );
    }
  }

  Future<void> _verifyDownloadedFile({
    required String installationDir,
    required ClientManifestFile file,
    required String temporaryPath,
  }) async {
    final actualSize = await _installationService.getFileSizeIfExists(
      temporaryPath,
    );
    if (actualSize == null) {
      await _launcherLogService.error(
        'Downloaded file is missing before verification.',
        installationDir: installationDir,
        details: <String, Object?>{
          'filePath': file.path,
          'temporaryPath': temporaryPath,
          'expectedSize': file.size,
          'expectedSha256': file.sha256,
        },
      );
      throw LauncherSyncException(
        'Downloaded file is missing: ${file.path}. '
        'See ${_launcherLogService.logHint(installationDir)}.',
      );
    }

    final actualSha256 = await _installationService.computeSha256(
      temporaryPath,
    );
    final expectedSha256 = file.sha256.toLowerCase();
    final normalizedActualSha256 = actualSha256.toLowerCase();

    if (actualSize == file.size && normalizedActualSha256 == expectedSha256) {
      return;
    }

    final preservedPath = await _installationService.preserveFailedDownload(
      temporaryPath,
    );
    await _launcherLogService.error(
      'Downloaded file failed verification.',
      installationDir: installationDir,
      details: <String, Object?>{
        'filePath': file.path,
        'temporaryPath': temporaryPath,
        'preservedPath': preservedPath,
        'expectedSize': file.size,
        'actualSize': actualSize,
        'expectedSha256': file.sha256,
        'actualSha256': actualSha256,
      },
    );
    throw LauncherSyncException(
      'Downloaded file failed verification: ${file.path}. '
      'See ${_launcherLogService.logHint(installationDir)}.',
    );
  }

  String _buildComparisonMessage({
    required ClientInstallationSnapshot localSnapshot,
    required String remoteBuildHash,
    required int filesToDownload,
    required int staleFiles,
  }) {
    if (localSnapshot.buildHash == remoteBuildHash &&
        filesToDownload == 0 &&
        staleFiles == 0) {
      return 'Local build matches the server manifest.';
    }

    return 'Update required: $filesToDownload file(s) to download, '
        '$staleFiles file(s) to remove.';
  }

  DownloadProgress _fullProgress(ClientManifest manifest) {
    return DownloadProgress(
      speed: 0,
      downloaded: manifest.totalSize,
      total: manifest.totalSize,
      eta: Duration.zero,
    );
  }

  void _emit(
    StreamController<ClientSyncStatus> controller,
    ClientSyncStatus status,
  ) {
    if (!controller.isClosed) {
      controller.add(status);
    }
  }

  Future<void> _throwIfCancelled(FutureOr<bool> Function()? isCancelled) async {
    if (isCancelled != null && await isCancelled()) {
      throw const CancelledException();
    }
  }
}

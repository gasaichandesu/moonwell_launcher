import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:moonwell_launcher/core/use_case.dart';
import 'package:moonwell_launcher/features/downloader/domain/entities/download_exceptions.dart';
import 'package:moonwell_launcher/features/downloader/domain/entities/download_progress.dart';
import 'package:moonwell_launcher/features/launcher/data/game_installation_service.dart';
import 'package:moonwell_launcher/features/launcher/data/launcher_api_client.dart';
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
  }) : _launcherApiClient = launcherApiClient,
       _installationService = installationService;

  final LauncherApiClient _launcherApiClient;
  final GameInstallationService _installationService;

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
    try {
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
      final remoteBuildHash = manifest.buildHash;

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
        remoteBuildHash: remoteBuildHash,
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

        await _installationService.ensureParentDirectoryExists(temporaryPath);
        await _installationService.deleteFileIfExists(temporaryPath);

        await _launcherApiClient.downloadFile(
          accessToken: accessToken,
          file: file,
          destinationPath: temporaryPath,
          isCancelled: isCancelled,
          onChunkReceived: (chunkBytes) {
            downloadedBytes += chunkBytes;
            bytesSinceLastTick += chunkBytes;
          },
        );

        final isValid = await _installationService.verifySha256(
          temporaryPath,
          file.sha256,
        );
        if (!isValid) {
          await _installationService.deleteFileIfExists(temporaryPath);
          throw LauncherSyncException(
            'Downloaded file failed verification: ${file.path}',
          );
        }

        await _installationService.replaceFile(
          temporaryPath: temporaryPath,
          destinationPath: destinationPath,
        );

        processedFiles += 1;
        emitProgress();
      }
    } finally {
      ticker.cancel();
    }
  }

  void _ensureVerificationPassed({
    required ClientManifest manifest,
    required ClientInstallationSnapshot snapshot,
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
      throw LauncherSyncException('Client verification failed after update.');
    }
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

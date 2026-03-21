import 'dart:async';
import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:moonwell_launcher/features/downloader/domain/entities/download_progress.dart';
import 'package:moonwell_launcher/features/launcher/application/client_sync_use_case.dart';
import 'package:moonwell_launcher/features/launcher/data/game_installation_service.dart';
import 'package:moonwell_launcher/features/launcher/data/launcher_api_client.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/client_installation_snapshot.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/client_manifest.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/client_manifest_file.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/client_sync_status.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/local_client_file.dart';

void main() {
  group('ClientSyncUseCase', () {
    test(
      'completes without downloads when local snapshot matches manifest',
      () async {
        final manifest = _manifestFromFiles([
          const ClientManifestFile(
            path: 'Wow.exe',
            size: 5,
            sha256: 'wow-hash',
          ),
          const ClientManifestFile(
            path: 'Data/common.MPQ',
            size: 10,
            sha256: 'data-hash',
          ),
        ]);
        final matchingSnapshot = ClientInstallationSnapshot.fromFiles([
          const LocalClientFile(path: 'Wow.exe', size: 5, sha256: 'wow-hash'),
          const LocalClientFile(
            path: 'Data/common.MPQ',
            size: 10,
            sha256: 'data-hash',
          ),
        ]);

        final api = _FakeLauncherApiClient(manifest);
        final installationService = _FakeGameInstallationService([
          matchingSnapshot,
        ]);
        final useCase = ClientSyncUseCase(
          launcherApiClient: api,
          installationService: installationService,
        );

        final statuses = await useCase
            .call(
              ClientSyncUseCaseInput(
                request: ClientSyncRequest(
                  installationDir: 'C:/MoonWell',
                  accessToken: 'token',
                  manifest: manifest,
                ),
              ),
            )
            .toList();

        expect(statuses.last.stage, ClientSyncStage.completed);
        expect(statuses.last.message, 'Client is up to date.');
        expect(api.downloadedPaths, isEmpty);
        expect(installationService.deletedRelativeFiles, isEmpty);
      },
    );

    test(
      'removes stale files and downloads changed files before final verify',
      () async {
        final manifest = _manifestFromFiles([
          const ClientManifestFile(
            path: 'Wow.exe',
            size: 5,
            sha256: 'wow-hash',
          ),
          const ClientManifestFile(
            path: 'Data/common.MPQ',
            size: 10,
            sha256: 'data-hash',
          ),
        ]);
        final initialSnapshot = ClientInstallationSnapshot.fromFiles([
          const LocalClientFile(path: 'Wow.exe', size: 5, sha256: 'old-wow'),
          const LocalClientFile(path: 'legacy.txt', size: 2, sha256: 'legacy'),
        ]);
        final verifiedSnapshot = ClientInstallationSnapshot.fromFiles([
          const LocalClientFile(path: 'Wow.exe', size: 5, sha256: 'wow-hash'),
          const LocalClientFile(
            path: 'Data/common.MPQ',
            size: 10,
            sha256: 'data-hash',
          ),
        ]);

        final api = _FakeLauncherApiClient(manifest);
        final installationService = _FakeGameInstallationService([
          initialSnapshot,
          verifiedSnapshot,
        ]);
        final useCase = ClientSyncUseCase(
          launcherApiClient: api,
          installationService: installationService,
        );

        final statuses = await useCase
            .call(
              ClientSyncUseCaseInput(
                request: ClientSyncRequest(
                  installationDir: 'C:/MoonWell',
                  accessToken: 'token',
                  manifest: manifest,
                ),
              ),
            )
            .toList();

        expect(
          statuses.map((status) => status.stage),
          containsAll([
            ClientSyncStage.removingStaleFiles,
            ClientSyncStage.downloadingFiles,
            ClientSyncStage.verifyingInstallation,
            ClientSyncStage.completed,
          ]),
        );
        expect(installationService.deletedRelativeFiles, ['legacy.txt']);
        expect(api.downloadedPaths, ['Wow.exe', 'Data/common.MPQ']);
        expect(statuses.last.message, 'Client is ready to play.');
      },
    );
  });
}

ClientManifest _manifestFromFiles(List<ClientManifestFile> files) {
  return ClientManifest.fromJson({
    'files': files
        .map(
          (file) => {
            'path': file.path,
            'size': file.size,
            'sha256': file.sha256,
          },
        )
        .toList(),
  });
}

class _FakeLauncherApiClient extends LauncherApiClient {
  _FakeLauncherApiClient(this._manifest);

  final ClientManifest _manifest;
  final List<String> downloadedPaths = [];

  @override
  Future<ClientManifest> fetchManifest(String accessToken) async => _manifest;

  @override
  Future<void> downloadFile({
    required String accessToken,
    required ClientManifestFile file,
    required String destinationPath,
    required FutureOr<bool> Function()? isCancelled,
    required void Function(int chunkBytes) onChunkReceived,
  }) async {
    downloadedPaths.add(file.path);
    onChunkReceived(file.size);
  }
}

class _FakeGameInstallationService extends GameInstallationService {
  _FakeGameInstallationService(List<ClientInstallationSnapshot> snapshots)
    : _snapshots = Queue.of(snapshots);

  final Queue<ClientInstallationSnapshot> _snapshots;
  final List<String> ensuredParentDirectories = [];
  final List<String> deletedRelativeFiles = [];
  final List<String> deletedFiles = [];
  final List<String> replacedDestinations = [];

  @override
  Future<ClientInstallationSnapshot> scanInstallation(
    String installationDir, {
    InstallationScanProgressCallback? onProgress,
    FutureOr<bool> Function()? isCancelled,
  }) async {
    final snapshot = _snapshots.removeFirst();
    var processedFiles = 0;
    var processedBytes = 0;

    for (final file in snapshot.files) {
      processedFiles += 1;
      processedBytes += file.size;
      onProgress?.call(
        DownloadProgress(
          speed: 0,
          downloaded: processedBytes,
          total: snapshot.files.fold<int>(0, (sum, item) => sum + item.size),
          eta: Duration.zero,
        ),
        file.path,
        processedFiles,
        snapshot.files.length,
      );
    }

    return snapshot;
  }

  @override
  Future<void> deleteRelativeFile(
    String installationDir,
    String relativePath,
  ) async {
    deletedRelativeFiles.add(relativePath);
  }

  @override
  String resolveClientPath(String installationDir, String relativePath) {
    return '$installationDir/$relativePath';
  }

  @override
  Future<void> ensureParentDirectoryExists(String filePath) async {
    ensuredParentDirectories.add(filePath);
  }

  @override
  Future<void> deleteFileIfExists(String filePath) async {
    deletedFiles.add(filePath);
  }

  @override
  Future<bool> verifySha256(String filePath, String expectedHash) async => true;

  @override
  Future<void> replaceFile({
    required String temporaryPath,
    required String destinationPath,
  }) async {
    replacedDestinations.add(destinationPath);
  }
}

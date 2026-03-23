import 'package:moonwell_launcher/features/downloader/domain/entities/download_progress.dart';

enum ClientSyncStage {
  fetchingManifest,
  scanningLocalFiles,
  comparingFiles,
  removingStaleFiles,
  downloadingFiles,
  verifyingInstallation,
  completed,
}

final class ClientSyncStatus {
  final ClientSyncStage stage;
  final DownloadProgress progress;
  final String message;
  final String? currentPath;
  final String? localBuildHash;
  final String? remoteBuildHash;
  final int processedFiles;
  final int totalFiles;

  const ClientSyncStatus({
    required this.stage,
    required this.progress,
    required this.message,
    required this.currentPath,
    required this.localBuildHash,
    required this.remoteBuildHash,
    required this.processedFiles,
    required this.totalFiles,
  });
}

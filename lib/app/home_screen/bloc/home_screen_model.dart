import 'package:flutter/foundation.dart';
import 'package:moonwell_launcher/features/downloader/domain/entities/download_progress.dart';

enum HomeScreenPhase {
  idle,
  ready,
  authenticating,
  syncing,
  paused,
  readyToPlay,
  failure,
}

@immutable
final class HomeScreenModel {
  static const Object _sentinel = Object();

  final DownloadProgress progress;
  final Uri? outputPath;
  final HomeScreenPhase phase;
  final bool isAuthenticated;
  final bool hasClientExecutable;
  final String statusText;
  final String? currentPath;
  final String? errorMessage;
  final String? localBuildHash;
  final String? remoteBuildHash;
  final int processedFiles;
  final int totalFiles;

  const HomeScreenModel({
    required this.progress,
    required this.outputPath,
    required this.phase,
    required this.isAuthenticated,
    required this.hasClientExecutable,
    required this.statusText,
    required this.currentPath,
    required this.errorMessage,
    required this.localBuildHash,
    required this.remoteBuildHash,
    required this.processedFiles,
    required this.totalFiles,
  });

  const HomeScreenModel.initial()
    : progress = const DownloadProgress.initial(),
      outputPath = null,
      phase = HomeScreenPhase.idle,
      isAuthenticated = false,
      hasClientExecutable = false,
      statusText = 'Загрузка...',
      currentPath = null,
      errorMessage = null,
      localBuildHash = null,
      remoteBuildHash = null,
      processedFiles = 0,
      totalFiles = 0;

  bool get isBusy =>
      phase == HomeScreenPhase.authenticating ||
      phase == HomeScreenPhase.syncing;

  bool get isSyncing => phase == HomeScreenPhase.syncing;

  bool get canPlay => hasClientExecutable && !isBusy;

  HomeScreenModel copyWith({
    DownloadProgress? progress,
    Object? outputPath = _sentinel,
    HomeScreenPhase? phase,
    bool? isAuthenticated,
    bool? hasClientExecutable,
    String? statusText,
    Object? currentPath = _sentinel,
    Object? errorMessage = _sentinel,
    Object? localBuildHash = _sentinel,
    Object? remoteBuildHash = _sentinel,
    int? processedFiles,
    int? totalFiles,
  }) {
    return HomeScreenModel(
      progress: progress ?? this.progress,
      outputPath: outputPath == _sentinel
          ? this.outputPath
          : outputPath as Uri?,
      phase: phase ?? this.phase,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      hasClientExecutable: hasClientExecutable ?? this.hasClientExecutable,
      statusText: statusText ?? this.statusText,
      currentPath: currentPath == _sentinel
          ? this.currentPath
          : currentPath as String?,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
      localBuildHash: localBuildHash == _sentinel
          ? this.localBuildHash
          : localBuildHash as String?,
      remoteBuildHash: remoteBuildHash == _sentinel
          ? this.remoteBuildHash
          : remoteBuildHash as String?,
      processedFiles: processedFiles ?? this.processedFiles,
      totalFiles: totalFiles ?? this.totalFiles,
    );
  }
}

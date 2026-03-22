import 'package:flutter/foundation.dart';
import 'package:moonwell_launcher/features/downloader/domain/entities/download_progress.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/launcher_news_item.dart';

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
  final List<LauncherNewsItem> newsItems;
  final bool isLoadingNews;
  final String? newsErrorMessage;

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
    required this.newsItems,
    required this.isLoadingNews,
    required this.newsErrorMessage,
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
      totalFiles = 0,
      newsItems = const <LauncherNewsItem>[],
      isLoadingNews = true,
      newsErrorMessage = null;

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
    List<LauncherNewsItem>? newsItems,
    bool? isLoadingNews,
    Object? newsErrorMessage = _sentinel,
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
      newsItems: newsItems ?? this.newsItems,
      isLoadingNews: isLoadingNews ?? this.isLoadingNews,
      newsErrorMessage: newsErrorMessage == _sentinel
          ? this.newsErrorMessage
          : newsErrorMessage as String?,
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:moonwell_launcher/features/downloader/domain/entities/download_progress.dart';

@immutable
final class HomeScreenModel {
  /// The current download progress.
  final DownloadProgress progress;

  /// The output path for the downloaded file.
  final Uri? outputPath;

  const HomeScreenModel({required this.progress, this.outputPath});

  const HomeScreenModel.initial()
    : progress = const DownloadProgress.initial(),
      outputPath = null;

  HomeScreenModel copyWith({DownloadProgress? progress, Uri? outputPath}) {
    return HomeScreenModel(
      progress: progress ?? this.progress,
      outputPath: outputPath ?? this.outputPath,
    );
  }
}

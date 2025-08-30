/// Represents the state of a download.
final class DownloadProgress {
  /// Download speed in bytes per second.
  final int speed;

  /// Total bytes downloaded so far.
  final int downloaded;

  /// Total bytes to download.
  final int total;

  /// Estimated time of arrival (ETA) for the download to complete.
  final Duration eta;

  const DownloadProgress({
    required this.speed,
    required this.downloaded,
    required this.total,
    required this.eta,
  });

  const DownloadProgress.initial()
    : speed = 0,
      downloaded = 0,
      total = 0,
      eta = Duration.zero;
}

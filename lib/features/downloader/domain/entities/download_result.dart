/// Represents the result of a download operation.
class DownloadResult {
  /// Local file path where the downloaded object is stored.
  final String path;

  /// Number of bytes downloaded.
  final int bytes;

  /// Entity tag (ETag) of the downloaded object.
  final String eTag;

  const DownloadResult({
    required this.path,
    required this.bytes,
    required this.eTag,
  });
}

/// Represents a request to download an object from a storage bucket.
class DownloadRequest {
  /// Local file path to save the downloaded object
  final String destinationPath;

  const DownloadRequest({required this.destinationPath});
}

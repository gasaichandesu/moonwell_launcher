import 'dart:async';

/// Interface for interacting with the file system.
abstract interface class FileSystem {
  /// Ensures that the parent directory of the given path exists.
  Future<void> ensureParentExists(String path);

  /// Checks if a file or directory exists at the given path.
  Future<bool> exists(String path);

  /// Returns the size of the file at the given path.
  Future<int> sizeOf(String path);

  /// Truncates the file at the given path to zero length.
  Future<void> truncate(String path);

  /// Creates an empty file at the given path.
  Future<void> createEmpty(String path);

  /// Opens a stream sink for appending data to the file at the given path.
  Future<StreamSink<List<int>>> openAppend(String path);

  /// Verifies the integrity of a file at the given path.
  Future<bool> verifyFile(
    String path, {
    required String expected,
    required String algo,
  });
}

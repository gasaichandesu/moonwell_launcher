import 'package:moonwell_launcher/features/downloader/domain/entities/remote_object_meta.dart';

/// Interface for reading data from storage.
abstract interface class StorageReader {
  /// Retrieves metadata about a remote object.
  Future<RemoteObjectMeta> stat({required String bucket, required String key});

  /// Reads data from a remote object starting at the specified offset.
  Future<Stream<List<int>>> readFromOffset({
    required String bucket,
    required String key,
    required int startOffset,
  });
}

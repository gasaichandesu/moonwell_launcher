import 'package:injectable/injectable.dart';
import 'package:minio/minio.dart';
import 'package:moonwell_launcher/features/downloader/domain/entities/remote_object_meta.dart';
import 'package:moonwell_launcher/features/downloader/domain/repositories/storage_reader.dart';

/// MinIO storage reader implementation.
@LazySingleton(as: StorageReader)
class MinioStorageReader implements StorageReader {
  final Minio _client;

  MinioStorageReader(this._client);

  @override
  Future<Stream<List<int>>> readFromOffset({
    required String bucket,
    required String key,
    required int startOffset,
  }) {
    return _client.getPartialObject(bucket, key, startOffset);
  }

  @override
  Future<RemoteObjectMeta> stat({
    required String bucket,
    required String key,
  }) async {
    final s = await _client.statObject(bucket, key);
    return RemoteObjectMeta(size: s.size ?? 0, eTag: s.etag ?? '');
  }
}

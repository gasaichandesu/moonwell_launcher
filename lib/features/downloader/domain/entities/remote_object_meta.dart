/// Represents metadata for a remote object in a storage bucket.
class RemoteObjectMeta {
  /// Size of the object in bytes.
  final int size;

  /// Entity tag (ETag) of the object.
  final String eTag;

  const RemoteObjectMeta({required this.size, required this.eTag});
}

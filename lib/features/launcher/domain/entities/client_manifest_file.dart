import 'client_hash_entry.dart';

final class ClientManifestFile implements ClientHashEntry {
  @override
  final String path;

  @override
  final int size;

  @override
  final String sha256;

  const ClientManifestFile({
    required this.path,
    required this.size,
    required this.sha256,
  });

  factory ClientManifestFile.fromJson(Map<String, dynamic> json) {
    return ClientManifestFile(
      path: normalizeClientPath(json['path'] as String? ?? ''),
      size: (json['size'] as num? ?? 0).toInt(),
      sha256: (json['sha256'] as String? ?? '').toLowerCase(),
    );
  }
}

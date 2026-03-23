import 'client_hash_entry.dart';
import 'client_manifest_file.dart';

final class ClientManifest {
  final List<ClientManifestFile> files;
  final String buildHash;

  const ClientManifest({required this.files, required this.buildHash});

  factory ClientManifest.fromJson(Map<String, dynamic> json) {
    final files =
        ((json['files'] as List<dynamic>? ?? const <dynamic>[])
                .whereType<Map<String, dynamic>>()
                .map(ClientManifestFile.fromJson)
                .toList())
            .cast<ClientManifestFile>();

    return ClientManifest(files: files, buildHash: computeBuildHash(files));
  }

  Map<String, ClientManifestFile> get filesByPath => {
    for (final file in files) normalizeClientPath(file.path): file,
  };

  int get totalSize => files.fold(0, (sum, file) => sum + file.size);
}

import 'client_hash_entry.dart';
import 'local_client_file.dart';

final class ClientInstallationSnapshot {
  final List<LocalClientFile> files;
  final String buildHash;

  const ClientInstallationSnapshot({
    required this.files,
    required this.buildHash,
  });

  factory ClientInstallationSnapshot.fromFiles(List<LocalClientFile> files) {
    return ClientInstallationSnapshot(
      files: files,
      buildHash: computeBuildHash(files),
    );
  }

  Map<String, LocalClientFile> get filesByPath => {
    for (final file in files) normalizeClientPath(file.path): file,
  };
}

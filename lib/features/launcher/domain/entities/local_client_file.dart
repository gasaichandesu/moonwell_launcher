import 'client_hash_entry.dart';

final class LocalClientFile implements ClientHashEntry {
  @override
  final String path;

  @override
  final int size;

  @override
  final String sha256;

  const LocalClientFile({
    required this.path,
    required this.size,
    required this.sha256,
  });
}

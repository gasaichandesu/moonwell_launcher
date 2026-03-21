import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

abstract interface class ClientHashEntry {
  String get path;
  int get size;
  String get sha256;
}

String normalizeClientPath(String rawPath) {
  final sanitized = rawPath.replaceAll('\\', '/').trim();
  final normalized = p.posix.normalize(sanitized);
  return normalized.startsWith('./') ? normalized.substring(2) : normalized;
}

String computeBuildHash(Iterable<ClientHashEntry> entries) {
  final canonicalEntries =
      entries
          .map(
            (entry) =>
                '${normalizeClientPath(entry.path)}:${entry.size}:${entry.sha256.toLowerCase()}',
          )
          .toList()
        ..sort();

  final payload = canonicalEntries.join('\n');
  return sha256.convert(utf8.encode(payload)).toString();
}

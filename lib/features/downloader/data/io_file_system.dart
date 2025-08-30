import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart' as c;
import 'package:injectable/injectable.dart';
import 'package:moonwell_launcher/features/downloader/domain/repositories/file_system.dart';

@LazySingleton(as: FileSystem)
class IoFileSystem implements FileSystem {
  @override
  Future<void> ensureParentExists(String path) =>
      File(path).parent.create(recursive: true);

  @override
  Future<bool> exists(String path) => File(path).exists();

  @override
  Future<int> sizeOf(String path) async => (await File(path).stat()).size;

  @override
  Future<void> truncate(String path) async =>
      File(path).writeAsBytes(const [], flush: true);

  @override
  Future<void> createEmpty(String path) => File(path).create(recursive: true);

  @override
  Future<StreamSink<List<int>>> openAppend(String path) async =>
      File(path).openWrite(mode: FileMode.append);

  @override
  Future<bool> verifyFile(
    String path, {
    required String expected,
    required String algo,
  }) async {
    final file = File(path);
    if (!await file.exists()) return false;

    final digestHex = await _computeDigestHex(file, algo);
    return _constantTimeEquals(digestHex.toLowerCase(), expected.toLowerCase());
  }

  Future<String> _computeDigestHex(File file, String algo) async {
    final hash = switch (algo.toLowerCase()) {
      'md5' => c.md5,
      'sha256' => c.sha256,
      _ => throw ArgumentError('Unsupported checksum algo: $algo'),
    };

    // Stream the file into the hash converter; no extra buffers.
    final digest = await hash.bind(file.openRead()).first; // -> c.Digest
    return digest.toString(); // lowercase hex
  }

  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}

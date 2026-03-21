import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:moonwell_launcher/config.dart';
import 'package:path/path.dart' as p;

class LauncherLogService {
  static Future<void> _pendingWrite = Future<void>.value();

  Future<void> info(
    String message, {
    String? installationDir,
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    return _write(
      level: 'INFO',
      message: message,
      installationDir: installationDir,
      details: details,
    );
  }

  Future<void> error(
    String message, {
    String? installationDir,
    Map<String, Object?> details = const <String, Object?>{},
    Object? error,
    StackTrace? stackTrace,
  }) {
    return _write(
      level: 'ERROR',
      message: message,
      installationDir: installationDir,
      details: details,
      error: error,
      stackTrace: stackTrace,
    );
  }

  Future<String> resolveLogPath({String? installationDir}) async {
    final logDirectory =
        installationDir == null || installationDir.trim().isEmpty
        ? p.join(Directory.systemTemp.path, 'moonwell_launcher')
        : p.join(installationDir, Config.launcherMetadataDirectoryName);

    await Directory(logDirectory).create(recursive: true);
    return p.join(logDirectory, Config.launcherLogFileName);
  }

  String logHint([String? installationDir]) {
    if (installationDir == null || installationDir.trim().isEmpty) {
      return Config.launcherLogFileName;
    }

    return '${Config.launcherMetadataDirectoryName}/${Config.launcherLogFileName}';
  }

  Future<void> _write({
    required String level,
    required String message,
    required String? installationDir,
    required Map<String, Object?> details,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final operation = _pendingWrite.then((_) async {
      final logPath = await resolveLogPath(installationDir: installationDir);
      final buffer = StringBuffer()
        ..writeln('[${DateTime.now().toIso8601String()}] [$level] $message');

      for (final entry in details.entries) {
        if (entry.value == null) {
          continue;
        }

        buffer.writeln('${entry.key}: ${_stringify(entry.value)}');
      }

      if (error != null) {
        buffer.writeln('error: ${_stringify(error)}');
      }

      if (stackTrace != null) {
        buffer.writeln('stackTrace: $stackTrace');
      }

      buffer.writeln();
      await File(
        logPath,
      ).writeAsString(buffer.toString(), mode: FileMode.append, flush: true);
    });

    _pendingWrite = operation.catchError((_) {});
    return operation;
  }

  String _stringify(Object? value) {
    if (value == null) {
      return 'null';
    }

    if (value is String) {
      return value;
    }

    if (value is Map || value is Iterable) {
      try {
        return jsonEncode(value);
      } catch (_) {
        return value.toString();
      }
    }

    return value.toString();
  }
}

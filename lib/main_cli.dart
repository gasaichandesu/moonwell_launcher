import 'dart:async';
import 'dart:io';
import 'package:logging/logging.dart';
import 'package:moonwell_launcher/features/downloader/application/download_manager.dart';
import 'package:moonwell_launcher/features/downloader/domain/entities/download_request.dart';
import 'package:moonwell_launcher/service_container.dart';

final _log = Logger('Downloader');

Future<void> main(List<String> arguments) async {
  await configureDependencies();
  _setupLogging();

  final manager = getIt<DownloadManager>();

  // Start the download and keep a handle to the subscription
  final stream = manager.start(
    id: 'client',
    request: DownloadRequest(
      destinationPath: '/Users/kalistratovm/Games/MoonWell/client.zip',
    ),
  );

  final done = Completer<int>(); // exit code completer
  late StreamSubscription sub;

  // Graceful shutdown on Ctrl-C / SIGTERM
  final sigintSub = ProcessSignal.sigint.watch();
  sigintSub.listen((_) async {
    _log.warning('SIGINT received. Cancelling all downloads…');
    await manager.cancelAll();
    await sub.cancel();
    if (!done.isCompleted) {
      done.complete(130); // 130 = terminated by Ctrl-C
    }
  });

  final sigtermSub = ProcessSignal.sigterm.watch().listen((_) async {
    _log.warning('SIGTERM received. Cancelling all downloads…');
    await manager.cancelAll();
    await sub.cancel();
    done.complete(143); // 143 = terminated by SIGTERM
  });

  sub = stream.listen(
    (p) {
      _log.info('Speed: ${p.speed}');
      _log.info('ETA:   ${p.eta}');
      _log.info('Done:  ${p.downloaded}/${p.total}');
    },
    onError: (e, st) async {
      _log.severe('Download error', e, st);
      await sigtermSub.cancel();
      done.complete(1);
    },
    onDone: () async {
      _log.info('Download completed');
      await sigtermSub.cancel();
      done.complete(0);
    },
    cancelOnError: true,
  );

  // ⬇️ Keep process alive until one of the completions above fires
  final code = await done.future;
  exit(code);
}

void _setupLogging() {
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((rec) {
    final color = switch (rec.level) {
      Level.SEVERE || Level.SHOUT => '\x1B[31m',
      Level.WARNING => '\x1B[33m',
      Level.INFO => '\x1B[36m',
      _ => '\x1B[90m',
    };
    stdout.writeln(
      '$color[${rec.time.toIso8601String()}] '
      '${rec.level.name.padRight(7)} '
      '${rec.loggerName}: ${rec.message}\x1B[0m',
    );
    if (rec.error != null) stdout.writeln('  Error: ${rec.error}');
    if (rec.stackTrace != null) stdout.writeln('  Stack: ${rec.stackTrace}');
  });
}

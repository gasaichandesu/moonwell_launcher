import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:moonwell_launcher/config.dart';
import 'package:moonwell_launcher/core/use_case.dart';
import 'package:moonwell_launcher/features/downloader/domain/entities/download_exceptions.dart';
import 'package:moonwell_launcher/features/downloader/domain/entities/download_progress.dart';
import 'package:moonwell_launcher/features/downloader/domain/entities/download_request.dart';
import 'package:moonwell_launcher/features/downloader/domain/entities/download_result.dart';
import 'package:moonwell_launcher/features/downloader/domain/repositories/file_system.dart';
import 'package:moonwell_launcher/features/downloader/domain/repositories/storage_reader.dart';

final class DownloadObjectUseCaseInput {
  final DownloadRequest request;

  final FutureOr<bool> Function()? isCancelled;

  final void Function(DownloadResult result)? onComplete;

  const DownloadObjectUseCaseInput({
    required this.request,
    this.isCancelled,
    this.onComplete,
  });
}

@lazySingleton
class DownloadObjectUseCase
    implements StreamUseCase<DownloadObjectUseCaseInput, DownloadProgress> {
  final StorageReader _storage;

  final FileSystem _fileSystem;

  const DownloadObjectUseCase({
    required StorageReader storage,
    required FileSystem fileSystem,
  }) : _storage = storage,
       _fileSystem = fileSystem;

  @override
  Stream<DownloadProgress> call(DownloadObjectUseCaseInput input) async* {
    final request = input.request;

    final meta = await _storage.stat(
      bucket: Config.bucketName,
      key: Config.objectName,
    );
    final total = meta.size;

    final pathToFile = '${request.destinationPath}/${Config.objectName}';

    await _fileSystem.ensureParentExists(pathToFile);

    int offset = 0;
    if (await _fileSystem.exists(pathToFile)) {
      offset = await _fileSystem.sizeOf(pathToFile);
      if (offset > total) {
        await _fileSystem.truncate(pathToFile);
        offset = 0;
      }

      if (offset == total) {
        input.onComplete?.call(
          DownloadResult(path: pathToFile, bytes: offset, eTag: meta.eTag),
        );

        return;
      }
    } else {
      await _fileSystem.createEmpty(pathToFile);
    }

    final objectStream = await _storage.readFromOffset(
      bucket: Config.bucketName,
      key: Config.objectName,
      startOffset: offset,
    );
    final sink = await _fileSystem.openAppend(pathToFile);
    final controller = StreamController<DownloadProgress>();

    final sw = Stopwatch()..start();
    int lastBytes = 0;
    int downloaded = offset;

    Timer? ticker;

    void tick() {
      final elapsedMs = sw.elapsedMilliseconds;
      final bps = elapsedMs == 0 ? 0 : (lastBytes * 1000) ~/ elapsedMs;
      final remaining = (total - downloaded).clamp(0, total);
      final eta = bps > 0 ? Duration(seconds: remaining ~/ bps) : Duration.zero;

      controller.add(
        DownloadProgress(
          downloaded: downloaded,
          total: total,
          speed: bps,
          eta: eta,
        ),
      );
      lastBytes = 0;
      sw
        ..reset()
        ..start();
    }

    ticker = Timer.periodic(const Duration(seconds: 1), (_) => tick());

    late StreamSubscription<List<int>> sub;
    controller.onCancel = () async {
      await sub.cancel();
      await sink.close();
      ticker?.cancel();
    };

    sub = objectStream.listen(
      (chunk) async {
        if (input.isCancelled != null && await input.isCancelled!.call()) {
          ticker?.cancel();
          await sub.cancel();
          await sink.close();
          controller.addError(const CancelledException());
          await controller.close();
          return;
        }
        sink.add(chunk);
        final n = chunk.length;
        downloaded += n;
        lastBytes += n;
      },
      onError: (e, st) async {
        ticker?.cancel();
        await sink.close();
        await controller.close();
        throw _mapError(e);
      },
      onDone: () async {
        ticker?.cancel();
        tick(); // final snapshot
        await sink.close();
        await controller.close();
        input.onComplete?.call(
          DownloadResult(path: pathToFile, bytes: downloaded, eTag: meta.eTag),
        );
      },
      cancelOnError: true,
    );

    yield* controller.stream;
  }

  DownloadException _mapError(Object e) {
    final s = e.toString();
    if (s.contains('SocketException') || s.contains('HandshakeException')) {
      return NetworkException(s);
    }
    if (s.contains('Minio')) return RemoteException(s);
    return IoException(s);
  }
}

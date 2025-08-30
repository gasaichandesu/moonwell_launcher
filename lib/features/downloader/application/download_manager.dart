import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:moonwell_launcher/features/downloader/domain/entities/download_exceptions.dart';
import 'package:moonwell_launcher/features/downloader/domain/entities/download_progress.dart';
import 'package:moonwell_launcher/features/downloader/domain/entities/download_request.dart';
import 'package:moonwell_launcher/features/downloader/use_cases/download_object_use_case.dart';

typedef DownloadId = String;

class _Session {
  _Session({required this.id, required this.request, required this.useCase})
    : progressController = StreamController<DownloadProgress>.broadcast();

  final DownloadId id;
  final DownloadRequest request;
  final DownloadObjectUseCase useCase;

  final StreamController<DownloadProgress> progressController;
  StreamSubscription<DownloadProgress>? sub;
  bool paused = false;
  bool cancelled = false;

  Stream<DownloadProgress> get stream => progressController.stream;

  Future<void> start() async {
    cancelled = false;
    paused = false;
    sub = useCase
        .call(
          DownloadObjectUseCaseInput(
            request: request,
            isCancelled: () async => cancelled || paused,
          ),
        )
        .listen(
          progressController.add,
          onError: progressController.addError,
          onDone: () => progressController.close(),
        );
  }

  Future<void> pause() async {
    paused = true;
    await sub?.cancel();
    sub = null;
  }

  Future<void> resume() async {
    if (cancelled) return;
    paused = false;
    await start(); // will resume from file size
  }

  Future<void> cancel() async {
    cancelled = true;
    await sub?.cancel();
    sub = null;
    if (!progressController.isClosed) {
      progressController.addError(const CancelledException());
      await progressController.close();
    }
  }
}

@lazySingleton
class DownloadManager {
  DownloadManager(this._useCase);

  final DownloadObjectUseCase _useCase;

  final Map<DownloadId, _Session> _sessions = {};

  /// Start or replace a session with [id].
  Stream<DownloadProgress> start({
    required DownloadId id,
    required DownloadRequest request,
  }) {
    // dispose old session if exists
    _sessions[id]?.cancel();
    final s = _Session(id: id, request: request, useCase: _useCase);
    _sessions[id] = s;
    unawaited(s.start());
    return s.stream;
  }

  Stream<DownloadProgress>? progress(DownloadId id) => _sessions[id]?.stream;

  Future<void> pause(DownloadId id) => _sessions[id]?.pause() ?? Future.value();
  Future<void> resume(DownloadId id) =>
      _sessions[id]?.resume() ?? Future.value();
  Future<void> cancel(DownloadId id) async {
    await _sessions[id]?.cancel();
    _sessions.remove(id);
  }

  bool isActive(DownloadId id) => _sessions.containsKey(id);
  Iterable<DownloadId> activeIds() => _sessions.keys;

  /// Cancel and clear all sessions (e.g., on sign-out).
  Future<void> cancelAll() async {
    for (final s in _sessions.values) {
      await s.cancel();
    }
    _sessions.clear();
  }
}

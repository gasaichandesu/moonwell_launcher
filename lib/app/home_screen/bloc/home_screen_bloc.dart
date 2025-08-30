import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonwell_launcher/app/home_screen/bloc/home_screen_model.dart';
import 'package:moonwell_launcher/features/downloader/application/download_manager.dart';
import 'package:moonwell_launcher/features/downloader/domain/entities/download_progress.dart';
import 'package:moonwell_launcher/features/downloader/domain/entities/download_request.dart';
import 'package:moonwell_launcher/features/preferences/domain/repositories/preferences_repository.dart';
import 'package:rxdart/rxdart.dart';

part 'home_screen_event.dart';
part 'home_screen_state.dart';

const _downloadId = 'client';

class HomeScreenBloc extends Bloc<HomeScreenEvent, HomeScreenState> {
  final DownloadManager _downloadManager;
  final PreferencesRepository _preferencesRepository;

  StreamSubscription<DownloadProgress>? _downloadProgressSubscription;

  HomeScreenBloc({
    required DownloadManager downloadManager,
    required PreferencesRepository preferencesRepository,
  }) : _downloadManager = downloadManager,
       _preferencesRepository = preferencesRepository,
       super(HomeScreenInitialState(model: HomeScreenModel.initial())) {
    _setupHandlers();

    add(HomeScreenLoad());
  }

  void _setupHandlers() {
    on<HomeScreenLoad>(_onHomeScreenLoad);
    on<HomeScreenDownloadRequested>(_onHomeScreenDownloadRequested);
    on<HomeScreenDownloadPaused>(_onHomeScreenDownloadPaused);
    on<HomeScreenOutputDirRequested>(_onHomeOutputDirRequested);
    on<HomeScreenDownloadProgressUpdated>(
      _onHomeScreenDownloadProgressUpdated,
      transformer: (events, mapper) =>
          events.throttleTime(const Duration(seconds: 2)).switchMap(mapper),
    );
  }

  Future<void> _onHomeScreenLoad(
    HomeScreenLoad event,
    Emitter<HomeScreenState> emit,
  ) async {
    final outputDir = await _preferencesRepository.getOutputDir();

    emit(
      HomeScreenReadyToDownloadState(
        model: state.model.copyWith(outputPath: outputDir),
      ),
    );
  }

  Future<void> _onHomeScreenDownloadRequested(
    HomeScreenDownloadRequested event,
    Emitter<HomeScreenState> emit,
  ) async {
    if (state.model.outputPath == null) {
      emit(HomeScreenOutputDirSelectionState(model: state.model.copyWith()));
      return;
    }

    _downloadProgressSubscription = _downloadManager
        .start(
          id: _downloadId,
          request: DownloadRequest(
            destinationPath: state.model.outputPath!.toFilePath(),
          ),
        )
        .listen((progress) => add(HomeScreenDownloadProgressUpdated(progress)));

    emit(HomeScreenDownloadInitializing(model: state.model.copyWith()));
  }

  void _onHomeScreenDownloadProgressUpdated(
    HomeScreenDownloadProgressUpdated event,
    Emitter<HomeScreenState> emit,
  ) {
    emit(
      HomeScreenDownloadingState(
        model: state.model.copyWith(progress: event.progress),
      ),
    );
  }

  @override
  Future<void> close() async {
    await _downloadProgressSubscription?.cancel();
    await _downloadManager.cancel(_downloadId);

    return super.close();
  }

  FutureOr<void> _onHomeScreenDownloadPaused(
    HomeScreenDownloadPaused event,
    Emitter<HomeScreenState> emit,
  ) async {
    await _downloadManager.pause(_downloadId);

    emit(HomeScreenDownloadPausedState(model: state.model.copyWith()));
  }

  FutureOr<void> _onHomeOutputDirRequested(
    HomeScreenOutputDirRequested event,
    Emitter<HomeScreenState> emit,
  ) async {
    emit(HomeScreenReadyToDownloadState(model: state.model.copyWith()));

    final directory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Please select installation directory',
    );

    if (directory == null) {
      return;
    }

    await _preferencesRepository.setOutputDir(Uri.directory(directory));

    emit(
      HomeScreenReadyToDownloadState(
        model: state.model.copyWith(outputPath: Uri.directory(directory)),
      ),
    );
  }
}

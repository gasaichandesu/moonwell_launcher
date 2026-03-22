import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonwell_launcher/app/home_screen/bloc/home_screen_model.dart';
import 'package:moonwell_launcher/features/downloader/domain/entities/download_exceptions.dart';
import 'package:moonwell_launcher/features/downloader/domain/entities/download_progress.dart';
import 'package:moonwell_launcher/features/launcher/application/client_sync_use_case.dart';
import 'package:moonwell_launcher/features/launcher/data/game_installation_service.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/client_manifest.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/client_sync_status.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/launcher_exception.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/launcher_session.dart';
import 'package:moonwell_launcher/features/preferences/domain/repositories/preferences_repository.dart';

part 'home_screen_event.dart';
part 'home_screen_state.dart';

class HomeScreenBloc extends Bloc<HomeScreenEvent, HomeScreenState> {
  HomeScreenBloc({
    required ClientSyncUseCase clientSyncUseCase,
    required GameInstallationService gameInstallationService,
    required PreferencesRepository preferencesRepository,
    required LauncherSession session,
    required ClientManifest manifest,
  }) : _clientSyncUseCase = clientSyncUseCase,
       _gameInstallationService = gameInstallationService,
       _preferencesRepository = preferencesRepository,
       _session = session,
       _manifest = manifest,
       super(
         HomeScreenState(
           model: HomeScreenModel.initial().copyWith(
             isAuthenticated: true,
             remoteBuildHash: manifest.buildHash,
           ),
         ),
       ) {
    on<HomeScreenLoad>(_onHomeScreenLoad);
    on<HomeScreenSyncRequested>(_onHomeScreenSyncRequested);
    on<HomeScreenOutputDirRequested>(_onHomeScreenOutputDirRequested);
    on<HomeScreenPauseRequested>(_onHomeScreenPauseRequested);
    on<HomeScreenPlayRequested>(_onHomeScreenPlayRequested);
    on<HomeScreenLogoutRequested>(_onHomeScreenLogoutRequested);
    on<HomeScreenSyncStatusChanged>(_onHomeScreenSyncStatusChanged);
    on<HomeScreenSyncFailed>(_onHomeScreenSyncFailed);

    add(HomeScreenLoad());
  }

  final ClientSyncUseCase _clientSyncUseCase;
  final GameInstallationService _gameInstallationService;
  final PreferencesRepository _preferencesRepository;

  StreamSubscription<ClientSyncStatus>? _syncSubscription;
  final LauncherSession _session;
  final ClientManifest _manifest;
  bool _pauseRequested = false;

  Future<void> _onHomeScreenLoad(
    HomeScreenLoad event,
    Emitter<HomeScreenState> emit,
  ) async {
    final outputPath = await _preferencesRepository.getOutputDir();
    final hasClientExecutable = await _resolveExecutablePresence(outputPath);

    emit(
      HomeScreenState(
        model: state.model.copyWith(
          outputPath: outputPath,
          hasClientExecutable: hasClientExecutable,
          phase: _stablePhase(hasClientExecutable),
          statusText: _buildIdleStatus(
            isAuthenticated: state.model.isAuthenticated,
            outputPath: outputPath,
            hasClientExecutable: hasClientExecutable,
          ),
        ),
      ),
    );
  }

  Future<void> _onHomeScreenSyncRequested(
    HomeScreenSyncRequested event,
    Emitter<HomeScreenState> emit,
  ) async {
    if (state.model.isSyncing) {
      return;
    }

    final outputPath = state.model.outputPath;
    if (outputPath == null) {
      add(HomeScreenOutputDirRequested());
      return;
    }

    await _syncSubscription?.cancel();
    _pauseRequested = false;

    emit(
      HomeScreenState(
        model: state.model.copyWith(
          phase: HomeScreenPhase.syncing,
          progress: const DownloadProgress.initial(),
          statusText: 'Подготавливаю проверку клиента...',
          currentPath: null,
          errorMessage: null,
          processedFiles: 0,
          totalFiles: 0,
        ),
      ),
    );

    _syncSubscription = _clientSyncUseCase
        .call(
          ClientSyncUseCaseInput(
            request: ClientSyncRequest(
              installationDir: outputPath.toFilePath(),
              accessToken: _session.accessToken,
              manifest: _manifest,
            ),
            isCancelled: () async => _pauseRequested,
          ),
        )
        .listen(
          (status) => add(HomeScreenSyncStatusChanged(status)),
          onError: (error, _) => add(HomeScreenSyncFailed(error)),
        );
  }

  Future<void> _onHomeScreenOutputDirRequested(
    HomeScreenOutputDirRequested event,
    Emitter<HomeScreenState> emit,
  ) async {
    if (state.model.isSyncing) {
      return;
    }

    final directory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Выберите папку установки Moonwell',
    );

    if (directory == null) {
      return;
    }

    final outputPath = Uri.directory(directory);
    await _preferencesRepository.setOutputDir(outputPath);

    final hasClientExecutable = await _resolveExecutablePresence(outputPath);

    emit(
      HomeScreenState(
        model: state.model.copyWith(
          outputPath: outputPath,
          hasClientExecutable: hasClientExecutable,
          phase: _stablePhase(hasClientExecutable),
          statusText: _buildIdleStatus(
            isAuthenticated: state.model.isAuthenticated,
            outputPath: outputPath,
            hasClientExecutable: hasClientExecutable,
          ),
          errorMessage: null,
        ),
      ),
    );

    add(HomeScreenSyncRequested());
  }

  Future<void> _onHomeScreenPauseRequested(
    HomeScreenPauseRequested event,
    Emitter<HomeScreenState> emit,
  ) async {
    if (!state.model.isSyncing) {
      return;
    }

    _pauseRequested = true;

    emit(
      HomeScreenState(
        model: state.model.copyWith(
          statusText: 'Останавливаю обновление...',
          errorMessage: null,
        ),
      ),
    );
  }

  Future<void> _onHomeScreenPlayRequested(
    HomeScreenPlayRequested event,
    Emitter<HomeScreenState> emit,
  ) async {
    final outputPath = state.model.outputPath;
    if (outputPath == null) {
      emit(_buildErrorState('Сначала выберите папку установки.'));
      return;
    }

    try {
      final installationDir = outputPath.toFilePath();
      await _gameInstallationService.clearCache(installationDir);
      await _gameInstallationService.launchGame(installationDir);

      emit(
        HomeScreenState(
          model: state.model.copyWith(
            phase: HomeScreenPhase.readyToPlay,
            statusText: 'Игра запущена. Папка Cache очищена перед стартом.',
            errorMessage: null,
          ),
        ),
      );
    } catch (error) {
      emit(
        _buildErrorState(
          'Не удалось запустить игру.',
          errorMessage: _formatError(error),
        ),
      );
    }
  }

  Future<void> _onHomeScreenLogoutRequested(
    HomeScreenLogoutRequested event,
    Emitter<HomeScreenState> emit,
  ) async {
    _pauseRequested = true;
    await _syncSubscription?.cancel();
    _syncSubscription = null;
    await _preferencesRepository.clearLauncherSession();

    emit(
      HomeScreenState(
        model: state.model.copyWith(
          phase: HomeScreenPhase.idle,
          isAuthenticated: false,
          progress: const DownloadProgress.initial(),
          statusText:
              'Сессия завершена. Войдите снова.',
          currentPath: null,
          errorMessage: null,
          localBuildHash: null,
          remoteBuildHash: null,
          processedFiles: 0,
          totalFiles: 0,
        ),
      ),
    );
  }

  Future<void> _onHomeScreenSyncStatusChanged(
    HomeScreenSyncStatusChanged event,
    Emitter<HomeScreenState> emit,
  ) async {
    final outputPath = state.model.outputPath;
    final isCompleted = event.status.stage == ClientSyncStage.completed;
    final hasClientExecutable = isCompleted
        ? await _resolveExecutablePresence(outputPath)
        : state.model.hasClientExecutable;

    emit(
      HomeScreenState(
        model: state.model.copyWith(
          progress: event.status.progress,
          phase: isCompleted
              ? _stablePhase(hasClientExecutable)
              : HomeScreenPhase.syncing,
          hasClientExecutable: hasClientExecutable,
          statusText: event.status.message,
          currentPath: event.status.currentPath,
          errorMessage: null,
          localBuildHash: event.status.localBuildHash,
          remoteBuildHash: event.status.remoteBuildHash,
          processedFiles: event.status.processedFiles,
          totalFiles: event.status.totalFiles,
        ),
      ),
    );
  }

  Future<void> _onHomeScreenSyncFailed(
    HomeScreenSyncFailed event,
    Emitter<HomeScreenState> emit,
  ) async {
    final hasClientExecutable = await _resolveExecutablePresence(
      state.model.outputPath,
    );

    if (_pauseRequested || event.error is CancelledException) {
      _pauseRequested = false;

      emit(
        HomeScreenState(
          model: state.model.copyWith(
            phase: HomeScreenPhase.paused,
            hasClientExecutable: hasClientExecutable,
            statusText: 'Обновление приостановлено.',
            currentPath: null,
            errorMessage: null,
          ),
        ),
      );
      return;
    }

    emit(
      HomeScreenState(
        model: state.model.copyWith(
          phase: HomeScreenPhase.failure,
          hasClientExecutable: hasClientExecutable,
          statusText: 'Не удалось завершить обновление клиента.',
          currentPath: null,
          errorMessage: _formatError(event.error),
        ),
      ),
    );
  }

  HomeScreenState _buildErrorState(String statusText, {String? errorMessage}) {
    final hasClientExecutable = state.model.hasClientExecutable;

    return HomeScreenState(
      model: state.model.copyWith(
        phase: hasClientExecutable
            ? HomeScreenPhase.readyToPlay
            : HomeScreenPhase.failure,
        statusText: statusText,
        errorMessage: errorMessage ?? statusText,
      ),
    );
  }

  HomeScreenPhase _stablePhase(bool hasClientExecutable) {
    return hasClientExecutable
        ? HomeScreenPhase.readyToPlay
        : HomeScreenPhase.ready;
  }

  Future<bool> _resolveExecutablePresence(Uri? outputPath) async {
    if (outputPath == null) {
      return false;
    }

    return _gameInstallationService.hasClientExecutable(
      outputPath.toFilePath(),
    );
  }

  String _buildIdleStatus({
    required bool isAuthenticated,
    required Uri? outputPath,
    required bool hasClientExecutable,
  }) {
    if (hasClientExecutable && isAuthenticated) {
      return 'Клиент найден. Можно играть или проверять обновления.';
    }

    if (hasClientExecutable) {
      return 'Клиент найден. Можно играть или авторизоваться для проверки обновлений.';
    }

    if (outputPath == null && !isAuthenticated) {
      return 'Выберите папку установки и авторизуйтесь.';
    }

    if (outputPath == null) {
      return 'Авторизация выполнена. Выберите папку установки.';
    }

    if (isAuthenticated) {
      return 'Папка выбрана. Можно устанавливать или обновлять клиент.';
    }

    return 'Папка выбрана. Авторизуйтесь для проверки файлов.';
  }

  String _formatError(Object error) {
    if (error is LauncherException) {
      return error.message;
    }

    if (error is DownloadException) {
      return error.message;
    }

    final raw = error.toString();
    return raw.startsWith('Exception: ') ? raw.substring(11) : raw;
  }

  @override
  Future<void> close() async {
    _pauseRequested = true;
    await _syncSubscription?.cancel();
    return super.close();
  }
}

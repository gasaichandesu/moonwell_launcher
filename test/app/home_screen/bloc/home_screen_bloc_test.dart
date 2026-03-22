import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moonwell_launcher/app/home_screen/bloc/home_screen_bloc.dart';
import 'package:moonwell_launcher/features/launcher/application/client_sync_use_case.dart';
import 'package:moonwell_launcher/features/launcher/data/game_installation_service.dart';
import 'package:moonwell_launcher/features/launcher/data/launcher_api_client.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/client_installation_snapshot.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/client_manifest.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/client_sync_status.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/launcher_news_item.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/launcher_session.dart';
import 'package:moonwell_launcher/features/preferences/domain/repositories/preferences_repository.dart';

void main() {
  group('HomeScreenBloc', () {
    test('loads launcher news on startup', () async {
      final bloc = HomeScreenBloc(
        clientSyncUseCase: _IdleClientSyncUseCase(),
        gameInstallationService: _FakeGameInstallationService(),
        launcherApiClient: _FakeLauncherApiClient(
          newsItems: const [
            LauncherNewsItem(
              id: 1,
              title: 'Update 1.2',
              body: 'News body',
              imageUrl: null,
              createdAt: null,
            ),
          ],
        ),
        preferencesRepository: _FakePreferencesRepository(),
        session: LauncherSession(
          accessToken: 'token',
          tokenType: 'Bearer',
          expiresAt: null,
        ),
        manifest: ClientManifest.fromJson(<String, Object?>{
          'files': <Map<String, Object?>>[],
        }),
      );

      await pumpEventQueue(times: 20);

      expect(bloc.state.model.isLoadingNews, isFalse);
      expect(bloc.state.model.newsErrorMessage, isNull);
      expect(bloc.state.model.newsItems, hasLength(1));
      expect(bloc.state.model.newsItems.first.title, 'Update 1.2');

      await bloc.close();
    });
  });
}

class _IdleClientSyncUseCase extends ClientSyncUseCase {
  _IdleClientSyncUseCase()
    : super(
        launcherApiClient: LauncherApiClient(),
        installationService: GameInstallationService(),
      );

  @override
  Stream<ClientSyncStatus> call(ClientSyncUseCaseInput input) {
    return const Stream<ClientSyncStatus>.empty();
  }
}

class _FakeLauncherApiClient extends LauncherApiClient {
  _FakeLauncherApiClient({required this.newsItems});

  final List<LauncherNewsItem> newsItems;

  @override
  Future<List<LauncherNewsItem>> fetchNews(String accessToken) async =>
      newsItems;
}

class _FakeGameInstallationService extends GameInstallationService {
  @override
  Future<bool> hasClientExecutable(String installationDir) async => false;

  @override
  Future<ClientInstallationSnapshot> scanInstallation(
    String installationDir, {
    InstallationScanProgressCallback? onProgress,
    FutureOr<bool> Function()? isCancelled,
  }) async {
    return ClientInstallationSnapshot.fromFiles(const []);
  }
}

class _FakePreferencesRepository implements PreferencesRepository {
  @override
  Future<void> clearLauncherSession() async {}

  @override
  Future<LauncherSession?> getLauncherSession() async => null;

  @override
  Future<Uri?> getOutputDir() async => null;

  @override
  Future<void> setLauncherSession(LauncherSession session) async {}

  @override
  Future<void> setOutputDir(Uri uri) async {}
}

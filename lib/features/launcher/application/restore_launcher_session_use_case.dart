import 'package:moonwell_launcher/features/launcher/data/launcher_api_client.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/client_manifest.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/launcher_session.dart';
import 'package:moonwell_launcher/features/preferences/domain/repositories/preferences_repository.dart';

final class RestoreLauncherSessionResult {
  final LauncherSession? session;
  final ClientManifest? manifest;

  const RestoreLauncherSessionResult._({
    required this.session,
    required this.manifest,
  });

  const RestoreLauncherSessionResult.unauthenticated()
    : this._(session: null, manifest: null);

  const RestoreLauncherSessionResult.authenticated({
    required LauncherSession session,
    required ClientManifest manifest,
  }) : this._(session: session, manifest: manifest);

  bool get isAuthenticated => session != null && manifest != null;
}

class RestoreLauncherSessionUseCase {
  RestoreLauncherSessionUseCase({
    required LauncherApiClient launcherApiClient,
    required PreferencesRepository preferencesRepository,
  }) : _launcherApiClient = launcherApiClient,
       _preferencesRepository = preferencesRepository;

  final LauncherApiClient _launcherApiClient;
  final PreferencesRepository _preferencesRepository;

  Future<RestoreLauncherSessionResult> call() async {
    final savedSession = await _preferencesRepository.getLauncherSession();
    if (savedSession == null || !savedSession.hasAccessToken) {
      return const RestoreLauncherSessionResult.unauthenticated();
    }

    if (savedSession.isExpired) {
      await _preferencesRepository.clearLauncherSession();
      return const RestoreLauncherSessionResult.unauthenticated();
    }

    try {
      final manifest = await _launcherApiClient.fetchManifest(
        savedSession.accessToken,
      );
      return RestoreLauncherSessionResult.authenticated(
        session: savedSession,
        manifest: manifest,
      );
    } catch (_) {
      return const RestoreLauncherSessionResult.unauthenticated();
    }
  }
}

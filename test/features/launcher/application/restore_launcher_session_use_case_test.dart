import 'package:flutter_test/flutter_test.dart';
import 'package:moonwell_launcher/features/launcher/application/restore_launcher_session_use_case.dart';
import 'package:moonwell_launcher/features/launcher/data/launcher_api_client.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/client_manifest.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/launcher_session.dart';
import 'package:moonwell_launcher/features/preferences/domain/repositories/preferences_repository.dart';

void main() {
  group('RestoreLauncherSessionUseCase', () {
    test('returns unauthenticated when there is no saved session', () async {
      final api = _FakeLauncherApiClient();
      final preferences = _FakePreferencesRepository();
      final useCase = RestoreLauncherSessionUseCase(
        launcherApiClient: api,
        preferencesRepository: preferences,
      );

      final result = await useCase();

      expect(result.isAuthenticated, isFalse);
      expect(api.fetchManifestCalls, 0);
    });

    test('clears expired session and returns unauthenticated', () async {
      final api = _FakeLauncherApiClient();
      final preferences = _FakePreferencesRepository(
        session: LauncherSession(
          accessToken: 'expired-token',
          tokenType: 'Bearer',
          expiresAt: DateTime.now().toUtc().subtract(
            const Duration(minutes: 1),
          ),
        ),
      );
      final useCase = RestoreLauncherSessionUseCase(
        launcherApiClient: api,
        preferencesRepository: preferences,
      );

      final result = await useCase();

      expect(result.isAuthenticated, isFalse);
      expect(preferences.clearedSession, isTrue);
      expect(api.fetchManifestCalls, 0);
    });

    test('restores session and manifest when saved token is valid', () async {
      final manifest = ClientManifest.fromJson({
        'files': [
          {'path': 'Wow.exe', 'size': 5, 'sha256': 'wow-hash'},
        ],
      });
      final api = _FakeLauncherApiClient(manifest: manifest);
      final preferences = _FakePreferencesRepository(
        session: LauncherSession(
          accessToken: 'saved-token',
          tokenType: 'Bearer',
          expiresAt: DateTime.now().toUtc().add(const Duration(days: 1)),
        ),
      );
      final useCase = RestoreLauncherSessionUseCase(
        launcherApiClient: api,
        preferencesRepository: preferences,
      );

      final result = await useCase();

      expect(result.isAuthenticated, isTrue);
      expect(result.session?.accessToken, 'saved-token');
      expect(result.manifest?.buildHash, manifest.buildHash);
      expect(api.fetchManifestCalls, 1);
    });
  });
}

class _FakeLauncherApiClient extends LauncherApiClient {
  _FakeLauncherApiClient({ClientManifest? manifest}) : _manifest = manifest;

  final ClientManifest? _manifest;
  int fetchManifestCalls = 0;

  @override
  Future<ClientManifest> fetchManifest(String accessToken) async {
    fetchManifestCalls += 1;
    return _manifest ??
        ClientManifest.fromJson(<String, Object?>{
          'files': <Map<String, Object?>>[],
        });
  }
}

class _FakePreferencesRepository implements PreferencesRepository {
  _FakePreferencesRepository({this.session});

  LauncherSession? session;
  bool clearedSession = false;

  @override
  Future<void> clearLauncherSession() async {
    clearedSession = true;
    session = null;
  }

  @override
  Future<LauncherSession?> getLauncherSession() async => session;

  @override
  Future<Uri?> getOutputDir() async => null;

  @override
  Future<void> setLauncherSession(LauncherSession session) async {
    this.session = session;
  }

  @override
  Future<void> setOutputDir(Uri uri) async {}
}

import 'package:flutter_test/flutter_test.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/launcher_session.dart';
import 'package:moonwell_launcher/features/preferences/data/repositories/shared_prefs_preferences_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SharedPrefsPreferencesRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('persists launcher session between reads', () async {
      final preferences = await SharedPreferences.getInstance();
      final repository = SharedPrefsPreferencesRepository(
        preferences: preferences,
      );
      final session = LauncherSession(
        accessToken: 'token',
        tokenType: 'Bearer',
        expiresAt: DateTime.parse('2030-01-01T00:00:00Z'),
      );

      await repository.setLauncherSession(session);
      final restoredSession = await repository.getLauncherSession();

      expect(restoredSession?.accessToken, 'token');
      expect(restoredSession?.tokenType, 'Bearer');
      expect(
        restoredSession?.expiresAt?.toUtc(),
        DateTime.parse('2030-01-01T00:00:00Z'),
      );
    });

    test('clears persisted launcher session', () async {
      final preferences = await SharedPreferences.getInstance();
      final repository = SharedPrefsPreferencesRepository(
        preferences: preferences,
      );

      await repository.setLauncherSession(
        LauncherSession(
          accessToken: 'token',
          tokenType: 'Bearer',
          expiresAt: null,
        ),
      );
      await repository.clearLauncherSession();

      expect(await repository.getLauncherSession(), isNull);
    });
  });
}

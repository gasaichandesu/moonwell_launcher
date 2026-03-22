import 'package:moonwell_launcher/features/launcher/domain/entities/launcher_session.dart';

abstract interface class PreferencesRepository {
  Future<Uri?> getOutputDir();

  Future<void> setOutputDir(Uri uri);

  Future<LauncherSession?> getLauncherSession();

  Future<void> setLauncherSession(LauncherSession session);

  Future<void> clearLauncherSession();
}

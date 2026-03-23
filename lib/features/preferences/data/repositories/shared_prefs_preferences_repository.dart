import 'dart:convert';

import 'package:injectable/injectable.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/launcher_session.dart';
import 'package:moonwell_launcher/features/preferences/domain/repositories/preferences_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _outputDirKey = 'output_dir';
const _launcherSessionKey = 'launcher_session';

@LazySingleton(as: PreferencesRepository, env: ['flutter'])
class SharedPrefsPreferencesRepository implements PreferencesRepository {
  final SharedPreferences _preferences;

  const SharedPrefsPreferencesRepository({
    required SharedPreferences preferences,
  }) : _preferences = preferences;

  @override
  Future<Uri?> getOutputDir() {
    final rawPath = _preferences.getString(_outputDirKey);

    if (rawPath == null) {
      return Future.value(null);
    }

    return Future.value(Uri.parse(rawPath));
  }

  @override
  Future<void> setOutputDir(Uri uri) {
    return _preferences.setString(_outputDirKey, uri.toString());
  }

  @override
  Future<LauncherSession?> getLauncherSession() {
    final rawSession = _preferences.getString(_launcherSessionKey);
    if (rawSession == null || rawSession.isEmpty) {
      return Future.value(null);
    }

    try {
      final decoded = jsonDecode(rawSession);
      if (decoded is! Map) {
        return Future.value(null);
      }

      final json = decoded.map((key, value) => MapEntry(key.toString(), value));
      return Future.value(LauncherSession.fromJson(json));
    } catch (_) {
      return Future.value(null);
    }
  }

  @override
  Future<void> setLauncherSession(LauncherSession session) {
    return _preferences.setString(
      _launcherSessionKey,
      jsonEncode(session.toJson()),
    );
  }

  @override
  Future<void> clearLauncherSession() {
    return _preferences.remove(_launcherSessionKey);
  }
}

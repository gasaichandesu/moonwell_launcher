import 'package:injectable/injectable.dart';
import 'package:moonwell_launcher/features/preferences/domain/repositories/preferences_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _outputDirKey = 'output_dir';

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
}

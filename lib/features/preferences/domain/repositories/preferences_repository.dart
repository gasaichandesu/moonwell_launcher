abstract interface class PreferencesRepository {
  Future<Uri?> getOutputDir();

  Future<void> setOutputDir(Uri uri);
}

final class Config {
  static const launcherApiBaseUrl = String.fromEnvironment(
    'MOONWELL_API_BASE_URL',
  );
  static const launcherLogFileName = 'launcher.log';
  static const gameExecutableName = 'Wow.exe';
  static const cacheDirectoryName = 'Cache';
  static const launcherMetadataDirectoryName = '.moonwell_launcher';
  static const hashCacheFileName = 'hash_cache.json';
  static const ignoredVerificationDirectories = <String>{
    'cache',
    'errors',
    'logs',
    'screenshots',
    'wtf',
    '.moonwell_launcher',
  };
}

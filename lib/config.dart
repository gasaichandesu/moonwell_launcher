final class Config {
  static const launcherApiBaseUrl = String.fromEnvironment(
    'MOONWELL_API_BASE_URL',
  );
  static const gameExecutableName = 'Wow.exe';
  static const cacheDirectoryName = 'Cache';
  static const ignoredVerificationDirectories = <String>{
    'cache',
    'errors',
    'logs',
    'screenshots',
    'wtf',
  };
}

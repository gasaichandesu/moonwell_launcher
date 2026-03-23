sealed class LauncherException implements Exception {
  final String message;

  const LauncherException(this.message);

  @override
  String toString() => message;
}

final class LauncherConfigurationException extends LauncherException {
  const LauncherConfigurationException(super.message);
}

final class LauncherApiException extends LauncherException {
  const LauncherApiException(super.message);
}

final class LauncherSyncException extends LauncherException {
  const LauncherSyncException(super.message);
}

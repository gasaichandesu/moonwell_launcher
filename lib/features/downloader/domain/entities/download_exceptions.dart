sealed class DownloadException implements Exception {
  final String message;

  const DownloadException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

final class NetworkException extends DownloadException {
  const NetworkException(super.message);
}

final class RemoteException extends DownloadException {
  const RemoteException(super.message);
}

final class IoException extends DownloadException {
  const IoException(super.message);
}

final class CancelledException extends DownloadException {
  const CancelledException() : super('Cancelled');
}

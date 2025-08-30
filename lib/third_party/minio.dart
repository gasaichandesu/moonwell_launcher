import 'package:injectable/injectable.dart';
import 'package:minio/minio.dart';
import 'package:moonwell_launcher/config.dart';

@module
abstract class MinioModule {
  @lazySingleton
  Minio get minioClient => Minio(
    endPoint: Config.host,
    accessKey: Config.keyId,
    secretKey: Config.secret,
  );
}

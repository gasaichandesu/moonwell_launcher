import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:moonwell_launcher/config.dart';
import 'package:moonwell_launcher/features/downloader/domain/entities/download_exceptions.dart';
import 'package:moonwell_launcher/features/launcher/data/launcher_log_service.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/client_manifest.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/client_manifest_file.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/launcher_exception.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/launcher_news_item.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/launcher_session.dart';

@lazySingleton
class LauncherApiClient {
  LauncherApiClient({LauncherLogService? launcherLogService})
    : _launcherLogService = launcherLogService ?? LauncherLogService(),
      _dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 30),
          headers: const {HttpHeaders.acceptHeader: 'application/json'},
        ),
      );

  final Dio _dio;
  final LauncherLogService _launcherLogService;

  Future<LauncherSession> login({
    required String username,
    required String password,
  }) async {
    final loginUri = _resolveUri('api/launcher/login');

    try {
      final response = await _dio.postUri(
        loginUri,
        data: {'username': username, 'password': password},
      );

      return LauncherSession.fromJson(_coerceMap(response.data));
    } on DioException catch (error, stackTrace) {
      await _launcherLogService.error(
        'Launcher login request failed.',
        details: <String, Object?>{
          'endpoint': loginUri.toString(),
          'statusCode': error.response?.statusCode,
          'dioType': error.type.name,
          'responseBody': _summarizePayload(error.response?.data),
        },
        error: error,
        stackTrace: stackTrace,
      );
      throw LauncherApiException(_extractErrorMessage(error));
    }
  }

  Future<ClientManifest> fetchManifest(String accessToken) async {
    final manifestUri = _resolveUri('api/launcher/manifest');

    try {
      final response = await _dio.getUri(
        manifestUri,
        options: _authorizedOptions(accessToken),
      );

      return ClientManifest.fromJson(_coerceMap(response.data));
    } on DioException catch (error, stackTrace) {
      await _launcherLogService.error(
        'Launcher manifest request failed.',
        details: <String, Object?>{
          'endpoint': manifestUri.toString(),
          'statusCode': error.response?.statusCode,
          'dioType': error.type.name,
          'responseBody': _summarizePayload(error.response?.data),
        },
        error: error,
        stackTrace: stackTrace,
      );
      throw LauncherApiException(_extractErrorMessage(error));
    }
  }

  Future<List<LauncherNewsItem>> fetchNews(String accessToken) async {
    final newsUri = _resolveUri('api/launcher/news');

    try {
      final response = await _dio.getUri(
        newsUri,
        options: _authorizedOptions(accessToken),
      );
      final payload = _coerceMap(response.data);
      final rawItems = payload['data'];
      if (rawItems is! List) {
        throw const LauncherApiException('Unexpected launcher news payload.');
      }

      return rawItems
          .whereType<Map>()
          .map(
            (item) => LauncherNewsItem.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList(growable: false);
    } on DioException catch (error, stackTrace) {
      await _launcherLogService.error(
        'Launcher news request failed.',
        details: <String, Object?>{
          'endpoint': newsUri.toString(),
          'statusCode': error.response?.statusCode,
          'dioType': error.type.name,
          'responseBody': _summarizePayload(error.response?.data),
        },
        error: error,
        stackTrace: stackTrace,
      );
      throw LauncherApiException(_extractErrorMessage(error));
    }
  }

  Future<void> downloadFile({
    required String installationDir,
    required String accessToken,
    required ClientManifestFile file,
    required String destinationPath,
    required FutureOr<bool> Function()? isCancelled,
    required void Function(int chunkBytes) onChunkReceived,
  }) async {
    final downloadLinkUri = _resolveUri(
      'api/launcher/download/${Uri.encodeComponent(file.path)}',
    );
    Uri? downloadUri;

    try {
      final downloadLinkResponse = await _dio.getUri(
        downloadLinkUri,
        options: _authorizedOptions(accessToken),
      );
      downloadUri = _extractDownloadUri(_coerceMap(downloadLinkResponse.data));
    } on DioException catch (error, stackTrace) {
      await _launcherLogService.error(
        'Failed to resolve presigned download URL.',
        installationDir: installationDir,
        details: <String, Object?>{
          'filePath': file.path,
          'endpoint': downloadLinkUri.toString(),
          'statusCode': error.response?.statusCode,
          'dioType': error.type.name,
          'responseBody': _summarizePayload(error.response?.data),
        },
        error: error,
        stackTrace: stackTrace,
      );
      throw LauncherApiException(
        _buildDownloadErrorMessage(
          error: error,
          filePath: file.path,
          logHint: _launcherLogService.logHint(installationDir),
          stage: 'resolve download link for',
        ),
      );
    } on LauncherApiException catch (error, stackTrace) {
      await _launcherLogService.error(
        'Launcher API returned an invalid presigned download payload.',
        installationDir: installationDir,
        details: <String, Object?>{
          'filePath': file.path,
          'endpoint': downloadLinkUri.toString(),
        },
        error: error,
        stackTrace: stackTrace,
      );
      throw LauncherApiException(
        '${error.message} See ${_launcherLogService.logHint(installationDir)}.',
      );
    }

    try {
      final response = await _dio.getUri<ResponseBody>(
        downloadUri,
        options: Options(
          responseType: ResponseType.stream,
          headers: const {HttpHeaders.acceptHeader: 'application/octet-stream'},
        ),
      );

      final stream = response.data?.stream;
      if (stream == null) {
        throw const LauncherApiException(
          'Server returned an empty file stream.',
        );
      }

      final sink = File(destinationPath).openWrite();

      try {
        await for (final chunk in stream) {
          if (isCancelled != null && await isCancelled()) {
            throw const CancelledException();
          }

          sink.add(chunk);
          onChunkReceived(chunk.length);
        }
      } finally {
        await sink.close();
      }
    } on DioException catch (error, stackTrace) {
      await _launcherLogService.error(
        'Failed to download file payload.',
        installationDir: installationDir,
        details: <String, Object?>{
          'filePath': file.path,
          'downloadUrl': downloadUri.replace(query: '').toString(),
          'statusCode': error.response?.statusCode,
          'dioType': error.type.name,
          'responseBody': _summarizePayload(error.response?.data),
        },
        error: error,
        stackTrace: stackTrace,
      );
      throw LauncherApiException(
        _buildDownloadErrorMessage(
          error: error,
          filePath: file.path,
          logHint: _launcherLogService.logHint(installationDir),
          stage: 'download',
        ),
      );
    } on LauncherApiException catch (error, stackTrace) {
      await _launcherLogService.error(
        'Downloaded file payload was invalid.',
        installationDir: installationDir,
        details: <String, Object?>{
          'filePath': file.path,
          'downloadUrl': downloadUri.replace(query: '').toString(),
        },
        error: error,
        stackTrace: stackTrace,
      );
      throw LauncherApiException(
        '${error.message} See ${_launcherLogService.logHint(installationDir)}.',
      );
    } on FileSystemException catch (error, stackTrace) {
      await _launcherLogService.error(
        'Failed to write downloaded file to disk.',
        installationDir: installationDir,
        details: <String, Object?>{
          'filePath': file.path,
          'destinationPath': destinationPath,
          'downloadUrl': downloadUri.replace(query: '').toString(),
        },
        error: error,
        stackTrace: stackTrace,
      );
      throw LauncherSyncException(
        'Failed to write downloaded file: ${file.path}. '
        'See ${_launcherLogService.logHint(installationDir)}.',
      );
    }
  }

  Options _authorizedOptions(
    String accessToken, {
    ResponseType? responseType,
    Map<String, Object?>? headers,
  }) {
    return Options(
      responseType: responseType,
      headers: {
        HttpHeaders.authorizationHeader: 'Bearer $accessToken',
        ...?headers,
      },
    );
  }

  Uri _resolveUri(String path) {
    final rawBaseUrl = Config.launcherApiBaseUrl.trim();
    if (rawBaseUrl.isEmpty) {
      throw const LauncherConfigurationException(
        'Set MOONWELL_API_BASE_URL before using the launcher API.',
      );
    }

    final baseUri = Uri.parse(
      rawBaseUrl.endsWith('/') ? rawBaseUrl : '$rawBaseUrl/',
    );

    if (!baseUri.hasScheme || baseUri.host.isEmpty) {
      throw const LauncherConfigurationException(
        'MOONWELL_API_BASE_URL must be an absolute URL.',
      );
    }

    return baseUri.resolve(path);
  }

  Map<String, dynamic> _coerceMap(Object? data) {
    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }

    throw const LauncherApiException('Unexpected API response payload.');
  }

  String _extractErrorMessage(DioException error) {
    final data = error.response?.data;

    if (data is Map<String, dynamic>) {
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
    }

    if (data is Map) {
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
    }

    if (data is String && data.trim().isNotEmpty) {
      return data;
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.error is SocketException) {
      return 'Unable to reach the launcher API.';
    }

    return error.message ?? 'Launcher API request failed.';
  }

  String _buildDownloadErrorMessage({
    required DioException error,
    required String filePath,
    required String logHint,
    required String stage,
  }) {
    final statusCode = error.response?.statusCode;

    if (statusCode == HttpStatus.notFound) {
      return 'File not found on the server: $filePath. See $logHint.';
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.error is SocketException) {
      return 'Network error while trying to $stage file: $filePath. '
          'See $logHint.';
    }

    return 'Failed to $stage file: $filePath. See $logHint.';
  }

  String? _summarizePayload(Object? data) {
    if (data == null) {
      return null;
    }

    final serialized = switch (data) {
      String value => value,
      Map() || List() => _safeJsonEncode(data),
      _ => data.toString(),
    };

    const maxLength = 1000;
    if (serialized.length <= maxLength) {
      return serialized;
    }

    return '${serialized.substring(0, maxLength)}...';
  }

  String _safeJsonEncode(Object? value) {
    try {
      return jsonEncode(value);
    } catch (_) {
      return value.toString();
    }
  }

  Uri _extractDownloadUri(Map<String, dynamic> payload) {
    final rawUrl = payload['url'];
    if (rawUrl is! String || rawUrl.trim().isEmpty) {
      throw const LauncherApiException(
        'Launcher API did not return a valid download URL.',
      );
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const LauncherApiException(
        'Launcher API returned an invalid presigned download URL.',
      );
    }

    return uri;
  }
}

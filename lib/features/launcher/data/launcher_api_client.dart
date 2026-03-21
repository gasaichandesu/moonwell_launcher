import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:moonwell_launcher/config.dart';
import 'package:moonwell_launcher/features/downloader/domain/entities/download_exceptions.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/client_manifest.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/client_manifest_file.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/launcher_exception.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/launcher_session.dart';

@lazySingleton
class LauncherApiClient {
  LauncherApiClient()
    : _dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 30),
          headers: const {HttpHeaders.acceptHeader: 'application/json'},
        ),
      );

  final Dio _dio;

  Future<LauncherSession> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _dio.postUri(
        _resolveUri('api/launcher/login'),
        data: {'username': username, 'password': password},
      );

      return LauncherSession.fromJson(_coerceMap(response.data));
    } on DioException catch (error) {
      throw LauncherApiException(_extractErrorMessage(error));
    }
  }

  Future<ClientManifest> fetchManifest(String accessToken) async {
    try {
      final response = await _dio.getUri(
        _resolveUri('api/launcher/manifest'),
        options: _authorizedOptions(accessToken),
      );

      return ClientManifest.fromJson(_coerceMap(response.data));
    } on DioException catch (error) {
      throw LauncherApiException(_extractErrorMessage(error));
    }
  }

  Future<void> downloadFile({
    required String accessToken,
    required ClientManifestFile file,
    required String destinationPath,
    required FutureOr<bool> Function()? isCancelled,
    required void Function(int chunkBytes) onChunkReceived,
  }) async {
    try {
      final response = await _dio.getUri<ResponseBody>(
        _resolveUri('api/launcher/download/${Uri.encodeComponent(file.path)}'),
        options: _authorizedOptions(
          accessToken,
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
    } on DioException catch (error) {
      throw LauncherApiException(_extractErrorMessage(error));
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
}

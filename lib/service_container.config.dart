// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:minio/minio.dart' as _i875;
import 'package:shared_preferences/shared_preferences.dart' as _i460;

import 'features/downloader/application/download_manager.dart' as _i535;
import 'features/downloader/data/io_file_system.dart' as _i173;
import 'features/downloader/data/minio_storage_reader.dart' as _i980;
import 'features/downloader/domain/repositories/file_system.dart' as _i843;
import 'features/downloader/domain/repositories/storage_reader.dart' as _i839;
import 'features/downloader/use_cases/download_object_use_case.dart' as _i925;
import 'features/preferences/data/repositories/shared_prefs_preferences_repository.dart'
    as _i662;
import 'features/preferences/domain/repositories/preferences_repository.dart'
    as _i44;
import 'third_party/minio.dart' as _i285;
import 'third_party/shared_preferences.dart' as _i1006;

const String _flutter = 'flutter';

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  Future<_i174.GetIt> init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) async {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final sharedPreferencesModule = _$SharedPreferencesModule();
    final minioModule = _$MinioModule();
    await gh.factoryAsync<_i460.SharedPreferences>(
      () => sharedPreferencesModule.prefs,
      preResolve: true,
    );
    gh.lazySingleton<_i875.Minio>(() => minioModule.minioClient);
    gh.lazySingleton<_i839.StorageReader>(
      () => _i980.MinioStorageReader(gh<_i875.Minio>()),
    );
    gh.lazySingleton<_i843.FileSystem>(() => _i173.IoFileSystem());
    gh.lazySingleton<_i44.PreferencesRepository>(
      () => _i662.SharedPrefsPreferencesRepository(
        preferences: gh<_i460.SharedPreferences>(),
      ),
      registerFor: {_flutter},
    );
    gh.lazySingleton<_i925.DownloadObjectUseCase>(
      () => _i925.DownloadObjectUseCase(
        storage: gh<_i839.StorageReader>(),
        fileSystem: gh<_i843.FileSystem>(),
      ),
    );
    gh.lazySingleton<_i535.DownloadManager>(
      () => _i535.DownloadManager(gh<_i925.DownloadObjectUseCase>()),
    );
    return this;
  }
}

class _$SharedPreferencesModule extends _i1006.SharedPreferencesModule {}

class _$MinioModule extends _i285.MinioModule {}

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
import 'package:shared_preferences/shared_preferences.dart' as _i460;

import 'features/launcher/application/client_sync_use_case.dart' as _i757;
import 'features/launcher/data/game_installation_service.dart' as _i315;
import 'features/launcher/data/launcher_api_client.dart' as _i703;
import 'features/preferences/data/repositories/shared_prefs_preferences_repository.dart'
    as _i662;
import 'features/preferences/domain/repositories/preferences_repository.dart'
    as _i44;
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
    await gh.factoryAsync<_i460.SharedPreferences>(
      () => sharedPreferencesModule.prefs,
      preResolve: true,
    );
    gh.lazySingleton<_i315.GameInstallationService>(
      () => _i315.GameInstallationService(),
    );
    gh.lazySingleton<_i703.LauncherApiClient>(() => _i703.LauncherApiClient());
    gh.lazySingleton<_i757.ClientSyncUseCase>(
      () => _i757.ClientSyncUseCase(
        launcherApiClient: gh<_i703.LauncherApiClient>(),
        installationService: gh<_i315.GameInstallationService>(),
      ),
    );
    gh.lazySingleton<_i44.PreferencesRepository>(
      () => _i662.SharedPrefsPreferencesRepository(
        preferences: gh<_i460.SharedPreferences>(),
      ),
      registerFor: {_flutter},
    );
    return this;
  }
}

class _$SharedPreferencesModule extends _i1006.SharedPreferencesModule {}

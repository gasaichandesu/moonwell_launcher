import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'service_container.config.dart';

final getIt = GetIt.instance;

@InjectableInit(
  initializerName: 'init',
  preferRelativeImports: true,
  asExtension: true,
)
Future<void> configureDependencies({String? env}) =>
    getIt.init(environment: env);

import 'package:flutter/material.dart';
import 'package:moonwell_launcher/app/home_screen/home_screen.dart';
import 'package:moonwell_launcher/app/login_screen/login_screen.dart';
import 'package:moonwell_launcher/app/theme/mw_theme.dart';
import 'package:moonwell_launcher/features/launcher/application/restore_launcher_session_use_case.dart';
import 'package:moonwell_launcher/features/launcher/data/launcher_api_client.dart';
import 'package:moonwell_launcher/features/preferences/domain/repositories/preferences_repository.dart';
import 'package:moonwell_launcher/service_container.dart';

class MoonWellApp extends StatelessWidget {
  const MoonWellApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MoonWell',
      home: const _LauncherBootstrapScreen(),
      theme: moonWellTheme(),
    );
  }
}

class _LauncherBootstrapScreen extends StatefulWidget {
  const _LauncherBootstrapScreen();

  @override
  State<_LauncherBootstrapScreen> createState() =>
      _LauncherBootstrapScreenState();
}

class _LauncherBootstrapScreenState extends State<_LauncherBootstrapScreen> {
  late final Future<RestoreLauncherSessionResult> _bootstrapFuture;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = RestoreLauncherSessionUseCase(
      launcherApiClient: getIt<LauncherApiClient>(),
      preferencesRepository: getIt<PreferencesRepository>(),
    )();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RestoreLauncherSessionResult>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LauncherBootstrapLoadingScreen();
        }

        final result =
            snapshot.data ??
            const RestoreLauncherSessionResult.unauthenticated();
        if (result.isAuthenticated) {
          return HomeScreen(
            session: result.session!,
            manifest: result.manifest!,
          );
        }

        return const LoginScreen();
      },
    );
  }
}

class _LauncherBootstrapLoadingScreen extends StatelessWidget {
  const _LauncherBootstrapLoadingScreen();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/background.png', fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.0,
                  colors: [
                    MWColors.abyss.withAlpha(200),
                    MWColors.abyss.withAlpha(240),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/logo.png',
                  height: 160,
                  filterQuality: FilterQuality.high,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

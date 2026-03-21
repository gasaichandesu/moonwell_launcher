import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonwell_launcher/app/home_screen/bloc/home_screen_bloc.dart';
import 'package:moonwell_launcher/app/home_screen/home_screen_content.dart';
import 'package:moonwell_launcher/app/theme/mw_theme.dart';
import 'package:moonwell_launcher/features/launcher/application/client_sync_use_case.dart';
import 'package:moonwell_launcher/features/launcher/data/game_installation_service.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/client_manifest.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/launcher_session.dart';
import 'package:moonwell_launcher/features/preferences/domain/repositories/preferences_repository.dart';
import 'package:moonwell_launcher/service_container.dart';
import 'package:window_manager/window_manager.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.session, required this.manifest});

  final LauncherSession session;
  final ClientManifest manifest;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<HomeScreenBloc>(
      create: (context) => HomeScreenBloc(
        clientSyncUseCase: getIt<ClientSyncUseCase>(),
        gameInstallationService: getIt<GameInstallationService>(),
        preferencesRepository: getIt<PreferencesRepository>(),
        session: session,
        manifest: manifest,
      ),
      child: Scaffold(
        body: Stack(
          children: [
            // Background image
            Positioned.fill(
              child: Image.asset('assets/background.png', fit: BoxFit.cover),
            ),
            // Gradient overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      MWColors.abyss.withAlpha(180),
                      MWColors.abyss.withAlpha(220),
                      MWColors.abyss.withAlpha(240),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
            // Main content
            const Positioned.fill(child: HomeScreenContent()),
            // Custom title bar
            const Positioned(top: 0, left: 0, right: 0, child: _TitleBar()),
          ],
        ),
      ),
    );
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      child: SizedBox(
        height: 36,
        child: Row(
          children: [
            const Spacer(),
            _TitleBarButton(
              icon: Icons.remove,
              onTap: () => windowManager.minimize(),
              color: cs.onSurface,
            ),
            _TitleBarButton(
              icon: Icons.crop_square,
              onTap: () async {
                if (await windowManager.isMaximized()) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
              color: cs.onSurface,
            ),
            _TitleBarButton(
              icon: Icons.close,
              onTap: () => SystemNavigator.pop(),
              color: MWColors.error,
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleBarButton extends StatelessWidget {
  const _TitleBarButton({
    required this.icon,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 36,
        child: Icon(icon, size: 16, color: color.withAlpha(180)),
      ),
    );
  }
}

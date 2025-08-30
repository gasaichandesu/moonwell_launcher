import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonwell_launcher/app/home_screen/bloc/home_screen_bloc.dart';
import 'package:moonwell_launcher/app/home_screen/left_pane.dart';
import 'package:moonwell_launcher/app/theme/mw_theme.dart';
import 'package:moonwell_launcher/features/downloader/application/download_manager.dart';
import 'package:moonwell_launcher/features/preferences/domain/repositories/preferences_repository.dart';
import 'package:moonwell_launcher/service_container.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocProvider<HomeScreenBloc>(
      create: (context) => HomeScreenBloc(
        downloadManager: getIt<DownloadManager>(),
        preferencesRepository: getIt<PreferencesRepository>(),
      ),
      child: Builder(
        builder: (context) {
          return Scaffold(
            body: Container(
              decoration: const BoxDecoration(
                // subtle vignette for “night” vibe
                gradient: RadialGradient(
                  center: Alignment(0, -0.5),
                  radius: 1.2,
                  colors: [MWColors.deepNavy, MWColors.abyss],
                ),
              ),
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: LeftPane(
                          title: Text(
                            'MoonWell',
                            style: theme.textTheme.headlineLarge,
                          ),
                          progress: 0.0,
                          isDownloading: false,
                          kbps: 0.0,
                          eta: Duration.zero,
                          onStart: () {
                            context.read<HomeScreenBloc>().add(
                              HomeScreenDownloadRequested(),
                            );
                          },
                          onPause: () {},
                          onReset: () {},
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

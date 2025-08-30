import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonwell_launcher/app/home_screen/bloc/home_screen_bloc.dart';
import 'package:moonwell_launcher/app/home_screen/home_screen_content.dart';
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
      child: BlocConsumer<HomeScreenBloc, HomeScreenState>(
        listener: (context, state) {
          if (state is HomeScreenOutputDirSelectionState) {
            showDialog(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: Text('Alert'),
                content: Text('Please select client location.'),
                actions: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.folder_open),
                    onPressed: () => context.read<HomeScreenBloc>().add(
                      HomeScreenOutputDirRequested(),
                    ),
                    label: Text('Select directory'),
                  ),
                ],
              ),
            );
          }
        },

        builder: (context, state) {
          return Scaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  child: Container(
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
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Image.asset(
                                'assets/background.png',
                                fit: BoxFit.fitWidth,
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: HomeScreenContent(
                                    title: Text(
                                      'MoonWell',
                                      style: theme.textTheme.headlineLarge,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (state is HomeScreenDownloadInitializing)
                  Center(child: const CircularProgressIndicator()),
              ],
            ),
          );
        },
      ),
    );
  }
}

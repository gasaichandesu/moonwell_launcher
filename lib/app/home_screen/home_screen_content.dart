import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonwell_launcher/app/home_screen/bloc/home_screen_bloc.dart';
import 'package:moonwell_launcher/app/home_screen/widgets/gilded_progress_bar.dart';
import 'package:moonwell_launcher/app/theme/mw_theme.dart';
import 'package:pixelarticons/pixel.dart';

class HomeScreenContent extends StatelessWidget {
  const HomeScreenContent({super.key, required this.title});

  final Widget title;

  String _speedLabel(BuildContext context) {
    final kbps = context.read<HomeScreenBloc>().state.model.progress.speed;

    if (kbps <= 0) return '—';
    if (kbps >= 1024) {
      return '${(kbps / 1024).toStringAsFixed(2)} MB/s';
    }
    return '${kbps.toStringAsFixed(0)} kB/s';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final deco = Theme.of(context).extension<MoonWellDecorations>()!;

    final state = context.read<HomeScreenBloc>().state;

    final percent = _resolvePercentage(context);
    final eta = state.model.progress.eta;

    final isDownloading = state is HomeScreenDownloadingState;
    final canPlay = state is HomeScreenReadyToPlayState;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title,
            const SizedBox(height: 16),
            Text(
              'Classic+ Wrath of the Lich King experience',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: cs.onSurface.withAlpha(200),
              ),
            ),
            const SizedBox(height: 28),
            const Spacer(),
            // Progress bar
            GildedProgressBar(
              value: state.model.progress.total == 0
                  ? 0
                  : state.model.progress.downloaded /
                        state.model.progress.total,
            ),

            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '$percent%',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Icon(Pixel.speedfast, size: 18, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  _speedLabel(context),
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                const SizedBox(width: 16),
                Icon(
                  Pixel.timeline, // Updated to use PixelArtIcons
                  size: 18,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  eta == Duration.zero
                      ? '—'
                      : '${eta.inMinutes}:${(eta.inSeconds % 60).toString().padLeft(2, '0')}',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Controls row
            Row(
              spacing: 12.0,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(
                      canPlay ? Icons.play_arrow_rounded : Icons.download,
                    ),
                    label: Text(
                      canPlay
                          ? 'Play'
                          : (isDownloading
                                ? 'Downloading…'
                                : (state.model.progress.downloaded == 0
                                      ? 'Install'
                                      : 'Resume')),
                    ),
                    onPressed: canPlay
                        ? null
                        : (isDownloading ? null : () => _onStart(context)),
                  ),
                ),
                OutlinedButton.icon(
                  icon: Icon(Pixel.pause),
                  label: Text('Pause'),
                  onPressed: isDownloading ? () => _onPause(context) : null,
                ),
              ],
            ),

            const SizedBox(height: 20),
            // Disk path / build info (placeholders)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withAlpha(128),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outline),
                boxShadow: (deco.cardGlow),
              ),
              child: Row(
                children: [
                  const Icon(Pixel.folder),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => context.read<HomeScreenBloc>().add(
                        HomeScreenOutputDirRequested(),
                      ),
                      child: Text(
                        'Install path: ${state.model.outputPath?.toFilePath() ?? '—'}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _resolvePercentage(BuildContext context) {
    final state = context.read<HomeScreenBloc>().state;

    if (state.model.progress.total == 0) {
      return '0.0';
    }

    final percentage =
        state.model.progress.downloaded / state.model.progress.total;

    return (percentage * 100).clamp(0, 100).toStringAsFixed(1);
  }

  void _onStart(BuildContext context) {
    context.read<HomeScreenBloc>().add(HomeScreenDownloadRequested());
  }

  void _onPause(BuildContext context) {
    context.read<HomeScreenBloc>().add(HomeScreenDownloadPaused());
  }

  void _onReset(BuildContext context) {
    // context.read<HomeScreenBloc>().add(HomeScreenDownloadReset());
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonwell_launcher/app/home_screen/bloc/home_screen_bloc.dart';
import 'package:moonwell_launcher/app/home_screen/widgets/progress_bar.dart';
import 'package:moonwell_launcher/app/theme/mw_theme.dart';
import 'package:pixelarticons/pixel.dart';

class LeftPane extends StatelessWidget {
  const LeftPane({
    super.key,
    required this.title,
    required this.progress,
    required this.isDownloading,
    required this.kbps,
    required this.eta,
    required this.onStart,
    required this.onPause,
    required this.onReset,
  });

  final Widget title;
  final double progress;
  final bool isDownloading;
  final double kbps;
  final Duration eta;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onReset;

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

    return BlocBuilder<HomeScreenBloc, HomeScreenState>(
      builder: (context, state) {
        final percent = _resolvePercentage(context);
        final eta = state.model.progress.eta;

        final canPlay = progress >= 1.0 && state is! HomeScreenDownloadingState;

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

                // Progress bar
                GildedProgressBar(value: progress),

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
                                    : (progress == 0 ? 'Install' : 'Resume')),
                        ),
                        onPressed: canPlay
                            ? () {}
                            : (isDownloading ? null : onStart),
                      ),
                    ),
                    // const SizedBox(width: 12),
                    // OutlinedButton.icon(
                    //   icon: Icon(
                    //     isDownloading ? Icons.pause_rounded : Icons.replay,
                    //   ),
                    //   label: Text(isDownloading ? 'Pause' : 'Reset'),
                    //   onPressed: isDownloading
                    //       ? onPause
                    //       : (progress > 0 ? onReset : null),
                    // ),
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
                        child: Text(
                          'Install path: ${state.model.outputPath?.toFilePath() ?? '—'}',
                          overflow: TextOverflow.ellipsis,
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
      },
    );
  }

  String _resolvePercentage(BuildContext context) {
    final state = context.read<HomeScreenBloc>().state;

    if (state is HomeScreenDownloadingState) {
      final percentage =
          state.model.progress.downloaded / state.model.progress.total;

      return (percentage * 100).clamp(0, 100).toStringAsFixed(1);
    }

    return '0.0';
  }
}

// main.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:moonwell_launcher/app/mw_app.dart';
import 'package:moonwell_launcher/app/theme/mw_theme.dart';
import 'package:moonwell_launcher/service_container.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = WindowOptions(
    size: Size(960, 540),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );

  unawaited(
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    }),
  );

  await configureDependencies(env: 'flutter');

  runApp(const MoonWellApp());
}

bool get _isDesktop => const {
  TargetPlatform.macOS,
  TargetPlatform.linux,
  TargetPlatform.windows,
}.contains(defaultTargetPlatform);

class LauncherHome extends StatefulWidget {
  const LauncherHome({super.key});

  @override
  State<LauncherHome> createState() => _LauncherHomeState();
}

class _LauncherHomeState extends State<LauncherHome> {
  double _progress = 0.0; // 0..1
  bool _isDownloading = false;
  double _kbps = 0; // fake speed
  Duration _eta = Duration.zero;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startDownload() {
    if (_isDownloading || _progress >= 1.0) return;
    setState(() => _isDownloading = true);

    _timer = Timer.periodic(const Duration(milliseconds: 160), (t) {
      // Fake speed & progress for demo
      final chunk = 0.002 + math.Random().nextDouble() * 0.004;
      _kbps = 800 + math.Random().nextDouble() * 2200; // 0.8–3.0 MB/s
      _progress = (_progress + chunk).clamp(0.0, 1.0);
      final remaining = (1 - _progress);
      // naive ETA based on current "speed"
      _eta = Duration(seconds: math.max(1, (remaining * 120).round()));

      if (_progress >= 1.0) {
        _isDownloading = false;
        t.cancel();
      }
      setState(() {});
    });
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _isDownloading = false);
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _progress = 0;
      _isDownloading = false;
      _kbps = 0;
      _eta = Duration.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final deco = Theme.of(context).extension<MoonWellDecorations>()!;
    final title = ShaderMask(
      shaderCallback: (rect) =>
          (deco.goldBevel as LinearGradient).createShader(rect),
      child: Text(
        'MOONWELL',
        style: Theme.of(
          context,
        ).textTheme.displaySmall?.copyWith(shadows: [deco.textGlow]),
      ),
    );

    if (!_isDesktop) {
      return Scaffold(
        body: Center(
          child: Text(
            'Desktop only. Please run on Windows, macOS, or Linux.',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          // subtle vignette for “night” vibe
          gradient: RadialGradient(
            center: Alignment(0, -0.5),
            radius: 1.2,
            colors: [Color(0xFF0F1522), Color(0xFF0B101A)],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 760),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // LEFT: Game title + download controls
                  Expanded(
                    flex: 3,
                    child: _LeftPane(
                      title: title,
                      progress: _progress,
                      isDownloading: _isDownloading,
                      kbps: _kbps,
                      eta: _eta,
                      onStart: _startDownload,
                      onPause: _pause,
                      onReset: _reset,
                    ),
                  ),
                  const SizedBox(width: 20),
                  // RIGHT: Patch notes
                  Expanded(flex: 4, child: _PatchNotesPane(color: cs.surface)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LeftPane extends StatelessWidget {
  const _LeftPane({
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

  String get _speedLabel {
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
    final percent = (progress * 100).clamp(0, 100).toStringAsFixed(1);

    final canPlay = progress >= 1.0 && !isDownloading;

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
              'Classic MMO Launcher',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: cs.onSurface.withOpacity(0.85),
              ),
            ),
            const SizedBox(height: 28),

            // Progress bar
            _GildedProgressBar(value: progress),

            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '$percent%',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Icon(Icons.speed, size: 18, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(_speedLabel, style: TextStyle(color: cs.onSurfaceVariant)),
                const SizedBox(width: 16),
                Icon(
                  Icons.timer_outlined,
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
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  icon: Icon(
                    isDownloading ? Icons.pause_rounded : Icons.replay,
                  ),
                  label: Text(isDownloading ? 'Pause' : 'Reset'),
                  onPressed: isDownloading
                      ? onPause
                      : (progress > 0 ? onReset : null),
                ),
              ],
            ),

            const SizedBox(height: 20),
            // Disk path / build info (placeholders)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outline),
                boxShadow: (deco.cardGlow),
              ),
              child: Row(
                children: [
                  const Icon(Icons.folder_open),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Install path: C:/Games/MoonWell',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.info_outline, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Build: 1.2.0 (live)',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GildedProgressBar extends StatelessWidget {
  const _GildedProgressBar({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final deco = Theme.of(context).extension<MoonWellDecorations>()!;
    return Container(
      height: 20,
      decoration: BoxDecoration(
        color: cs.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Fill with gold bevel
          FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            alignment: Alignment.centerLeft,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: (deco.goldBevel as LinearGradient),
              ),
            ),
          ),
          // Subtle top highlight
          Align(
            alignment: Alignment.topCenter,
            child: Container(height: 6, color: Colors.white.withOpacity(0.08)),
          ),
        ],
      ),
    );
  }
}

class _PatchNotesPane extends StatelessWidget {
  const _PatchNotesPane({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Example static notes — wire your real source here.
    final notes = [
      (
        '1.2.0 — “Moonlit March”',
        [
          'New dungeon: *Hall of Tides*.',
          'Launcher supports delta updates with blockmaps.',
          'Improved shader warmup (faster first launch).',
          'Fixed login race condition on slow networks.',
        ],
      ),
      (
        '1.1.5',
        [
          'Balance pass on Ranger & Warlock.',
          'Memory usage reduced ~12% in large towns.',
        ],
      ),
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              border: Border(bottom: BorderSide(color: cs.outline)),
            ),
            child: Row(
              children: [
                const Icon(Icons.article_outlined),
                const SizedBox(width: 10),
                Text(
                  'Patch Notes',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {}, // hook to "Open full changelog"
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Full changelog'),
                ),
              ],
            ),
          ),
          // Body
          Expanded(
            child: Scrollbar(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                itemCount: notes.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, i) {
                  final (title, items) = notes[i];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ...items.map(
                        (s) => Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('•  '),
                            Expanded(
                              child: Text(
                                s,
                                style: TextStyle(
                                  color: cs.onSurface.withOpacity(0.9),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

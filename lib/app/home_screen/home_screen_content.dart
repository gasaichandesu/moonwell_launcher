import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonwell_launcher/app/home_screen/bloc/home_screen_bloc.dart';
import 'package:moonwell_launcher/app/home_screen/bloc/home_screen_model.dart';
import 'package:moonwell_launcher/app/home_screen/widgets/gilded_progress_bar.dart';
import 'package:moonwell_launcher/app/theme/mw_theme.dart';
import 'package:moonwell_launcher/features/launcher/domain/entities/launcher_news_item.dart';
import 'package:pixelarticons/pixel.dart';

class HomeScreenContent extends StatelessWidget {
  const HomeScreenContent({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HomeScreenBloc>().state;
    final model = state.model;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 36),
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: _NewsPanel(model: model, cs: cs),
                ),
                SizedBox(
                  width: 320,
                  child: _RightPanel(model: model, cs: cs),
                ),
              ],
            ),
          ),
          _BottomBar(model: model, cs: cs),
        ],
      ),
    );
  }
}

class _NewsPanel extends StatelessWidget {
  const _NewsPanel({required this.model, required this.cs});

  final HomeScreenModel model;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Image.asset(
                'assets/logo.png',
                height: 120,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
          Text(
            '\u041d\u043e\u0432\u043e\u0441\u0442\u0438',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: cs.onSurface),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.white, Colors.white.withAlpha(0)],
                stops: const [0.0, 0.85, 1.0],
              ).createShader(bounds),
              blendMode: BlendMode.dstIn,
              child: _buildNewsBody(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsBody(BuildContext context) {
    if (model.isLoadingNews) {
      return Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.2, color: cs.primary),
        ),
      );
    }

    if (model.newsItems.isEmpty && model.newsErrorMessage != null) {
      return ListView(
        padding: const EdgeInsets.only(right: 16, bottom: 24),
        children: [
          _NewsStatusCard(
            icon: Icons.cloud_off_rounded,
            title:
                '\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c '
                '\u0437\u0430\u0433\u0440\u0443\u0437\u0438\u0442\u044c '
                '\u043d\u043e\u0432\u043e\u0441\u0442\u0438',
            description: model.newsErrorMessage!,
          ),
        ],
      );
    }

    if (model.newsItems.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(right: 16, bottom: 24),
        children: const [
          _NewsStatusCard(
            icon: Icons.inbox_outlined,
            title:
                '\u041d\u043e\u0432\u043e\u0441\u0442\u0435\u0439 '
                '\u043f\u043e\u043a\u0430 \u043d\u0435\u0442',
            description:
                '\u041a\u043e\u0433\u0434\u0430 \u0432 API \u043f\u043e\u044f'
                '\u0432\u044f\u0442\u0441\u044f \u043f\u0443\u0431\u043b\u0438'
                '\u043a\u0430\u0446\u0438\u0438, \u043e\u043d\u0438 '
                '\u043f\u043e\u044f\u0432\u044f\u0442\u0441\u044f \u0437\u0434'
                '\u0435\u0441\u044c.',
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(right: 16, bottom: 24),
      itemCount: model.newsItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return _NewsCard(item: model.newsItems[index]);
      },
    );
  }
}

class _NewsStatusCard extends StatelessWidget {
  const _NewsStatusCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface.withAlpha(140),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withAlpha(100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: cs.tertiary),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: cs.tertiary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurface.withAlpha(200),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.item});

  final LauncherNewsItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface.withAlpha(140),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withAlpha(100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: cs.tertiary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (item.createdAt != null) ...[
            const SizedBox(height: 6),
            Text(
              _formatCreatedAt(item.createdAt!),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
          if (item.imageUrl != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 7,
                child: Image.network(
                  item.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: cs.surface.withAlpha(120),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            item.body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurface.withAlpha(200),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCreatedAt(DateTime value) {
    final localValue = value.toLocal();
    final day = localValue.day.toString().padLeft(2, '0');
    final month = localValue.month.toString().padLeft(2, '0');
    final year = localValue.year.toString();
    return '$day.$month.$year';
  }
}

class _RightPanel extends StatelessWidget {
  const _RightPanel({required this.model, required this.cs});

  final HomeScreenModel model;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final deco = Theme.of(context).extension<MoonWellDecorations>()!;

    return Container(
      margin: const EdgeInsets.only(right: 20, top: 8, bottom: 12),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MWColors.abyss.withAlpha(200),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline.withAlpha(80)),
        boxShadow: deco.cardGlow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => context.read<HomeScreenBloc>().add(
                HomeScreenLogoutRequested(),
              ),
              icon: const Icon(Icons.logout_rounded, size: 16),
              label: const Text('\u0412\u044b\u0439\u0442\u0438'),
              style: TextButton.styleFrom(
                foregroundColor: cs.onSurfaceVariant,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Spacer(),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.read<HomeScreenBloc>().add(
              HomeScreenOutputDirRequested(),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: cs.surface.withAlpha(100),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outline.withAlpha(80)),
              ),
              child: Row(
                children: [
                  Icon(Pixel.folder, size: 18, color: cs.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      model.outputPath?.toFilePath() ??
                          '\u0412\u044b\u0431\u0440\u0430\u0442\u044c '
                              '\u043f\u0430\u043f\u043a\u0443',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.edit,
                    size: 14,
                    color: cs.onSurfaceVariant.withAlpha(120),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surface.withAlpha(80),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outline.withAlpha(60)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  model.statusText,
                  style: TextStyle(
                    color: cs.onSurface.withAlpha(180),
                    fontSize: 13,
                  ),
                ),
                if (model.currentPath != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    model.currentPath!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
                  ),
                ],
                if (model.totalFiles > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    '\u0424\u0430\u0439\u043b\u044b: '
                    '${model.processedFiles}/${model.totalFiles}',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
                  ),
                ],
                if (model.errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    model.errorMessage!,
                    style: TextStyle(color: cs.error, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const Spacer(),
          if (model.remoteBuildHash != null || model.localBuildHash != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Build: ${_shortHash(model.localBuildHash)} / '
                '${_shortHash(model.remoteBuildHash)}',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }

  String _shortHash(String? hash) {
    if (hash == null || hash.isEmpty) {
      return '-';
    }

    if (hash.length <= 12) {
      return hash;
    }

    return '${hash.substring(0, 8)}...${hash.substring(hash.length - 4)}';
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.model, required this.cs});

  final HomeScreenModel model;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final progressValue = model.progress.total == 0
        ? 0.0
        : model.progress.downloaded / model.progress.total;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [MWColors.abyss.withAlpha(0), MWColors.abyss.withAlpha(230)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (model.isSyncing) ...[
            Row(
              children: [
                Expanded(child: GildedProgressBar(value: progressValue)),
                const SizedBox(width: 12),
                Text(
                  '${(progressValue * 100).clamp(0, 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _formatSpeed(model.progress.speed),
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  icon: Icon(_resolvePrimaryIcon(model), size: 20),
                  label: Text(_resolvePrimaryLabel(model)),
                  onPressed: model.isBusy
                      ? null
                      : () => _onPrimaryAction(context, model),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                  ),
                ),
              ),
              if (model.canPlay || model.isSyncing) ...[
                const SizedBox(width: 8),
                SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    icon: Icon(_resolveSecondaryIcon(model), size: 18),
                    label: Text(_resolveSecondaryLabel(model)),
                    onPressed: () => _onSecondaryAction(context, model),
                  ),
                ),
              ],
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: cs.surface.withAlpha(100),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.outline.withAlpha(60)),
                  ),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    model.currentPath ?? model.statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface.withAlpha(160),
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _onPrimaryAction(BuildContext context, HomeScreenModel model) {
    final bloc = context.read<HomeScreenBloc>();

    if (model.canPlay) {
      bloc.add(HomeScreenPlayRequested());
      return;
    }

    bloc.add(HomeScreenSyncRequested());
  }

  void _onSecondaryAction(BuildContext context, HomeScreenModel model) {
    final bloc = context.read<HomeScreenBloc>();

    if (model.isSyncing) {
      bloc.add(HomeScreenPauseRequested());
      return;
    }

    if (model.canPlay) {
      bloc.add(HomeScreenSyncRequested());
      return;
    }

    bloc.add(HomeScreenOutputDirRequested());
  }

  String _resolvePrimaryLabel(HomeScreenModel model) {
    if (model.isSyncing) {
      return '\u041e\u0431\u043d\u043e\u0432\u043b\u0435\u043d\u0438\u0435...';
    }

    if (model.canPlay) {
      return '\u0418\u0433\u0440\u0430\u0442\u044c';
    }

    return model.hasClientExecutable
        ? '\u041e\u0431\u043d\u043e\u0432\u0438\u0442\u044c'
        : '\u0423\u0441\u0442\u0430\u043d\u043e\u0432\u0438\u0442\u044c';
  }

  IconData _resolvePrimaryIcon(HomeScreenModel model) {
    if (model.canPlay) {
      return Icons.play_arrow_rounded;
    }

    return Icons.download_rounded;
  }

  String _resolveSecondaryLabel(HomeScreenModel model) {
    if (model.isSyncing) {
      return '\u041f\u0430\u0443\u0437\u0430';
    }

    if (model.canPlay) {
      return '\u041f\u0440\u043e\u0432\u0435\u0440\u0438\u0442\u044c';
    }

    return '\u041f\u0430\u043f\u043a\u0430';
  }

  IconData _resolveSecondaryIcon(HomeScreenModel model) {
    if (model.isSyncing) {
      return Pixel.pause;
    }

    if (model.canPlay) {
      return Icons.refresh_rounded;
    }

    return Pixel.folder;
  }

  String _formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond <= 0) {
      return '-';
    }

    if (bytesPerSecond >= 1024 * 1024) {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(2)} MB/s';
    }

    if (bytesPerSecond >= 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    }

    return '$bytesPerSecond B/s';
  }
}

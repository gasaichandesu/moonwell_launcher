import 'package:flutter/material.dart';
import 'package:moonwell_launcher/app/theme/mw_theme.dart';

class GildedProgressBar extends StatelessWidget {
  const GildedProgressBar({super.key, required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final deco = Theme.of(context).extension<MoonWellDecorations>()!;

    return Container(
      height: 20,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Subtle top highlight
          Positioned(
            top: 0.0,
            height: 6.0,
            left: 0.0,
            right: 0.0,
            child: ColoredBox(color: Colors.white.withAlpha(10)),
          ),
          Positioned.fill(
            child: FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              alignment: Alignment.centerLeft,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: (deco.goldBevel as LinearGradient),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

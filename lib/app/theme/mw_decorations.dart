part of 'mw_theme.dart';

class MoonWellDecorations extends ThemeExtension<MoonWellDecorations> {
  final Gradient goldBevel; // for gilded headers/buttons
  final Shadow textGlow; // subtle moonlight glow
  final List<BoxShadow> cardGlow;

  const MoonWellDecorations({
    required this.goldBevel,
    required this.textGlow,
    required this.cardGlow,
  });

  @override
  MoonWellDecorations copyWith({
    Gradient? goldBevel,
    Shadow? textGlow,
    List<BoxShadow>? cardGlow,
  }) => MoonWellDecorations(
    goldBevel: goldBevel ?? this.goldBevel,
    textGlow: textGlow ?? this.textGlow,
    cardGlow: cardGlow ?? this.cardGlow,
  );

  @override
  ThemeExtension<MoonWellDecorations> lerp(
    ThemeExtension<MoonWellDecorations>? other,
    double t,
  ) {
    if (other is! MoonWellDecorations) return this;
    return MoonWellDecorations(
      goldBevel: Gradient.lerp(goldBevel, other.goldBevel, t)!,
      textGlow: Shadow.lerp(textGlow, other.textGlow, t)!,
      cardGlow: [
        for (int i = 0; i < cardGlow.length; i++)
          BoxShadow.lerp(cardGlow[i], other.cardGlow[i], t)!,
      ],
    );
  }
}

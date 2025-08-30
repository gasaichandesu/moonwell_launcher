import 'package:flutter/material.dart';

part 'mw_colors.dart';
part 'mw_decorations.dart';

ThemeData moonWellTheme() {
  const cs = ColorScheme(
    brightness: Brightness.dark,
    primary: MWColors.gold,
    onPrimary: Color(0xFF1B1202),
    primaryContainer: MWColors.goldDark,
    onPrimaryContainer: Color(0xFFFFF0C2),

    secondary: Color(0xFFC08A2E), // bronze accent
    onSecondary: Color(0xFF201300),
    secondaryContainer: Color(0xFF3B2A00),
    onSecondaryContainer: Color(0xFFF6E2B6),

    tertiary: MWColors.moonBlue, // moon-glow accent
    onTertiary: Color(0xFF081120),
    tertiaryContainer: Color(0xFF143A66),
    onTertiaryContainer: Color(0xFFD9EBFF),

    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),

    surface: MWColors.abyss,
    onSurface: Color(0xFFE5EAF6),
    surfaceContainerHighest: MWColors.stormNavy,
    onSurfaceVariant: Color(0xFFC3C8D6),

    outline: MWColors.outline,
    outlineVariant: Color(0xFF40495C),
    shadow: Colors.black,
    scrim: Colors.black87,
    inverseSurface: Color(0xFFE5EAF6),
    onInverseSurface: Color(0xFF11151E),
    inversePrimary: Color(0xFFF0D072),
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: cs.surface,
    canvasColor: cs.surface,
  );

  final text = base.textTheme
      .apply(
        fontFamily: 'Cinzel',
        bodyColor: cs.onSurface,
        displayColor: cs.onSurface,
      )
      .copyWith(
        displayLarge: base.textTheme.displayLarge?.copyWith(
          letterSpacing: 0.5,
          fontWeight: FontWeight.w700,
          shadows: const [Shadow(blurRadius: 10, color: Color(0x336BA3FF))],
        ),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      );

  return base.copyWith(
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: cs.onSurface,
      centerTitle: true,
      titleTextStyle: text.titleLarge,
      toolbarHeight: 64,
    ),

    cardTheme: CardThemeData(
      color: cs.surface,
      elevation: 0,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: MWColors.outline.withAlpha(150)),
        borderRadius: BorderRadius.circular(20),
      ),
      shadowColor: MWColors.moonBlue.withAlpha(63),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        elevation: const WidgetStatePropertyAll(6),
        shadowColor: WidgetStatePropertyAll(MWColors.moonBlue.withAlpha(89)),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return MWColors.gold.withAlpha(115);
          }
          return cs.primary;
        }),
        foregroundColor: const WidgetStatePropertyAll(
          Color(0xFF1B1202),
        ), // dark text on gold
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(cs.tertiary),
        overlayColor: WidgetStatePropertyAll(cs.tertiary.withAlpha(10)),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(cs.tertiaryContainer),
        foregroundColor: WidgetStatePropertyAll(cs.onTertiaryContainer),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        side: WidgetStatePropertyAll(
          BorderSide(color: MWColors.outlineGold.withAlpha(230)),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        foregroundColor: WidgetStatePropertyAll(cs.primary),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cs.surfaceContainerHighest,
      hintStyle: TextStyle(color: cs.onSurfaceVariant.withAlpha(179)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: MWColors.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cs.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cs.error),
      ),
      prefixIconColor: cs.onSurfaceVariant,
      suffixIconColor: cs.onSurfaceVariant,
    ),

    chipTheme: base.chipTheme.copyWith(
      backgroundColor: cs.surfaceContainerHighest,
      side: BorderSide(color: MWColors.outline),
      selectedColor: cs.primaryContainer,
      labelStyle: TextStyle(color: cs.onSurface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),

    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: cs.primary,
      inactiveTrackColor: cs.primary.withAlpha(63),
      thumbColor: cs.primary,
    ),

    dividerTheme: DividerThemeData(
      color: MWColors.outline,
      thickness: 1,
      space: 24,
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: cs.surface,
      selectedItemColor: cs.primary,
      unselectedItemColor: cs.onSurface.withAlpha(153),
      elevation: 8,
      type: BottomNavigationBarType.fixed,
    ),

    extensions: <ThemeExtension<dynamic>>[
      const MoonWellDecorations(
        goldBevel: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            MWColors.goldSoft, // highlight
            MWColors.gold, // body
            Color(0xFFC58A1E), // warm edge
          ],
          stops: [0.0, 0.55, 1.0],
        ),
        textGlow: Shadow(
          color: Color(0x446BA3FF), // moon-glow
          blurRadius: 14,
          offset: Offset(0, 0),
        ),
        cardGlow: [
          BoxShadow(
            color: Color(0x33143666), // cool rim light
            blurRadius: 28,
            spreadRadius: 2,
            offset: Offset(0, 8),
          ),
        ],
      ),
    ],
  );
}

import 'package:flutter/material.dart';

part 'mw_colors.dart';
part 'mw_decorations.dart';

ThemeData moonWellTheme() {
  const cs = ColorScheme.dark(
    brightness: Brightness.dark,
    primary: Color(0xFF5460A2),
    onPrimary: Color(0xFFDDE0FB),

    secondary: Color(0xFF5F6BD2),
    onSecondary: Color(0xFFDDE0FB),

    tertiary: Color(0xFF6494EB),
    onTertiary: Color(0xFF090F2B),

    error: Color(0xFFD86A8A),
    onError: Color(0xFF090F2B),

    surface: Color(0xFF1A2759),
    onSurface: Color(0xFFDDE0FB),

    outline: Color(0xFF4B4E6E),
    shadow: Color(0xFF000000),
    scrim: Color(0xCC000000),
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
      color: cs.surface.withAlpha(50),
      elevation: 0,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: MWColors.outline.withAlpha(150)),
        borderRadius: BorderRadius.circular(20),
      ),
      shadowColor: MWColors.tertiary.withAlpha(63),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        textStyle: WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cinzel'),
        ),
        elevation: const WidgetStatePropertyAll(6),
        shadowColor: WidgetStatePropertyAll(MWColors.tertiary.withAlpha(89)),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return MWColors.primary.withAlpha(115);
          }
          return cs.primary;
        }),
        foregroundColor: const WidgetStatePropertyAll(Color(0xFFDDE0FB)),
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
          BorderSide(color: MWColors.outline.withAlpha(230)),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return cs.primary.withAlpha(100);
          }
          return cs.primary;
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return MWColors.stormNavy.withAlpha(100);
          }
          return MWColors.stormNavy;
        }),
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
            Color(0xFF7A85CC), // highlight
            Color(0xFF5460A2), // body
            Color(0xFF3E4880), // edge
          ],
          stops: [0.0, 0.55, 1.0],
        ),
        textGlow: Shadow(
          color: Color(0x446494EB),
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

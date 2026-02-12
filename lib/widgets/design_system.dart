import 'package:flutter/material.dart';

class LoomColors {
  static const background = Color(0xFFF7F8FA);
  static const surface = Color(0xFFFFFFFF);
  static const primary = Color(0xFF3CC77A);
  static const primaryStrong = Color(0xFF26A75E);
  static const divider = Color(0x14000000);
  static const textPrimary = Color(0xFF111111);
  static const textSecondary = Color(0xA6000000);
  static const textTertiary = Color(0x73000000);
  static const success = Color(0xFF2E9D5B);
  static const warning = Color(0xFFC58B2A);
  static const danger = Color(0xFFB84A4A);
}

class LoomTypography {
  // Big number (deposit/XP)
  static const bigNumber = TextStyle(
    fontSize: 64,
    fontWeight: FontWeight.w600,
    height: 1.05,
  );

  // Screen title
  static const screenTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
  );

  // Section title
  static const sectionTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );

  // Body
  static const body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  // Secondary
  static const secondary = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );
}

class LoomSpacing {
  static const screen = 20.0;
  static const base = 8.0;
  static const sm = 16.0;
  static const md = 24.0;
  static const lg = 32.0;
}

class LoomRadius {
  static const card = 16.0;
  static const button = 14.0;
}

class LoomElevation {
  static const card = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 12,
      offset: Offset(0, 6),
    ),
  ];
}

class LoomSizes {
  static const buttonHeight = 56.0;
  static const buttonRadius = 18.0;
  static const cardPadding = 16.0;
  static const dotSize = 8.0;
}

class LoomTheme {
  static Color bg(BuildContext context) {
    return Theme.of(context).colorScheme.surface;
  }

  static Color surface(BuildContext context) {
    return Theme.of(context).colorScheme.surface;
  }

  static Color card(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return scheme.surfaceVariant;
  }

  static Color border(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return scheme.outlineVariant ?? scheme.outline;
  }

  static Color textPrimary(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }

  static Color textSecondary(BuildContext context) {
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }

  static Color accent(BuildContext context) {
    return Theme.of(context).colorScheme.primary;
  }

  static Color positive(BuildContext context) {
    return Theme.of(context).colorScheme.tertiary;
  }

  static Color negative(BuildContext context) {
    return Theme.of(context).colorScheme.error;
  }

  static Color disabled(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface.withOpacity(0.38);
  }

  static Color shadow(BuildContext context) {
    return Theme.of(context).shadowColor.withOpacity(0.08);
  }

  static Color chipBgSelected(BuildContext context) {
    return accent(context).withOpacity(0.12);
  }

  static Color chipBg(BuildContext context) {
    return surface(context);
  }

  static Color badgeBgActive(BuildContext context) {
    return accent(context).withOpacity(0.12);
  }

  static Color badgeBgNeutral(BuildContext context) {
    return Theme.of(context).colorScheme.surfaceVariant;
  }

  static TextStyle h1(BuildContext context) {
    return Theme.of(context).textTheme.titleLarge ?? LoomTypography.screenTitle;
  }

  static TextStyle h2(BuildContext context) {
    return Theme.of(context).textTheme.titleMedium ?? LoomTypography.sectionTitle;
  }

  static TextStyle body(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium ?? LoomTypography.body;
  }

  static TextStyle caption(BuildContext context) {
    return Theme.of(context).textTheme.bodySmall ?? LoomTypography.secondary;
  }

  static ThemeData lightTheme() {
    final colorScheme = ColorScheme.fromSeed(seedColor: LoomColors.primary).copyWith(
      primary: LoomColors.primary,
      secondary: LoomColors.primaryStrong,
      tertiary: LoomColors.success,
      error: LoomColors.danger,
      surface: LoomColors.background,
      surfaceVariant: const Color(0xFFE9EDF2),
      outlineVariant: LoomColors.divider,
      onSurface: LoomColors.textPrimary,
      onSurfaceVariant: LoomColors.textSecondary,
      onPrimary: const Color(0xFFFFFFFF),
      onTertiary: const Color(0xFFFFFFFF),
      onError: const Color(0xFFFFFFFF),
    );
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: LoomColors.background,
      textTheme: const TextTheme(
        titleLarge: LoomTypography.screenTitle,
        bodyMedium: LoomTypography.body,
        bodySmall: LoomTypography.secondary,
      ),
      dividerColor: LoomColors.divider,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(LoomSizes.buttonHeight),
          padding: const EdgeInsets.symmetric(
            vertical: LoomSpacing.sm,
            horizontal: LoomSpacing.screen,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LoomRadius.button),
          ),
          textStyle: LoomTypography.body.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(LoomSizes.buttonHeight),
          side: const BorderSide(color: LoomColors.divider),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LoomRadius.button),
          ),
          textStyle: LoomTypography.body.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  static ThemeData nightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: LoomColors.primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFF63D68B),
      secondary: const Color(0xFF4ECF98),
      tertiary: const Color(0xFF6AE6B2),
      error: const Color(0xFFFF7A7A),
      surface: const Color(0xFF121416),
      surfaceVariant: const Color(0xFF1C1F23),
      outlineVariant: const Color(0x26FFFFFF),
      onSurface: const Color(0xFFEAEAEA),
      onSurfaceVariant: const Color(0xFFB8B8B8),
      onPrimary: const Color(0xFF0E0E0E),
      onTertiary: const Color(0xFF0E0E0E),
      onError: const Color(0xFF0E0E0E),
    );
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF121416),
      cardColor: const Color(0xFF1C1F23),
      textTheme: const TextTheme(
        titleLarge: LoomTypography.screenTitle,
        bodyMedium: LoomTypography.body,
        bodySmall: LoomTypography.secondary,
      ).apply(
        bodyColor: const Color(0xFFEAEAEA),
        displayColor: const Color(0xFFEAEAEA),
      ),
      dividerColor: const Color(0x26FFFFFF),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(LoomSizes.buttonHeight),
          padding: const EdgeInsets.symmetric(
            vertical: LoomSpacing.sm,
            horizontal: LoomSpacing.screen,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LoomRadius.button),
          ),
          textStyle: LoomTypography.body.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(LoomSizes.buttonHeight),
          side: const BorderSide(color: Color(0x26FFFFFF)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LoomRadius.button),
          ),
          textStyle: LoomTypography.body.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  static ThemeData oceanTheme() {
    final colorScheme = ColorScheme.fromSeed(seedColor: const Color(0xFF3A8FD6)).copyWith(
      primary: const Color(0xFF3A8FD6),
      secondary: const Color(0xFF2F7BBC),
      tertiary: const Color(0xFF2F9F9C),
      error: const Color(0xFFE06F66),
      surface: const Color(0xFFF4F8FB),
      surfaceVariant: const Color(0xFFE6F0F7),
      outlineVariant: LoomColors.divider,
      onSurface: LoomColors.textPrimary,
      onSurfaceVariant: LoomColors.textSecondary,
      onPrimary: const Color(0xFFFFFFFF),
      onTertiary: const Color(0xFFFFFFFF),
      onError: const Color(0xFFFFFFFF),
    );
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF4F8FB),
      cardColor: LoomColors.surface,
      textTheme: const TextTheme(
        titleLarge: LoomTypography.screenTitle,
        bodyMedium: LoomTypography.body,
        bodySmall: LoomTypography.secondary,
      ),
      dividerColor: LoomColors.divider,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(LoomSizes.buttonHeight),
          padding: const EdgeInsets.symmetric(
            vertical: LoomSpacing.sm,
            horizontal: LoomSpacing.screen,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LoomRadius.button),
          ),
          textStyle: LoomTypography.body.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(LoomSizes.buttonHeight),
          side: const BorderSide(color: LoomColors.divider),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LoomRadius.button),
          ),
          textStyle: LoomTypography.body.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  static ThemeData warmTheme() {
    final colorScheme = ColorScheme.fromSeed(seedColor: const Color(0xFFE07A4F)).copyWith(
      primary: const Color(0xFFE07A4F),
      secondary: const Color(0xFFD56C44),
      tertiary: const Color(0xFF9C8A3C),
      error: const Color(0xFFC85A4A),
      surface: const Color(0xFFFFF7F1),
      surfaceVariant: const Color(0xFFFBE8DB),
      outlineVariant: LoomColors.divider,
      onSurface: LoomColors.textPrimary,
      onSurfaceVariant: LoomColors.textSecondary,
      onPrimary: const Color(0xFFFFFFFF),
      onTertiary: const Color(0xFFFFFFFF),
      onError: const Color(0xFFFFFFFF),
    );
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFFFF7F1),
      cardColor: LoomColors.surface,
      textTheme: const TextTheme(
        titleLarge: LoomTypography.screenTitle,
        bodyMedium: LoomTypography.body,
        bodySmall: LoomTypography.secondary,
      ),
      dividerColor: LoomColors.divider,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(LoomSizes.buttonHeight),
          padding: const EdgeInsets.symmetric(
            vertical: LoomSpacing.sm,
            horizontal: LoomSpacing.screen,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LoomRadius.button),
          ),
          textStyle: LoomTypography.body.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(LoomSizes.buttonHeight),
          side: const BorderSide(color: LoomColors.divider),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LoomRadius.button),
          ),
          textStyle: LoomTypography.body.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

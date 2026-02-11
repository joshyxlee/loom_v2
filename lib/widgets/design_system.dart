import 'package:flutter/material.dart';

class LoomColors {
  static const background = Color(0xFFF7F8FA);
  static const surface = Color(0xFFFFFFFF);
  static const primary = Color(0xFF3CC77A);
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
    fontSize: 40,
    fontWeight: FontWeight.w700,
    height: 1.1,
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
  static const buttonHeight = 52.0;
  static const cardPadding = 20.0;
  static const dotSize = 8.0;
}

class LoomTheme {
  static ThemeData lightTheme() {
    final colorScheme = ColorScheme.fromSeed(seedColor: LoomColors.primary);
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
}

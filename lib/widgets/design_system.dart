import 'package:flutter/material.dart';

class LoomColors {
  static const background = Color(0xFFF7F8FA);
  static const surface = Color(0xFFFFFFFF);
  static const primary = Color(0xFF3CC77A);
  static const secondary = Color(0xFF111111);
  static const divider = Color(0x14000000);
  static const mutedText = Color(0xA6000000);
  static const tertiaryText = Color(0x73000000);
  static const success = Color(0xFF2E9D5B);
  static const warning = Color(0xFFC58B2A);
  static const danger = Color(0xFFB84A4A);
}

class LoomTypography {
  // display: large numeric hero (knowledge balance)
  static const display = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w700,
    height: 1.0,
  );

  // title: section headers and primary titles
  static const title = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
  );

  // body: standard content
  static const body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  // caption: small supportive text
  static const caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );

  // micro: tiny hints and secondary labels
  static const micro = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );
}

class LoomSpacing {
  static const xs = 8.0;
  static const sm = 16.0;
  static const md = 24.0;
  static const lg = 32.0;
  static const xl = 40.0;
  static const screen = 20.0;
}

class LoomRadius {
  static const card = 16.0;
  static const button = 16.0;
  static const pill = 999.0;
}

class LoomElevation {
  static const card = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 12,
      offset: Offset(0, 6),
    ),
  ];

  static const modal = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 18,
      offset: Offset(0, 10),
    ),
  ];
}

class LoomSizes {
  static const buttonHeight = 52.0;
  static const listRowHeight = 64.0;
  static const dotSize = 8.0;
  static const heroWatermark = 140.0;
}

class LoomTheme {
  static ThemeData lightTheme() {
    final colorScheme = ColorScheme.fromSeed(seedColor: LoomColors.primary);
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: LoomColors.background,
      textTheme: const TextTheme(
        titleLarge: LoomTypography.title,
        bodyMedium: LoomTypography.body,
        bodySmall: LoomTypography.caption,
      ),
      dividerColor: LoomColors.divider,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(
            vertical: LoomSpacing.sm,
            horizontal: LoomSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LoomRadius.button),
          ),
          textStyle: LoomTypography.body,
        ),
      ),
    );
  }
}

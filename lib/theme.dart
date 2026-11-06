import 'package:flutter/material.dart';

/// "Ember" palette — sampled from the copper marble watch-face reference.
/// Pure black AMOLED base, warm copper accents, cream/blush highlights.
class C {
  C._();

  static const black = Color(0xFF000000);
  static const shell = Color(0xFF050403);

  static const surface = Color(0xFF120D0B);
  static const surface2 = Color(0xFF1B1411);
  static const line = Color(0xFF33261F);

  static const copper = Color(0xFFE37C48);
  static const copperDeep = Color(0xFF914C2E);
  static const ember = Color(0xFF4E2014);
  static const blush = Color(0xFFE1BBA4);
  static const cream = Color(0xFFF6E8DE);
  static const gold = Color(0xFFFFC27A);
  static const ice = Color(0xFF8FD0FF);

  static const text = Color(0xFFFFFFFF);
  static const dim = Color(0xFFA38E82);
  static const onCopper = Color(0xFF1A0B04);
}

/// Thin, wide numerals — the watch-face look (Poppins Light).
TextStyle wLight(double size, {Color color = C.text, double ls = 0}) =>
    TextStyle(
      fontFamily: 'Poppins',
      fontWeight: FontWeight.w300,
      fontSize: size,
      letterSpacing: ls,
      color: color,
      height: 1.0,
    );

/// Small caps-style labels (Poppins Medium).
TextStyle wLabel(double size,
        {Color color = C.cream,
        double ls = 0.6,
        FontWeight weight = FontWeight.w500}) =>
    TextStyle(
      fontFamily: 'Poppins',
      fontWeight: weight,
      fontSize: size,
      letterSpacing: ls,
      color: color,
      height: 1.15,
    );

class TileStyle {
  const TileStyle(this.bg, this.fg, {this.glow, this.border});
  final Color bg;
  final Color fg;
  final Color? glow;
  final Color? border;
}

/// Warm ramp: dark ember -> copper -> blush -> glowing gold.
const Map<int, TileStyle> kTileStyles = {
  2: TileStyle(Color(0xFF2A1F1A), Color(0xFFF1DFD2)),
  4: TileStyle(Color(0xFF3B2A21), Color(0xFFF6E3D3)),
  8: TileStyle(Color(0xFF5E3220), Color(0xFFFFE9D8)),
  16: TileStyle(Color(0xFF8A4326), Color(0xFFFFF1E6)),
  32: TileStyle(Color(0xFFB8582F), Color(0xFFFFF4EA)),
  64: TileStyle(Color(0xFFE37C48), Color(0xFF1A0B04),
      glow: Color(0x33E37C48)),
  128: TileStyle(Color(0xFFF0975F), Color(0xFF1A0B04),
      glow: Color(0x44F0975F)),
  256: TileStyle(Color(0xFFF5B07C), Color(0xFF1A0B04),
      glow: Color(0x55F5B07C)),
  512: TileStyle(Color(0xFFE1BBA4), Color(0xFF2A140B),
      glow: Color(0x55E1BBA4)),
  1024: TileStyle(Color(0xFFF6D9C4), Color(0xFF2A140B),
      glow: Color(0x66F6D9C4)),
  2048: TileStyle(Color(0xFFFFD08A), Color(0xFF3A1606),
      glow: Color(0x99FFC27A), border: Color(0xFFFFF1D6)),
};

TileStyle styleFor(int val) => kTileStyles[val] ?? kTileStyles[2048]!;

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: C.black,
    fontFamily: 'Poppins',
    fontFamilyFallback: const ['Nunito'],
    colorScheme:
        ColorScheme.fromSeed(seedColor: C.copper, brightness: Brightness.dark),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: C.text,
      displayColor: C.text,
      fontFamily: 'Poppins',
      fontFamilyFallback: const ['Nunito'],
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: C.copper,
      selectionHandleColor: C.copper,
      selectionColor: Color(0x55E37C48),
    ),
  );
}

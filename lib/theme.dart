import 'package:flutter/material.dart';

/// Couleurs du drapeau du Bénin, utilisées aussi comme code d'état :
/// vert = à jour / OK, jaune = à vérifier, rouge = critique.
class SperoColors {
  static const vert = Color(0xFF008751);
  static const vertFonce = Color(0xFF006B40);
  static const vertClair = Color(0xFFE3F3EB);
  static const jaune = Color(0xFFFCD116);
  static const jauneClair = Color(0xFFFFF6CC);
  static const surJaune = Color(0xFF1D1A05);
  static const rouge = Color(0xFFE8112D);
  static const rougeClair = Color(0xFFFDE4E7);

  static const fond = Color(0xFFF5F7F4);
  static const texte = Color(0xFF17201A);
  static const gris = Color(0xFF6B786F);
  static const ligne = Color(0xFFE2E8E1);
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: SperoColors.vert,
    brightness: brightness,
    primary: dark ? const Color(0xFF2BB673) : SperoColors.vert,
    onPrimary: Colors.white,
    secondary: SperoColors.jaune,
    onSecondary: SperoColors.surJaune,
    error: dark ? const Color(0xFFFF4D62) : SperoColors.rouge,
    surface: dark ? const Color(0xFF171F19) : Colors.white,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    scaffoldBackgroundColor: dark ? const Color(0xFF0F1511) : SperoColors.fond,
  );
  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xFF0F1511) : SperoColors.fond,
      foregroundColor: dark ? Colors.white : SperoColors.texte,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: dark ? Colors.white : SperoColors.texte,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: dark ? const Color(0xFF2A352D) : SperoColors.ligne),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF1D2720) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: dark ? const Color(0xFF2A352D) : SperoColors.ligne),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: dark ? const Color(0xFF2A352D) : SperoColors.ligne),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: dark ? const Color(0xFF1F3A2B) : SperoColors.vertClair,
      labelTextStyle: WidgetStatePropertyAll(const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    ),
    chipTheme: base.chipTheme.copyWith(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99))),
  );
}

enum Niveau { ok, attention, critique }

extension NiveauStyle on Niveau {
  Color get couleur => switch (this) {
    Niveau.ok => SperoColors.vert,
    Niveau.attention => SperoColors.jaune,
    Niveau.critique => SperoColors.rouge,
  };
  Color get surCouleur => this == Niveau.attention ? SperoColors.surJaune : Colors.white;
  Color get fondClair => switch (this) {
    Niveau.ok => SperoColors.vertClair,
    Niveau.attention => SperoColors.jauneClair,
    Niveau.critique => SperoColors.rougeClair,
  };
  String get libelle => switch (this) {
    Niveau.ok => 'Information',
    Niveau.attention => 'À vérifier',
    Niveau.critique => 'Critique',
  };
}

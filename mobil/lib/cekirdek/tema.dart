import 'package:flutter/material.dart';

/// Web arayüzündeki yumuşak, sade renkler (public/style.css "UI kiti" teması).
class Renk {
  static const ana = Color(0xFF3D5A80);
  static const vurgu = Color(0xFFA4161A);

  // Açık tema
  static const kagit = Color(0xFFFAF8F4);
  static const kart = Color(0xFFFFFFFF);
  static const murekkep = Color(0xFF1C1B19);
  static const soluk = Color(0xFF78746C);
  static const ince = Color(0xFFE7E3DA);
  static const icZemin = Color(0xFFF6F2E8);

  // Koyu tema
  static const kagitKoyu = Color(0xFF14161A);
  static const kartKoyu = Color(0xFF1E2127);
  static const murekkepKoyu = Color(0xFFEDEAE3);
  static const solukKoyu = Color(0xFF9C978D);
  static const inceKoyu = Color(0xFF2E323A);
  static const icZeminKoyu = Color(0xFF191C21);
}

/// Bağlamdan tema renkleri (açık/koyu).
extension TemaRenkleri on BuildContext {
  bool get koyu => Theme.of(this).brightness == Brightness.dark;
  Color get kart => koyu ? Renk.kartKoyu : Renk.kart;
  Color get yazi => koyu ? Renk.murekkepKoyu : Renk.murekkep;
  Color get soluk => koyu ? Renk.solukKoyu : Renk.soluk;
  Color get ince => koyu ? Renk.inceKoyu : Renk.ince;
  Color get icZemin => koyu ? Renk.icZeminKoyu : Renk.icZemin;
  Color get ana => koyu ? const Color(0xFF8FB0DA) : Renk.ana;
}

ThemeData temaOlustur(Brightness parlaklik) {
  final koyu = parlaklik == Brightness.dark;
  final yazi = koyu ? Renk.murekkepKoyu : Renk.murekkep;
  final ince = koyu ? Renk.inceKoyu : Renk.ince;
  final ana = koyu ? const Color(0xFF8FB0DA) : Renk.ana;
  final sema = ColorScheme.fromSeed(seedColor: Renk.ana, brightness: parlaklik).copyWith(
    primary: ana,
    onPrimary: koyu ? const Color(0xFF0E1A2B) : Colors.white,
    surface: koyu ? Renk.kagitKoyu : Renk.kagit,
    onSurface: yazi,
    error: koyu ? const Color(0xFFFF8A80) : Renk.vurgu,
    outlineVariant: ince,
  );
  final alanKenar = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: ince),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: sema,
    scaffoldBackgroundColor: koyu ? Renk.kagitKoyu : Renk.kagit,
    appBarTheme: AppBarTheme(
      backgroundColor: koyu ? Renk.kagitKoyu : Renk.kagit,
      foregroundColor: yazi,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(color: yazi, fontSize: 19, fontWeight: FontWeight.w600),
    ),
    dividerColor: ince,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: koyu ? Renk.kartKoyu : Renk.kart,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: alanKenar,
      enabledBorder: alanKenar,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: ana, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        side: BorderSide(color: ince),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textTheme: Typography.material2021().black.apply(bodyColor: yazi, displayColor: yazi),
  );
}

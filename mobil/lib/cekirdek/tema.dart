import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Web arayüzündeki yumuşak, sade renkler (public/style.css "UI kiti" teması).
class Renk {
  static const ana = Color(0xFF3D5A80);
  static const vurgu = Color(0xFFA4161A);

  /// Üst bant rengi: öğretmende dersin rengi, diğerlerinde marka rengi (web: --bant / --ana).
  static const bant = Color(0xFF4B5565);

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

/// Başlıklarda kullanılan serif yazı (web: --serif).
const serif = TextStyle(fontFamily: 'Charter', fontFamilyFallback: ['Georgia', 'Cambria', 'Noto Serif', 'serif']);

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

/// Satır içinde ya da Wrap'te duran düğmeler için: tema düğmeleri tam genişliğe uzadığından
/// bunlara dar (içeriği kadar) genişlik verilir. Web'deki `.kucuk` düğme gibi 40 px yükseklik.
const kompakt = ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(0, 40)), padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)));

ThemeData temaOlustur(Brightness parlaklik, {Color? bant}) {
  final bantRengi = bant ?? Renk.bant;
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
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: ince),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: sema,
    scaffoldBackgroundColor: koyu ? Renk.kagitKoyu : Renk.kagit,
    appBarTheme: AppBarTheme(
      backgroundColor: bantRengi,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 68,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(30))),
      titleTextStyle: serif.copyWith(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w600),
    ),
    // Web başlığındaki geri düğmesi: yarı saydam, yuvarlak köşeli kutu içinde ok
    actionIconTheme: ActionIconThemeData(
      backButtonIconBuilder: (context) => Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: Colors.white.withValues(alpha: .35)),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.arrow_back, size: 20, color: Colors.white),
      ),
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
        minimumSize: const Size.fromHeight(46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(46),
        side: BorderSide(color: ana.withValues(alpha: .5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    // Web'deki ikincil düğme gibi: ince çerçeveli, yuvarlak köşeli
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        side: BorderSide(color: ana.withValues(alpha: .5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
      ),
    ),
    textTheme: Typography.material2021().black.apply(bodyColor: yazi, displayColor: yazi),
  );
}

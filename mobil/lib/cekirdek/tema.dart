import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Web arayüzündeki yumuşak, sade renkler (public/style.css "UI kiti" teması).
class Renk {
  /// Düğme/vurgu rengi: iOS tarzı mavi (web: --ana).
  static const ana = Color(0xFF2F6BD6);
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
/// bunlara dar (içeriği kadar) genişlik verilir. Web'deki `.kucuk` düğme gibi 34 px yükseklik.
const kompakt = ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(0, 34)), padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14)));

/// Dolu cam düğme zemini: ana renk (hafif saydam) + üstte beyaz ışık geçişi (iOS "tinted glass").
Widget _camDolu(Color ana, Set<WidgetState> durum, Widget? cocuk) {
  final kapali = durum.contains(WidgetState.disabled);
  final basili = durum.contains(WidgetState.pressed);
  final zemin = ana.withValues(alpha: kapali ? .38 : (basili ? 1 : .9));
  return DecoratedBox(
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: zemin),
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: .34), Colors.white.withValues(alpha: .08), Colors.white.withValues(alpha: 0)],
          stops: const [0, .48, 1],
        ),
      ),
      child: cocuk,
    ),
  );
}

/// İkincil cam düğme zemini: buzlu beyaz.
Widget _camBuzlu(Set<WidgetState> durum, Widget? cocuk) {
  final basili = durum.contains(WidgetState.pressed);
  return DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: basili
            ? [const Color(0xFFE8EEFA), const Color(0xFFDCE6F8)]
            : [Colors.white.withValues(alpha: .95), const Color(0xFFF6F6F8).withValues(alpha: .85)],
      ),
    ),
    child: cocuk,
  );
}

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
      toolbarHeight: 64, // panel bandıyla aynı sabit yükseklik
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      // Düz köşe + alt kenarda dersin renginden bir ton koyu ince çizgi (keskin görünüm)
      shape: Border(bottom: BorderSide(color: Color.alphaBlend(Colors.black.withValues(alpha: .22), bantRengi))),
      titleTextStyle: serif.copyWith(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w600),
    ),
    // Web başlığındaki geri düğmesi: yarı saydam, yuvarlak köşeli kutu içinde ok
    actionIconTheme: ActionIconThemeData(
      backButtonIconBuilder: (context) => Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: .35)),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.arrow_back, size: 20, color: Colors.white),
      ),
    ),
    dividerColor: ince,
    visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
    // Girdi alanları: ince (≈40 px), 8 px köşe, sade çerçeve
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      isDense: true,
      fillColor: koyu ? Renk.kartKoyu : Renk.kart,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: alanKenar,
      enabledBorder: alanKenar,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: ana, width: 1.4),
      ),
    ),
    // Düğmeler: iOS tarzı "cam". Dolu düğme ana renkte yarı saydam, üstte ışık parlaması, beyazımsı ince çerçeve;
    // ikincil düğme buzlu beyaz. Yükseklik 40 px, 10 px köşe.
    filledButtonTheme: FilledButtonThemeData(
      style:
          FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(40),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            elevation: 0,
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: .1),
          ).copyWith(
            side: WidgetStateProperty.resolveWith((d) => BorderSide(color: Colors.white.withValues(alpha: d.contains(WidgetState.disabled) ? .2 : .38))),
            backgroundBuilder: (context, durum, child) => _camDolu(ana, durum, child),
          ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(40),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        side: BorderSide(color: const Color(0xFF3C3C43).withValues(alpha: .16)),
        foregroundColor: ana,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: .1),
      ).copyWith(backgroundBuilder: (context, durum, child) => _camBuzlu(durum, child)),
    ),
    // Metin düğmesi: çerçevesiz, ana renk yazı; arka plan yalnız basılınca belirir
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        foregroundColor: ana,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    textTheme: Typography.material2021().black.apply(bodyColor: yazi, displayColor: yazi),
  );
}

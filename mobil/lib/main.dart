import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'cekirdek/oturum.dart';
import 'cekirdek/tema.dart';
import 'ekranlar/acilis.dart';
import 'ekranlar/giris.dart';
import 'ekranlar/kilit.dart';
import 'ekranlar/panel.dart';
import 'ekranlar/profil_sec.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NeademyUygulamasi());
}

class NeademyUygulamasi extends StatefulWidget {
  const NeademyUygulamasi({super.key, this.oturum});

  /// Testlerde sahte oturum verilebilir.
  final Oturum? oturum;

  @override
  State<NeademyUygulamasi> createState() => _NeademyUygulamasiState();
}

class _NeademyUygulamasiState extends State<NeademyUygulamasi> with WidgetsBindingObserver {
  /// Arka planda bu süreden uzun kalırsa biyometrik kilit yeniden devreye girer.
  static const _kilitSuresi = Duration(minutes: 2);

  late final Oturum _oturum = widget.oturum ?? Oturum();
  DateTime? _arkaPlanaGecti;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _oturum.baslat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState durum) {
    if (durum == AppLifecycleState.paused) {
      _arkaPlanaGecti = DateTime.now();
    } else if (durum == AppLifecycleState.resumed) {
      final gecti = _arkaPlanaGecti;
      _arkaPlanaGecti = null;
      if (gecti != null && DateTime.now().difference(gecti) > _kilitSuresi) _oturum.kilitle();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'neademy',
      debugShowCheckedModeBanner: false,
      theme: temaOlustur(Brightness.light),
      darkTheme: temaOlustur(Brightness.dark),
      themeMode: ThemeMode.system,
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: ListenableBuilder(
        listenable: _oturum,
        builder: (context, _) => switch (_oturum.durum) {
          Durum.aciliyor => const AcilisEkrani(),
          Durum.baglantiYok => AcilisEkrani(hata: 'Sunucuya ulaşılamadı.', yenidenDene: _oturum.baslat),
          Durum.guncellemeGerek => const AcilisEkrani(
              hata: 'Uygulamanın yeni bir sürümü var. Devam etmek için mağazadan güncelleyin.',
            ),
          Durum.bakim => AcilisEkrani(hata: _oturum.ayar.bakim, yenidenDene: _oturum.baslat),
          Durum.cikis => GirisEkrani(oturum: _oturum),
          Durum.profilSecimi => ProfilSecEkrani(oturum: _oturum),
          Durum.kilitli => KilitEkrani(oturum: _oturum),
          Durum.giris => PanelEkrani(oturum: _oturum),
        },
      ),
    );
  }
}

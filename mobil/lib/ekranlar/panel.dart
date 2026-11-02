import 'package:flutter/material.dart';

import '../cekirdek/api.dart';
import '../cekirdek/oturum.dart';
import '../cekirdek/tema.dart';
import 'derslerim.dart';
import 'devamsizlik.dart';
import 'duyurular.dart';
import 'etut.dart';
import 'notlarim.dart';
import 'odev_takip.dart';
import 'odevler.dart';
import 'ogrencilerim.dart';
import 'ogrencim.dart';
import 'program.dart';
import 'takvimim.dart';
import 'teslim.dart';
import 'veli_mesaj.dart';

class Modul {
  Modul({required this.id, required this.ad, required this.aciklama});

  factory Modul.json(Map<String, dynamic> j) =>
      Modul(id: j['id'] as String, ad: j['ad'] as String? ?? '', aciklama: j['aciklama'] as String? ?? '');

  final String id;
  final String ad;
  final String aciklama;
}

/// Uygulamada ekranı hazır olan modüller (id → ekran). Menüyü sunucudaki modül listesi belirler;
/// burada olmayanlar "Yakında" görünür, rol/yetki süzmesi sunucuda yapılır.
final _hazirEkranlar = <String, ({IconData ikon, Widget Function(Api api) ekran})>{
  'takvimim': (ikon: Icons.calendar_month_outlined, ekran: (api) => TakvimimEkrani(api: api)),
  'devamsizlik-veli': (ikon: Icons.fact_check_outlined, ekran: (api) => DevamsizlikEkrani(api: api, baslik: 'Devamsızlık')),
  'devamsizlik-ogrenci': (ikon: Icons.fact_check_outlined, ekran: (api) => DevamsizlikEkrani(api: api, baslik: 'Devamsızlığım')),
  'duyurular': (ikon: Icons.campaign_outlined, ekran: (api) => DuyurularEkrani(api: api)),
  'duyurular-ogretmen': (ikon: Icons.campaign_outlined, ekran: (api) => DuyurularEkrani(api: api)),
  'odev-takip': (ikon: Icons.assignment_outlined, ekran: (api) => OdevlerEkrani(api: api)),
  'ders-programi': (ikon: Icons.schedule_outlined, ekran: (api) => ProgramEkrani(api: api)),
  'notlarim': (ikon: Icons.bar_chart_outlined, ekran: (api) => NotlarimEkrani(api: api)),
  'ogrencim': (ikon: Icons.person_outline, ekran: (api) => OgrencimEkrani(api: api)),
  'odev-takip-ogretmen': (ikon: Icons.fact_check_outlined, ekran: (api) => OdevTakipOgretmenEkrani(api: api)),
  'derslerim': (ikon: Icons.menu_book_outlined, ekran: (api) => DerslerimEkrani(api: api)),
  'ogrencilerim': (ikon: Icons.groups_outlined, ekran: (api) => OgrencilerimEkrani(api: api)),
  'veli-bilgilendirme': (ikon: Icons.mark_email_unread_outlined, ekran: (api) => VeliBilgilendirmeEkrani(api: api)),
  'etut': (ikon: Icons.event_available_outlined, ekran: (api) => EtutEkrani(api: api, rol: 'ogretmen')),
  'etut-ogrenci': (ikon: Icons.event_available_outlined, ekran: (api) => EtutEkrani(api: api, rol: 'ogrenci')),
  'etut-veli': (ikon: Icons.event_available_outlined, ekran: (api) => EtutEkrani(api: api, rol: 'veli')),
  'teslim': (ikon: Icons.group_outlined, ekran: (api) => TeslimYetkileriEkrani(api: api)),
  'teslim-kodu': (ikon: Icons.qr_code_2, ekran: (api) => TeslimKoduEkrani(api: api)),
  'teslim-kapi': (ikon: Icons.qr_code_scanner, ekran: (api) => TeslimKapiEkrani(api: api)),
};

class PanelEkrani extends StatefulWidget {
  const PanelEkrani({super.key, required this.oturum});

  final Oturum oturum;

  @override
  State<PanelEkrani> createState() => _PanelEkraniState();
}

class _PanelEkraniState extends State<PanelEkrani> {
  List<Modul>? _moduller;
  String? _hata;
  bool _biyometriVar = false;
  String? _kapatilanDuyuru;

  @override
  void initState() {
    super.initState();
    _yukle();
    widget.oturum.biyometri.kullanilabilir().then((v) {
      if (mounted) setState(() => _biyometriVar = v);
    });
  }

  Future<void> _yukle() async {
    setState(() => _hata = null);
    widget.oturum.ayariYenile();
    try {
      final j = await widget.oturum.api.get('/api/moduller') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() => _moduller = [for (final m in (j['moduller'] as List)) Modul.json(m as Map<String, dynamic>)]);
    } on ApiHata catch (e) {
      if (mounted && !e.oturumYok) setState(() => _hata = e.mesaj);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ben = widget.oturum.ben!;
    final moduller = _moduller;
    final kapali = widget.oturum.ayar.kapaliModuller;
    final acik = [for (final m in moduller ?? <Modul>[]) if (!kapali.contains(m.id)) m];
    final hazir = [for (final m in acik) if (_hazirEkranlar.containsKey(m.id)) m];
    final yakinda = [for (final m in acik) if (!_hazirEkranlar.containsKey(m.id)) m];
    final duyuru = widget.oturum.ayar.duyuru;
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _yukle,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ben.ad, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -.3)),
                        const SizedBox(height: 2),
                        Text(
                          [ben.unvan, ben.sube].where((e) => e.isNotEmpty).join(' · '),
                          style: TextStyle(color: context.soluk, fontSize: 14.5),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_horiz, color: context.soluk),
                    tooltip: 'Menü',
                    onSelected: (v) {
                      if (v == 'profil') widget.oturum.profilDegistir();
                      if (v == 'kilit') widget.oturum.kilidiAyarla(!widget.oturum.kilitAcik);
                      if (v == 'cikis') widget.oturum.cikisYap();
                    },
                    itemBuilder: (_) => [
                      if (ben.coklu) const PopupMenuItem(value: 'profil', child: Text('Profil değiştir')),
                      if (_biyometriVar)
                        PopupMenuItem(
                          value: 'kilit',
                          child: Text(widget.oturum.kilitAcik ? 'Biyometrik açılışı kapat' : 'Biyometrik açılışı aç'),
                        ),
                      const PopupMenuItem(value: 'cikis', child: Text('Çıkış yap')),
                    ],
                  ),
                ],
              ),
              if (ben.kurum.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(ben.kurum, style: TextStyle(color: context.soluk, fontSize: 13.5)),
              ],
              const SizedBox(height: 22),
              if (duyuru != null && duyuru.id != _kapatilanDuyuru)
                _DuyuruSeridi(duyuru: duyuru, onKapat: () => setState(() => _kapatilanDuyuru = duyuru.id)),
              if (_hata != null)
                _Mesaj(_hata!, onTekrar: _yukle)
              else if (moduller == null)
                const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)))
              else ...[
                for (final m in hazir)
                  _ModulKarti(
                    modul: m,
                    ikon: _hazirEkranlar[m.id]!.ikon,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _hazirEkranlar[m.id]!.ekran(widget.oturum.api))),
                  ),
                if (yakinda.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text('Yakında uygulamada', style: TextStyle(color: context.soluk, fontSize: 13.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  for (final m in yakinda) _ModulKarti(modul: m, ikon: Icons.schedule, onTap: null),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ModulKarti extends StatelessWidget {
  const _ModulKarti({required this.modul, required this.ikon, required this.onTap});

  final Modul modul;
  final IconData ikon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final etkin = onTap != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: etkin ? context.kart : context.icZemin,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: context.ince)),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(ikon, color: etkin ? context.ana : context.soluk),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(modul.ad, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: etkin ? context.yazi : context.soluk)),
                      if (modul.aciklama.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(modul.aciklama, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.soluk, fontSize: 13.5, height: 1.3)),
                      ],
                    ],
                  ),
                ),
                if (etkin) Icon(Icons.chevron_right, color: context.soluk),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DuyuruSeridi extends StatelessWidget {
  const _DuyuruSeridi({required this.duyuru, required this.onKapat});

  final Duyuru duyuru;
  final VoidCallback onKapat;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
          decoration: BoxDecoration(
            color: context.icZemin,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.ince),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (duyuru.baslik != null) Text(duyuru.baslik!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                    Text(duyuru.metin, style: TextStyle(color: context.soluk, fontSize: 13.5, height: 1.35)),
                  ],
                ),
              ),
              IconButton(icon: Icon(Icons.close, size: 18, color: context.soluk), tooltip: 'Kapat', onPressed: onKapat),
            ],
          ),
        ),
      );
}

class _Mesaj extends StatelessWidget {
  const _Mesaj(this.metin, {required this.onTekrar});

  final String metin;
  final VoidCallback onTekrar;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          children: [
            Text(metin, textAlign: TextAlign.center, style: TextStyle(color: context.soluk)),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onTekrar, child: const Text('Tekrar dene')),
          ],
        ),
      );
}

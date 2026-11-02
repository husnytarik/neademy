import 'package:flutter/material.dart';

import '../bilesenler/ikon.dart';
import '../cekirdek/api.dart';
import '../cekirdek/oturum.dart';
import '../cekirdek/tema.dart';
import 'baskan_toplanti.dart';
import 'derslerim.dart';
import 'devamsizlik.dart';
import 'duyurular.dart';
import 'etut.dart';
import 'gelisim_ogretmen.dart';
import 'duyuru_yonetim.dart';
import 'kulup.dart';
import 'kisiler.dart';
import 'kurum.dart';
import 'profil.dart';
import 'ogrenciler.dart';
import 'zumrem.dart';
import 'notlarim.dart';
import 'odev_takip.dart';
import 'odevler.dart';
import 'panel_ozet.dart';
import 'ogrencilerim.dart';
import 'ogrencim.dart';
import 'kurulum.dart';
import 'ders_programi_yonetim.dart';
import 'gelisim_yonetim.dart';
import 'kulup_yonetim.dart';
import 'okul_takvimi.dart';
import 'program.dart';
import 'rapor.dart';
import 'sinav.dart';
import 'takvimim.dart';
import 'teslim.dart';
import 'veli_mesaj.dart';

class Modul {
  Modul({required this.id, required this.ad, required this.aciklama});

  factory Modul.json(Map<String, dynamic> j) => Modul(id: j['id'] as String, ad: j['ad'] as String? ?? '', aciklama: j['aciklama'] as String? ?? '');

  final String id;
  final String ad;
  final String aciklama;
}

/// Uygulamada ekranı hazır olan modüller (id → ekran). Menüyü sunucudaki modül listesi belirler;
/// burada olmayanlar "Yakında" görünür, rol/yetki süzmesi sunucuda yapılır.
final _hazirEkranlar = <String, Widget Function(Api api)>{
  'takvimim': (api) => TakvimimEkrani(api: api),
  'devamsizlik-veli': (api) => DevamsizlikEkrani(api: api, baslik: 'Devamsızlık'),
  'devamsizlik-ogrenci': (api) => DevamsizlikEkrani(api: api, baslik: 'Devamsızlığım'),
  'duyurular': (api) => DuyurularEkrani(api: api),
  'duyurular-ogretmen': (api) => DuyurularEkrani(api: api),
  'odev-takip': (api) => OdevlerEkrani(api: api),
  'ders-programi': (api) => ProgramEkrani(api: api),
  'notlarim': (api) => NotlarimEkrani(api: api),
  'ogrencim': (api) => OgrencimEkrani(api: api),
  'odev-takip-ogretmen': (api) => OdevTakipOgretmenEkrani(api: api),
  'derslerim': (api) => DerslerimEkrani(api: api),
  'ogrencilerim': (api) => OgrencilerimEkrani(api: api),
  'veli-bilgilendirme': (api) => VeliBilgilendirmeEkrani(api: api),
  'gelisim-ogretmen': (api) => GelisimOgretmenEkrani(api: api),
  'kulup-ogretmen': (api) => KulupOgretmenEkrani(api: api),
  'kulup-ogrenci': (api) => KulupOgrenciEkrani(api: api),
  'zumrem': (api) => ZumremEkrani(api: api),
  'duyuru': (api) => DuyuruYonetimEkrani(api: api),
  'baskan-toplanti': (api) => BaskanToplantiEkrani(api: api),
  'kurum': (api) => KurumEkrani(api: api),
  'kampusler': (api) => KampuslerEkrani(api: api),
  'kullanici-rol': (api) => KisilerEkrani(api: api),
  'ogrenci-yonetim': (api) => OgrencilerEkrani(api: api),
  'okul-kurulum': (api) => KurulumEkrani(api: api),
  'okul-takvimi': (api) => OkulTakvimiEkrani(api: api),
  'kulup-yonetimi': (api) => KulupYonetimEkrani(api: api),
  'gelisim-yonetim': (api) => GelisimYonetimEkrani(api: api),
  'rapor': (api) => RaporEkrani(api: api),
  'ders-programi-yonetimi': (api) => DersProgramiYonetimEkrani(api: api),
  'not-girisi': (api) => SinavEkrani(api: api, yonetim: false),
  'sinav-yonetim': (api) => SinavEkrani(api: api, yonetim: true),
  'etut': (api) => EtutEkrani(api: api, rol: 'ogretmen'),
  'etut-ogrenci': (api) => EtutEkrani(api: api, rol: 'ogrenci'),
  'etut-veli': (api) => EtutEkrani(api: api, rol: 'veli'),
  'teslim': (api) => TeslimYetkileriEkrani(api: api),
  'teslim-kodu': (api) => TeslimKoduEkrani(api: api),
  'teslim-kapi': (api) => TeslimKapiEkrani(api: api),
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
  int _yenileme = 0;

  @override
  void initState() {
    super.initState();
    _yukle();
    widget.oturum.biyometri.kullanilabilir().then((v) {
      if (mounted) setState(() => _biyometriVar = v);
    });
  }

  Future<void> _yukle() async {
    setState(() {
      _hata = null;
      _yenileme++;
    });
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
    final acik = [
      for (final m in moduller ?? <Modul>[])
        if (!kapali.contains(m.id)) m,
    ];
    final hazir = [
      for (final m in acik)
        if (_hazirEkranlar.containsKey(m.id)) m,
    ];
    final yakinda = [
      for (final m in acik)
        if (!_hazirEkranlar.containsKey(m.id)) m,
    ];
    final duyuru = widget.oturum.ayar.duyuru;
    final menu = PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz, color: Colors.white),
      tooltip: 'Menü',
      onSelected: (v) {
        if (v == 'hesap') Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ProfilEkrani(api: widget.oturum.api)));
        if (v == 'profil') widget.oturum.profilDegistir();
        if (v == 'kilit') widget.oturum.kilidiAyarla(!widget.oturum.kilitAcik);
        if (v == 'cikis') widget.oturum.cikisYap();
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'hesap', child: Text('Profilim')),
        if (ben.coklu) const PopupMenuItem(value: 'profil', child: Text('Profil değiştir')),
        if (_biyometriVar) PopupMenuItem(value: 'kilit', child: Text(widget.oturum.kilitAcik ? 'Biyometrik açılışı kapat' : 'Biyometrik açılışı aç')),
        const PopupMenuItem(value: 'cikis', child: Text('Çıkış yap')),
      ],
    );
    final ogretmen = ben.rol == 'ogretmen';
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _yukle,
        edgeOffset: 120,
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            PanelBandi(ben: ben, menu: menu, api: widget.oturum.api),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (ogretmen)
                    Transform.translate(
                      offset: const Offset(0, -34),
                      child: OgretmenOzeti(key: ValueKey(_yenileme), api: widget.oturum.api),
                    ),
                  if (ogretmen) const SizedBox(height: 0) else const SizedBox(height: 16),
                  if (duyuru != null && duyuru.id != _kapatilanDuyuru)
                    _DuyuruSeridi(duyuru: duyuru, onKapat: () => setState(() => _kapatilanDuyuru = duyuru.id)),
                  if (_hata != null)
                    _Mesaj(_hata!, onTekrar: _yukle)
                  else if (moduller == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
                    )
                  else
                    Transform.translate(
                      offset: Offset(0, ogretmen ? -22 : 0),
                      child: GridView(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, mainAxisExtent: 58),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        children: [
                          for (final m in [...hazir, ...yakinda])
                            _Kare(
                              modul: m,
                              hazir: _hazirEkranlar.containsKey(m.id),
                              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _hazirEkranlar[m.id]!(widget.oturum.api))),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modül başına ikon rengi (web: .kare[data-modul] --ik); listede olmayan modül gri kalır.
Color _modulRengi(String id) {
  bool on(String x) => id.startsWith(x);
  if (on('etut')) return const Color(0xFFF97316);
  if (on('derslerim') || on('ders-programi')) return const Color(0xFF3B82F6);
  if (const {'not-girisi', 'sinav-yonetim', 'rapor', 'notlarim'}.contains(id)) return const Color(0xFF8B5CF6);
  if (on('ogrenci-yonetim')) return const Color(0xFF06B6D4);
  if (id == 'ogrencilerim' || on('devamsizlik')) return const Color(0xFF10B981);
  if (on('veli-bilgilendirme')) return const Color(0xFFEC4899);
  if (id == 'kullanici-rol' || id == 'ogrencim') return const Color(0xFF6366F1);
  if (id == 'okul-kurulum' || id == 'teslim') return const Color(0xFF14B8A6);
  if (id == 'kurum') return const Color(0xFF0EA5E9);
  if (id == 'okul-takvimi') return const Color(0xFFF59E0B);
  if (on('duyuru')) return const Color(0xFFEF4444);
  if (on('odev-takip')) return const Color(0xFFD97706);
  if (id == 'zumrem') return const Color(0xFFD946EF);
  if (on('kulup')) return const Color(0xFFEAB308);
  if (on('gelisim')) return const Color(0xFF22C55E);
  return const Color(0xFF64748B);
}

/// Modül kutusu (web: .kare): solda renkli ikon, yanında serif başlık; ekranı olmayan kesik çizgili "Yakında".
class _Kare extends StatelessWidget {
  const _Kare({required this.modul, required this.hazir, required this.onTap});

  final Modul modul;
  final bool hazir;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final renk = _modulRengi(modul.id);
    final govde = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: hazir ? renk : context.icZemin,
              borderRadius: BorderRadius.circular(9),
              boxShadow: hazir ? [BoxShadow(color: renk.withValues(alpha: .35), blurRadius: 10, offset: const Offset(0, 4), spreadRadius: -4)] : null,
            ),
            alignment: Alignment.center,
            child: CizgiIkon(modul.id, boyut: 19, renk: hazir ? Colors.white : context.soluk),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              modul.ad,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: serif.copyWith(fontSize: 14.5, fontWeight: FontWeight.w600, height: 1.15, color: context.yazi),
            ),
          ),
        ],
      ),
    );
    final sekil = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: hazir ? BorderSide.none : BorderSide(color: context.ince));
    return Opacity(
      opacity: hazir ? 1 : .55,
      child: Material(
        color: hazir ? context.kart : Colors.transparent,
        elevation: hazir ? 1.5 : 0,
        shadowColor: Colors.black.withValues(alpha: .25),
        shape: sekil,
        child: hazir ? InkWell(customBorder: sekil, onTap: onTap, child: govde) : govde,
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
          IconButton(
            icon: Icon(Icons.close, size: 18, color: context.soluk),
            tooltip: 'Kapat',
            onPressed: onKapat,
          ),
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
        Text(
          metin,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.soluk),
        ),
        const SizedBox(height: 14),
        OutlinedButton(onPressed: onTekrar, child: const Text('Tekrar dene')),
      ],
    ),
  );
}

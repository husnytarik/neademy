import 'package:flutter/material.dart';

import '../bilesenler/ortak.dart';
import '../cekirdek/api.dart';
import '../cekirdek/takvim_model.dart';
import '../cekirdek/tema.dart';
import 'ders_detay.dart';

export 'ders_bitir.dart' show DersBitirEkrani;

const _yesil = Color(0xFF2E9E5B);
const _kirmizi = Color(0xFFD64545);
const _gri = Color(0xFF8A867D);

/// Öğretmen: Günlük / Haftalık / Sınıflarım görünümleri; bir derse dokununca sekmeli ders detayı açılır.
class DerslerimEkrani extends StatefulWidget {
  const DerslerimEkrani({super.key, required this.api});

  final Api api;

  @override
  State<DerslerimEkrani> createState() => _DerslerimEkraniState();
}

class _DerslerimEkraniState extends State<DerslerimEkrani> {
  String _gorunum = 'gun';
  String? _tarih; // null: sunucunun bugünü
  String _bugun = '';
  Map<String, dynamic>? _veri;
  String? _hata;
  bool _yukleniyor = true;
  int _istek = 0;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final benim = ++_istek;
    setState(() {
      _yukleniyor = _veri == null;
      _hata = null;
    });
    try {
      final q = _tarih == null ? '' : '?tarih=$_tarih';
      final j = await widget.api.get(_gorunum == 'hafta' ? '/api/ders/hafta$q' : '/api/ders/liste$q') as Map<String, dynamic>;
      if (!mounted || benim != _istek) return;
      setState(() {
        _veri = j;
        _bugun = j.s('bugun');
        _tarih ??= j.s('tarih').isNotEmpty ? j.s('tarih') : null;
        _yukleniyor = false;
      });
    } on ApiHata catch (e) {
      if (mounted && benim == _istek && !e.oturumYok) {
        setState(() {
          _hata = e.mesaj;
          _yukleniyor = false;
        });
      }
    }
  }

  String get _gecerliTarih => _tarih ?? (_bugun.isNotEmpty ? _bugun : tarihYaz(DateTime.now()));

  void _git(String? tarih) {
    setState(() {
      _tarih = tarih;
      _veri = null;
    });
    _yukle();
  }

  void _gorunumSec(String g) {
    if (g == _gorunum) return;
    setState(() {
      _gorunum = g;
      _veri = null;
    });
    _yukle();
  }

  Future<void> _tarihSec() async {
    final t = tarihCoz(_gecerliTarih);
    final d = await showDatePicker(context: context, initialDate: DateTime(t.year, t.month, t.day), firstDate: DateTime(2024), lastDate: DateTime(2030));
    if (d != null) _git(tarihYaz(DateTime.utc(d.year, d.month, d.day)));
  }

  Future<void> _dersAc(Map<String, dynamic> d, String tarih, {bool programdan = true}) async {
    if (d['kulupId'] != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Kulüp çalışması "Kulüp" bölümünden girilir.')));
      return;
    }
    final degisti = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DersDetayEkrani(api: widget.api, ders: programdan ? d : {...d, 'dersSaati': null}, tarih: tarih, bugun: _bugun),
      ),
    );
    if (degisti == true && mounted) _yukle();
  }

  void _etutAc(Map<String, dynamic> e, String tarih) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Etüt · ${e.s('ders').isEmpty ? 'Genel' : e.s('ders')}', style: serif.copyWith(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              '${uzunTarih(tarih)} · ${e.s('saat')} · ${e.n('sure')} dk${e.s('yer').isEmpty ? '' : ' · ${e.s('yer')}'}',
              style: TextStyle(color: context.soluk),
            ),
            const SizedBox(height: 12),
            if (e.s('konu').isNotEmpty) Text('Konu: ${e.s('konu')}'),
            Text('${e.n('kisi')} öğrenci davetli'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tarih = _gecerliTarih;
    final j = _veri;
    Widget icerik;
    if (j == null) {
      icerik = _hata == null || _yukleniyor
          ? const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
            )
          : Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Column(
                children: [
                  Text(
                    _hata ?? 'Veri alınamadı.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.soluk),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton(onPressed: _yukle, child: const Text('Tekrar dene')),
                ],
              ),
            );
    } else {
      icerik = switch (_gorunum) {
        'hafta' => _Hafta(veri: j, bugun: _bugun, ac: (d, t) => _dersAc(d, t), etutAc: _etutAc),
        'siniflar' => _Siniflar(veri: j, ac: (a) => _dersAc(a, tarih, programdan: false)),
        _ => _Gunluk(veri: j, ac: (d) => _dersAc(d, tarih), etutAc: (e) => _etutAc(e, tarih), sonraki: () => _git(gunKaydir(tarih, 1))),
      };
    }
    final hafta = _gorunum == 'hafta';
    return Scaffold(
      appBar: AppBar(title: const Text('Derslerim')),
      body: RefreshIndicator(
        onRefresh: _yukle,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          children: [
            Sekmeler(secenekler: const [('gun', 'Günlük'), ('hafta', 'Haftalık'), ('siniflar', 'Sınıflarım')], secili: _gorunum, degisti: _gorunumSec),
            if (_gorunum != 'siniflar') ...[
              const SizedBox(height: 12),
              _GunSeridi(
                baslik: hafta ? _haftaBasligi(j, tarih) : uzunTarih(tarih),
                bugunde: hafta ? (j?.l('gunler').any((g) => g.s('tarih') == _bugun) ?? false) : tarih == _bugun,
                geri: () => _git(gunKaydir(tarih, hafta ? -7 : -1)),
                ileri: () => _git(gunKaydir(tarih, hafta ? 7 : 1)),
                sec: _tarihSec,
                bugun: () => _git(null),
              ),
            ],
            const SizedBox(height: 14),
            icerik,
          ],
        ),
      ),
    );
  }

  String _haftaBasligi(Map<String, dynamic>? j, String tarih) {
    final gunler = j?.l('gunler') ?? const [];
    if (gunler.length < 7) return uzunTarih(tarih);
    String kisa(String t) {
      final d = tarihCoz(t);
      return '${d.day} ${ayAdlari[d.month - 1]}';
    }

    return '${kisa(j!.s('pazartesi'))} – ${kisa(gunler[6].s('tarih'))}';
  }
}

class _GunSeridi extends StatelessWidget {
  const _GunSeridi({required this.baslik, required this.bugunde, required this.geri, required this.ileri, required this.sec, required this.bugun});

  final String baslik;
  final bool bugunde;
  final VoidCallback geri;
  final VoidCallback ileri;
  final VoidCallback sec;
  final VoidCallback bugun;

  @override
  Widget build(BuildContext context) {
    Widget dugme(IconData ikon, VoidCallback f, String ipucu) => Material(
      color: context.kart,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: context.ince),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: f,
        child: SizedBox(width: 46, height: 46, child: Icon(ikon, color: context.yazi)),
      ),
    );
    return Row(
      children: [
        dugme(Icons.chevron_left, geri, 'Önceki'),
        const SizedBox(width: 8),
        Expanded(
          child: Material(
            color: context.kart,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: context.ince),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: sec,
              child: SizedBox(
                height: 46,
                child: Center(
                  child: Text(
                    baslik,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: serif.copyWith(fontSize: 16.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        dugme(Icons.chevron_right, ileri, 'Sonraki'),
        if (!bugunde) ...[const SizedBox(width: 8), dugme(Icons.today_outlined, bugun, 'Bugün')],
      ],
    );
  }
}

Color _renk(Map<String, dynamic> d, BuildContext context) => rengiCoz(d.s('renk')) ?? context.ana;

class _Gunluk extends StatelessWidget {
  const _Gunluk({required this.veri, required this.ac, required this.etutAc, required this.sonraki});

  final Map<String, dynamic> veri;
  final void Function(Map<String, dynamic>) ac;
  final void Function(Map<String, dynamic>) etutAc;
  final VoidCallback sonraki;

  @override
  Widget build(BuildContext context) {
    final dersler = veri.l('gunluk');
    final etutler = veri.l('etutler');
    if (dersler.isEmpty && etutler.isEmpty) {
      final tatil = veri.s('tatil');
      return Column(
        children: [
          BosNot(
            tatil.isNotEmpty
                ? '$tatil · okul tatil'
                : veri['hafta_sonu'] == true
                ? 'Bugün ders günü değil.'
                : 'Bu günde dersiniz yok.',
          ),
          if (veri['hafta_sonu'] == true) OutlinedButton(onPressed: sonraki, child: const Text('Sonraki güne git')),
        ],
      );
    }
    final ogeler = [
      for (final d in dersler) (bas: d.s('aralik').split('–').first, ders: d, etut: false),
      for (final e in etutler) (bas: e.s('saat'), ders: e, etut: true),
    ]..sort((a, b) => a.bas.compareTo(b.bas));
    return Column(
      children: [for (final o in ogeler) _DersSatiri(o.ders, bas: o.bas, etut: o.etut, onTap: () => o.etut ? etutAc(o.ders) : ac(o.ders))],
    );
  }
}

class _DersSatiri extends StatelessWidget {
  const _DersSatiri(this.d, {required this.bas, required this.etut, required this.onTap});

  final Map<String, dynamic> d;
  final String bas;
  final bool etut;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final renk = _renk(d, context);
    final kulup = d['kulupId'] != null;
    final durum = d.s('durum');
    final (isaret, isaretRenk, ad) = switch (durum) {
      'tamam' => ('✓', _yesil, d.n('gelmedi') > 0 ? 'Tamamlandı · ${d.n('gelmedi')} gelmedi' : 'Tamamlandı'),
      'gecikti' => ('!', _kirmizi, 'Süresi geçti · tamamlanmadı'),
      'iptal' => ('⊘', _gri, 'Ders iptal edildi'),
      _ => ('', _gri, ''),
    };
    final baslik = etut
        ? '${d.s('ders').isEmpty ? 'Genel' : d.s('ders')}${d.s('konu').isEmpty ? '' : ' · ${d.s('konu')}'}'
        : (kulup ? 'Kulüp · ${d.s('sinif')}' : d.s('sinif'));
    final alt = etut ? '${d.n('kisi')} öğrenci${d.s('yer').isEmpty ? '' : ' · ${d.s('yer')}'}' : (kulup ? 'Kulüp' : d.s('ders'));
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: context.kart,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: context.ince),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 5, color: renk),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
                  child: SizedBox(
                    width: 58,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(etut ? 'Etüt' : bas, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        Text(etut ? bas : '${d.n('dersSaati')}. ders', style: TextStyle(color: context.soluk, fontSize: 12.5)),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(baslik, style: serif.copyWith(fontSize: 16.5, fontWeight: FontWeight.w600)),
                        if (alt.isNotEmpty) Text(alt, style: TextStyle(color: context.soluk, fontSize: 13)),
                        if (ad.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              ad,
                              style: TextStyle(color: isaretRenk, fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (isaret.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Center(
                      child: Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: isaretRenk.withValues(alpha: .15), shape: BoxShape.circle),
                        child: Text(
                          isaret,
                          style: TextStyle(color: isaretRenk, fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Haftalık tablo: satırlar ders saatleri, sütunlar günler; hücrede sınıf adı ve durum işareti.
class _Hafta extends StatelessWidget {
  const _Hafta({required this.veri, required this.bugun, required this.ac, required this.etutAc});

  final Map<String, dynamic> veri;
  final String bugun;
  final void Function(Map<String, dynamic> ders, String tarih) ac;
  final void Function(Map<String, dynamic> etut, String tarih) etutAc;

  @override
  Widget build(BuildContext context) {
    // Ders günü olmayan ve dersi/etüdü bulunmayan günler gösterilmez
    final gunler = [
      for (final g in veri.l('gunler'))
        if (g['acik'] == true || g.s('tatil').isNotEmpty || g.l('dersler').isNotEmpty || g.l('etutler').isNotEmpty) g,
    ];
    final zamanlar = [for (final z in (veri['zamanlar'] as List? ?? const [])) z.toString()];
    final dersSayisi = veri.l('gunler').fold<int>(0, (n, g) => n + g.l('dersler').length);
    final etutler = [
      for (final g in veri.l('gunler'))
        for (final e in g.l('etutler')) {...e, 'tarih': g.s('tarih')},
    ];
    final etutDk = etutler.fold<int>(0, (n, e) => n + e.n('sure'));
    if (gunler.isEmpty) return const BosNot('Bu hafta ders yok.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10, left: 2),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$dersSayisi saat ders',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (etutler.isNotEmpty) TextSpan(text: ' · ${etutler.length} etüt ($etutDk dk)'),
              ],
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: context.kart,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.ince),
          ),
          padding: const EdgeInsets.all(6),
          child: Table(
            columnWidths: {0: const FixedColumnWidth(40), for (var i = 1; i <= gunler.length; i++) i: const FlexColumnWidth()},
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                children: [
                  const SizedBox(),
                  for (final g in gunler) _GunBasi(g, bugunde: g.s('tarih') == bugun),
                ],
              ),
              for (var i = 0; i < zamanlar.length; i++)
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Column(
                        children: [
                          Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                          Text(zamanlar[i].split('–').first, style: TextStyle(color: context.soluk, fontSize: 9.5)),
                        ],
                      ),
                    ),
                    for (final g in gunler)
                      Padding(
                        padding: const EdgeInsets.all(1.5),
                        child: _Hucre(
                          dersler: [
                            for (final d in g.l('dersler'))
                              if (d.n('dersSaati') == i + 1) d,
                          ],
                          ac: (d) => ac(d, g.s('tarih')),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 10, left: 2),
          child: Text('✓ ders işlendi · ⊘ iptal · ! süresi geçti, tamamlanmadı', style: TextStyle(color: context.soluk, fontSize: 12)),
        ),
        if (etutler.isNotEmpty) ...[
          const Baslik('Bu haftaki etütler'),
          for (final e in etutler)
            KartKutu(
              onTap: () => etutAc(e, e.s('tarih')),
              child: Row(
                children: [
                  DersRozeti(e.s('kisa').isEmpty ? 'E' : e.s('kisa'), rengiCoz(e.s('renk')) ?? context.ana, boyut: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.s('konu').isEmpty ? (e.s('ders').isEmpty ? 'Etüt' : e.s('ders')) : e.s('konu'),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        Text('${uzunTarih(e.s('tarih'))} · ${e.s('saat')} · ${e.n('sure')} dk', style: TextStyle(color: context.soluk, fontSize: 12.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _GunBasi extends StatelessWidget {
  const _GunBasi(this.g, {required this.bugunde});

  final Map<String, dynamic> g;
  final bool bugunde;

  @override
  Widget build(BuildContext context) {
    final t = g.s('tarih');
    return Container(
      margin: const EdgeInsets.all(1.5),
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(color: bugunde ? context.ana.withValues(alpha: .14) : null, borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Text(
            kisaGunAdlari[(tarihCoz(t).weekday - 1) % 7],
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: g.s('tatil').isNotEmpty ? _gri : null),
          ),
          Text('${t.substring(8)}.${t.substring(5, 7)}', style: TextStyle(color: context.soluk, fontSize: 10.5)),
        ],
      ),
    );
  }
}

class _Hucre extends StatelessWidget {
  const _Hucre({required this.dersler, required this.ac});

  final List<Map<String, dynamic>> dersler;
  final void Function(Map<String, dynamic>) ac;

  @override
  Widget build(BuildContext context) {
    if (dersler.isEmpty) return const SizedBox(height: 44);
    return Column(
      children: [
        for (final d in dersler)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Builder(
              builder: (context) {
                final renk = _renk(d, context);
                final durum = d.s('durum');
                final gecikti = durum == 'gecikti';
                final isaret = switch (durum) {
                  'tamam' => ' ✓',
                  'gecikti' => ' !',
                  'iptal' => ' ⊘',
                  _ => '',
                };
                return Material(
                  color: gecikti ? renk : renk.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(9),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(9),
                    onTap: () => ac(d),
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      child: Text(
                        '${d['kulupId'] != null ? 'Kulüp' : d.s('sinif')}$isaret',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, color: gecikti ? Colors.white : okunur(context, renk)),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _Siniflar extends StatelessWidget {
  const _Siniflar({required this.veri, required this.ac});

  final Map<String, dynamic> veri;
  final void Function(Map<String, dynamic>) ac;

  @override
  Widget build(BuildContext context) {
    final atamalar = veri.l('atamalar');
    if (atamalar.isEmpty) return const BosNot('Size atanmış ders yok.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text('Sınıfa dokunun: öğrenciler, konular ve ödevler', style: TextStyle(color: context.soluk, fontSize: 13.5)),
        ),
        for (final a in atamalar)
          KartKutu(
            onTap: () => ac(a),
            child: Row(
              children: [
                DersRozeti(a.s('kisa'), _renk(a, context), boyut: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.s('sinif'), style: serif.copyWith(fontSize: 16.5, fontWeight: FontWeight.w600)),
                      Text('${a.s('ders')} · ${a.n('ogrenciSayisi')} öğrenci', style: TextStyle(color: context.soluk, fontSize: 13)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: context.soluk),
              ],
            ),
          ),
      ],
    );
  }
}

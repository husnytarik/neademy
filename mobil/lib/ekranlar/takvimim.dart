import 'package:flutter/material.dart';

import '../cekirdek/api.dart';
import '../cekirdek/takvim_model.dart';
import '../cekirdek/tema.dart';

/// Öğretmenin takvimi: ay ızgarası (türe göre renkli noktalar) ve hafta listesi.
class TakvimimEkrani extends StatefulWidget {
  const TakvimimEkrani({super.key, required this.api});

  final Api api;

  @override
  State<TakvimimEkrani> createState() => _TakvimimEkraniState();
}

class _TakvimimEkraniState extends State<TakvimimEkrani> {
  final Map<String, TakvimAyi> _onbellek = {};
  bool _hafta = false;
  String? _secili; // seçili gün
  String? _bugun;
  String? _hata;
  bool _yukleniyor = true;

  String get _ay => _secili!.substring(0, 7);

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<TakvimAyi> _ayGetir(String ay) async {
    final varsa = _onbellek[ay];
    if (varsa != null) return varsa;
    final j = await widget.api.get('/api/takvim?ay=$ay') as Map<String, dynamic>;
    final v = TakvimAyi.json(j);
    _bugun = v.bugun;
    return _onbellek[ay] = v;
  }

  /// Seçili gün için gereken ay(lar)ı getirir. Hafta iki aya yayılırsa ikisi de gerekir.
  Future<void> _yukle() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      if (_secili == null) {
        // Sunucunun "bugün"ü esas alınır (Europe/Istanbul); ilk istek bu ayın tahmini ile yapılır
        final simdi = DateTime.now();
        final ilk = await _ayGetir('${simdi.year}-${simdi.month.toString().padLeft(2, '0')}');
        _secili = ilk.bugun;
      }
      await _ayGetir(_ay);
      if (_hafta) {
        await _ayGetir(pazartesi(_secili!).substring(0, 7));
        await _ayGetir(gunKaydir(pazartesi(_secili!), 6).substring(0, 7));
      }
    } on ApiHata catch (e) {
      if (mounted) setState(() => _hata = e.mesaj);
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  void _git(String tarih) {
    setState(() => _secili = tarih);
    _yukle();
  }

  void _adim(int n) => _git(_hafta ? gunKaydir(_secili!, 7 * n) : ayKaydir(_secili!, n));

  TakvimGunu? _gun(String tarih) => _onbellek[tarih.substring(0, 7)]?.harita[tarih] ?? _onbellek[_ay]?.harita[tarih];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Takvimim')),
      body: _secili == null
          ? Center(child: _hata != null ? _HataKutusu(_hata!, _yukle) : const CircularProgressIndicator(strokeWidth: 2.5))
          : RefreshIndicator(
              onRefresh: () async {
                _onbellek.clear();
                await _yukle();
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  _GorunumSecici(hafta: _hafta, degisti: (h) {
                    setState(() => _hafta = h);
                    _yukle();
                  }),
                  const SizedBox(height: 14),
                  _Serit(
                    baslik: _hafta
                        ? '${kisaTarih(pazartesi(_secili!))} – ${kisaTarih(gunKaydir(pazartesi(_secili!), 6))}'
                        : '${ayAdlari[int.parse(_ay.substring(5)) - 1]} ${_ay.substring(0, 4)}',
                    onGeri: () => _adim(-1),
                    onIleri: () => _adim(1),
                    onBugun: _bugun == null ? null : () => _git(_bugun!),
                  ),
                  const SizedBox(height: 14),
                  if (_hata != null)
                    _HataKutusu(_hata!, _yukle)
                  else if (_onbellek[_ay] == null)
                    const Padding(padding: EdgeInsets.only(top: 48), child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)))
                  else if (_hafta)
                    ..._haftaIcerigi()
                  else
                    ..._ayIcerigi(_onbellek[_ay]!),
                  if (_yukleniyor && _onbellek[_ay] != null)
                    const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator(minHeight: 2)),
                ],
              ),
            ),
    );
  }

  List<Widget> _ayIcerigi(TakvimAyi v) {
    final g = v.harita[_secili!];
    return [
      _AyIzgarasi(ay: v, secili: _secili!, bugun: _bugun ?? v.bugun, sec: (t) => setState(() => _secili = t)),
      const SizedBox(height: 14),
      _Lejant(v.gorunenTurler()),
      const SizedBox(height: 16),
      if (g != null) ...[
        Text(uzunTarih(g.tarih), style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        _GunSatirlari(g),
      ],
    ];
  }

  List<Widget> _haftaIcerigi() {
    final bas = pazartesi(_secili!);
    final gunler = <TakvimGunu>[];
    for (var i = 0; i < 7; i++) {
      final g = _gun(gunKaydir(bas, i));
      if (g == null) continue;
      // Ders günü olmayan ve boş günler gösterilmez
      if (g.ogeler.isEmpty && g.tatil == null && !g.acik) continue;
      gunler.add(g);
    }
    final bugun = _bugun;
    return [
      _Lejant(_onbellek[_ay]!.gorunenTurler(gunler)),
      const SizedBox(height: 16),
      for (final g in gunler) ...[
        Row(children: [
          Text(uzunTarih(g.tarih), style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600)),
          if (g.tarih == bugun) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              decoration: BoxDecoration(color: context.ana, borderRadius: BorderRadius.circular(99)),
              child: Text('Bugün', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 11.5, fontWeight: FontWeight.w600)),
            ),
          ],
        ]),
        const SizedBox(height: 10),
        _GunSatirlari(g),
        const SizedBox(height: 18),
      ],
    ];
  }
}

class _GorunumSecici extends StatelessWidget {
  const _GorunumSecici({required this.hafta, required this.degisti});

  final bool hafta;
  final ValueChanged<bool> degisti;

  @override
  Widget build(BuildContext context) => SegmentedButton<bool>(
        showSelectedIcon: false,
        segments: const [ButtonSegment(value: false, label: Text('Ay')), ButtonSegment(value: true, label: Text('Hafta'))],
        selected: {hafta},
        onSelectionChanged: (s) => degisti(s.first),
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          minimumSize: const WidgetStatePropertyAll(Size.fromHeight(42)),
        ),
      );
}

class _Serit extends StatelessWidget {
  const _Serit({required this.baslik, required this.onGeri, required this.onIleri, required this.onBugun});

  final String baslik;
  final VoidCallback onGeri;
  final VoidCallback onIleri;
  final VoidCallback? onBugun;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          IconButton(onPressed: onGeri, icon: const Icon(Icons.chevron_left), tooltip: 'Önceki'),
          Expanded(
            child: Text(baslik, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          ),
          TextButton(onPressed: onBugun, child: const Text('Bugün')),
          IconButton(onPressed: onIleri, icon: const Icon(Icons.chevron_right), tooltip: 'Sonraki'),
        ],
      );
}

class _AyIzgarasi extends StatelessWidget {
  const _AyIzgarasi({required this.ay, required this.secili, required this.bugun, required this.sec});

  final TakvimAyi ay;
  final String secili;
  final String bugun;
  final ValueChanged<String> sec;

  @override
  Widget build(BuildContext context) {
    final hucreler = <Widget>[];
    for (final g in ay.gunler) {
      hucreler.add(_Hucre(
        gun: g,
        disari: g.tarih.substring(0, 7) != ay.ay,
        bugun: g.tarih == bugun,
        secili: g.tarih == secili,
        onTap: () => sec(g.tarih),
      ));
    }
    return Column(
      children: [
        Row(children: [
          for (final a in kisaGunAdlari)
            Expanded(child: Center(child: Text(a, style: TextStyle(fontSize: 12, color: context.soluk)))),
        ]),
        const SizedBox(height: 6),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: .78,
          children: hucreler,
        ),
      ],
    );
  }
}

class _Hucre extends StatelessWidget {
  const _Hucre({required this.gun, required this.disari, required this.bugun, required this.secili, required this.onTap});

  final TakvimGunu gun;
  final bool disari;
  final bool bugun;
  final bool secili;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ana = context.ana;
    final kapali = !gun.acik || gun.tatil != null;
    final turSirasi = [for (final t in turler.keys) if (gun.ogeler.any((o) => o.tur == t)) t];
    final yaziRengi = secili ? Theme.of(context).colorScheme.onPrimary : (bugun ? ana : context.yazi);
    return Semantics(
      button: true,
      selected: secili,
      label: '${uzunTarih(gun.tarih)}${gun.tatil != null ? ', ${gun.tatil}' : ''}${gun.ogeler.isNotEmpty ? ', ${gun.ogeler.length} kayıt' : ''}',
      child: Opacity(
        opacity: disari && !secili ? .45 : 1,
        child: Material(
          color: secili ? ana : (kapali ? context.icZemin : context.kart),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: bugun || secili ? ana : context.ince),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Column(
                children: [
                  Text('${int.parse(gun.tarih.substring(8))}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: yaziRengi)),
                  const SizedBox(height: 5),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 3,
                    runSpacing: 3,
                    children: [
                      for (final t in turSirasi)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: turler[t]!.renk,
                            shape: BoxShape.circle,
                            border: secili ? Border.all(color: Colors.white, width: 1.2) : null,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Lejant extends StatelessWidget {
  const _Lejant(this.gorunen);

  final List<String> gorunen;

  @override
  Widget build(BuildContext context) {
    if (gorunen.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        for (final t in gorunen)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: turler[t]!.renk, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(turler[t]!.ad, style: TextStyle(fontSize: 13, color: context.soluk)),
            ],
          ),
      ],
    );
  }
}

class _GunSatirlari extends StatelessWidget {
  const _GunSatirlari(this.gun);

  final TakvimGunu gun;

  @override
  Widget build(BuildContext context) {
    if (gun.ogeler.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          gun.tatil != null ? '${gun.tatil} · okul tatil' : (!gun.acik ? 'Ders günü değil.' : 'Bu gün için kayıt yok.'),
          style: TextStyle(color: context.soluk, fontSize: 14.5),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (gun.tatil != null)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('${gun.tatil} · okul tatil', style: TextStyle(color: context.soluk, fontSize: 14))),
        for (final o in gun.ogeler) _Satir(o),
      ],
    );
  }
}

class _Satir extends StatelessWidget {
  const _Satir(this.oge);

  final TakvimOgesi oge;

  @override
  Widget build(BuildContext context) {
    final renk = oge.cizgiRengi;
    final tur = turler[oge.tur];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: context.kart,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.ince),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: renk),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 0, 10),
              child: SizedBox(
                width: 46,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(oge.bas.isEmpty ? '—' : oge.bas, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                    if (oge.bit.isNotEmpty) Text(oge.bit, style: TextStyle(fontSize: 12.5, color: context.soluk)),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (oge.tur == 'ders' && oge.kisa != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(color: renk, borderRadius: BorderRadius.circular(6)),
                            child: Text(oge.kisa!, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
                          ),
                        Text(oge.baslik, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        if (oge.tur != 'ders' && tur != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                            decoration: BoxDecoration(border: Border.all(color: renk), borderRadius: BorderRadius.circular(99)),
                            child: Text(tur.ad, style: TextStyle(color: renk, fontSize: 11.5, fontWeight: FontWeight.w600)),
                          ),
                        if (durumAdlari[oge.durum] != null)
                          Text(durumAdlari[oge.durum]!, style: TextStyle(color: context.soluk, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    if (oge.alt.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(oge.alt, style: TextStyle(color: context.soluk, fontSize: 13.5)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HataKutusu extends StatelessWidget {
  const _HataKutusu(this.metin, this.tekrar);

  final String metin;
  final VoidCallback tekrar;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(metin, textAlign: TextAlign.center, style: TextStyle(color: context.soluk)),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: tekrar, child: const Text('Tekrar dene')),
          ],
        ),
      );
}

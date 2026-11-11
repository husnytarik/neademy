import 'package:flutter/material.dart';

import '../bilesenler/ortak.dart';
import '../bilesenler/yoklama_ogeleri.dart';
import '../cekirdek/api.dart';
import '../cekirdek/takvim_model.dart';
import '../cekirdek/tema.dart';

const _yesil = Color(0xFF2E9E5B);
const _kirmizi = Color(0xFFD64545);
const _yanitAd = {'bekliyor': 'Yanıt bekleniyor', 'gelecek': 'Gelecek', 'gelmeyecek': 'Gelmeyecek'};
const _devamAd = {'geldi': 'Geldi', 'gelmedi': 'Gelmedi', 'izinli': 'İzinli'};

String _bugun() => tarihYaz(DateTime.now());

String _tarihEtiket(String t) {
  final d = tarihCoz(t);
  return '${d.day} ${ayAdlari[d.month - 1]} ${gunAdlari[d.weekday - 1]}';
}

/// Etüt: öğretmen açar ve yoklama alır, veli "gelecek / gelmeyecek" bildirir, öğrenci davetlerini görür.
class EtutEkrani extends StatefulWidget {
  const EtutEkrani({super.key, required this.api, required this.rol});

  final Api api;

  /// 'ogretmen' | 'veli' | 'ogrenci'
  final String rol;

  @override
  State<EtutEkrani> createState() => _EtutEkraniState();
}

class _EtutEkraniState extends State<EtutEkrani> {
  int _surum = 0;

  Future<void> _islem(Future<dynamic> Function() is_, {String? basari}) async {
    try {
      await is_();
      if (!mounted) return;
      if (basari != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(basari)));
      }
      setState(() => _surum++);
    } catch (e) {
      if (mounted) hataGoster(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ogretmen = widget.rol == 'ogretmen';
    final sayfa = VeriSayfasi(
      key: ValueKey(_surum),
      baslik: widget.rol == 'veli'
          ? 'Etüt onayları'
          : widget.rol == 'ogrenci'
          ? 'Etütlerim'
          : 'Etüt',
      getir: () => widget.api.get('/api/etut/liste'),
      cizim: (context, veri) {
        final etutler = (veri as Map<String, dynamic>).l('etutler');
        final bugun = _bugun();
        final yaklasan = [
          for (final e in etutler)
            if (e.s('durum') == 'planli' && e.s('tarih').compareTo(bugun) >= 0) e,
        ]..sort((a, b) => '${a.s('tarih')}${a.s('saat')}'.compareTo('${b.s('tarih')}${b.s('saat')}'));
        final gecmis = [
          for (final e in etutler)
            if (!yaklasan.contains(e)) e,
        ];
        Widget kart(Map<String, dynamic> e) => switch (widget.rol) {
          'ogretmen' => _OgretmenEtut(e, bugun: bugun, iptal: () => _iptal(e), yoklama: () => _yoklama(e)),
          'veli' => _VeliEtut(e, bugun: bugun, yanit: (y) => _yanit(e, y)),
          _ => _OgrenciEtut(e),
        };
        return [
          if (etutler.isEmpty) BosNot(ogretmen ? 'Henüz etüt açmadınız.' : 'Etüt daveti yok.'),
          if (yaklasan.isNotEmpty) const Baslik('Yaklaşan', ust: 8),
          for (final e in yaklasan) kart(e),
          if (gecmis.isNotEmpty) const Baslik('Geçmiş ve iptal edilenler'),
          for (final e in gecmis) kart(e),
        ];
      },
    );
    if (!ogretmen) return sayfa;
    return Stack(
      children: [
        sayfa,
        Positioned(
          right: 16,
          bottom: 16 + MediaQuery.of(context).padding.bottom,
          child: FloatingActionButton.extended(onPressed: _yeni, icon: const Icon(Icons.add), label: const Text('Etüt aç')),
        ),
      ],
    );
  }

  Future<void> _yanit(Map<String, dynamic> e, String y) => _islem(
    () => widget.api.post('/api/etut/yanit', {'etutId': e.n('id'), 'ogrenciId': e.n('ogrenciId'), 'yanit': y}),
    basari: y == 'gelecek' ? 'Katılım bildirildi.' : 'Katılmayacağınız bildirildi.',
  );

  Future<void> _iptal(Map<String, dynamic> e) async {
    if (!await onayIste(context, '"${e.s('konu')}" etütü iptal edilsin mi?', evet: 'İptal et')) return;
    await _islem(() => widget.api.post('/api/etut/iptal', {'etutId': e.n('id')}), basari: 'Etüt iptal edildi.');
  }

  Future<void> _yoklama(Map<String, dynamic> e) async {
    final durum = await Navigator.of(context).push<Map<int, String>>(MaterialPageRoute(builder: (_) => _EtutYoklamasi(etut: e)));
    if (durum == null) return;
    await _islem(
      () => widget.api.post('/api/etut/yoklama', {
        'etutId': e.n('id'),
        'kayitlar': [
          for (final d in durum.entries) {'ogrenciId': d.key, 'durum': d.value},
        ],
      }),
      basari: 'Yoklama kaydedildi.',
    );
  }

  Future<void> _yeni() async {
    Map<String, dynamic> secenek;
    try {
      secenek = await widget.api.get('/api/etut/secenek') as Map<String, dynamic>;
    } catch (e) {
      if (mounted) hataGoster(context, e);
      return;
    }
    if (!mounted) return;
    final govde = await Navigator.of(context).push<Map<String, dynamic>>(MaterialPageRoute(builder: (_) => _EtutFormu(secenek: secenek)));
    if (govde == null) return;
    try {
      await widget.api.post('/api/etut/ekle', govde);
    } on ApiHata catch (e) {
      if (!mounted) return;
      if (e.kod == 409 && e.mesaj.contains('ders programı')) {
        if (!await onayIste(context, '${e.mesaj}. Yine de etüt açılsın mı?', evet: 'Yine de aç')) return;
        await _islem(() => widget.api.post('/api/etut/ekle', {...govde, 'cakismayiOnayla': true}), basari: 'Etüt açıldı.');
      } else {
        hataGoster(context, e);
      }
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Etüt açıldı; veliler bilgilendirilecek.')));
      setState(() => _surum++);
    }
  }
}

class _Baslik extends StatelessWidget {
  const _Baslik(this.e);

  final Map<String, dynamic> e;

  @override
  Widget build(BuildContext context) {
    final iptal = e.s('durum') == 'iptal';
    final d = tarihCoz(e.s('tarih'));
    final bas = e.s('saat');
    final sure = e.n('sureDk');
    final bit = _bitis(bas, sure);
    final altSatir = [e.s('ders'), e.s('yer')].where((x) => x.isNotEmpty).join(' · ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(color: context.ana.withValues(alpha: .12), borderRadius: BorderRadius.circular(10)),
          child: Column(
            children: [
              Text('${d.day}', style: serif.copyWith(fontSize: 21, fontWeight: FontWeight.w700)),
              Text(ayAdlari[d.month - 1].substring(0, 3).toUpperCase(), style: TextStyle(color: context.soluk, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      e.s('konu').isEmpty ? e.s('ders') : e.s('konu'),
                      style: serif.copyWith(fontSize: 16, fontWeight: FontWeight.w700, decoration: iptal ? TextDecoration.lineThrough : null),
                    ),
                  ),
                  if (iptal) const Cip('İptal', renk: _kirmizi),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                '$bas${bit.isEmpty ? '' : '–$bit'} · $sure dk',
                style: TextStyle(color: context.soluk, fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
              if (e.s('ogretmen').isNotEmpty) Text('Öğretmen: ${e.s('ogretmen')}', style: TextStyle(color: context.soluk, fontSize: 13.5)),
              if (altSatir.isNotEmpty) Text(altSatir, style: TextStyle(color: context.soluk, fontSize: 13.5)),
              if (e.s('not').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(e.s('not'), style: const TextStyle(fontSize: 13.5, height: 1.35)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

String _bitis(String saat, int dk) {
  final p = saat.split(':');
  if (p.length != 2) return '';
  final t = (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0) + dk;
  return '${(t ~/ 60 % 24).toString().padLeft(2, '0')}:${(t % 60).toString().padLeft(2, '0')}';
}

class _OgrenciEtut extends StatelessWidget {
  const _OgrenciEtut(this.e);

  final Map<String, dynamic> e;

  @override
  Widget build(BuildContext context) => KartKutu(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Baslik(e),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: [
            if (e.s('devam').isNotEmpty) Cip('Devam: ${_devamAd[e.s('devam')] ?? e.s('devam')}', renk: e.s('devam') == 'gelmedi' ? _kirmizi : _yesil),
            if (e.s('devam').isEmpty && e.s('durum') == 'planli')
              Cip(
                _yanitAd[e.s('yanit')] ?? e.s('yanit'),
                renk: e.s('yanit') == 'gelecek'
                    ? _yesil
                    : e.s('yanit') == 'gelmeyecek'
                    ? _kirmizi
                    : null,
              ),
          ],
        ),
      ],
    ),
  );
}

class _VeliEtut extends StatelessWidget {
  const _VeliEtut(this.e, {required this.bugun, required this.yanit});

  final Map<String, dynamic> e;
  final String bugun;
  final void Function(String) yanit;

  @override
  Widget build(BuildContext context) {
    final acik = e.s('durum') == 'planli' && e.s('tarih').compareTo(bugun) >= 0;
    final y = e.s('yanit');
    return KartKutu(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (e.s('ogrenci').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Cip(e.s('ogrenci'), renk: context.ana),
            ),
          _Baslik(e),
          const SizedBox(height: 10),
          if (acik)
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () => yanit('gelecek'),
                    style: y == 'gelecek' ? FilledButton.styleFrom(backgroundColor: _yesil, foregroundColor: Colors.white) : null,
                    child: const Text('Gelecek'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () => yanit('gelmeyecek'),
                    style: y == 'gelmeyecek' ? FilledButton.styleFrom(backgroundColor: _kirmizi, foregroundColor: Colors.white) : null,
                    child: const Text('Gelmeyecek'),
                  ),
                ),
              ],
            )
          else if (e.s('devam').isNotEmpty)
            Cip('Devam: ${_devamAd[e.s('devam')] ?? e.s('devam')}', renk: e.s('devam') == 'gelmedi' ? _kirmizi : _yesil)
          else if (e.s('durum') == 'planli')
            Cip('Yanıt: ${_yanitAd[y] ?? y}'),
        ],
      ),
    );
  }
}

class _OgretmenEtut extends StatelessWidget {
  const _OgretmenEtut(this.e, {required this.bugun, required this.iptal, required this.yoklama});

  final Map<String, dynamic> e;
  final String bugun;
  final VoidCallback iptal;
  final VoidCallback yoklama;

  @override
  Widget build(BuildContext context) {
    final planli = e.s('durum') == 'planli';
    final kat = e.l('katilimcilar');
    int say(String y) => kat.where((k) => k.s('yanit') == y).length;
    return KartKutu(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Baslik(e),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Cip('${kat.length} öğrenci'),
              if (planli) ...[
                Cip('${say('gelecek')} gelecek', renk: _yesil),
                Cip('${say('gelmeyecek')} gelmeyecek', renk: _kirmizi),
                Cip('${say('bekliyor')} bekliyor'),
              ],
            ],
          ),
          if (kat.isNotEmpty)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                dense: true,
                title: Text('Öğrenciler', style: TextStyle(color: context.soluk, fontSize: 13.5)),
                children: [
                  for (final k in kat)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(k.s('ad')),
                      trailing: Text(
                        k.s('devam').isNotEmpty ? _devamAd[k.s('devam')] ?? '' : _yanitAd[k.s('yanit')] ?? '',
                        style: TextStyle(color: context.soluk, fontSize: 12.5),
                      ),
                    ),
                ],
              ),
            ),
          if (planli)
            Wrap(
              spacing: 8,
              children: [
                if (e.s('tarih').compareTo(bugun) <= 0) OutlinedButton(style: kompakt, onPressed: yoklama, child: const Text('Yoklama al')),
                TextButton(
                  onPressed: iptal,
                  style: TextButton.styleFrom(foregroundColor: _kirmizi),
                  child: const Text('İptal et'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Etüt yoklaması: web'deki gibi özet çubuğu, "hepsini geldi yap" ve öğrenci hapları (halka menüyle seçilir).
class _EtutYoklamasi extends StatefulWidget {
  const _EtutYoklamasi({required this.etut});

  final Map<String, dynamic> etut;

  @override
  State<_EtutYoklamasi> createState() => _EtutYoklamasiState();
}

class _EtutYoklamasiState extends State<_EtutYoklamasi> {
  static const _secenekler = {'geldi', 'gelmedi', 'izinli'};
  late final Map<int, String> _durum = {for (final k in widget.etut.l('katilimcilar')) k.n('ogrenciId'): k.s('devam').isEmpty ? 'geldi' : k.s('devam')};

  @override
  Widget build(BuildContext context) {
    final katilimcilar = widget.etut.l('katilimcilar');
    final sayilar = <String, int>{};
    for (final d in _durum.values) {
      sayilar[d] = (sayilar[d] ?? 0) + 1;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Yoklama')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  Text(widget.etut.s('konu'), style: serif.copyWith(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  YoklamaOzeti(sayilar: sayilar),
                  const SizedBox(height: 12),
                  TopluGeldiDugmesi(onPressed: () => setState(() => _durum.updateAll((_, _) => 'geldi'))),
                  const SizedBox(height: 12),
                  YoklamaIzgarasi(
                    cocuklar: [
                      for (final k in katilimcilar)
                        YoklamaHapi(
                          ad: k.s('ad'),
                          durum: _durum[k.n('ogrenciId')] ?? 'geldi',
                          secenekler: _secenekler,
                          alt: _yanitAd[k.s('yanit')] ?? '',
                          altRenk: switch (k.s('yanit')) {
                            'gelecek' => _yesil,
                            'gelmeyecek' => _kirmizi,
                            _ => null,
                          },
                          degisti: (v) => setState(() => _durum[k.n('ogrenciId')] = v),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: FilledButton(
                onPressed: () => Navigator.pop(context, _durum),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                child: const Text('Yoklamayı kaydet'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Yeni etüt formu; doldurulunca `/api/etut/ekle` gövdesini döndürür.
class _EtutFormu extends StatefulWidget {
  const _EtutFormu({required this.secenek});

  final Map<String, dynamic> secenek;

  @override
  State<_EtutFormu> createState() => _EtutFormuState();
}

class _EtutFormuState extends State<_EtutFormu> {
  final _konu = TextEditingController();
  final _yer = TextEditingController();
  final _not = TextEditingController();
  DateTime _tarih = DateTime.now();
  TimeOfDay _saat = const TimeOfDay(hour: 15, minute: 30);
  late int _sure = (widget.secenek['sureler'] as List?)?.map((e) => e as num).map((e) => e.toInt()).firstOrNull ?? 40;
  int? _ders;
  final _siniflar = <int>{};
  final _cikarilan = <int>{};
  String? _hata;

  List<Map<String, dynamic>> _sinifOgrencileri(int sinifId) => [
    for (final o in widget.secenek.l('ogrenciler'))
      if (o.n('sinifId') == sinifId) o,
  ];

  int _davetliSayisi(int sinifId) => _sinifOgrencileri(sinifId).where((o) => !_cikarilan.contains(o.n('id'))).length;

  /// Seçili sınıflardaki, listeden çıkarılmamış öğrencilerin kimlikleri.
  List<int> get _davetliler => {
    for (final sid in _siniflar)
      for (final o in _sinifOgrencileri(sid))
        if (!_cikarilan.contains(o.n('id'))) o.n('id'),
  }.toList();

  void _sinifDegistir(Iterable<Map<String, dynamic>> siniflar, bool ekle) => setState(() {
    for (final c in siniflar) {
      if (ekle) {
        _siniflar.add(c.n('id'));
      } else {
        _siniflar.remove(c.n('id'));
        _cikarilan.removeAll(_sinifOgrencileri(c.n('id')).map((o) => o.n('id')));
      }
    }
  });

  static int _adSirasi(Map<String, dynamic> a, Map<String, dynamic> b) {
    final x = int.tryParse(RegExp(r'^\d+').firstMatch(a.s('ad'))?.group(0) ?? '') ?? 999;
    final y = int.tryParse(RegExp(r'^\d+').firstMatch(b.s('ad'))?.group(0) ?? '') ?? 999;
    return x != y ? x.compareTo(y) : a.s('ad').compareTo(b.s('ad'));
  }

  List<Widget> _sinifGruplari(BuildContext context, List<Map<String, dynamic>> siniflar) {
    final seviyeler = <String, List<Map<String, dynamic>>>{};
    for (final c in siniflar) {
      final sv = RegExp(r'^\d+').firstMatch(c.s('ad'))?.group(0) ?? 'Diğer';
      seviyeler.putIfAbsent(sv, () => []).add(c);
    }
    final anahtarlar = seviyeler.keys.toList()..sort((a, b) => (int.tryParse(a) ?? 999).compareTo(int.tryParse(b) ?? 999));
    return [
      for (final sv in anahtarlar) ...[
        Row(
          children: [
            Expanded(
              child: Text(
                int.tryParse(sv) != null ? '$sv. sınıflar' : sv,
                style: TextStyle(color: context.soluk, fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(
              onPressed: () => _sinifDegistir(seviyeler[sv]!, !seviyeler[sv]!.every((c) => _siniflar.contains(c.n('id')))),
              child: Text(seviyeler[sv]!.every((c) => _siniflar.contains(c.n('id'))) ? 'Tümünü kaldır' : 'Tümü'),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in seviyeler[sv]!..sort(_adSirasi))
              _SinifCipi(
                ad: c.s('ad'),
                toplam: _sinifOgrencileri(c.n('id')).length,
                secili: _siniflar.contains(c.n('id')) ? _davetliSayisi(c.n('id')) : null,
                onTap: () => _sinifDegistir([c], !_siniflar.contains(c.n('id'))),
              ),
          ],
        ),
        const SizedBox(height: 6),
      ],
    ];
  }

  List<Widget> _secilenSiniflar(BuildContext context, List<Map<String, dynamic>> siniflar) => [
    for (final c in siniflar.where((c) => _siniflar.contains(c.n('id'))).toList()..sort(_adSirasi)) ...[
      Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 8),
        child: Text(
          '${c.s('ad')} · ${_davetliSayisi(c.n('id'))}/${_sinifOgrencileri(c.n('id')).length} öğrenci',
          style: TextStyle(color: context.soluk, fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
      YoklamaIzgarasi(
        cocuklar: [
          for (final o in _sinifOgrencileri(c.n('id')))
            _OgrenciCipi(
              ad: o.s('ad'),
              secili: !_cikarilan.contains(o.n('id')),
              onTap: () => setState(() => _cikarilan.contains(o.n('id')) ? _cikarilan.remove(o.n('id')) : _cikarilan.add(o.n('id'))),
            ),
        ],
      ),
    ],
  ];

  @override
  void dispose() {
    _konu.dispose();
    _yer.dispose();
    _not.dispose();
    super.dispose();
  }

  void _gonder() {
    if (_konu.text.trim().length < 2) return setState(() => _hata = 'Konuyu yazın.');
    if (_davetliler.isEmpty) return setState(() => _hata = 'En az bir sınıf seçin; listede en az bir öğrenci kalmalı.');
    Navigator.pop(context, {
      'konu': _konu.text.trim(),
      'tarih': tarihYaz(_tarih),
      'saat': '${_saat.hour.toString().padLeft(2, '0')}:${_saat.minute.toString().padLeft(2, '0')}',
      'sureDk': _sure,
      'dersId': _ders,
      'yer': _yer.text.trim(),
      'not': _not.text.trim(),
      'sinifIds': <int>[],
      'ogrenciIds': _davetliler,
    });
  }

  @override
  Widget build(BuildContext context) {
    final sureler = [
      for (final s in (widget.secenek['sureler'] as List? ?? const [40])) (s as num).toInt(),
    ];
    final dersler = widget.secenek.l('dersler');
    final siniflar = widget.secenek.l('siniflar');
    return Scaffold(
      appBar: AppBar(title: const Text('Yeni etüt')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            TextField(
              controller: _konu,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Konu'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event_outlined),
                    label: Text(_tarihEtiket(tarihYaz(_tarih))),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _tarih,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 180)),
                      );
                      if (d != null) setState(() => _tarih = d);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.schedule_outlined),
                    label: Text(_saat.format(context)),
                    onPressed: () async {
                      final s = await showTimePicker(context: context, initialTime: _saat);
                      if (s != null) setState(() => _saat = s);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: sureler.contains(_sure) ? _sure : null,
                    decoration: const InputDecoration(labelText: 'Süre'),
                    items: [for (final s in sureler) DropdownMenuItem(value: s, child: Text('$s dk'))],
                    onChanged: (s) => setState(() => _sure = s ?? _sure),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    initialValue: _ders,
                    decoration: const InputDecoration(labelText: 'Ders'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Belirtme')),
                      for (final d in dersler) DropdownMenuItem<int?>(value: d.n('id'), child: Text(d.s('ad'))),
                    ],
                    onChanged: (d) => setState(() => _ders = d),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _yer,
              decoration: const InputDecoration(labelText: 'Yer (isteğe bağlı)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _not,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Not (isteğe bağlı)'),
            ),
            const Baslik('Sınıflar'),
            ..._sinifGruplari(context, siniflar),
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 2),
              child: Text(
                _davetliler.isEmpty ? 'Henüz sınıf seçilmedi.' : 'Davet edilecek öğrenci: ${_davetliler.length}',
                style: TextStyle(color: context.soluk, fontSize: 13.5),
              ),
            ),
            ..._secilenSiniflar(context, siniflar),
            if (_hata != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _hata!,
                  style: const TextStyle(color: _kirmizi, fontWeight: FontWeight.w600),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _gonder,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: const Text('Etüt aç'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sınıf düğmesi: ad ve altında öğrenci sayısı (seçiliyse davet edilen/toplam).
class _SinifCipi extends StatelessWidget {
  const _SinifCipi({required this.ad, required this.toplam, required this.secili, required this.onTap});

  final String ad;
  final int toplam;
  final int? secili;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final acik = secili != null;
    final renk = context.ana;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 64),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: acik ? renk.withValues(alpha: secili == toplam ? .16 : .08) : context.icZemin,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: acik ? renk : context.ince, width: acik ? 1.5 : 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(ad, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            Text(acik ? '$secili/$toplam' : '$toplam', style: TextStyle(fontSize: 11.5, color: context.soluk)),
          ],
        ),
      ),
    );
  }
}

/// Seçili sınıftaki öğrenci: dokununca listeden çıkar / geri ekle.
class _OgrenciCipi extends StatelessWidget {
  const _OgrenciCipi({required this.ad, required this.secili, required this.onTap});

  final String ad;
  final bool secili;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const yesil = Color(0xFF2E9E5B);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.fromLTRB(12, 0, 5, 0),
        decoration: BoxDecoration(
          color: secili ? yesil.withValues(alpha: .12) : context.icZemin,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: secili ? yesil.withValues(alpha: .4) : context.ince),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                ad,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, height: 1.15, color: secili ? null : context.soluk, decoration: secili ? null : TextDecoration.lineThrough),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: secili ? yesil : context.soluk.withValues(alpha: .5), shape: BoxShape.circle),
              child: Text(
                secili ? '✓' : '+',
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

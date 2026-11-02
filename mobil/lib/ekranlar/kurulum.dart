import 'package:flutter/material.dart';

import '../bilesenler/ortak.dart';
import '../cekirdek/api.dart';
import '../cekirdek/tema.dart';

void _uyar(BuildContext context, String metin) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(metin)));

/// Sunucuya yazar; hata olursa uyarır. Başarıda true döner.
Future<bool> _yaz(BuildContext context, Api api, String yol, Map<String, dynamic> govde) async {
  try {
    await api.post(yol, govde);
    return true;
  } catch (e) {
    if (context.mounted) hataGoster(context, e);
    return false;
  }
}

Set<int> _idler(dynamic l) => {for (final x in (l as List? ?? const [])) (x as num).toInt()};

String _okulEtiket(Map<String, dynamic> s, List<Map<String, dynamic>> kampusler) {
  if (kampusler.length < 2) return s.s('ad');
  final k = kampusler.where((x) => x.n('id') == s.n('kampusId')).firstOrNull;
  return k == null ? s.s('ad') : '${s.s('ad')} · ${k.s('ad')}';
}

String _ogretmenAdi(String kademe) => kademe == 'Ortaokul' || kademe == 'Lise' ? 'Mentor öğretmen' : 'Sınıf öğretmeni';

/// Kurulumdaki verilerden türetilen kısayollar.
extension _Kurulum on Map<String, dynamic> {
  List<Map<String, dynamic>> aktifOgretmenler(int subeId) => [
    for (final o in l('ogretmenler'))
      if (o.s('durum') == 'aktif' && o.n('subeId') == subeId) o,
  ];

  List<Map<String, dynamic>> sinifOgretmenAdaylari(int subeId, String kademe) {
    final kisitli = (this['sinifOgretmeniKademeleri'] as List? ?? const []).contains(kademe);
    return [
      for (final o in aktifOgretmenler(subeId))
        if (!kisitli || o.n('bransId') == n('sinifOgretmenligiId')) o,
    ];
  }

  String ogretmenAd(int? uyelikId) => l('ogretmenler').where((o) => o.n('uyelikId') == uyelikId).firstOrNull?.s('ad') ?? '';
}

/// Sınıf ve kadro: dersler, öğretmenler, sınıflar (ders/öğretmen/öğrenci atamaları) ve öğrenci listesi.
class KurulumEkrani extends StatefulWidget {
  const KurulumEkrani({super.key, required this.api});

  final Api api;

  @override
  State<KurulumEkrani> createState() => _KurulumEkraniState();
}

class _KurulumEkraniState extends State<KurulumEkrani> {
  String _sekme = 'siniflar';
  String _ara = '';
  String _sinif = '';
  int _n = 0;

  Api get api => widget.api;

  Future<void> _git(Widget sayfa) async {
    await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => sayfa));
    if (mounted) setState(() => _n++);
  }

  @override
  Widget build(BuildContext context) => VeriSayfasi(
    key: ValueKey(_n),
    baslik: 'Sınıf ve kadro',
    getir: () async => await api.get('/api/yonetim/kurulum'),
    cizim: (context, raw) {
      final v = raw as Map<String, dynamic>;
      return [
        Sekmeler(
          secenekler: const [('siniflar', 'Sınıflar'), ('dersler', 'Dersler'), ('ogretmenler', 'Öğretmenler'), ('ogrenciler', 'Öğrenciler')],
          secili: _sekme,
          degisti: (d) => setState(() => _sekme = d),
        ),
        const SizedBox(height: 8),
        if (_sekme == 'siniflar') ..._siniflar(context, v),
        if (_sekme == 'dersler') ..._dersler(context, v),
        if (_sekme == 'ogretmenler') ..._ogretmenler(context, v),
        if (_sekme == 'ogrenciler') ..._ogrenciler(context, v),
      ];
    },
  );

  // ---- Sınıflar ----
  List<Widget> _siniflar(BuildContext context, Map<String, dynamic> v) {
    final subeler = v.l('subeler');
    String? grup;
    return [
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: () => _git(_SinifEkle(api: api, veri: v)),
          child: const Text('+ Sınıf aç'),
        ),
      ),
      if (v.l('siniflar').isEmpty) const BosNot('Henüz sınıf açılmadı.'),
      for (final s in v.l('siniflar')) ...[
        if ('${subeler.length > 1 ? '${s.s('sube')} · ' : ''}${s.s('kademe')}' != grup)
          Baslik(grup = '${subeler.length > 1 ? '${s.s('sube')} · ' : ''}${s.s('kademe')}', ust: 10),
        KartKutu(
          onTap: () => _git(_SinifSayfasi(api: api, id: s.n('id'))),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.s('ad'), style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
                    Text(
                      '${v.ogretmenAd(s['sinifOgretmenUyelikId'] as int?).isEmpty ? '${_ogretmenAdi(s.s('kademe'))} yok' : v.ogretmenAd(s['sinifOgretmenUyelikId'] as int?)} · ${s.n('ogrenciSayisi')} öğrenci',
                      style: TextStyle(color: context.soluk, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.soluk),
            ],
          ),
        ),
      ],
    ];
  }

  // ---- Dersler ----
  List<Widget> _dersler(BuildContext context, Map<String, dynamic> v) {
    final tumKademe = (v['kademeler'] as List? ?? const []).length;
    return [
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: () => _git(_DersFormu(api: api, kademeler: [for (final k in (v['kademeler'] as List? ?? const [])) '$k'])),
          child: const Text('+ Ders ekle'),
        ),
      ),
      if (v.l('dersler').isEmpty) const BosNot('Henüz ders açılmadı.'),
      for (final d in v.l('dersler'))
        Builder(
          builder: (context) {
            final sistem = d.s('ad') == 'Kulüp';
            final brans = d.n('id') == v.n('sinifOgretmenligiId');
            final sinif = v.l('atamalar').where((a) => a.n('dersId') == d.n('id')).length;
            final ogr = v.l('ogretmenler').where((o) => _idler(o['dersIds']).contains(d.n('id'))).length;
            final kademeler = (d['kademeler'] as List? ?? const []).map((e) => '$e').toList();
            final kademe = kademeler.length == tumKademe ? 'Tüm kademeler' : kademeler.join(' · ');
            final alt = sistem
                ? 'Sistem dersi'
                : brans
                ? 'Branş · ${v.l('ogretmenler').where((o) => o.n('bransId') == d.n('id')).length} öğretmen'
                : '$kademe · $sinif sınıf · $ogr öğretmen';
            return KartKutu(
              onTap: sistem ? null : () => _git(_DersFormu(api: api, kademeler: const [], ders: d)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.s('ad'), style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
                        Text(alt, style: TextStyle(color: context.soluk, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  if (!sistem) Icon(Icons.chevron_right, color: context.soluk),
                ],
              ),
            );
          },
        ),
    ];
  }

  // ---- Öğretmenler (salt okunur özet) ----
  List<Widget> _ogretmenler(BuildContext context, Map<String, dynamic> v) {
    final coklu = v.l('subeler').length > 1;
    String? grup;
    return [
      Text('Öğretmen ekleme ve düzenleme Kişiler sayfasındadır.', style: TextStyle(color: context.soluk, fontSize: 12.5)),
      if (v.l('ogretmenler').isEmpty) const BosNot('Henüz öğretmen kaydı yok.'),
      for (final o in v.l('ogretmenler')) ...[
        if (coklu && o.s('sube') != grup) Baslik(grup = o.s('sube').isEmpty ? 'Okulsuz' : o.s('sube'), ust: 10),
        KartKutu(
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: context.ana.withValues(alpha: .14),
                child: Text(
                  o.s('ad').isEmpty ? '?' : o.s('ad').characters.first.toUpperCase(),
                  style: TextStyle(color: context.ana, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.s('ad'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    Text(
                      '${o.s('durum') == 'aktif' ? '' : 'Pasif · '}${_idler(o['dersIds']).isEmpty ? 'Ders tanımlı değil' : v.l('dersler').where((d) => _idler(o['dersIds']).contains(d.n('id'))).map((d) => d.s('ad')).join(', ')}',
                      style: TextStyle(color: context.soluk, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ];
  }

  // ---- Öğrenciler ----
  List<Widget> _ogrenciler(BuildContext context, Map<String, dynamic> v) {
    final subeler = v.l('subeler');
    final q = _ara.trim().toLowerCase();
    if (_sinif.isNotEmpty && _sinif != 'yok' && !v.l('siniflar').any((s) => '${s.n('id')}' == _sinif)) _sinif = '';
    final liste = [
      for (final o in v.l('ogrenciler'))
        if (o.s('durum') == 'aktif' &&
            (q.isEmpty || o.s('ad').toLowerCase().contains(q) || o.s('okulNo').contains(q)) &&
            (_sinif.isEmpty || (_sinif == 'yok' ? o['sinifId'] == null : '${o['sinifId']}' == _sinif)))
          o,
    ];
    return [
      TextField(
        decoration: const InputDecoration(hintText: 'Ad ya da okul no ara…', prefixIcon: Icon(Icons.search)),
        onChanged: (x) => setState(() => _ara = x),
      ),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        initialValue: _sinif,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Sınıf'),
        items: [
          const DropdownMenuItem(value: '', child: Text('Tüm sınıflar')),
          const DropdownMenuItem(value: 'yok', child: Text('Sınıfsız')),
          for (final s in v.l('siniflar'))
            DropdownMenuItem(
              value: '${s.n('id')}',
              child: Text(subeler.length > 1 ? '${s.s('sube')} · ${s.s('ad')}' : s.s('ad'), overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (x) => setState(() => _sinif = x ?? ''),
      ),
      const SizedBox(height: 6),
      Text('${liste.length} öğrenci · sınıfını değiştirmek için dokunun', style: TextStyle(color: context.soluk, fontSize: 12.5)),
      if (liste.isEmpty) const BosNot('Gösterilecek öğrenci yok.'),
      for (final o in liste)
        KartKutu(
          onTap: () => _sinifSec(context, v, o),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.s('ad'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    Text(
                      [
                        o.s('okulNo').isEmpty ? '' : 'No ${o.s('okulNo')}',
                        v.l('siniflar').where((s) => s.n('id') == o.n('sinifId')).firstOrNull?.s('ad') ?? 'Sınıfsız',
                        for (final x in o.l('veliler').take(1)) x.s('ad'),
                      ].where((e) => e.isNotEmpty).join(' · '),
                      style: TextStyle(color: context.soluk, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Icon(Icons.swap_horiz, color: context.soluk),
            ],
          ),
        ),
    ];
  }

  Future<void> _sinifSec(BuildContext context, Map<String, dynamic> v, Map<String, dynamic> o) async {
    final secenek = [
      for (final s in v.l('siniflar'))
        if (s.n('subeId') == o.n('subeId')) s,
    ];
    final secilen = await showDialog<int>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text(o.s('ad')),
        children: [
          SimpleDialogOption(onPressed: () => Navigator.pop(c, -1), child: const Text('Sınıfsız')),
          for (final s in secenek) SimpleDialogOption(onPressed: () => Navigator.pop(c, s.n('id')), child: Text('${s.s('kademe')} · ${s.s('ad')}')),
        ],
      ),
    );
    if (secilen == null || !context.mounted) return;
    if (await _yaz(context, api, '/api/yonetim/ogrenci-sinif', {'ogrenciUyelikId': o.n('uyelikId'), 'sinifId': secilen < 0 ? null : secilen}) && mounted) {
      setState(() => _n++);
    }
  }
}

class _DersFormu extends StatefulWidget {
  const _DersFormu({required this.api, required this.kademeler, this.ders});

  final Api api;
  final List<String> kademeler;
  final Map<String, dynamic>? ders;

  @override
  State<_DersFormu> createState() => _DersFormuState();
}

class _DersFormuState extends State<_DersFormu> {
  late final _ad = TextEditingController(text: widget.ders?.s('ad') ?? '');
  late final Set<String> _secili = {
    for (final k in widget.kademeler)
      if (k != 'Anasınıfı') k,
  };
  bool _mesgul = false;

  @override
  void dispose() {
    _ad.dispose();
    super.dispose();
  }

  Future<void> _gonder(String yol, Map<String, dynamic> govde) async {
    setState(() => _mesgul = true);
    if (await _yaz(context, widget.api, yol, govde)) {
      if (mounted) Navigator.pop(context, true);
    } else if (mounted) {
      setState(() => _mesgul = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.ders;
    return Scaffold(
      appBar: AppBar(title: Text(d == null ? 'Yeni ders' : d.s('ad'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          TextField(
            controller: _ad,
            maxLength: 60,
            decoration: const InputDecoration(labelText: 'Ders adı', hintText: 'Örn. Fen Bilimleri'),
          ),
          if (d == null) ...[
            const Baslik('Hangi kademelerde okutulur?'),
            Wrap(
              spacing: 8,
              children: [
                for (final k in widget.kademeler)
                  FilterChip(label: Text(k), selected: _secili.contains(k), onSelected: (x) => setState(() => x ? _secili.add(k) : _secili.remove(k))),
              ],
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _mesgul
                ? null
                : () {
                    if (d == null && _secili.isEmpty) return _uyar(context, 'En az bir kademe seçin.');
                    _gonder(d == null ? '/api/yonetim/ders-ekle' : '/api/yonetim/ders-duzenle', {
                      if (d != null) 'id': d.n('id'),
                      'ad': _ad.text,
                      if (d == null) 'kademeler': _secili.toList(),
                    });
                  },
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: Text(d == null ? 'Dersi ekle' : 'Kaydet'),
          ),
          if (d != null)
            TextButton(
              onPressed: _mesgul
                  ? null
                  : () async {
                      if (await onayIste(context, '${d.s('ad')} dersi silinsin mi?', evet: 'Sil')) await _gonder('/api/yonetim/ders-sil', {'id': d.n('id')});
                    },
              child: Text('Dersi sil', style: TextStyle(color: Colors.red.shade600)),
            ),
        ],
      ),
    );
  }
}

class _SinifEkle extends StatefulWidget {
  const _SinifEkle({required this.api, required this.veri});

  final Api api;
  final Map<String, dynamic> veri;

  @override
  State<_SinifEkle> createState() => _SinifEkleState();
}

class _SinifEkleState extends State<_SinifEkle> {
  final _ad = TextEditingController();
  late int _sube = widget.veri.l('subeler').isEmpty ? 0 : widget.veri.l('subeler').first.n('id');
  late String _kademe = (widget.veri['kademeler'] as List? ?? const ['']).first.toString();
  int? _ogretmen;
  bool _mesgul = false;

  @override
  void dispose() {
    _ad.dispose();
    super.dispose();
  }

  Future<void> _ekle() async {
    setState(() => _mesgul = true);
    try {
      final r = await widget.api.post('/api/yonetim/sinif-ekle', {'subeId': _sube, 'kademe': _kademe, 'ad': _ad.text}) as Map<String, dynamic>;
      if (_ogretmen != null) await widget.api.post('/api/yonetim/sinif-ogretmeni', {'sinifId': r['id'], 'uyelikId': _ogretmen});
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _mesgul = false);
        hataGoster(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.veri;
    final adaylar = v.sinifOgretmenAdaylari(_sube, _kademe);
    return Scaffold(
      appBar: AppBar(title: const Text('Sınıf aç')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          DropdownButtonFormField<int>(
            initialValue: _sube == 0 ? null : _sube,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Okul'),
            items: [
              for (final s in v.l('subeler'))
                DropdownMenuItem(
                  value: s.n('id'),
                  child: Text(_okulEtiket(s, v.l('kampusler')), overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (x) => setState(() {
              _sube = x ?? _sube;
              _ogretmen = null;
            }),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _kademe,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Kademe'),
            items: [for (final k in (v['kademeler'] as List? ?? const [])) DropdownMenuItem(value: '$k', child: Text('$k'))],
            onChanged: (x) => setState(() {
              _kademe = x ?? _kademe;
              _ogretmen = null;
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ad,
            maxLength: 20,
            decoration: const InputDecoration(labelText: 'Sınıf adı', hintText: 'Örn. 6-A'),
          ),
          DropdownButtonFormField<int?>(
            initialValue: adaylar.any((o) => o.n('uyelikId') == _ogretmen) ? _ogretmen : null,
            isExpanded: true,
            decoration: InputDecoration(labelText: '${_ogretmenAdi(_kademe)} (isteğe bağlı)'),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('Sonra belirlenecek')),
              for (final o in adaylar)
                DropdownMenuItem<int?>(
                  value: o.n('uyelikId'),
                  child: Text(o.s('ad'), overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (x) => setState(() => _ogretmen = x),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _mesgul ? null : _ekle,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: Text(_mesgul ? 'Açılıyor…' : 'Sınıfı aç'),
          ),
        ],
      ),
    );
  }
}

/// Bir sınıf: sınıf öğretmeni, dersler ve ders öğretmenleri, öğrenciler.
class _SinifSayfasi extends StatefulWidget {
  const _SinifSayfasi({required this.api, required this.id});

  final Api api;
  final int id;

  @override
  State<_SinifSayfasi> createState() => _SinifSayfasiState();
}

class _SinifSayfasiState extends State<_SinifSayfasi> {
  int _n = 0;
  int? _eklenecekDers;
  int? _eklenecekOgrenci;
  final _saat = TextEditingController(text: '2');

  Api get api => widget.api;

  @override
  void dispose() {
    _saat.dispose();
    super.dispose();
  }

  Future<void> _yap(String yol, Map<String, dynamic> govde, {String? basari}) async {
    if (await _yaz(context, api, yol, govde) && mounted) {
      if (basari != null) _uyar(context, basari);
      setState(() => _n++);
    } else if (mounted) {
      setState(() => _n++);
    }
  }

  @override
  Widget build(BuildContext context) => VeriSayfasi(
    key: ValueKey(_n),
    baslik: 'Sınıf',
    getir: () async => await api.get('/api/yonetim/kurulum'),
    cizim: (context, raw) {
      final v = raw as Map<String, dynamic>;
      final s = v.l('siniflar').where((x) => x.n('id') == widget.id).firstOrNull;
      if (s == null) return const [BosNot('Sınıf bulunamadı.')];
      final ogretmenler = v.aktifOgretmenler(s.n('subeId'));
      final adaylar = v.sinifOgretmenAdaylari(s.n('subeId'), s.s('kademe'));
      final soId = s['sinifOgretmenUyelikId'] as int?;
      final atamalar = v.l('atamalar').where((a) => a.n('sinifId') == widget.id).toList();
      final ogrenciler = v.l('ogrenciler').where((o) => o.n('sinifId') == widget.id).toList();
      final eklenmemis = [
        for (final d in v.l('dersler'))
          if (d.n('id') != v.n('sinifOgretmenligiId') &&
              (d['kademeler'] as List? ?? const []).contains(s.s('kademe')) &&
              !atamalar.any((a) => a.n('dersId') == d.n('id')))
            d,
      ];
      final adayOgrenciler = v.l('ogrenciler').where((o) => o.s('durum') == 'aktif' && o['sinifId'] == null && o.n('subeId') == s.n('subeId')).toList();
      return [
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: Text('${s.s('sube')} · ${s.s('kademe')} · ${s.s('ad')}', style: serif.copyWith(fontSize: 19, fontWeight: FontWeight.w700)),
        ),
        DropdownButtonFormField<int?>(
          initialValue: adaylar.any((o) => o.n('uyelikId') == soId) ? soId : null,
          isExpanded: true,
          decoration: InputDecoration(labelText: _ogretmenAdi(s.s('kademe'))),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('Belirlenmedi')),
            for (final o in adaylar)
              DropdownMenuItem<int?>(
                value: o.n('uyelikId'),
                child: Text(o.s('ad'), overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (x) => _yap('/api/yonetim/sinif-ogretmeni', {'sinifId': widget.id, 'uyelikId': x}, basari: '${_ogretmenAdi(s.s('kademe'))} güncellendi.'),
        ),
        Baslik('Dersler (${atamalar.length})', ust: 14),
        if (atamalar.isEmpty) const BosNot('Bu sınıfa henüz ders eklenmedi.'),
        for (final a in atamalar)
          Builder(
            builder: (context) {
              final uygun = ogretmenler.where((o) => _idler(o['dersIds']).contains(a.n('dersId'))).toList();
              final secili = a['ogretmenUyelikId'] as int?;
              return KartKutu(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(a.s('ders'), style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
                        ),
                        TextButton(
                          onPressed: () async {
                            if (a.n('kullanilan') > 0 &&
                                !await onayIste(context, 'Bu dersin programdaki ${a.n('kullanilan')} saati de silinecek. Devam edilsin mi?', evet: 'Kaldır')) {
                              return;
                            }
                            await _yap('/api/yonetim/atama-sil', {'atamaId': a.n('id')}, basari: 'Ders sınıftan kaldırıldı.');
                          },
                          child: const Text('Kaldır'),
                        ),
                      ],
                    ),
                    Text(
                      'Haftada ${a.n('haftalikSaat')} saat · programda ${a.n('kullanilan')}/${a.n('haftalikSaat')}',
                      style: TextStyle(color: context.soluk, fontSize: 12.5),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int?>(
                      initialValue: uygun.any((o) => o.n('uyelikId') == secili) ? secili : null,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Öğretmen'),
                      hint: Text(uygun.isEmpty ? 'Bu dersi verebilen öğretmen yok' : 'Öğretmen seçin'),
                      items: [
                        for (final o in uygun)
                          DropdownMenuItem<int?>(
                            value: o.n('uyelikId'),
                            child: Text(o.s('ad'), overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (x) =>
                          _yap('/api/yonetim/atama-ogretmen', {'atamaId': a.n('id'), 'ogretmenUyelikId': x}, basari: 'Dersin öğretmeni güncellendi.'),
                    ),
                  ],
                ),
              );
            },
          ),
        if (eklenmemis.isNotEmpty) ...[
          const Baslik('Derse ekle', ust: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<int>(
                  initialValue: eklenmemis.any((d) => d.n('id') == _eklenecekDers) ? _eklenecekDers : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Ders'),
                  items: [
                    for (final d in eklenmemis)
                      DropdownMenuItem(
                        value: d.n('id'),
                        child: Text(d.s('ad'), overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (x) => setState(() => _eklenecekDers = x),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _saat,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Saat/hafta'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              if (_eklenecekDers == null) return _uyar(context, 'Bir ders seçin.');
              _yap('/api/yonetim/atama-ekle', {
                'sinifId': widget.id,
                'dersId': _eklenecekDers,
                'haftalikSaat': int.tryParse(_saat.text) ?? 2,
              }, basari: 'Ders sınıfa eklendi. Şimdi dersin öğretmenini seçin.');
              setState(() => _eklenecekDers = null);
            },
            child: const Text('Dersi sınıfa ekle'),
          ),
        ],
        Baslik('Öğrenciler (${ogrenciler.length})', ust: 14),
        if (ogrenciler.isEmpty) const BosNot('Bu sınıfta henüz öğrenci yok.'),
        for (final o in ogrenciler)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(o.s('ad')),
            subtitle: o.s('okulNo').isEmpty ? null : Text('No ${o.s('okulNo')}'),
            trailing: IconButton(
              tooltip: 'Sınıftan çıkar',
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => _yap('/api/yonetim/ogrenci-sinif', {'ogrenciUyelikId': o.n('uyelikId'), 'sinifId': null}, basari: 'Öğrenci sınıftan çıkarıldı.'),
            ),
          ),
        DropdownButtonFormField<int>(
          initialValue: adayOgrenciler.any((o) => o.n('uyelikId') == _eklenecekOgrenci) ? _eklenecekOgrenci : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Sınıfa öğrenci ekle'),
          hint: Text(adayOgrenciler.isEmpty ? 'Sınıfsız öğrenci yok' : 'Öğrenci seçin'),
          items: [
            for (final o in adayOgrenciler)
              DropdownMenuItem(
                value: o.n('uyelikId'),
                child: Text(o.s('ad'), overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (x) {
            if (x == null) return;
            setState(() => _eklenecekOgrenci = null);
            _yap('/api/yonetim/ogrenci-sinif', {'ogrenciUyelikId': x, 'sinifId': widget.id}, basari: 'Öğrenci sınıfa eklendi.');
          },
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () async {
            if (!await onayIste(context, '${s.s('ad')} sınıfı silinsin mi? Derslerin programdaki yerleşimi de silinir.', evet: 'Sil')) return;
            if (!context.mounted) return;
            if (await _yaz(context, api, '/api/yonetim/sinif-sil', {'sinifId': widget.id}) && context.mounted) Navigator.pop(context, true);
          },
          child: Text('Sınıfı sil', style: TextStyle(color: Colors.red.shade600)),
        ),
      ];
    },
  );
}

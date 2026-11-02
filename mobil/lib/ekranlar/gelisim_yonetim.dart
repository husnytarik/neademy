import 'package:flutter/material.dart';

import '../bilesenler/ortak.dart';
import '../cekirdek/api.dart';
import '../cekirdek/takvim_model.dart';
import '../cekirdek/tema.dart';
import 'gelisim_ogretmen.dart' show GorusmeFormu;

void _bildir(BuildContext context, String metin) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(metin)));

String _aralik(Map<String, dynamic> d) => '${kisaTarih(d.s('baslangic'))} – ${uzunTarih(d.s('bitis'))}';

(String, Color) _durum(String durum) => switch (durum) {
  'acik' => ('Açık', Colors.green.shade700),
  'yaklasan' => ('Yaklaşan', Colors.blueGrey),
  _ => ('Kapandı', Colors.grey),
};

/// Gelişim yönetimi (yönetim): öğrenci raporu, gözlem dönemleri ve başlıklar.
class GelisimYonetimEkrani extends StatefulWidget {
  const GelisimYonetimEkrani({super.key, required this.api});

  final Api api;

  @override
  State<GelisimYonetimEkrani> createState() => _GelisimYonetimEkraniState();
}

class _GelisimYonetimEkraniState extends State<GelisimYonetimEkrani> {
  int _n = 0;
  String _sekme = 'rapor';

  void _yenile() => setState(() => _n++);

  @override
  Widget build(BuildContext context) => VeriSayfasi(
    key: ValueKey(_n),
    baslik: 'Gelişim raporu',
    getir: () async => await widget.api.get('/api/gelisim/ayar'),
    cizim: (context, raw) {
      final v = raw as Map<String, dynamic>;
      return [
        Sekmeler(
          secenekler: const [('rapor', 'Rapor'), ('donemler', 'Dönemler'), ('basliklar', 'Başlıklar')],
          secili: _sekme,
          degisti: (x) => setState(() => _sekme = x),
        ),
        const SizedBox(height: 14),
        if (_sekme == 'rapor') _RaporSecimi(api: widget.api),
        if (_sekme == 'donemler') ..._donemler(context, v),
        if (_sekme == 'basliklar') ..._basliklar(context, v),
      ];
    },
  );

  Future<void> _ac(Widget sayfa) async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => sayfa));
    if (ok == true) _yenile();
  }

  List<Widget> _donemler(BuildContext context, Map<String, dynamic> v) {
    final liste = v.l('donemler');
    return [
      Text('Öğretmenler yalnızca dönem açıkken giriş yapar.', style: TextStyle(color: context.soluk, fontSize: 13)),
      const SizedBox(height: 8),
      EkleDugmesi(
        '+ Yeni dönem',
        onPressed: () => _ac(_DonemFormu(api: widget.api, bugun: v.s('bugun'))),
      ),
      const SizedBox(height: 10),
      if (liste.isEmpty) const BosNot('Henüz dönem yok. “Yeni dönem” ile ilkini açın.'),
      for (final d in liste)
        KartKutu(
          onTap: () => _ac(_DonemSayfasi(api: widget.api, donem: d, bugun: v.s('bugun'))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(d.s('ad'), style: serif.copyWith(fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                  Cip(_durum(d.s('durum')).$1, renk: _durum(d.s('durum')).$2),
                ],
              ),
              const SizedBox(height: 4),
              Text(_aralik(d), style: TextStyle(color: context.soluk, fontSize: 13)),
              if (d.s('toplantiTarihi').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Veli toplantısı: ${uzunTarih(d.s('toplantiTarihi'))}', style: const TextStyle(fontSize: 13)),
                ),
            ],
          ),
        ),
    ];
  }

  Future<void> _tasi(Map<String, dynamic> b, String yon) async {
    try {
      await widget.api.post('/api/gelisim/baslik-sira', {'id': b.n('id'), 'yon': yon});
      if (mounted) _yenile();
    } catch (e) {
      if (mounted) hataGoster(context, e);
    }
  }

  List<Widget> _basliklar(BuildContext context, Map<String, dynamic> v) {
    final liste = v.l('basliklar');
    return [
      Text(
        '${liste.where((b) => b['aktif'] == true).length} aktif başlık · sıra raporda da bu şekildedir',
        style: TextStyle(color: context.soluk, fontSize: 13),
      ),
      const SizedBox(height: 8),
      EkleDugmesi('+ Yeni başlık', onPressed: () => _ac(_BaslikFormu(api: widget.api))),
      const SizedBox(height: 10),
      if (liste.isEmpty) const BosNot('Henüz başlık yok. Örn. Akademik süreç, Dikkat ve ders içi davranış…'),
      for (final (i, b) in liste.indexed)
        KartKutu(
          onTap: () => _ac(_BaslikFormu(api: widget.api, baslik: b)),
          child: Opacity(
            opacity: b['aktif'] == true ? 1 : .55,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.s('ad'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      if (b.s('aciklama').isNotEmpty || b['aktif'] != true)
                        Text(b.s('aciklama').isNotEmpty ? b.s('aciklama') : 'Pasif', style: TextStyle(color: context.soluk, fontSize: 12.5)),
                    ],
                  ),
                ),
                IconButton(tooltip: 'Yukarı taşı', icon: const Icon(Icons.arrow_upward, size: 20), onPressed: i == 0 ? null : () => _tasi(b, 'yukari')),
                IconButton(
                  tooltip: 'Aşağı taşı',
                  icon: const Icon(Icons.arrow_downward, size: 20),
                  onPressed: i == liste.length - 1 ? null : () => _tasi(b, 'asagi'),
                ),
              ],
            ),
          ),
        ),
    ];
  }
}

/// Rapor: sınıf ve öğrenci seçilir, tüm öğretmenlerin girişleri tek raporda toplanır.
class _RaporSecimi extends StatefulWidget {
  const _RaporSecimi({required this.api});

  final Api api;

  @override
  State<_RaporSecimi> createState() => _RaporSecimiState();
}

class _RaporSecimiState extends State<_RaporSecimi> {
  late final Future<dynamic> _gelen = widget.api.get('/api/gelisim/siniflar');
  int? _sinif;
  int? _ogrenci;

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: _gelen,
    builder: (context, s) {
      if (s.hasError) return BosNot(s.error is ApiHata ? (s.error as ApiHata).mesaj : 'Sınıflar alınamadı.');
      if (!s.hasData) {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      final siniflar = (s.data as Map<String, dynamic>).l('siniflar');
      final secili = siniflar.where((x) => x.n('id') == _sinif).firstOrNull;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sınıf ve öğrenciyi seçin; tüm öğretmenlerin girdiği veriler tek raporda toplanır.', style: TextStyle(color: context.soluk, fontSize: 13)),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            initialValue: _sinif,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Sınıf'),
            items: [for (final x in siniflar) DropdownMenuItem(value: x.n('id'), child: Text(x.s('ad')))],
            onChanged: (x) => setState(() {
              _sinif = x;
              _ogrenci = null;
            }),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            key: ValueKey(_sinif),
            initialValue: _ogrenci,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Öğrenci'),
            items: [
              for (final o in secili?.l('ogrenciler') ?? const <Map<String, dynamic>>[])
                DropdownMenuItem(
                  value: o.n('id'),
                  child: Text(o.s('ad') + (o.s('okulNo').isEmpty ? '' : ' · ${o.s('okulNo')}'), overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: secili == null ? null : (x) => setState(() => _ogrenci = x),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _ogrenci == null
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _OgrenciRaporu(api: widget.api, ogrenciId: _ogrenci!),
                    ),
                  ),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: const Text('Raporu aç'),
          ),
        ],
      );
    },
  );
}

class _OgrenciRaporu extends StatefulWidget {
  const _OgrenciRaporu({required this.api, required this.ogrenciId});

  final Api api;
  final int ogrenciId;

  @override
  State<_OgrenciRaporu> createState() => _OgrenciRaporuState();
}

class _OgrenciRaporuState extends State<_OgrenciRaporu> {
  int _n = 0;

  Future<void> _gorusme(Map<String, dynamic> v, {Map<String, dynamic>? mevcut, String tur = 'gorusme'}) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => GorusmeFormu(api: widget.api, ogrenciId: widget.ogrenciId, donemler: v.l('donemler'), bugun: v.s('bugun'), mevcut: mevcut, tur: tur),
      ),
    );
    if (ok == true && mounted) setState(() => _n++);
  }

  Future<void> _sil(Map<String, dynamic> g) async {
    if (!await onayIste(context, 'Bu not silinsin mi?', evet: 'Sil')) return;
    try {
      await widget.api.post('/api/gelisim/gorusme-sil', {'id': g.n('id')});
      if (mounted) setState(() => _n++);
    } catch (e) {
      if (mounted) hataGoster(context, e);
    }
  }

  Widget _gorusmeSatiri(BuildContext context, Map<String, dynamic> v, Map<String, dynamic> g) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Cip(g.s('tur') == 'toplanti' ? 'Veli toplantısı' : 'Veli görüşmesi', renk: context.ana),
            const SizedBox(width: 8),
            Expanded(
              child: Text(uzunTarih(g.s('tarih')), style: TextStyle(color: context.soluk, fontSize: 12.5)),
            ),
            if (g['duzenlenebilir'] == true) ...[
              IconButton(
                tooltip: 'Düzenle',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.edit_outlined, size: 19, color: context.soluk),
                onPressed: () => _gorusme(v, mevcut: g),
              ),
              IconButton(
                tooltip: 'Sil',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.delete_outline, size: 19, color: context.soluk),
                onPressed: () => _sil(g),
              ),
            ],
          ],
        ),
        Text(g.s('notu'), style: const TextStyle(height: 1.35)),
        if (g.s('yazan').isNotEmpty) Text(g.s('yazan'), style: TextStyle(color: context.soluk, fontSize: 12)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => VeriSayfasi(
    key: ValueKey(_n),
    baslik: 'Gelişim raporu',
    getir: () async => await widget.api.get('/api/gelisim/rapor?ogrenciId=${widget.ogrenciId}'),
    cizim: (context, raw) {
      final v = raw as Map<String, dynamic>;
      final o = v.m('ogrenci');
      final basliklar = v.l('basliklar');
      final donemler = v.l('donemler').reversed.toList();
      final diger = v.l('donemsizGorusmeler');
      return [
        Text(o.s('ad'), style: serif.copyWith(fontSize: 21, fontWeight: FontWeight.w700)),
        Text(
          [o.s('sinif'), if (o.s('okulNo').isNotEmpty) 'No ${o.s('okulNo')}'].where((x) => x.isNotEmpty).join(' · '),
          style: TextStyle(color: context.soluk),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _gorusme(v, tur: 'toplanti'),
                child: const Text('+ Veli toplantısı'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(onPressed: () => _gorusme(v), child: const Text('+ Veli görüşmesi')),
            ),
          ],
        ),
        if (donemler.isEmpty) const BosNot('Henüz dönem yok.'),
        for (final d in donemler)
          KartKutu(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(d.s('ad'), style: serif.copyWith(fontSize: 17, fontWeight: FontWeight.w700)),
                    ),
                    Cip(_durum(d.s('durum')).$1, renk: _durum(d.s('durum')).$2),
                  ],
                ),
                Text(_aralik(d), style: TextStyle(color: context.soluk, fontSize: 12.5)),
                if (d.l('girisler').isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Bu dönem için öğretmen girişi yok.', style: TextStyle(color: context.soluk)),
                  ),
                for (final b in basliklar)
                  if (d.l('girisler').any((g) => g.n('baslikId') == b.n('id'))) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(b.s('ad'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                    ),
                    for (final g in d.l('girisler').where((g) => g.n('baslikId') == b.n('id')))
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              g.s('ders').isEmpty ? g.s('ogretmen') : '${g.s('ogretmen')} · ${g.s('ders')}',
                              style: TextStyle(color: context.soluk, fontSize: 12),
                            ),
                            Text(g.s('metin'), style: const TextStyle(height: 1.35)),
                          ],
                        ),
                      ),
                  ],
                for (final g in d.l('gorusmeler')) _gorusmeSatiri(context, v, g),
              ],
            ),
          ),
        if (diger.isNotEmpty) ...[
          const Baslik('Diğer görüşmeler'),
          KartKutu(child: Column(children: [for (final g in diger) _gorusmeSatiri(context, v, g)])),
        ],
      ];
    },
  );
}

/// Dönem ayrıntısı: bilgiler ve öğretmen giriş takibi.
class _DonemSayfasi extends StatefulWidget {
  const _DonemSayfasi({required this.api, required this.donem, required this.bugun});

  final Api api;
  final Map<String, dynamic> donem;
  final String bugun;

  @override
  State<_DonemSayfasi> createState() => _DonemSayfasiState();
}

class _DonemSayfasiState extends State<_DonemSayfasi> {
  Future<void> _yenidenAc() async {
    final d = widget.donem;
    if (!await onayIste(context, '${d.s('ad')} 7 gün için yeniden açılsın mı? Öğretmenler yorumlarını güncelleyebilir.', evet: 'Aç')) return;
    final bitis = tarihYaz(tarihCoz(widget.bugun).add(const Duration(days: 7)));
    try {
      await widget.api.post('/api/gelisim/donem-kaydet', {
        'id': d.n('id'),
        'ad': d.s('ad'),
        'baslangic': d.s('baslangic'),
        'bitis': bitis,
        'toplantiTarihi': d.s('toplantiTarihi'),
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) hataGoster(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.donem;
    return VeriSayfasi(
      baslik: d.s('ad'),
      getir: () async => await widget.api.get('/api/gelisim/takip?donemId=${d.n('id')}'),
      cizim: (context, raw) {
        final v = raw as Map<String, dynamic>;
        final ogretmenler = v.l('ogretmenler');
        final tamam = ogretmenler.where((t) => t.n('tamam') == t.n('ogrenciSayisi')).length;
        return [
          KartKutu(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Dönem', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    Cip(_durum(d.s('durum')).$1, renk: _durum(d.s('durum')).$2),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Giriş tarihleri: ${_aralik(d)}'),
                Text('Veli toplantısı: ${d.s('toplantiTarihi').isEmpty ? 'Belirlenmedi' : uzunTarih(d.s('toplantiTarihi'))}'),
                Text('Başlık sayısı: ${v.n('baslikSayisi')}'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final ok = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => _DonemFormu(api: widget.api, bugun: widget.bugun, donem: d),
                      ),
                    );
                    if (ok == true && context.mounted) Navigator.of(context).pop(true);
                  },
                  child: const Text('Düzenle'),
                ),
              ),
              if (d.s('durum') == 'kapandi') ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(onPressed: _yenidenAc, child: const Text('Yeniden aç (7 gün)')),
                ),
              ],
            ],
          ),
          Baslik('Öğretmen girişleri · $tamam/${ogretmenler.length} tamam', ust: 16),
          if (ogretmenler.isEmpty) const BosNot('Öğrencisi olan öğretmen yok.'),
          for (final t in ogretmenler)
            KartKutu(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.s('ad'), style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (t.s('dersler').isNotEmpty) Text(t.s('dersler'), style: TextStyle(color: context.soluk, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  Cip(
                    '${t.n('tamam')}/${t.n('ogrenciSayisi')} öğrenci',
                    renk: t.n('tamam') == t.n('ogrenciSayisi') ? Colors.green.shade700 : (t.n('tamam') > 0 || t.n('kismi') > 0 ? context.ana : null),
                  ),
                ],
              ),
            ),
        ];
      },
    );
  }
}

/// Dönem ekleme / düzenleme.
class _DonemFormu extends StatefulWidget {
  const _DonemFormu({required this.api, required this.bugun, this.donem});

  final Api api;
  final String bugun;
  final Map<String, dynamic>? donem;

  @override
  State<_DonemFormu> createState() => _DonemFormuState();
}

class _DonemFormuState extends State<_DonemFormu> {
  late final _ad = TextEditingController(text: widget.donem?.s('ad'));
  late String _bas = widget.donem?.s('baslangic') ?? widget.bugun;
  late String _bit = widget.donem?.s('bitis') ?? tarihYaz(tarihCoz(widget.bugun).add(const Duration(days: 14)));
  late String _top = widget.donem?.s('toplantiTarihi') ?? '';
  bool _mesgul = false;

  @override
  void dispose() {
    _ad.dispose();
    super.dispose();
  }

  Future<String?> _sec(String mevcut) async {
    final t = await showDatePicker(
      context: context,
      initialDate: mevcut.isEmpty ? tarihCoz(widget.bugun) : tarihCoz(mevcut),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    return t == null ? null : tarihYaz(t);
  }

  Future<void> _kaydet() async {
    if (_ad.text.trim().length < 2) return _bildir(context, 'Dönem adı en az 2 karakter olmalı.');
    setState(() => _mesgul = true);
    try {
      await widget.api.post('/api/gelisim/donem-kaydet', {
        if (widget.donem != null) 'id': widget.donem!.n('id'),
        'ad': _ad.text.trim(),
        'baslangic': _bas,
        'bitis': _bit,
        'toplantiTarihi': _top,
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _mesgul = false);
      hataGoster(context, e);
    }
  }

  Future<void> _sil() async {
    if (!await onayIste(context, '${widget.donem!.s('ad')} silinsin mi?', evet: 'Sil')) return;
    try {
      await widget.api.post('/api/gelisim/donem-sil', {'id': widget.donem!.n('id')});
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) hataGoster(context, e);
    }
  }

  Widget _tarih(String ad, String deger, ValueChanged<String> yaz, {bool bosOlur = false}) => OutlinedButton(
    onPressed: () async {
      final s = await _sec(deger);
      if (s != null) setState(() => yaz(s));
    },
    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), alignment: Alignment.centerLeft),
    child: Text(deger.isEmpty && bosOlur ? '$ad: seçilmedi' : '$ad: ${uzunTarih(deger)}'),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.donem == null ? 'Yeni dönem' : widget.donem!.s('ad'))),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _ad,
          maxLength: 60,
          decoration: const InputDecoration(labelText: 'Dönem adı', hintText: 'Örn. Kasım gözlemi'),
        ),
        const SizedBox(height: 8),
        _tarih('Giriş başlangıcı', _bas, (x) => _bas = x),
        const SizedBox(height: 10),
        _tarih('Giriş bitişi', _bit, (x) => _bit = x),
        const SizedBox(height: 10),
        _tarih('Veli toplantısı', _top, (x) => _top = x, bosOlur: true),
        if (_top.isNotEmpty) TextButton(onPressed: () => setState(() => _top = ''), child: const Text('Toplantı tarihini kaldır')),
        const SizedBox(height: 8),
        Text(
          'Öğretmenler yorumlarını başlangıç ve bitiş tarihleri arasında girebilir; bitince dönem yalnızca okunur olur.',
          style: TextStyle(color: context.soluk, fontSize: 12.5),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _mesgul ? null : _kaydet,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          child: Text(_mesgul ? 'Kaydediliyor…' : (widget.donem == null ? 'Dönemi aç' : 'Değişiklikleri kaydet')),
        ),
        if (widget.donem != null)
          TextButton(
            onPressed: _sil,
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade600),
            child: const Text('Dönemi sil'),
          ),
      ],
    ),
  );
}

/// Başlık ekleme / düzenleme.
class _BaslikFormu extends StatefulWidget {
  const _BaslikFormu({required this.api, this.baslik});

  final Api api;
  final Map<String, dynamic>? baslik;

  @override
  State<_BaslikFormu> createState() => _BaslikFormuState();
}

class _BaslikFormuState extends State<_BaslikFormu> {
  late final _ad = TextEditingController(text: widget.baslik?.s('ad'));
  late final _aciklama = TextEditingController(text: widget.baslik?.s('aciklama'));
  late bool _aktif = widget.baslik == null ? true : widget.baslik!['aktif'] == true;
  bool _mesgul = false;

  @override
  void dispose() {
    _ad.dispose();
    _aciklama.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    if (_ad.text.trim().length < 2) return _bildir(context, 'Başlık adı en az 2 karakter olmalı.');
    setState(() => _mesgul = true);
    try {
      await widget.api.post('/api/gelisim/baslik-kaydet', {
        if (widget.baslik != null) 'id': widget.baslik!.n('id'),
        'ad': _ad.text.trim(),
        'aciklama': _aciklama.text.trim(),
        'aktif': _aktif,
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _mesgul = false);
      hataGoster(context, e);
    }
  }

  Future<void> _sil() async {
    if (!await onayIste(context, '${widget.baslik!.s('ad')} silinsin mi?', evet: 'Sil')) return;
    try {
      await widget.api.post('/api/gelisim/baslik-sil', {'id': widget.baslik!.n('id')});
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) hataGoster(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.baslik;
    return Scaffold(
      appBar: AppBar(title: Text(b == null ? 'Yeni başlık' : b.s('ad'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _ad,
            maxLength: 60,
            decoration: const InputDecoration(labelText: 'Başlık adı', hintText: 'Örn. Sorumluluk ve öz düzenleme'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _aciklama,
            maxLength: 200,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Öğretmenlere açıklama (isteğe bağlı)'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Aktif (öğretmenlere gösterilir)'),
            value: _aktif,
            onChanged: (x) => setState(() => _aktif = x),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _mesgul ? null : _kaydet,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: Text(_mesgul ? 'Kaydediliyor…' : (b == null ? 'Başlığı ekle' : 'Değişiklikleri kaydet')),
          ),
          if (b != null) ...[
            TextButton(
              onPressed: _sil,
              style: TextButton.styleFrom(foregroundColor: Colors.red.shade600),
              child: const Text('Başlığı sil'),
            ),
            if (b.n('girisSayisi') > 0)
              Text(
                'Bu başlığa ${b.n('girisSayisi')} yorum girilmiş; silinemez, “Aktif” işaretini kaldırarak gizleyebilirsiniz.',
                style: TextStyle(color: context.soluk, fontSize: 12.5),
              ),
          ],
        ],
      ),
    );
  }
}

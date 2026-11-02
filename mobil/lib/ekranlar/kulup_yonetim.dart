import 'package:flutter/material.dart';

import '../bilesenler/ortak.dart';
import '../cekirdek/api.dart';
import '../cekirdek/tema.dart';

void _bildir(BuildContext context, String metin) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(metin)));

List<String> _metinler(Object? l) => [for (final x in (l as List? ?? const [])) '$x'];

/// Kulüp yönetimi (yönetim): kulüpler, tercih talepleri ve kulüp saatleri.
class KulupYonetimEkrani extends StatefulWidget {
  const KulupYonetimEkrani({super.key, required this.api});

  final Api api;

  @override
  State<KulupYonetimEkrani> createState() => _KulupYonetimEkraniState();
}

class _KulupYonetimEkraniState extends State<KulupYonetimEkrani> {
  int _n = 0;
  String _sekme = 'kulupler';

  void _yenile() => setState(() => _n++);

  @override
  Widget build(BuildContext context) => VeriSayfasi(
    key: ValueKey(_n),
    baslik: 'Kulüpler',
    getir: () async => await widget.api.get('/api/kulup/yonetim'),
    cizim: (context, raw) {
      final v = raw as Map<String, dynamic>;
      return [
        Sekmeler(
          secenekler: const [('kulupler', 'Kulüpler'), ('talepler', 'Talepler'), ('saatler', 'Kulüp saatleri')],
          secili: _sekme,
          degisti: (x) => setState(() => _sekme = x),
        ),
        const SizedBox(height: 14),
        if (_sekme == 'kulupler') ..._kulupler(context, v),
        if (_sekme == 'talepler') _TalepSekmesi(api: widget.api, degisti: _yenile),
        if (_sekme == 'saatler') _SaatSekmesi(api: widget.api, veri: v, degisti: _yenile),
      ];
    },
  );

  List<Widget> _kulupler(BuildContext context, Map<String, dynamic> v) {
    final liste = v.l('kulupler');
    return [
      EkleDugmesi(
        '+ Kulüp ekle',
        onPressed: () async {
          final ok = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => _KulupFormu(api: widget.api, veri: v),
            ),
          );
          if (ok == true) _yenile();
        },
      ),
      const SizedBox(height: 10),
      if (liste.isEmpty) const BosNot('Henüz kulüp yok.'),
      for (final k in liste)
        KartKutu(
          onTap: () async {
            final ok = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => _KulupSayfasi(api: widget.api, veri: v, kulup: k),
              ),
            );
            if (ok == true) _yenile();
          },
          child: Opacity(
            opacity: k['aktif'] == true ? 1 : .55,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(k.s('ad'), style: serif.copyWith(fontSize: 17, fontWeight: FontWeight.w700)),
                    ),
                    if (k['aktif'] != true) const Cip('Pasif'),
                  ],
                ),
                if (k.s('tema').isNotEmpty) Text(k.s('tema'), style: TextStyle(color: context.soluk, fontSize: 13)),
                const SizedBox(height: 6),
                Text('${k.s('gunAd')} · ${k.s('aralik')} · ${_metinler(k['seviyeler']).join(', ')}', style: const TextStyle(fontSize: 13.5)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 10,
                  children: [
                    Text('${k.n('uyeSayisi')}/${k.n('kontenjan')} üye', style: TextStyle(color: context.soluk, fontSize: 13)),
                    if (k.n('bekleyen') > 0)
                      Text(
                        '${k.n('bekleyen')} bekleyen talep',
                        style: TextStyle(color: context.ana, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
    ];
  }
}

/// Kulüp ayrıntısı: bilgiler, üyeler, pasife alma, silme.
class _KulupSayfasi extends StatefulWidget {
  const _KulupSayfasi({required this.api, required this.veri, required this.kulup});

  final Api api;
  final Map<String, dynamic> veri;
  final Map<String, dynamic> kulup;

  @override
  State<_KulupSayfasi> createState() => _KulupSayfasiState();
}

class _KulupSayfasiState extends State<_KulupSayfasi> {
  int _n = 0;
  bool _degisti = false;

  Future<void> _islem(Future<void> Function() is_, {bool kapat = false}) async {
    try {
      await is_();
      if (!mounted) return;
      _degisti = true;
      if (kapat) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _n++);
      }
    } catch (e) {
      if (!mounted) return;
      hataGoster(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.kulup;
    final aktif = k['aktif'] == true;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (geri, _) {
        if (!geri) Navigator.of(context).pop(_degisti);
      },
      child: VeriSayfasi(
        key: ValueKey(_n),
        baslik: k.s('ad'),
        getir: () async => await widget.api.get('/api/kulup/uyeler?kulupId=${k.n('id')}'),
        cizim: (context, raw) {
          final uyeler = (raw as Map<String, dynamic>).l('uyeler');
          return [
            if (k.s('tema').isNotEmpty) Text(k.s('tema'), style: TextStyle(color: context.soluk)),
            const SizedBox(height: 8),
            KartKutu(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Satir('Zaman', '${k.s('gunAd')} · ${k.n('dersSaati')}. ders (${k.s('aralik')})'),
                  _Satir('Sınıflar', _metinler(k['seviyeler']).join(', ')),
                  _Satir('Öğretmenler', [for (final o in k.l('ogretmenler')) o.s('ad')].join(', ')),
                  _Satir('Kontenjan', '${uyeler.length}/${k.n('kontenjan')}'),
                  if (k.s('aciklama').isNotEmpty) _Satir('Tanıtım', k.s('aciklama')),
                ],
              ),
            ),
            Baslik('Üyeler (${uyeler.length})', ust: 14),
            if (uyeler.isEmpty) const BosNot('Henüz üye yok.'),
            for (final u in uyeler)
              KartKutu(
                child: Row(
                  children: [
                    Expanded(child: Text('${u.s('ad')} · ${u.s('sinif')}', style: const TextStyle(fontSize: 14.5))),
                    TextButton(
                      onPressed: () async {
                        if (!await onayIste(context, '${u.s('ad')} kulüpten çıkarılsın mı?', evet: 'Çıkar')) return;
                        await _islem(() async => await widget.api.post('/api/kulup/cikar', {'ogrenciId': u.n('uyelikId')}));
                      },
                      child: const Text('Çıkar'),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: () async {
                final ok = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => _KulupFormu(api: widget.api, veri: widget.veri, kulup: k),
                  ),
                );
                if (ok == true && context.mounted) Navigator.of(context).pop(true);
              },
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
              child: const Text('Düzenle'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _islem(() async {
                await widget.api.post('/api/kulup/durum', {'id': k.n('id'), 'aktif': !aktif});
              }, kapat: true),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
              child: Text(aktif ? 'Pasife al' : 'Aktif et'),
            ),
            TextButton(
              onPressed: () async {
                if (!await onayIste(context, '${k.s('ad')} kulübü silinsin mi?', evet: 'Sil')) return;
                await _islem(() async => await widget.api.post('/api/kulup/sil', {'id': k.n('id')}), kapat: true);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red.shade600),
              child: const Text('Kulübü sil'),
            ),
          ];
        },
      ),
    );
  }
}

class _Satir extends StatelessWidget {
  const _Satir(this.ad, this.deger);

  final String ad;
  final String deger;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(ad, style: TextStyle(fontSize: 12, color: context.soluk)),
        Text(deger.isEmpty ? '—' : deger, style: const TextStyle(fontSize: 14.5)),
      ],
    ),
  );
}

/// Kulüp ekleme / düzenleme formu.
class _KulupFormu extends StatefulWidget {
  const _KulupFormu({required this.api, required this.veri, this.kulup});

  final Api api;
  final Map<String, dynamic> veri;
  final Map<String, dynamic>? kulup;

  @override
  State<_KulupFormu> createState() => _KulupFormuState();
}

class _KulupFormuState extends State<_KulupFormu> {
  late final _ad = TextEditingController(text: widget.kulup?.s('ad'));
  late final _tema = TextEditingController(text: widget.kulup?.s('tema'));
  late final _aciklama = TextEditingController(text: widget.kulup?.s('aciklama'));
  late final _kontenjan = TextEditingController(text: widget.kulup == null ? '20' : '${widget.kulup!.n('kontenjan')}');
  late int? _gun = widget.kulup?.n('gun');
  late int? _saat = widget.kulup?.n('dersSaati');
  late final Set<String> _duzeyler = {..._metinler(widget.kulup?['seviyeler'])};
  late final Set<int> _ogretmenler = {for (final o in (widget.kulup?.l('ogretmenler') ?? const <Map<String, dynamic>>[])) o.n('uyelikId')};
  bool _mesgul = false;

  @override
  void dispose() {
    _ad.dispose();
    _tema.dispose();
    _aciklama.dispose();
    _kontenjan.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    if (_ad.text.trim().length < 2) return _bildir(context, 'Kulüp adı en az 2 karakter olmalı.');
    final kont = int.tryParse(_kontenjan.text.trim()) ?? 0;
    if (kont < 1 || kont > 300) return _bildir(context, 'Kontenjan 1-300 arası olmalı.');
    if (_gun == null || _saat == null) return _bildir(context, 'Kulüp günü ve ders saatini seçin.');
    if (_duzeyler.isEmpty) return _bildir(context, 'En az bir sınıf düzeyi seçin.');
    if (_ogretmenler.isEmpty) return _bildir(context, 'En az bir kulüp öğretmeni seçin.');
    setState(() => _mesgul = true);
    try {
      await widget.api.post('/api/kulup/kaydet', {
        if (widget.kulup != null) 'id': widget.kulup!.n('id'),
        'ad': _ad.text.trim(),
        'tema': _tema.text.trim(),
        'aciklama': _aciklama.text.trim(),
        'kontenjan': kont,
        'gun': _gun,
        'dersSaati': _saat,
        'seviyeler': _duzeyler.toList(),
        'ogretmenler': _ogretmenler.toList(),
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _mesgul = false);
      hataGoster(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.veri;
    final zamanlar = _metinler(v['zamanlar']);
    final duzeyler = _metinler(v['duzeyler']);
    return Scaffold(
      appBar: AppBar(title: Text(widget.kulup == null ? 'Yeni kulüp' : 'Kulübü düzenle')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _ad,
            decoration: const InputDecoration(labelText: 'Kulüp adı'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tema,
            decoration: const InputDecoration(labelText: 'Tema (isteğe bağlı)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _aciklama,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(labelText: 'Tanıtım'),
          ),
          TextField(
            controller: _kontenjan,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Kontenjan'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _gun,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Gün'),
            items: [for (final g in v.l('gunler')) DropdownMenuItem(value: g.n('gun'), child: Text(g.s('ad')))],
            onChanged: (x) => setState(() => _gun = x),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _saat,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Ders saati'),
            items: [for (final (i, z) in zamanlar.indexed) DropdownMenuItem(value: i + 1, child: Text('${i + 1}. ders · $z'))],
            onChanged: (x) => setState(() => _saat = x),
          ),
          const Baslik('Sınıf düzeyleri', ust: 16),
          Wrap(
            spacing: 8,
            children: [
              for (final d in duzeyler)
                FilterChip(label: Text(d), selected: _duzeyler.contains(d), onSelected: (s) => setState(() => s ? _duzeyler.add(d) : _duzeyler.remove(d))),
            ],
          ),
          const Baslik('Kulüp öğretmenleri', ust: 16),
          Wrap(
            spacing: 8,
            children: [
              for (final o in v.l('ogretmenler'))
                FilterChip(
                  label: Text(o.s('ad')),
                  selected: _ogretmenler.contains(o.n('uyelikId')),
                  onSelected: (s) => setState(() => s ? _ogretmenler.add(o.n('uyelikId')) : _ogretmenler.remove(o.n('uyelikId'))),
                ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _mesgul ? null : _kaydet,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: Text(_mesgul ? 'Kaydediliyor…' : 'Kaydet'),
          ),
        ],
      ),
    );
  }
}

/// Öğrenci tercihleri: yerleştir, reddet, kulüpten çıkar.
class _TalepSekmesi extends StatefulWidget {
  const _TalepSekmesi({required this.api, required this.degisti});

  final Api api;
  final VoidCallback degisti;

  @override
  State<_TalepSekmesi> createState() => _TalepSekmesiState();
}

class _TalepSekmesiState extends State<_TalepSekmesi> {
  late Future<dynamic> _gelen = widget.api.get('/api/kulup/talepler');

  void _yenile() => setState(() => _gelen = widget.api.get('/api/kulup/talepler'));

  Future<void> _yap(String yol, Map<String, dynamic> govde) async {
    try {
      await widget.api.post(yol, govde);
      if (!mounted) return;
      _yenile();
      widget.degisti();
    } catch (e) {
      if (!mounted) return;
      hataGoster(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: _gelen,
    builder: (context, s) {
      if (s.hasError) return BosNot(s.error is ApiHata ? (s.error as ApiHata).mesaj : 'Talepler alınamadı.');
      if (!s.hasData) {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      final liste = (s.data as Map<String, dynamic>).l('ogrenciler');
      if (liste.isEmpty) return const BosNot('Henüz kulüp talebi yok.');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final o in liste)
            KartKutu(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(o.s('ad'), style: serif.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
                  Text(
                    [o.s('sinif'), if (o.s('okulNo').isNotEmpty) 'No ${o.s('okulNo')}'].where((x) => x.isNotEmpty).join(' · '),
                    style: TextStyle(color: context.soluk, fontSize: 12.5),
                  ),
                  if (o['uye'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          Text('Yerleşti: ${o.m('uye').s('ad')}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          TextButton(onPressed: () => _yap('/api/kulup/cikar', {'ogrenciId': o.n('uyelikId')}), child: const Text('Kulüpten çıkar')),
                        ],
                      ),
                    ),
                  for (final t in o.l('talepler')) _talep(context, o, t),
                ],
              ),
            ),
        ],
      );
    },
  );

  Widget _talep(BuildContext context, Map<String, dynamic> o, Map<String, dynamic> t) {
    final uyeMi = o['uye'] != null && o.m('uye').n('id') == t.n('kulupId');
    final dolu = t.n('uyeSayisi') >= t.n('kontenjan');
    final durum = switch (t.s('durum')) {
      'kabul' => 'Kabul',
      'red' => 'Reddedildi',
      _ => 'Bekliyor',
    };
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 2,
        children: [
          Text('${t.n('sira')}. ${t.s('kulup')}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          Text('${t.n('uyeSayisi')}/${t.n('kontenjan')} · $durum', style: TextStyle(color: context.soluk, fontSize: 12.5)),
          if (!uyeMi)
            TextButton(
              onPressed: dolu ? null : () => _yap('/api/kulup/yerlestir', {'ogrenciId': o.n('uyelikId'), 'kulupId': t.n('kulupId')}),
              child: const Text('Yerleştir'),
            ),
          if (t.s('durum') == 'bekliyor') TextButton(onPressed: () => _yap('/api/kulup/red', {'talepId': t.n('id')}), child: const Text('Reddet')),
        ],
      ),
    );
  }
}

/// Düzey bazında kulüp saatleri: sınıf programlarına "Kulüp" dersi koyar/kaldırır.
class _SaatSekmesi extends StatefulWidget {
  const _SaatSekmesi({required this.api, required this.veri, required this.degisti});

  final Api api;
  final Map<String, dynamic> veri;
  final VoidCallback degisti;

  @override
  State<_SaatSekmesi> createState() => _SaatSekmesiState();
}

class _SaatSekmesiState extends State<_SaatSekmesi> {
  String? _duzey;
  int? _gun;
  int? _saat;
  bool _mesgul = false;

  Future<void> _gonder(Map<String, dynamic> govde) async {
    setState(() => _mesgul = true);
    try {
      final r = await widget.api.post('/api/kulup/saat', govde);
      if (!mounted) return;
      final atlanan = r is Map<String, dynamic> ? r.l('atlanan') : const <Map<String, dynamic>>[];
      _bildir(
        context,
        atlanan.isEmpty
            ? 'Kulüp saati güncellendi.'
            : 'Güncellendi; ${atlanan.length} sınıf atlandı (${atlanan.first.s('sinif')}: ${atlanan.first.s('ders')} dersi var).',
      );
      setState(() => _mesgul = false);
      widget.degisti();
    } catch (e) {
      if (!mounted) return;
      setState(() => _mesgul = false);
      hataGoster(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.veri;
    final zamanlar = _metinler(v['zamanlar']);
    final saatler = v.l('kulupSaatleri');
    final sayilar = (v['sinifSayisi'] as Map?) ?? const {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Seçtiğiniz düzeydeki tüm sınıfların programına aynı gün ve saatte “Kulüp” dersi konur.', style: TextStyle(color: context.soluk, fontSize: 13)),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _duzey,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Sınıf düzeyi'),
          items: [for (final d in _metinler(v['duzeyler'])) DropdownMenuItem(value: d, child: Text('$d (${sayilar[d] ?? 0} sınıf)'))],
          onChanged: (x) => setState(() => _duzey = x),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<int>(
          initialValue: _gun,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Gün'),
          items: [for (final g in v.l('gunler')) DropdownMenuItem(value: g.n('gun'), child: Text(g.s('ad')))],
          onChanged: (x) => setState(() => _gun = x),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<int>(
          initialValue: _saat,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Ders saati'),
          items: [for (final (i, z) in zamanlar.indexed) DropdownMenuItem(value: i + 1, child: Text('${i + 1}. ders · $z'))],
          onChanged: (x) => setState(() => _saat = x),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _mesgul
              ? null
              : () {
                  if (_duzey == null || _gun == null || _saat == null) return _bildir(context, 'Düzey, gün ve ders saatini seçin.');
                  _gonder({'duzey': _duzey, 'gun': _gun, 'saat': _saat});
                },
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: const Text('Kulüp saati ekle'),
        ),
        const Baslik('Tanımlı kulüp saatleri', ust: 18),
        if (saatler.isEmpty) const BosNot('Kulüp saati tanımlı değil.'),
        for (final s in saatler)
          KartKutu(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.s('duzey'), style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        '${s.s('gunAd')} · ${s.n('saat')}. ders (${s.s('aralik')}) · ${s.n('sinif')} sınıf',
                        style: TextStyle(color: context.soluk, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _mesgul ? null : () => _gonder({'duzey': s.s('duzey'), 'gun': s.n('gun'), 'saat': s.n('saat'), 'kaldir': true}),
                  child: const Text('Kaldır'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

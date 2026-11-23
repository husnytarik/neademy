import 'package:flutter/material.dart';

import '../bilesenler/ortak.dart';
import '../cekirdek/api.dart';
import '../cekirdek/tema.dart';

const _yonler = {'cift': 'Sabah ve akşam', 'sabah': 'Yalnız sabah', 'aksam': 'Yalnız akşam'};

void _bildir(BuildContext context, String metin) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(metin)));

Future<void> _git(BuildContext context, Widget ekran, VoidCallback yenile) async {
  final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => ekran));
  if (ok == true) yenile();
}

/// Servis yönetimi (yönetim): servisler, güzergâh durakları, öğrenci bağlama.
class ServisYonetimEkrani extends StatefulWidget {
  const ServisYonetimEkrani({super.key, required this.api});

  final Api api;

  @override
  State<ServisYonetimEkrani> createState() => _ServisYonetimEkraniState();
}

class _ServisYonetimEkraniState extends State<ServisYonetimEkrani> {
  int _n = 0;
  String _okul = '';
  Map<String, dynamic>? _baglam;

  void _yenile() => setState(() => _n++);

  Future<dynamic> _getir() async {
    _baglam ??= await widget.api.get('/api/servis/baglam') as Map<String, dynamic>;
    return await widget.api.get('/api/servis/liste?okul=$_okul');
  }

  @override
  Widget build(BuildContext context) => VeriSayfasi(
    key: ValueKey('$_n$_okul'),
    baslik: 'Öğrenci servisi',
    getir: _getir,
    cizim: (context, raw) {
      final v = raw as Map<String, dynamic>;
      final t = v.m('toplam');
      final okullar = _baglam!.l('okullar');
      final liste = v.l('servisler');
      return [
        if (okullar.length > 1)
          SuzgecCipleri(
            secenekler: [('', 'Tüm okullar'), for (final b in okullar) ('${b.n('id')}', b.s('ad'))],
            secili: _okul,
            degisti: (x) => setState(() => _okul = x),
          ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [Cip('Öğrenci ${t.n('ogrenci')}'), Cip('Servisli ${t.n('servisli')}', renk: const Color(0xFF2E9E5B)), Cip('Servissiz ${t.n('servissiz')}', renk: const Color(0xFFD64545))],
        ),
        const SizedBox(height: 10),
        EkleDugmesi('+ Yeni servis', onPressed: () => _git(context, _ServisFormu(api: widget.api, baglam: _baglam!), _yenile)),
        const SizedBox(height: 10),
        if (liste.isEmpty) const BosNot('Henüz servis eklenmemiş. "Yeni servis" ile başlayın.'),
        for (final s in liste)
          KartKutu(
            onTap: () => _git(context, _ServisDetay(api: widget.api, baglam: _baglam!, id: s.n('id')), _yenile),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.s('ad'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                      Text(
                        [if (okullar.length > 1) s.s('okul'), if (s.s('plaka').isNotEmpty) s.s('plaka'), if (s.s('soforAd').isNotEmpty) s.s('soforAd'), '${s.n('durak')} durak'].join(' · '),
                        style: TextStyle(color: context.soluk, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                if (s['aktif'] == false) ...[const Cip('Pasif'), const SizedBox(width: 8)],
                Text(s.n('kapasite') > 0 ? '${s.n('dolu')} / ${s.n('kapasite')}' : '${s.n('dolu')}', style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
      ];
    },
  );
}

// ---------------- Servis formu ----------------
class _ServisFormu extends StatefulWidget {
  const _ServisFormu({required this.api, required this.baglam, this.servis});

  final Api api;
  final Map<String, dynamic> baglam;
  final Map<String, dynamic>? servis;

  @override
  State<_ServisFormu> createState() => _ServisFormuState();
}

class _ServisFormuState extends State<_ServisFormu> {
  late final _ad = TextEditingController(text: widget.servis?.s('ad'));
  late final _plaka = TextEditingController(text: widget.servis?.s('plaka'));
  late final _sofor = TextEditingController(text: widget.servis?.s('soforAd'));
  late final _soforTel = TextEditingController(text: widget.servis?.s('soforTel'));
  late final _hostes = TextEditingController(text: widget.servis?.s('hostesAd'));
  late final _hostesTel = TextEditingController(text: widget.servis?.s('hostesTel'));
  late final _kapasite = TextEditingController(text: widget.servis == null ? '' : '${widget.servis!.n('kapasite')}');
  late final _not = TextEditingController(text: widget.servis?.s('notu'));
  late bool _aktif = widget.servis?['aktif'] != false;
  int? _okul;
  bool _mesgul = false;

  @override
  void initState() {
    super.initState();
    final okullar = widget.baglam.l('okullar');
    _okul = widget.servis?.n('okulId') ?? (okullar.length == 1 ? okullar.first.n('id') : null);
  }

  Future<void> _kaydet() async {
    setState(() => _mesgul = true);
    try {
      await widget.api.post('/api/servis/kaydet', {
        if (widget.servis != null) 'id': widget.servis!.n('id'),
        if (widget.servis == null) 'okulId': _okul,
        'ad': _ad.text,
        'plaka': _plaka.text,
        'soforAd': _sofor.text,
        'soforTel': _soforTel.text,
        'hostesAd': _hostes.text,
        'hostesTel': _hostesTel.text,
        'kapasite': _kapasite.text.trim().isEmpty ? 0 : int.tryParse(_kapasite.text.trim()),
        'notu': _not.text,
        'aktif': _aktif,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _mesgul = false);
      hataGoster(context, e);
    }
  }

  Widget _alan(TextEditingController c, String ad, {TextInputType? tur, int satir = 1}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(controller: c, keyboardType: tur, maxLines: satir, decoration: InputDecoration(labelText: ad)),
  );

  @override
  Widget build(BuildContext context) {
    final okullar = widget.baglam.l('okullar');
    return Scaffold(
      appBar: AppBar(title: Text(widget.servis == null ? 'Yeni servis' : 'Servisi düzenle')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.servis == null && okullar.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<int>(
                initialValue: _okul,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Okul'),
                items: [for (final b in okullar) DropdownMenuItem(value: b.n('id'), child: Text(b.s('ad')))],
                onChanged: (x) => setState(() => _okul = x),
              ),
            ),
          _alan(_ad, 'Servis adı (örn. Servis 1)'),
          _alan(_plaka, 'Plaka'),
          _alan(_sofor, 'Şoför adı'),
          _alan(_soforTel, 'Şoför telefonu', tur: TextInputType.phone),
          _alan(_hostes, 'Hostes adı'),
          _alan(_hostesTel, 'Hostes telefonu', tur: TextInputType.phone),
          _alan(_kapasite, 'Kapasite (boşsa sınırsız)', tur: TextInputType.number),
          _alan(_not, 'Not', satir: 3),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Serviste hizmet veriyor'), value: _aktif, onChanged: (x) => setState(() => _aktif = x)),
          const SizedBox(height: 8),
          FilledButton(onPressed: _mesgul || _okul == null ? null : _kaydet, child: Text(_mesgul ? 'Kaydediliyor…' : 'Kaydet')),
        ],
      ),
    );
  }
}

// ---------------- Servis ayrıntısı ----------------
class _ServisDetay extends StatefulWidget {
  const _ServisDetay({required this.api, required this.baglam, required this.id});

  final Api api;
  final Map<String, dynamic> baglam;
  final int id;

  @override
  State<_ServisDetay> createState() => _ServisDetayState();
}

class _ServisDetayState extends State<_ServisDetay> {
  int _n = 0;
  bool _degisti = false;

  void _yenile() => setState(() {
    _n++;
    _degisti = true;
  });

  Future<void> _islem(Future<dynamic> Function() is_, {String? basari}) async {
    try {
      await is_();
      if (!mounted) return;
      if (basari != null) _bildir(context, basari);
      _yenile();
    } catch (e) {
      if (mounted) hataGoster(context, e);
    }
  }

  Future<void> _ogrenciDuzenle(Map<String, dynamic> o, List<Map<String, dynamic>> duraklar) async {
    int? durak = duraklar.any((d) => d.n('id') == o.n('durakId')) ? o.n('durakId') : null;
    var yon = o.s('yon');
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(c).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(o.s('ad'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                initialValue: durak,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Durak'),
                items: [const DropdownMenuItem(value: null, child: Text('Belirtilmedi')), for (final d in duraklar) DropdownMenuItem(value: d.n('id'), child: Text(d.s('ad')))],
                onChanged: (x) => set(() => durak = x),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: yon,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Kullanım'),
                items: [for (final e in _yonler.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                onChanged: (x) => set(() => yon = x ?? yon),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Kaydet')),
            ],
          ),
        ),
      ),
    );
    if (ok == true) await _islem(() => widget.api.post('/api/servis/ogrenci-guncelle', {'ogrenciId': o.n('id'), 'durakId': durak, 'yon': yon}), basari: 'Güncellendi');
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (ok, _) {
      if (!ok) Navigator.pop(context, _degisti);
    },
    child: VeriSayfasi(
      key: ValueKey(_n),
      baslik: 'Servis',
      getir: () => widget.api.get('/api/servis/detay?id=${widget.id}'),
      cizim: (context, raw) {
        final v = raw as Map<String, dynamic>;
        final s = v.m('servis');
        final duraklar = v.l('duraklar');
        final ogrenciler = v.l('ogrenciler');
        String ad(String id) => duraklar.firstWhere((d) => d.n('id') == int.tryParse(id), orElse: () => const {})['ad']?.toString() ?? 'Durak yok';
        return [
          KartKutu(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(s.s('ad'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                    if (s['aktif'] == false) const Cip('Pasif'),
                  ],
                ),
                const SizedBox(height: 6),
                for (final (a, d) in [
                  ('Okul', s.s('okul')),
                  ('Plaka', s.s('plaka')),
                  ('Şoför', [s.s('soforAd'), s.s('soforTel')].where((x) => x.isNotEmpty).join(' · ')),
                  ('Hostes', [s.s('hostesAd'), s.s('hostesTel')].where((x) => x.isNotEmpty).join(' · ')),
                  ('Kapasite', s.n('kapasite') > 0 ? '${ogrenciler.length} / ${s.n('kapasite')}' : '${ogrenciler.length} öğrenci'),
                  ('Not', s.s('notu')),
                ])
                  if (d.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 3), child: Text('$a: $d')),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton(onPressed: () => _git(context, _ServisFormu(api: widget.api, baglam: widget.baglam, servis: s), _yenile), child: const Text('Düzenle')),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFD64545)),
                      onPressed: () async {
                        if (!await onayIste(context, '"${s.s('ad')}" silinsin mi?', evet: 'Sil')) return;
                        if (!context.mounted) return;
                        try {
                          await widget.api.post('/api/servis/sil', {'id': widget.id});
                          if (context.mounted) Navigator.pop(context, true);
                        } catch (e) {
                          if (context.mounted) hataGoster(context, e);
                        }
                      },
                      child: const Text('Sil'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
              const Expanded(child: Baslik('Güzergâh durakları')),
              TextButton(onPressed: () => _git(context, _DurakDuzenle(api: widget.api, servisId: widget.id, duraklar: duraklar), _yenile), child: const Text('Düzenle')),
            ],
          ),
          if (duraklar.isEmpty) const BosNot('Durak eklenmemiş.'),
          for (final (i, d) in duraklar.indexed)
            KartKutu(
              child: Row(
                children: [
                  Text('${i + 1}.  ', style: TextStyle(color: context.soluk)),
                  Expanded(child: Text(d.s('ad'))),
                  Text([if (d.s('sabahSaat').isNotEmpty) 'Sabah ${d.s('sabahSaat')}', if (d.s('aksamSaat').isNotEmpty) 'Akşam ${d.s('aksamSaat')}'].join(' · '), style: TextStyle(color: context.soluk, fontSize: 13)),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(child: Baslik('Öğrenciler (${ogrenciler.length})')),
              TextButton(
                onPressed: s['aktif'] == false ? null : () => _git(context, _OgrenciEkle(api: widget.api, servis: s, duraklar: duraklar), _yenile),
                child: const Text('+ Öğrenci ekle'),
              ),
            ],
          ),
          if (ogrenciler.isEmpty) const BosNot('Bu servise bağlı öğrenci yok.'),
          for (final o in ogrenciler)
            KartKutu(
              onTap: () => _ogrenciDuzenle(o, duraklar),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(o.s('ad'), style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text('${o.s('sinif')}${o.s('sinif').isEmpty ? '' : ' · '}${o['durakId'] == null ? 'Durak yok' : ad('${o['durakId']}')} · ${_yonler[o.s('yon')] ?? ''}', style: TextStyle(color: context.soluk, fontSize: 13)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Servisten çıkar',
                    icon: const Icon(Icons.close),
                    onPressed: () async {
                      if (await onayIste(context, '${o.s('ad')} servisten çıkarılsın mı?', evet: 'Çıkar')) {
                        await _islem(() => widget.api.post('/api/servis/cikar', {'ogrenciId': o.n('id')}), basari: 'Çıkarıldı');
                      }
                    },
                  ),
                ],
              ),
            ),
        ];
      },
    ),
  );
}

// ---------------- Durak düzenleme ----------------
class _DurakDuzenle extends StatefulWidget {
  const _DurakDuzenle({required this.api, required this.servisId, required this.duraklar});

  final Api api;
  final int servisId;
  final List<Map<String, dynamic>> duraklar;

  @override
  State<_DurakDuzenle> createState() => _DurakDuzenleState();
}

class _SatirDurak {
  _SatirDurak(Map<String, dynamic> d)
    : id = d['id'] as int?,
      ad = TextEditingController(text: d.s('ad')),
      sabah = TextEditingController(text: d.s('sabahSaat')),
      aksam = TextEditingController(text: d.s('aksamSaat'));

  final int? id;
  final TextEditingController ad, sabah, aksam;
}

class _DurakDuzenleState extends State<_DurakDuzenle> {
  late final List<_SatirDurak> _satirlar = [for (final d in widget.duraklar) _SatirDurak(d)];
  bool _mesgul = false;

  Future<void> _kaydet() async {
    setState(() => _mesgul = true);
    try {
      await widget.api.post('/api/servis/duraklar', {
        'servisId': widget.servisId,
        'duraklar': [for (final s in _satirlar) {'id': s.id, 'ad': s.ad.text, 'sabahSaat': s.sabah.text.trim(), 'aksamSaat': s.aksam.text.trim()}],
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _mesgul = false);
      hataGoster(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Güzergâh durakları')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final (i, s) in _satirlar.indexed)
          KartKutu(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: TextField(controller: s.ad, decoration: InputDecoration(labelText: '${i + 1}. durak adı'))),
                    IconButton(icon: const Icon(Icons.arrow_upward), onPressed: i == 0 ? null : () => setState(() => _satirlar.insert(i - 1, _satirlar.removeAt(i)))),
                    IconButton(icon: const Icon(Icons.arrow_downward), onPressed: i == _satirlar.length - 1 ? null : () => setState(() => _satirlar.insert(i + 1, _satirlar.removeAt(i)))),
                    IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => setState(() => _satirlar.removeAt(i))),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: TextField(controller: s.sabah, keyboardType: TextInputType.datetime, decoration: const InputDecoration(labelText: 'Sabah (07:30)'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: s.aksam, keyboardType: TextInputType.datetime, decoration: const InputDecoration(labelText: 'Akşam (16:45)'))),
                  ],
                ),
              ],
            ),
          ),
        OutlinedButton(onPressed: () => setState(() => _satirlar.add(_SatirDurak(const {}))), child: const Text('+ Durak ekle')),
        const SizedBox(height: 12),
        FilledButton(onPressed: _mesgul ? null : _kaydet, child: Text(_mesgul ? 'Kaydediliyor…' : 'Kaydet')),
      ],
    ),
  );
}

// ---------------- Servise öğrenci ekleme ----------------
class _OgrenciEkle extends StatefulWidget {
  const _OgrenciEkle({required this.api, required this.servis, required this.duraklar});

  final Api api;
  final Map<String, dynamic> servis;
  final List<Map<String, dynamic>> duraklar;

  @override
  State<_OgrenciEkle> createState() => _OgrenciEkleState();
}

class _OgrenciEkleState extends State<_OgrenciEkle> {
  final _ara = TextEditingController();
  List<Map<String, dynamic>> _liste = [];
  final _secili = <int>{};
  int? _durak;
  String _yon = 'cift';
  bool _yukleniyor = true, _mesgul = false;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    try {
      final v = await widget.api.get('/api/servis/servissizler?okul=${widget.servis.n('okulId')}&ara=${Uri.encodeQueryComponent(_ara.text.trim())}') as Map<String, dynamic>;
      if (mounted) setState(() => _liste = v.l('ogrenciler'));
    } catch (e) {
      if (mounted) hataGoster(context, e);
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Future<void> _ekle() async {
    setState(() => _mesgul = true);
    try {
      await widget.api.post('/api/servis/ata', {'servisId': widget.servis.n('id'), 'ogrenciIds': _secili.toList(), 'durakId': _durak, 'yon': _yon});
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _mesgul = false);
      hataGoster(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Servise öğrenci ekle')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            children: [
              TextField(controller: _ara, textInputAction: TextInputAction.search, onSubmitted: (_) => _yukle(), decoration: InputDecoration(labelText: 'Öğrenci ara', suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _yukle))),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      initialValue: _durak,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Durak'),
                      items: [const DropdownMenuItem(value: null, child: Text('Belirtilmedi')), for (final d in widget.duraklar) DropdownMenuItem(value: d.n('id'), child: Text(d.s('ad')))],
                      onChanged: (x) => setState(() => _durak = x),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _yon,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Kullanım'),
                      items: [for (final e in _yonler.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                      onChanged: (x) => setState(() => _yon = x ?? _yon),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _yukleniyor
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
              : _liste.isEmpty
              ? const BosNot('Servissiz öğrenci bulunamadı.')
              : ListView(
                  children: [
                    for (final o in _liste)
                      CheckboxListTile(
                        value: _secili.contains(o.n('id')),
                        title: Text(o.s('ad')),
                        subtitle: o.s('sinif').isEmpty ? null : Text(o.s('sinif')),
                        onChanged: (x) => setState(() => x == true ? _secili.add(o.n('id')) : _secili.remove(o.n('id'))),
                      ),
                  ],
                ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: _secili.isEmpty || _mesgul ? null : _ekle,
              child: Text(_mesgul ? 'Ekleniyor…' : '${_secili.length} öğrenciyi ekle'),
            ),
          ),
        ),
      ],
    ),
  );
}

import 'package:flutter/material.dart';

import '../bilesenler/ortak.dart';
import '../cekirdek/api.dart';
import '../cekirdek/tema.dart';
import '../cekirdek/yazdir.dart';
import 'kisi_dosyasi.dart';

const _gorevAdi = {'mudur': 'Müdür', 'mudur_yrd': 'Müdür yardımcısı'};

Future<Map<String, dynamic>> _getir(Api api) async {
  final k = await api.get('/api/yonetim/kullanicilar?tur=personel') as Map<String, dynamic>;
  final r = await api.get('/api/yonetim/roller') as Map<String, dynamic>;
  final s = await api.get('/api/yonetim/subeler') as Map<String, dynamic>;
  final sec = await api.get('/api/yonetim/kullanici-secenek') as Map<String, dynamic>;
  return {
    'kullanicilar': k.l('kullanicilar'),
    'roller': r.l('roller'),
    'katalog': r.l('katalog'),
    'subeler': s.l('subeler'),
    'kampusler': s.l('kampusler'),
    'sec': sec,
  };
}

String _okulEtiket(Map<String, dynamic> s, List<Map<String, dynamic>> kampusler) {
  if (kampusler.length < 2) return s.s('ad');
  final k = kampusler.where((x) => x.n('id') == s.n('kampusId')).firstOrNull;
  return k == null ? s.s('ad') : '${s.s('ad')} · ${k.s('ad')}';
}

Set<int> _idler(dynamic l) => {for (final x in (l as List? ?? const [])) (x as num).toInt()};

bool _personelUyelik(Map<String, dynamic> m) => m.s('rol') == 'yonetim' || m.s('rol') == 'ogretmen';

bool _calisiyor(Map<String, dynamic> u) => u.l('uyelikler').any((m) => _personelUyelik(m) && m.s('durum') == 'aktif');

/// Kişinin görev unvanları (web kisiler.js gorevler()): kurum yönetimi, müdür görevleri, ek roller, branş.
List<String> _gorevler(Map<String, dynamic> u, Map<String, dynamic> sec) {
  final roller = sec.l('roller');
  final dersler = sec.l('dersler');
  final liste = <String>[];
  final uyeler = u.l('uyelikler');
  if (uyeler.any((m) => m.s('rol') == 'yonetim' && m.s('gorev') == 'kurum' && m.s('durum') == 'aktif')) liste.add('Kurum yönetimi');
  for (final g in u.l('okulGorevleri')) {
    liste.add(_gorevAdi[g.s('gorev')] ?? g.s('gorev'));
  }
  for (final id in _idler(u['roller'])) {
    final r = roller.where((x) => x.n('id') == id).firstOrNull;
    if (r != null && r.s('kod') != 'zumre') liste.add(r.s('ad'));
  }
  final ogretmenler = uyeler.where((m) => m.s('rol') == 'ogretmen' && m.s('durum') == 'aktif').toList();
  if (ogretmenler.isNotEmpty) {
    final branslar = {
      for (final m in ogretmenler)
        if (dersler.where((d) => d.n('id') == m.n('bransId')).firstOrNull?.s('ad') case final String ad when ad.isNotEmpty) ad,
    };
    liste.add(branslar.isEmpty ? 'Öğretmen' : '${branslar.join(' / ')} öğretmeni');
    if (ogretmenler.any((m) => m['baskan'] == true)) liste.add('Zümre başkanı');
  }
  return liste.toSet().toList();
}

List<String> _okullari(Map<String, dynamic> u) => {
  for (final m in u.l('uyelikler'))
    if (_personelUyelik(m) && m.s('durum') == 'aktif' && m.s('sube').isNotEmpty) m.s('sube'),
}.toList();

/// Kişiler: personel listesi (süzgeç, arama), kişi dosyası, yeni kişi ve roller.
class KisilerEkrani extends StatefulWidget {
  const KisilerEkrani({super.key, required this.api});

  final Api api;

  @override
  State<KisilerEkrani> createState() => _KisilerEkraniState();
}

class _KisilerEkraniState extends State<KisilerEkrani> {
  String _sekme = 'personel';
  String _gorev = 'tum';
  String _durum = 'aktif';
  bool _duzenle = false;
  int _okul = 0;
  String _ara = '';
  int _n = 0;

  Api get api => widget.api;

  Future<T?> _git<T>(Widget sayfa) async {
    final r = await Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => sayfa));
    if (mounted) setState(() => _n++);
    return r;
  }

  Future<void> _yeniKisi(Map<String, dynamic> v) async {
    final r = await _git<Map<String, dynamic>>(
      _YeniKisi(api: api, subeler: v.l('subeler'), kampusler: v.l('kampusler'), sec: v['sec'] as Map<String, dynamic>),
    );
    if (r == null || !mounted) return;
    await _git<bool>(KisiDosyasi(api: api, kisiId: r.n('id'), yeni: r['mevcut'] != true, mevcut: r['mevcut'] == true));
  }

  List<Map<String, dynamic>> _suz(Map<String, dynamic> v) {
    final q = _ara.trim().toLowerCase();
    return [
      for (final u in v.l('kullanicilar'))
        if (_uygun(u, q)) u,
    ];
  }

  bool _uygun(Map<String, dynamic> u, String q) {
    final m = u.l('uyelikler').where((x) => _personelUyelik(x) && (_okul == 0 || x.n('subeId') == _okul)).toList();
    if (m.isEmpty) return false;
    final aktif = m.any((x) => x.s('durum') == 'aktif');
    if (_durum == 'aktif' && !aktif) return false;
    if (_durum == 'pasif' && aktif) return false;
    if (_gorev == 'ogretmen' && !m.any((x) => x.s('rol') == 'ogretmen')) return false;
    if (_gorev == 'yonetim' && !m.any((x) => x.s('rol') == 'yonetim')) return false;
    if (_gorev == 'mudur' && u.l('okulGorevleri').isEmpty) return false;
    return q.isEmpty || u.s('ad').toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) => VeriSayfasi(
    key: ValueKey(_n),
    baslik: 'Kişiler',
    eylemler: (context, raw) => _sekme == 'rol' ? const [] : [YazdirDugmesi(onPressed: () => _yazdir(context, raw as Map<String, dynamic>))],
    getir: () => _getir(api),
    cizim: (context, raw) {
      final v = raw as Map<String, dynamic>;
      final roller = v.l('roller');
      final subeler = v.l('subeler');
      final kampusler = v.l('kampusler');
      final sec = v['sec'] as Map<String, dynamic>;
      final kisiler = _suz(v);
      return [
        Sekmeler(
          secenekler: const [('personel', 'Personel'), ('rol', 'Roller')],
          secili: _sekme,
          degisti: (d) => setState(() {
            _sekme = d;
            _duzenle = false;
          }),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(_sekme == 'rol' ? '${roller.length} rol' : '${kisiler.length} kişi', style: TextStyle(color: context.soluk)),
            ),
            if (_sekme == 'personel')
              TextButton(onPressed: () => _yeniKisi(v), child: const Text('+ Yeni kişi'))
            else ...[
              if (_duzenle) TextButton(onPressed: () => _git<bool>(_RolFormu(api: api, katalog: v.l('katalog'))), child: const Text('+ Yeni rol')),
              TextButton(onPressed: () => setState(() => _duzenle = !_duzenle), child: Text(_duzenle ? 'Bitti' : 'Düzenle')),
            ],
          ],
        ),
        if (_sekme == 'personel') ...[
          SuzgecCipleri(
            secenekler: const [('tum', 'Tüm görevler'), ('ogretmen', 'Öğretmenler'), ('yonetim', 'Yönetim'), ('mudur', 'Müdür ve yardımcıları')],
            secili: _gorev,
            degisti: (d) => setState(() => _gorev = d),
          ),
          const SizedBox(height: 6),
          SuzgecCipleri(
            secenekler: const [('aktif', 'Çalışanlar'), ('pasif', 'Ayrılanlar'), ('hepsi', 'Hepsi')],
            secili: _durum,
            degisti: (d) => setState(() => _durum = d),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            initialValue: _okul,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Okul'),
            items: [
              const DropdownMenuItem(value: 0, child: Text('Tüm okullar')),
              for (final s in subeler)
                DropdownMenuItem(
                  value: s.n('id'),
                  child: Text(_okulEtiket(s, kampusler), overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (x) => setState(() => _okul = x ?? 0),
          ),
          const SizedBox(height: 10),
          TextField(
            decoration: const InputDecoration(hintText: 'Ara…', prefixIcon: Icon(Icons.search)),
            onChanged: (x) => setState(() => _ara = x),
          ),
          const SizedBox(height: 6),
          if (kisiler.isEmpty) const BosNot('Bu seçimde kayıtlı kişi yok.'),
          for (final u in kisiler) _kisiSatiri(context, u, sec),
        ] else ...[
          for (final r in roller) _rolSatiri(context, r, v),
        ],
      ];
    },
  );

  /// Web'deki personel listesi çıktısı: seçili süzgece göre numaralı tablo.
  void _yazdir(BuildContext context, Map<String, dynamic> v) {
    final sec = v['sec'] as Map<String, dynamic>;
    final subeler = v.l('subeler');
    final kampusler = v.l('kampusler');
    final okulAdi = _okul == 0 ? 'Tüm okullar' : [for (final s in subeler) if (s.n('id') == _okul) _okulEtiket(s, kampusler)].firstOrNull ?? 'Tüm okullar';
    final satirlar = [
      for (final u in _suz(v)) [u.s('ad'), _gorevler(u, sec).join(', '), _okullari(u).join(', ')],
    ]..sort((a, b) => a[0].toLowerCase().compareTo(b[0].toLowerCase()));
    raporYazdir(
      context,
      api,
      baslik: 'Personel listesi',
      alt: '$okulAdi · ${satirlar.length} kişi',
      bolumler: [
        RaporBolumu(
          sutunlar: const ['No', 'Ad soyad', 'Görev', 'Okul'],
          satirlar: [for (var i = 0; i < satirlar.length; i++) ['${i + 1}', ...satirlar[i]]],
          bos: 'Bu seçimde kayıtlı kişi yok.',
        ),
      ],
    );
  }

  Widget _kisiSatiri(BuildContext context, Map<String, dynamic> u, Map<String, dynamic> sec) {
    final g = _gorevler(u, sec);
    final calisiyor = _calisiyor(u);
    final alt = [g.isEmpty ? 'Görev atanmamış' : g.join(', '), _okullari(u).join(', '), if (!calisiyor) 'Ayrıldı'].where((e) => e.isNotEmpty).join(' · ');
    return Opacity(
      opacity: calisiyor ? 1 : 0.6,
      child: KartKutu(
        onTap: () => _git<bool>(KisiDosyasi(api: api, kisiId: u.n('id'))),
        child: Row(
          children: [
            KisiAvatari(ad: u.s('ad'), foto: u.s('foto'), api: api),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u.s('ad'), style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
                  Text(alt, style: TextStyle(color: calisiyor && g.isEmpty ? Colors.red.shade600 : context.soluk, fontSize: 12.5)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: context.soluk),
          ],
        ),
      ),
    );
  }

  Widget _rolSatiri(BuildContext context, Map<String, dynamic> r, Map<String, dynamic> v) {
    final kisi = r['okulAtar'] == true ? '${r.n('kisi')} kişi · Okul kurulumunda atanır' : '${r.n('kisi')} kişi';
    return KartKutu(
      onTap: () => _git<bool>(_RolFormu(api: api, katalog: v.l('katalog'), rol: r, duzenle: _duzenle)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.s('ad'), style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
                Text(
                  '${r['kilitli'] == true ? 'Tüm yetkiler' : '${(r['yetkiler'] as List? ?? const []).length} yetki'} · $kisi',
                  style: TextStyle(color: context.soluk, fontSize: 12.5),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: context.soluk),
        ],
      ),
    );
  }
}

/// Yeni kişi: okul(lar) açıkça seçilir (sessiz varsayılan yok), görevler bağımsızdır, eklemeden önce özet onayı istenir.
class _YeniKisi extends StatefulWidget {
  const _YeniKisi({required this.api, required this.subeler, required this.kampusler, required this.sec});

  final Api api;
  final List<Map<String, dynamic>> subeler;
  final List<Map<String, dynamic>> kampusler;
  final Map<String, dynamic> sec;

  @override
  State<_YeniKisi> createState() => _YeniKisiState();
}

class _YeniKisiState extends State<_YeniKisi> {
  final _ad = TextEditingController();
  final _kimlik = TextEditingController();
  final _tel = TextEditingController();
  late final Set<int> _okullar = {if (widget.subeler.length == 1) widget.subeler.first.n('id')};
  final Set<int> _dersler = {};
  final Set<int> _roller = {};
  bool _ogretmen = false, _yonetim = false, _mesgul = false;
  String _mudur = '';
  String _kimlikUyari = '';
  String _sonKontrol = '';

  List<Map<String, dynamic>> get _rolListesi => [for (final r in widget.sec.l('roller')) if (r.s('kod') != 'zumre') r];

  @override
  void dispose() {
    _ad.dispose();
    _kimlik.dispose();
    _tel.dispose();
    super.dispose();
  }

  /// Kimlik zaten kayıtlıysa yeni hesap açılmaz; görev mevcut hesaba eklenir. Kişi önceden bilgilendirilir.
  Future<void> _kontrol() async {
    final k = _kimlik.text.trim();
    if (k.length < 5 || k == _sonKontrol) return;
    _sonKontrol = k;
    try {
      final r = await widget.api.get('/api/yonetim/kullanici-kontrol?kimlik=${Uri.encodeQueryComponent(k)}') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() => _kimlikUyari = r['var'] == true ? 'Bu kimlik zaten kayıtlı: ${r.s('ad')}. Yeni hesap açılmaz; seçtiğiniz görevler bu hesaba eklenir.' : '');
    } catch (_) {
      if (mounted) setState(() => _kimlikUyari = '');
    }
  }

  String _okulAd(int id) => [for (final s in widget.subeler) if (s.n('id') == id) _okulEtiket(s, widget.kampusler)].firstOrNull ?? '';

  Future<void> _ekle() async {
    final ad = _ad.text.trim();
    if (ad.isEmpty) return _uyar('Ad soyad yazın.');
    if (_kimlik.text.trim().isEmpty) return _uyar('T.C. / pasaport no yazın.');
    if (_okullar.isEmpty) return _uyar('Okul seçin: kişi hangi okulda çalışacak?');
    if (!_ogretmen && !_yonetim && _roller.isEmpty) return _uyar('En az bir görev seçin: öğretmen, yönetim ya da ek görev.');
    final mudur = _yonetim && _okullar.length == 1 ? _mudur : '';
    final okullar = _okullar.map(_okulAd).join(', ');
    final gorevler = [
      if (_yonetim) 'Yönetim',
      if (mudur.isNotEmpty) _gorevAdi[mudur] ?? mudur,
      if (_ogretmen) 'Öğretmen',
      for (final r in _rolListesi) if (_roller.contains(r.n('id'))) r.s('ad'),
    ];
    final soru = '$ad şöyle eklenecek:\n\n• Okul: $okullar\n• Görev: ${gorevler.join(', ')}\n\nDoğru mu? Yanlış çıkarsa kişi dosyasından düzeltebilir ya da geri alabilirsiniz.';
    if (!await onayIste(context, soru, evet: 'Doğru, ekle')) return;
    setState(() => _mesgul = true);
    try {
      final r = await widget.api.post('/api/yonetim/kullanici-yeni', {
        'ad': ad,
        'kimlik': _kimlik.text.trim(),
        'telefon': _tel.text.trim(),
        'subeIds': _okullar.toList(),
        'ogretmen': _ogretmen,
        'dersIds': _ogretmen ? _dersler.toList() : <int>[],
        'yonetim': _yonetim,
        'rolIds': _roller.toList(),
        'mudurGorev': mudur,
      }) as Map<String, dynamic>;
      if (mounted) Navigator.pop(context, r);
    } catch (e) {
      if (mounted) {
        setState(() => _mesgul = false);
        hataGoster(context, e);
      }
    }
  }

  void _uyar(String metin) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(metin)));

  @override
  Widget build(BuildContext context) {
    final dersler = widget.sec.l('dersler');
    final gorevler = widget.sec.m('gorevler');
    return Scaffold(
      appBar: AppBar(title: const Text('Yeni kişi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          TextField(
            controller: _ad,
            maxLength: 80,
            decoration: const InputDecoration(labelText: 'Ad soyad'),
          ),
          Focus(
            onFocusChange: (odakta) {
              if (!odakta) _kontrol();
            },
            child: TextField(
              controller: _kimlik,
              maxLength: 20,
              decoration: const InputDecoration(labelText: 'T.C. / pasaport no'),
            ),
          ),
          if (_kimlikUyari.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_kimlikUyari, style: TextStyle(color: Colors.orange.shade800, fontSize: 12.5)),
            ),
          TextField(
            controller: _tel,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Telefon', hintText: '5XX XXX XX XX'),
          ),
          const Baslik('Okul'),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final s in widget.subeler)
                FilterChip(
                  label: Text(_okulEtiket(s, widget.kampusler)),
                  selected: _okullar.contains(s.n('id')),
                  onSelected: (x) => setState(() => x ? _okullar.add(s.n('id')) : _okullar.remove(s.n('id'))),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Kişinin çalışacağı okulu seçin (birden çok olabilir).', style: TextStyle(color: context.soluk, fontSize: 12.5)),
          ),
          const Baslik('Görev'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Öğretmen', style: TextStyle(fontWeight: FontWeight.w600)),
            value: _ogretmen,
            onChanged: (x) => setState(() => _ogretmen = x),
          ),
          if (_ogretmen) ...[
            Text('Verdiği dersler', style: TextStyle(color: context.soluk, fontSize: 12.5)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final d in dersler)
                  FilterChip(
                    label: Text(d.s('ad')),
                    selected: _dersler.contains(d.n('id')),
                    onSelected: (x) => setState(() => x ? _dersler.add(d.n('id')) : _dersler.remove(d.n('id'))),
                  ),
              ],
            ),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Yönetim', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Yönetim paneline girer.'),
            value: _yonetim,
            onChanged: (x) => setState(() => _yonetim = x),
          ),
          if (_yonetim && _okullar.length == 1)
            DropdownButtonFormField<String>(
              initialValue: _mudur,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Müdürlük görevi'),
              items: [
                const DropdownMenuItem(value: '', child: Text('Müdürlük görevi yok')),
                for (final e in gorevler.entries) DropdownMenuItem(value: e.key, child: Text('${e.value}')),
              ],
              onChanged: (x) => setState(() => _mudur = x ?? ''),
            ),
          const Baslik('Ek görev (Güvenlik, Rehber vb.)'),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final r in _rolListesi)
                FilterChip(
                  label: Text(r.s('ad')),
                  selected: _roller.contains(r.n('id')),
                  onSelected: (x) => setState(() => x ? _roller.add(r.n('id')) : _roller.remove(r.n('id'))),
                ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _mesgul ? null : _ekle,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: Text(_mesgul ? 'Ekleniyor…' : 'Kişiyi ekle'),
          ),
        ],
      ),
    );
  }
}

/// Rol sayfası: yeni rol oluşturur; var olan rolün yetkilerini gösterir, düzenleme kipinde değiştirir.
class _RolFormu extends StatefulWidget {
  const _RolFormu({required this.api, required this.katalog, this.rol, this.duzenle = true});

  final Api api;
  final List<Map<String, dynamic>> katalog;
  final Map<String, dynamic>? rol;
  final bool duzenle;

  @override
  State<_RolFormu> createState() => _RolFormuState();
}

class _RolFormuState extends State<_RolFormu> {
  late final _ad = TextEditingController(text: widget.rol?.s('ad') ?? '');
  late final _aciklama = TextEditingController(text: widget.rol?.s('aciklama') ?? '');
  late final Set<String> _secili = {for (final k in (widget.rol?['yetkiler'] as List? ?? const [])) '$k'};
  bool _mesgul = false;

  @override
  void dispose() {
    _ad.dispose();
    _aciklama.dispose();
    super.dispose();
  }

  Future<void> _gonder(String yol, Map<String, dynamic> govde) async {
    setState(() => _mesgul = true);
    try {
      await widget.api.post(yol, govde);
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
    final r = widget.rol;
    final yeni = r == null;
    final kilitli = r?['kilitli'] == true;
    final duzenlenir = (yeni || widget.duzenle) && !kilitli;
    final adlar = {
      for (final g in widget.katalog)
        for (final y in g.l('yetkiler')) y.s('kod'): y.s('ad'),
    };
    return Scaffold(
      appBar: AppBar(title: Text(yeni ? 'Yeni rol' : r.s('ad'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (yeni)
            TextField(
              controller: _ad,
              maxLength: 40,
              decoration: const InputDecoration(labelText: 'Rol adı', hintText: 'Örn. Kütüphane sorumlusu'),
            ),
          if (duzenlenir)
            TextField(
              controller: _aciklama,
              maxLength: 140,
              decoration: const InputDecoration(labelText: 'Açıklama', hintText: 'Kısa açıklama (isteğe bağlı)'),
            )
          else if (!yeni && r.s('aciklama').isNotEmpty)
            Text(r.s('aciklama'), style: TextStyle(color: context.soluk)),
          if (kilitli) const BosNot('Bu rol her şeyi yapabilir ve değiştirilemez.'),
          if (!kilitli && !duzenlenir) ...[
            if (_secili.isEmpty) const BosNot('Bu rol hiçbir yetki vermez; yalnızca kayıt içindir.'),
            for (final k in _secili)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.check, color: context.ana, size: 18),
                title: Text(adlar[k] ?? k),
              ),
          ],
          if (duzenlenir) ...[
            if (yeni)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Bu rol hangi işleri yapabilsin?', style: TextStyle(color: context.soluk)),
              ),
            for (final g in widget.katalog) ...[
              Baslik(g.s('grup')),
              for (final y in g.l('yetkiler'))
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(y.s('ad'), style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(y.s('aciklama'), style: TextStyle(color: context.soluk, fontSize: 12.5)),
                  value: _secili.contains(y.s('kod')),
                  onChanged: (x) => setState(() => x ? _secili.add(y.s('kod')) : _secili.remove(y.s('kod'))),
                ),
            ],
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _mesgul
                  ? null
                  : () => _gonder('/api/yonetim/rol-kaydet', {
                      'id': r?.n('id'),
                      'ad': yeni ? _ad.text : r.s('ad'),
                      'aciklama': _aciklama.text,
                      'yetkiler': _secili.toList(),
                    }),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: Text(_mesgul ? 'Kaydediliyor…' : (yeni ? 'Rolü oluştur' : 'Kaydet')),
            ),
            if (!yeni && r['sistem'] != true)
              TextButton(
                onPressed: _mesgul
                    ? null
                    : () async {
                        final soru = '"${r.s('ad')}" rolü silinsin mi? ${r.n('kisi') > 0 ? '${r.n('kisi')} kişiden bu rol alınır.' : ''}';
                        if (await onayIste(context, soru, evet: 'Sil')) await _gonder('/api/yonetim/rol-sil', {'id': r.n('id')});
                      },
                child: Text('Rolü sil', style: TextStyle(color: Colors.red.shade600)),
              ),
          ],
        ],
      ),
    );
  }
}

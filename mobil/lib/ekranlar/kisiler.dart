import 'package:flutter/material.dart';

import '../bilesenler/ortak.dart';
import '../cekirdek/api.dart';
import '../cekirdek/tema.dart';

const _rolAdi = {'yonetim': 'Yönetim', 'ogretmen': 'Öğretmen', 'ogrenci': 'Öğrenci', 'veli': 'Veli'};
const _gorevAdi = {'mudur': 'Müdür', 'mudur_yrd': 'Müdür yardımcısı'};

Future<Map<String, dynamic>> _getir(Api api) async {
  final k = await api.get('/api/yonetim/kullanicilar') as Map<String, dynamic>;
  final r = await api.get('/api/yonetim/roller') as Map<String, dynamic>;
  final s = await api.get('/api/yonetim/subeler') as Map<String, dynamic>;
  return {'kullanicilar': k.l('kullanicilar'), 'roller': r.l('roller'), 'katalog': r.l('katalog'), 'subeler': s.l('subeler'), 'kampusler': s.l('kampusler')};
}

String _okulEtiket(Map<String, dynamic> s, List<Map<String, dynamic>> kampusler) {
  if (kampusler.length < 2) return s.s('ad');
  final k = kampusler.where((x) => x.n('id') == s.n('kampusId')).firstOrNull;
  return k == null ? s.s('ad') : '${s.s('ad')} · ${k.s('ad')}';
}

bool _atanabilir(Map<String, dynamic> r) => r['okulAtar'] != true && r['kilitli'] != true && r.s('kod') != 'zumre';

Set<int> _idler(dynamic l) => {for (final x in (l as List? ?? const [])) (x as num).toInt()};

/// Kişiler: yönetim kadrosu, öğretmenler ve roller (düzenleme kipinde ad, rol, üyelik ve yetki değişir).
class KisilerEkrani extends StatefulWidget {
  const KisilerEkrani({super.key, required this.api});

  final Api api;

  @override
  State<KisilerEkrani> createState() => _KisilerEkraniState();
}

class _KisilerEkraniState extends State<KisilerEkrani> {
  String _sekme = 'kadro';
  bool _duzenle = false;
  int _okul = 0;
  String _ara = '';
  int _n = 0;

  Api get api => widget.api;

  Future<void> _git(Widget sayfa) async {
    await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => sayfa));
    if (mounted) setState(() => _n++);
  }

  @override
  Widget build(BuildContext context) => VeriSayfasi(
    key: ValueKey(_n),
    baslik: 'Kişiler',
    getir: () => _getir(api),
    cizim: (context, raw) {
      final v = raw as Map<String, dynamic>;
      final roller = v.l('roller');
      final subeler = v.l('subeler');
      final kampusler = v.l('kampusler');
      final rol = _sekme == 'ogretmen' ? 'ogretmen' : 'yonetim';
      final q = _ara.trim().toLowerCase();
      final kisiler = [
        for (final u in v.l('kullanicilar'))
          if (u.l('uyelikler').any((m) => m.s('rol') == rol && (_okul == 0 || m.n('subeId') == _okul)) && (q.isEmpty || u.s('ad').toLowerCase().contains(q))) u,
      ];
      return [
        Sekmeler(
          secenekler: const [('kadro', 'Yönetim'), ('ogretmen', 'Öğretmenler'), ('rol', 'Roller')],
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
            if (_duzenle && _sekme != 'ogretmen')
              TextButton(
                onPressed: () => _git(
                  _sekme == 'rol' ? _RolFormu(api: api, katalog: v.l('katalog')) : _YeniKisi(api: api, subeler: subeler, kampusler: kampusler, roller: roller),
                ),
                child: Text(_sekme == 'rol' ? '+ Yeni rol' : '+ Yeni kişi'),
              ),
            TextButton(onPressed: () => setState(() => _duzenle = !_duzenle), child: Text(_duzenle ? 'Bitti' : 'Düzenle')),
          ],
        ),
        if (_sekme != 'rol') ...[
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
          for (final u in kisiler) _kisiSatiri(context, u, roller, rol),
        ] else ...[
          for (final r in roller) _rolSatiri(context, r, v),
        ],
      ];
    },
  );

  String _gorevler(Map<String, dynamic> u, List<Map<String, dynamic>> roller) {
    final liste = <String>[];
    if (u.l('uyelikler').any((m) => m.s('rol') == 'yonetim' && m.s('gorev') == 'kurum' && m.s('durum') == 'aktif')) liste.add('Kurum yönetimi');
    for (final g in u.l('okulGorevleri')) {
      liste.add('${_gorevAdi[g.s('gorev')] ?? g.s('gorev')} · ${g.s('okul')}');
    }
    final ids = _idler(u['roller']);
    final ek = [
      for (final r in roller)
        if (ids.contains(r.n('id'))) r.s('ad'),
    ];
    if (ek.isNotEmpty) liste.add(ek.join(', '));
    return liste.join(' · ');
  }

  Widget _kisiSatiri(BuildContext context, Map<String, dynamic> u, List<Map<String, dynamic>> roller, String rol) {
    final uyeler = u.l('uyelikler').where((m) => m.s('rol') == rol).toList();
    final pasif = uyeler.every((m) => m.s('durum') == 'pasif');
    final okullar = {
      for (final m in uyeler)
        if (m.s('durum') == 'aktif' && m.s('sube').isNotEmpty) m.s('sube'),
    }.join(', ');
    final gorev = _sekme == 'kadro' ? _gorevler(u, roller) : '';
    final ek = [
      for (final r in roller)
        if (_idler(u['roller']).contains(r.n('id'))) r.s('ad'),
    ].join(', ');
    final alt = [
      if (_sekme == 'kadro') (gorev.isNotEmpty ? gorev : okullar) else okullar,
      if (_sekme != 'kadro' && ek.isNotEmpty) ek,
      if (pasif) 'Pasif',
      u.s('telefon'),
    ].where((e) => e.isNotEmpty).join(' · ');
    final uyari = _sekme == 'kadro' && !pasif && gorev.isEmpty;
    return KartKutu(
      onTap: _duzenle ? () => _git(_KisiDuzen(api: api, kisiId: u.n('id'), rol: rol)) : null,
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: context.ana.withValues(alpha: .14),
            child: Text(
              u.s('ad').isEmpty ? '?' : u.s('ad').characters.first.toUpperCase(),
              style: TextStyle(color: context.ana, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(u.s('ad'), style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
                Text.rich(
                  TextSpan(
                    children: [
                      if (uyari)
                        TextSpan(
                          text: 'Rol atanmamış · ',
                          style: TextStyle(color: Colors.red.shade600),
                        ),
                      TextSpan(text: alt),
                    ],
                  ),
                  style: TextStyle(color: context.soluk, fontSize: 12.5),
                ),
              ],
            ),
          ),
          if (_duzenle) Icon(Icons.chevron_right, color: context.soluk),
        ],
      ),
    );
  }

  Widget _rolSatiri(BuildContext context, Map<String, dynamic> r, Map<String, dynamic> v) {
    final kisi = r['okulAtar'] == true ? '${r.n('kisi')} kişi · Okul kurulumunda atanır' : '${r.n('kisi')} kişi';
    return KartKutu(
      onTap: () => _git(_RolFormu(api: api, katalog: v.l('katalog'), rol: r, duzenle: _duzenle)),
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

/// Bir kişinin düzenleme sayfası: ad, yönetim rolleri, üyelikler.
class _KisiDuzen extends StatefulWidget {
  const _KisiDuzen({required this.api, required this.kisiId, required this.rol});

  final Api api;
  final int kisiId;
  final String rol;

  @override
  State<_KisiDuzen> createState() => _KisiDuzenState();
}

class _KisiDuzenState extends State<_KisiDuzen> {
  int _n = 0;
  TextEditingController? _ad;
  String _yeniRol = '';
  int _yeniSube = 0;
  bool _ekle = false;

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  Future<void> _yap(String yol, Map<String, dynamic> govde, {String? basari}) async {
    try {
      await widget.api.post(yol, govde);
      if (!mounted) return;
      if (basari != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(basari)));
      setState(() => _n++);
    } catch (e) {
      if (mounted) hataGoster(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => VeriSayfasi(
    key: ValueKey(_n),
    baslik: 'Kişi',
    getir: () => _getir(widget.api),
    cizim: (context, raw) {
      final v = raw as Map<String, dynamic>;
      final u = v.l('kullanicilar').where((x) => x.n('id') == widget.kisiId).firstOrNull;
      if (u == null) return const [BosNot('Kişi bulunamadı.')];
      final roller = v.l('roller');
      final subeler = v.l('subeler');
      final kampusler = v.l('kampusler');
      _ad ??= TextEditingController(text: u.s('ad'));
      _yeniRol = _yeniRol.isEmpty ? widget.rol : _yeniRol;
      if (_yeniSube == 0 && subeler.isNotEmpty) _yeniSube = subeler.first.n('id');
      final verilen = _idler(u['roller']);
      final uyelikler = u.l('uyelikler');
      final kaynak =
          uyelikler.where((m) => m.s('rol') == 'yonetim' && m.s('durum') == 'aktif').firstOrNull ?? uyelikler.where((m) => m.s('durum') == 'aktif').firstOrNull;
      return [
        const Baslik('Ad soyad', ust: 4),
        TextField(
          controller: _ad,
          maxLength: 80,
          decoration: const InputDecoration(hintText: 'Ad soyad'),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => _yap('/api/yonetim/kullanici-ad', {'userId': u.n('id'), 'ad': _ad!.text}, basari: 'Ad güncellendi.'),
            child: const Text('Adı kaydet'),
          ),
        ),
        const Baslik('Yönetim rolleri'),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            if (uyelikler.any((m) => m.s('rol') == 'yonetim' && m.s('gorev') == 'kurum' && m.s('durum') == 'aktif')) const Cip('Kurum yönetimi'),
            for (final g in u.l('okulGorevleri')) Cip('${_gorevAdi[g.s('gorev')] ?? g.s('gorev')} · ${g.s('okul')}'),
            for (final r in roller.where(_atanabilir))
              FilterChip(
                label: Text(r.s('ad')),
                selected: verilen.contains(r.n('id')),
                onSelected: (sec) => _yap('/api/yonetim/kullanici-rol', {'userId': u.n('id'), 'rolId': r.n('id'), 'ver': sec, 'subeId': kaynak?.n('subeId')}),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text('Müdür ve müdür yardımcısı görevleri Okul kurulumunda verilir.', style: TextStyle(color: context.soluk, fontSize: 12.5)),
        const Baslik('Üyelikler'),
        for (final m in uyelikler)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text('${_rolAdi[m.s('rol')] ?? m.s('rol')} · ${m.s('sube').isEmpty ? '-' : m.s('sube')}${m.s('durum') == 'pasif' ? ' · pasif' : ''}'),
            trailing: TextButton(
              onPressed: () async {
                final pasif = m.s('durum') == 'pasif';
                if (!pasif && !await onayIste(context, '${u.s('ad')}: bu üyelik pasifleştirilsin mi? Bu profille giriş yapamaz.', evet: 'Pasifleştir')) return;
                await _yap('/api/yonetim/uyelik-durum', {'uyelikId': m.n('id'), 'durum': pasif ? 'aktif' : 'pasif'});
              },
              child: Text(m.s('durum') == 'pasif' ? 'Aktifleştir' : 'Pasifleştir'),
            ),
          ),
        if (!_ekle)
          TextButton(onPressed: () => setState(() => _ekle = true), child: const Text('+ Üyelik ekle'))
        else ...[
          DropdownButtonFormField<int>(
            initialValue: _yeniSube,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Okul'),
            items: [
              for (final s in subeler)
                DropdownMenuItem(
                  value: s.n('id'),
                  child: Text(_okulEtiket(s, kampusler), overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (x) => setState(() => _yeniSube = x ?? _yeniSube),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _yeniRol,
            decoration: const InputDecoration(labelText: 'Rol'),
            items: const [
              DropdownMenuItem(value: 'yonetim', child: Text('Yönetim')),
              DropdownMenuItem(value: 'ogretmen', child: Text('Öğretmen')),
            ],
            onChanged: (x) => setState(() => _yeniRol = x ?? _yeniRol),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () async {
              await _yap('/api/yonetim/uyelik-ekle', {'userId': u.n('id'), 'subeId': _yeniSube, 'rol': _yeniRol}, basari: 'Üyelik eklendi.');
              if (mounted) setState(() => _ekle = false);
            },
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: const Text('Üyelik ekle'),
          ),
        ],
      ];
    },
  );
}

class _YeniKisi extends StatefulWidget {
  const _YeniKisi({required this.api, required this.subeler, required this.kampusler, required this.roller});

  final Api api;
  final List<Map<String, dynamic>> subeler;
  final List<Map<String, dynamic>> kampusler;
  final List<Map<String, dynamic>> roller;

  @override
  State<_YeniKisi> createState() => _YeniKisiState();
}

class _YeniKisiState extends State<_YeniKisi> {
  final _ad = TextEditingController();
  final _kimlik = TextEditingController();
  final _tel = TextEditingController();
  late int _okul = widget.subeler.isEmpty ? 0 : widget.subeler.first.n('id');
  int? _rol;
  bool _mesgul = false;

  @override
  void dispose() {
    _ad.dispose();
    _kimlik.dispose();
    _tel.dispose();
    super.dispose();
  }

  Future<void> _ekle() async {
    setState(() => _mesgul = true);
    try {
      await widget.api.post('/api/yonetim/kullanici-ekle', {
        'ad': _ad.text,
        'kimlik': _kimlik.text,
        'telefon': _tel.text,
        'subeId': _okul,
        'rol': 'yonetim',
        'rolId': _rol,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _mesgul = false);
        hataGoster(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Yeni yönetici')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        TextField(
          controller: _ad,
          maxLength: 80,
          decoration: const InputDecoration(labelText: 'Ad soyad'),
        ),
        TextField(
          controller: _kimlik,
          maxLength: 20,
          decoration: const InputDecoration(labelText: 'T.C. / pasaport no'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _tel,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Telefon', hintText: '5XX XXX XX XX'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: _okul == 0 ? null : _okul,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Okul'),
          items: [
            for (final s in widget.subeler)
              DropdownMenuItem(
                value: s.n('id'),
                child: Text(_okulEtiket(s, widget.kampusler), overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (x) => setState(() => _okul = x ?? _okul),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: _rol,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Rol'),
          hint: const Text('Rol seçin'),
          items: [for (final r in widget.roller.where(_atanabilir)) DropdownMenuItem(value: r.n('id'), child: Text(r.s('ad')))],
          onChanged: (x) => setState(() => _rol = x),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _mesgul ? null : _ekle,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          child: Text(_mesgul ? 'Ekleniyor…' : 'Kişiyi ekle'),
        ),
      ],
    ),
  );
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

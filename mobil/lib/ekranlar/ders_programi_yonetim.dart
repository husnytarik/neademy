import 'package:flutter/material.dart';

import '../bilesenler/ortak.dart';
import '../cekirdek/api.dart';
import '../cekirdek/takvim_model.dart';
import '../cekirdek/tema.dart';

const _kisa = {1: 'Pzt', 2: 'Sal', 3: 'Çar', 4: 'Per', 5: 'Cum', 6: 'Cmt', 0: 'Paz'};
const _uzun = {1: 'Pazartesi', 2: 'Salı', 3: 'Çarşamba', 4: 'Perşembe', 5: 'Cuma', 6: 'Cumartesi', 0: 'Pazar'};
const _turAd = {'nobet': 'Nöbet', 'gorev': 'Görev'};

void _uyar(BuildContext context, String metin) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(metin)));

String _soyad(String ad) => ad.trim().split(' ').last;

extension _Yapi on Map<String, dynamic> {
  Map<String, dynamic> get okul => m('okul');
  List<Map<String, dynamic>> get acikGunler => [
    for (final g in okul.l('gunler'))
      if (g['acik'] == true) g,
  ];
  List<Map<String, dynamic>> get saatler => okul.l('saatler');

  /// Aynı kişi birden fazla okulda öğretmense tek satırda gösterilir.
  List<Map<String, dynamic>> get tekilOgretmenler {
    final goruldu = <int>{};
    return [
      for (final o in l('ogretmenler'))
        if (goruldu.add(o.n('userId'))) o,
    ];
  }
}

Future<String?> _saatSec(BuildContext context, String mevcut) async {
  final p = mevcut.split(':');
  final t = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: int.tryParse(p.first) ?? 8, minute: p.length > 1 ? int.tryParse(p.last) ?? 0 : 0),
    builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: w!),
  );
  if (t == null) return null;
  return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// Gün sütunları ve ders saati satırlarından oluşan haftalık ızgara.
class _Izgara extends StatelessWidget {
  const _Izgara({required this.yapi, required this.hucre});

  final Map<String, dynamic> yapi;
  final Widget Function(int gun, int saat) hucre;

  @override
  Widget build(BuildContext context) {
    final gunler = yapi.acikGunler;
    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 38),
            for (final g in gunler)
              Expanded(
                child: Center(
                  child: Text(
                    _kisa[g.n('no')] ?? '',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.soluk),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (final (i, z) in yapi.saatler.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 38,
                  child: Column(
                    children: [
                      Text('${i + 1}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      Text(z.s('bas'), style: TextStyle(fontSize: 9.5, color: context.soluk)),
                    ],
                  ),
                ),
                for (final g in gunler)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: SizedBox(height: 46, child: hucre(g.n('no'), i + 1)),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Hucre extends StatelessWidget {
  const _Hucre({this.renk, this.ust = '', this.alt = '', this.cizgili = false, this.onTap});

  final Color? renk;
  final String ust;
  final String alt;
  final bool cizgili;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dolu = renk != null;
    return Material(
      color: dolu ? renk!.withValues(alpha: .16) : (cizgili ? Colors.red.withValues(alpha: .07) : context.icZemin),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: dolu ? renk!.withValues(alpha: .5) : context.ince),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 2),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (ust.isNotEmpty)
                Text(
                  ust,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              if (alt.isNotEmpty)
                Text(
                  alt,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9, color: context.soluk),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ders programı: sınıf programı (fırça ile yerleştirme), öğretmen programı ve müsaitlik, nöbet/görev.
class DersProgramiYonetimEkrani extends StatefulWidget {
  const DersProgramiYonetimEkrani({super.key, required this.api});

  final Api api;

  @override
  State<DersProgramiYonetimEkrani> createState() => _DersProgramiYonetimEkraniState();
}

class _DersProgramiYonetimEkraniState extends State<DersProgramiYonetimEkrani> {
  String _sekme = 'sinif';

  @override
  Widget build(BuildContext context) => VeriSayfasi(
    baslik: 'Ders programı',
    getir: () async => await widget.api.get('/api/yonetim/sinif-yapisi'),
    cizim: (context, raw) {
      final yapi = raw as Map<String, dynamic>;
      return [
        Sekmeler(
          secenekler: const [('sinif', 'Sınıf'), ('ogretmen', 'Öğretmen'), ('gorev', 'Nöbet / görev')],
          secili: _sekme,
          degisti: (d) => setState(() => _sekme = d),
        ),
        const SizedBox(height: 10),
        if (_sekme == 'sinif') _SinifProgrami(key: const ValueKey('sinif'), api: widget.api, yapi: yapi),
        if (_sekme == 'ogretmen') _OgretmenProgrami(key: const ValueKey('ogretmen'), api: widget.api, yapi: yapi),
        if (_sekme == 'gorev') _GorevSekmesi(key: const ValueKey('gorev'), api: widget.api, yapi: yapi),
      ];
    },
  );
}

// ---------------------------------------------------------------- Sınıf programı

class _SinifProgrami extends StatefulWidget {
  const _SinifProgrami({super.key, required this.api, required this.yapi});

  final Api api;
  final Map<String, dynamic> yapi;

  @override
  State<_SinifProgrami> createState() => _SinifProgramiState();
}

class _SinifProgramiState extends State<_SinifProgrami> {
  int? _sinif;
  int? _firca;
  List<Map<String, dynamic>> _atamalar = [];
  Map<String, Map<String, dynamic>> _hucreler = {};
  Map<String, String> _mesgul = {};
  bool _yukleniyor = true;
  String? _hata;

  Api get api => widget.api;

  @override
  void initState() {
    super.initState();
    final s = widget.yapi.l('siniflar');
    _sinif = s.isEmpty ? null : s.first.n('id');
    _yukle();
  }

  Future<void> _yukle() async {
    if (_sinif == null) {
      setState(() => _yukleniyor = false);
      return;
    }
    try {
      final a = await api.get('/api/yonetim/atamalar?sinifId=$_sinif') as Map<String, dynamic>;
      final p = await api.get('/api/yonetim/program?sinifId=$_sinif') as Map<String, dynamic>;
      _atamalar = [
        for (final x in a.l('atamalar'))
          if (x['ogretmenUyelikId'] != null) x,
      ];
      if (_firca != null && !_atamalar.any((x) => x.n('id') == _firca)) _firca = null;
      _hucreler = {for (final h in p.l('hucreler')) '${h.n('gun')}-${h.n('saat')}': h};
      await _mesguluYukle();
      if (mounted) {
        setState(() {
          _yukleniyor = false;
          _hata = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _yukleniyor = false;
          _hata = e is ApiHata ? e.mesaj : 'Program yüklenemedi.';
        });
      }
    }
  }

  /// Fırçadaki öğretmenin dolu saatleri (çakışan hücreler kırmızı görünür).
  Future<void> _mesguluYukle() async {
    _mesgul = {};
    final a = _atamalar.where((x) => x.n('id') == _firca).firstOrNull;
    if (a == null) return;
    final uid = a.n('ogretmenUserId');
    final p = await api.get('/api/yonetim/ogretmen-programi?userId=$uid') as Map<String, dynamic>;
    final d = await api.get('/api/yonetim/ogretmen-durum?userId=$uid') as Map<String, dynamic>;
    final sinifAd = widget.yapi.l('siniflar').where((s) => s.n('id') == _sinif).firstOrNull?.s('ad');
    for (final h in p.l('hucreler')) {
      if (h.s('sinif') != sinifAd) _mesgul['${h.n('gun')}-${h.n('saat')}'] = '${h.s('sinif')} sınıfında derste';
    }
    for (final k in d.l('kapali')) {
      _mesgul['${k.n('gun')}-${k.n('saat')}'] = 'Müsait değil';
    }
    for (final g in d.l('gorevler')) {
      if (g.s('tekrar') != 'haftalik') continue;
      for (final s in (g['saatler'] as List? ?? const [])) {
        _mesgul['${g.n('gun')}-$s'] = '${_turAd[g.s('tur')]}: ${g.s('ad')}';
      }
    }
  }

  Future<void> _fircaSec(int? id) async {
    setState(() => _firca = id);
    try {
      await _mesguluYukle();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _hucreTikla(int gun, int saat) async {
    final h = _hucreler['$gun-$saat'];
    int? atamaId;
    if (h != null && (_firca == null || h.n('atamaId') == _firca)) {
      atamaId = null;
    } else if (_firca != null) {
      atamaId = _firca;
    } else {
      return _uyar(context, 'Önce yukarıdaki listeden bir ders seçin.');
    }
    try {
      await api.post('/api/yonetim/program-hucre', {'sinifId': _sinif, 'gun': gun, 'saat': saat, 'atamaId': atamaId});
    } catch (e) {
      if (mounted) hataGoster(context, e);
    }
    await _yukle();
  }

  Future<void> _otomatik() async {
    final bastan = _hucreler.isNotEmpty
        ? await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('Programda dolu hücreler var'),
              content: const Text('Mevcut programı silip baştan mı kuralım, yoksa yalnızca eksik saatleri mi tamamlayalım?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c), child: const Text('Vazgeç')),
                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Eksikleri tamamla')),
                TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Baştan kur')),
              ],
            ),
          )
        : false;
    if (bastan == null || !mounted) return;
    try {
      final r = await api.post('/api/yonetim/program-otomatik', {'sinifId': _sinif, 'bastan': bastan}) as Map<String, dynamic>;
      final eksik = r.l('eksik').map((e) => '${e.s('ders')} (${e.n('kalan')} saat)').join(', ');
      if (mounted) _uyar(context, '${r.n('yerlesen')} ders saati yerleştirildi.${eksik.isEmpty ? '' : ' Yer bulunamayan: $eksik.'}');
    } catch (e) {
      if (mounted) hataGoster(context, e);
    }
    await _yukle();
  }

  Future<void> _temizle() async {
    if (_hucreler.isEmpty) return;
    if (!await onayIste(context, 'Bu sınıfın tüm haftalık programı silinsin mi?', evet: 'Temizle')) return;
    try {
      await api.post('/api/yonetim/program-temizle', {'sinifId': _sinif});
      if (mounted) _uyar(context, 'Program temizlendi.');
    } catch (e) {
      if (mounted) hataGoster(context, e);
    }
    await _yukle();
  }

  @override
  Widget build(BuildContext context) {
    final siniflar = widget.yapi.l('siniflar');
    if (siniflar.isEmpty) return const BosNot("Önce Sınıf ve kadro'dan sınıf açın.");
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<int>(
          initialValue: _sinif,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Sınıf'),
          items: [
            for (final s in siniflar)
              DropdownMenuItem(
                value: s.n('id'),
                child: Text('${s.s('sube')} · ${s.s('ad')}', overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (x) {
            setState(() {
              _sinif = x;
              _firca = null;
              _yukleniyor = true;
            });
            _yukle();
          },
        ),
        const SizedBox(height: 10),
        if (_yukleniyor)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_hata != null) BosNot(_hata!),
        if (!_yukleniyor && _hata == null) ...[
          Text('Bir ders seçip hücrelere dokunun; dolu hücreye dokunmak boşaltır.', style: TextStyle(color: context.soluk, fontSize: 12.5)),
          const SizedBox(height: 8),
          if (_atamalar.isEmpty) const BosNot('Bu sınıfa öğretmeni atanmış ders yok. Sınıf ve kadro bölümünden ders ve öğretmen atayın.'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in _atamalar)
                ChoiceChip(
                  selected: _firca == a.n('id'),
                  avatar: CircleAvatar(radius: 6, backgroundColor: rengiCoz(a['renk'] as String?) ?? context.ana),
                  label: Text('${a.s('ders')} · ${_soyad(a.s('ogretmen'))} ${a.n('kullanilan')}/${a.n('haftalikSaat')}'),
                  onSelected: (x) => _fircaSec(x ? a.n('id') : null),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _Izgara(
            yapi: widget.yapi,
            hucre: (gun, saat) {
              final h = _hucreler['$gun-$saat'];
              if (h != null) {
                return _Hucre(
                  renk: rengiCoz(h['renk'] as String?) ?? context.ana,
                  ust: h.s('kisa').isEmpty ? h.s('ders').characters.take(3).toString() : h.s('kisa'),
                  alt: _soyad(h.s('ogretmen')),
                  onTap: () => _hucreTikla(gun, saat),
                );
              }
              return _Hucre(cizgili: _firca != null && _mesgul.containsKey('$gun-$saat'), onTap: () => _hucreTikla(gun, saat));
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.tonal(onPressed: _sinif == null ? null : _otomatik, child: const Text('Otomatik yerleştir')),
              OutlinedButton(onPressed: _hucreler.isEmpty ? null : _temizle, child: const Text('Programı temizle')),
            ],
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------- Öğretmen programı

class _OgretmenProgrami extends StatefulWidget {
  const _OgretmenProgrami({super.key, required this.api, required this.yapi});

  final Api api;
  final Map<String, dynamic> yapi;

  @override
  State<_OgretmenProgrami> createState() => _OgretmenProgramiState();
}

class _OgretmenProgramiState extends State<_OgretmenProgrami> {
  int? _kisi;
  bool _yukleniyor = false;
  bool _duzenle = false;
  bool _mesgul = false;
  Map<String, Map<String, dynamic>> _ders = {};
  Map<String, dynamic> _durum = {};
  Set<String> _kapali = {};
  final _azami = TextEditingController();

  Api get api => widget.api;

  @override
  void dispose() {
    _azami.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    if (_kisi == null) return;
    setState(() => _yukleniyor = true);
    try {
      final p = await api.get('/api/yonetim/ogretmen-programi?userId=$_kisi') as Map<String, dynamic>;
      final d = await api.get('/api/yonetim/ogretmen-durum?userId=$_kisi') as Map<String, dynamic>;
      _ders = {for (final h in p.l('hucreler')) '${h.n('gun')}-${h.n('saat')}': h};
      _durum = d;
      _kapali = {for (final k in d.l('kapali')) '${k.n('gun')}-${k.n('saat')}'};
      _azami.text = d['azami'] == null ? '' : '${d['azami']}';
      _duzenle = false;
    } catch (e) {
      if (mounted) hataGoster(context, e);
    }
    if (mounted) setState(() => _yukleniyor = false);
  }

  Map<String, Map<String, dynamic>> get _gorevHaritasi => {
    for (final g in _durum.l('gorevler'))
      if (g.s('tekrar') == 'haftalik')
        for (final s in (g['saatler'] as List? ?? const [])) '${g.n('gun')}-$s': g,
  };

  Future<void> _kaydet() async {
    setState(() => _mesgul = true);
    try {
      await api.post('/api/yonetim/ogretmen-musait', {
        'userId': _kisi,
        'kapali': [
          for (final k in _kapali) {'gun': int.parse(k.split('-').first), 'saat': int.parse(k.split('-').last)},
        ],
        'azami': _azami.text.trim(),
      });
      if (mounted) _uyar(context, 'Kaydedildi.');
      await _yukle();
    } catch (e) {
      if (mounted) hataGoster(context, e);
    }
    if (mounted) setState(() => _mesgul = false);
  }

  @override
  Widget build(BuildContext context) {
    final ogretmenler = widget.yapi.tekilOgretmenler;
    final gorev = _gorevHaritasi;
    final toplam = widget.yapi.acikGunler.length * widget.yapi.saatler.length;
    final azami = _durum['azami'] as int?;
    final bos = (toplam - _ders.length - gorev.length - _kapali.length).clamp(0, toplam);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<int>(
          initialValue: _kisi,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Öğretmen'),
          hint: const Text('Öğretmen seçin'),
          items: [
            for (final o in ogretmenler)
              DropdownMenuItem(
                value: o.n('userId'),
                child: Text(o.s('ad'), overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (x) {
            _kisi = x;
            _yukle();
          },
        ),
        const SizedBox(height: 10),
        if (_yukleniyor)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_kisi != null && !_yukleniyor) ...[
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              _Ozet('${_ders.length}${azami == null ? '' : ' / $azami'}', 'ders', asim: azami != null && _ders.length > azami),
              _Ozet('${gorev.length}', 'nöbet / görev'),
              _Ozet('${_kapali.length}', 'müsait değil'),
              _Ozet('$bos', 'boş'),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: _duzenle
                ? TextButton(onPressed: _mesgul ? null : _yukle, child: const Text('Vazgeç'))
                : TextButton(onPressed: () => setState(() => _duzenle = true), child: const Text('Müsaitliği düzenle')),
          ),
          if (_duzenle) ...[Text('Müsait olmadığı saatlere dokunun.', style: TextStyle(color: context.soluk, fontSize: 12.5)), const SizedBox(height: 6)],
          _Izgara(
            yapi: widget.yapi,
            hucre: (gun, saat) {
              final k = '$gun-$saat';
              final h = _ders[k];
              if (h != null) return _Hucre(renk: rengiCoz(h['renk'] as String?) ?? context.ana, ust: h.s('sinif'), alt: h.s('ders'));
              final g = gorev[k];
              if (g != null) return _Hucre(renk: g.s('tur') == 'nobet' ? Colors.orange : Colors.teal, ust: _turAd[g.s('tur')] ?? '', alt: g.s('ad'));
              final kapali = _kapali.contains(k);
              return _Hucre(
                cizgili: kapali,
                ust: kapali ? '✕' : '',
                onTap: _duzenle ? () => setState(() => kapali ? _kapali.remove(k) : _kapali.add(k)) : null,
              );
            },
          ),
          if (_duzenle) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _azami,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Haftalık azami ders yükü (isteğe bağlı)'),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _mesgul ? null : _kaydet,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: Text(_mesgul ? 'Kaydediliyor…' : 'Kaydet'),
            ),
          ],
        ],
      ],
    );
  }
}

class _Ozet extends StatelessWidget {
  const _Ozet(this.sayi, this.ad, {this.asim = false});

  final String sayi;
  final String ad;
  final bool asim;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: sayi,
          style: TextStyle(fontWeight: FontWeight.w700, color: asim ? Colors.red.shade600 : null),
        ),
        TextSpan(
          text: ' $ad',
          style: TextStyle(color: context.soluk),
        ),
      ],
    ),
    style: const TextStyle(fontSize: 13.5),
  );
}

// ---------------------------------------------------------------- Nöbet ve görev

String _gorevZamani(Map<String, dynamic> g) {
  final saatler = (g['saatler'] as List? ?? const []).map((e) => (e as num).toInt()).toList();
  final saat = g.s('bas').isNotEmpty && g.s('bit').isNotEmpty
      ? '${g.s('bas')}–${g.s('bit')}'
      : (saatler.isEmpty ? '' : '${saatler.first}–${saatler.last}. ders');
  if (g.s('tekrar') == 'haftalik') return 'Her ${_uzun[g.n('gun')] ?? ''} · $saat';
  return '${uzunTarih(g.s('tarih'))} · $saat';
}

class _GorevSekmesi extends StatefulWidget {
  const _GorevSekmesi({super.key, required this.api, required this.yapi});

  final Api api;
  final Map<String, dynamic> yapi;

  @override
  State<_GorevSekmesi> createState() => _GorevSekmesiState();
}

class _GorevSekmesiState extends State<_GorevSekmesi> {
  late Future<dynamic> _gelen = widget.api.get('/api/yonetim/gorevler');
  int? _suz;
  bool _duzenle = false;

  void _yenile() => setState(() => _gelen = widget.api.get('/api/yonetim/gorevler'));

  Future<void> _form([Map<String, dynamic>? g]) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _GorevFormu(api: widget.api, yapi: widget.yapi, gorev: g, kisi: _suz),
      ),
    );
    if (mounted) _yenile();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: _gelen,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (snap.hasError) return BosNot(snap.error is ApiHata ? (snap.error as ApiHata).mesaj : 'Yüklenemedi.');
      final tum = (snap.data as Map<String, dynamic>).l('gorevler');
      final liste = [
        for (final g in tum)
          if (_suz == null || g.n('userId') == _suz) g,
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<int?>(
            initialValue: _suz,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Öğretmen'),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('Tüm öğretmenler')),
              for (final o in widget.yapi.tekilOgretmenler)
                DropdownMenuItem<int?>(
                  value: o.n('userId'),
                  child: Text(o.s('ad'), overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (x) => setState(() => _suz = x),
          ),
          Wrap(
            alignment: WrapAlignment.end,
            children: [
              TextButton(onPressed: () => setState(() => _duzenle = !_duzenle), child: Text(_duzenle ? 'Bitti' : 'Düzenle')),
              TextButton(onPressed: () => _form(), child: const Text('+ Nöbet / görev')),
            ],
          ),
          if (liste.isEmpty) const BosNot('Henüz nöbet ya da görevlendirme girilmedi.'),
          for (final (tur, baslik) in const [('nobet', 'Nöbetler'), ('gorev', 'Görevlendirmeler')])
            if (liste.any((g) => g.s('tur') == tur)) ...[
              Baslik(baslik, ust: 6),
              for (final g in liste.where((x) => x.s('tur') == tur))
                KartKutu(
                  onTap: _duzenle ? () => _form(g) : null,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(g.s('ogretmen'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                            Text([g.s('ad'), g.s('yer')].where((e) => e.isNotEmpty).join(' · '), style: TextStyle(color: context.soluk, fontSize: 12.5)),
                            Text(_gorevZamani(g), style: TextStyle(color: context.soluk, fontSize: 12.5)),
                          ],
                        ),
                      ),
                      if (_duzenle)
                        IconButton(
                          tooltip: 'Sil',
                          icon: Icon(Icons.delete_outline, color: Colors.red.shade600),
                          onPressed: () async {
                            if (!await onayIste(context, '${g.s('ogretmen')}: ${g.s('ad')} silinsin mi?', evet: 'Sil')) return;
                            if (!context.mounted) return;
                            try {
                              await widget.api.post('/api/yonetim/gorev-sil', {'id': g.n('id')});
                              if (mounted) _yenile();
                            } catch (e) {
                              if (context.mounted) hataGoster(context, e);
                            }
                          },
                        ),
                    ],
                  ),
                ),
            ],
        ],
      );
    },
  );
}

class _GorevFormu extends StatefulWidget {
  const _GorevFormu({required this.api, required this.yapi, this.gorev, this.kisi});

  final Api api;
  final Map<String, dynamic> yapi;
  final Map<String, dynamic>? gorev;
  final int? kisi;

  @override
  State<_GorevFormu> createState() => _GorevFormuState();
}

class _GorevFormuState extends State<_GorevFormu> {
  late int? _kisi = widget.gorev?.n('userId') ?? widget.kisi;
  late String _tur = widget.gorev?.s('tur') ?? 'nobet';
  late String _tekrar = widget.gorev?.s('tekrar') ?? 'haftalik';
  late final _ad = TextEditingController(text: widget.gorev?.s('ad') ?? '');
  late final _yer = TextEditingController(text: widget.gorev?.s('yer') ?? '');
  late String _tarih = widget.gorev?.s('tarih') ?? '';
  late (String, String) _son = (widget.gorev?.s('bas') ?? '', widget.gorev?.s('bit') ?? '');
  final Map<int, (String, String)> _gunSaat = {};
  (String, String) _tek = ('', '');
  bool _mesgul = false;

  @override
  void initState() {
    super.initState();
    final g = widget.gorev;
    if (g != null) {
      if (g.s('tekrar') == 'haftalik') {
        _gunSaat[g.n('gun')] = (g.s('bas'), g.s('bit'));
      } else {
        _tek = (g.s('bas'), g.s('bit'));
      }
    }
  }

  @override
  void dispose() {
    _ad.dispose();
    _yer.dispose();
    super.dispose();
  }

  Future<void> _saatAyarla(int? gun, bool basMi) async {
    final mevcut = gun == null ? _tek : _gunSaat[gun]!;
    final s = await _saatSec(context, basMi ? mevcut.$1 : mevcut.$2);
    if (s == null) return;
    final yeni = basMi ? (s, mevcut.$2) : (mevcut.$1, s);
    setState(() {
      if (gun == null) {
        _tek = yeni;
      } else {
        _gunSaat[gun] = yeni;
      }
      _son = yeni;
    });
  }

  Future<void> _tarihSec() async {
    final simdi = DateTime.now();
    final t = await showDatePicker(
      context: context,
      initialDate: _tarih.isEmpty ? simdi : tarihCoz(_tarih),
      firstDate: DateTime(simdi.year - 1),
      lastDate: DateTime(simdi.year + 2),
    );
    if (t != null) setState(() => _tarih = tarihYaz(DateTime.utc(t.year, t.month, t.day)));
  }

  Future<void> _kaydet() async {
    if (_kisi == null) return _uyar(context, 'Öğretmen seçiniz.');
    setState(() => _mesgul = true);
    final haftalik = _tekrar == 'haftalik';
    try {
      await widget.api.post('/api/yonetim/gorev-kaydet', {
        if (widget.gorev != null) 'id': widget.gorev!.n('id'),
        'userId': _kisi,
        'tur': _tur,
        'ad': _ad.text,
        'yer': _yer.text,
        'tekrar': _tekrar,
        if (haftalik)
          'gunler': [
            for (final g in widget.yapi.acikGunler)
              if (_gunSaat.containsKey(g.n('no'))) {'gun': g.n('no'), 'bas': _gunSaat[g.n('no')]!.$1, 'bit': _gunSaat[g.n('no')]!.$2},
          ],
        if (!haftalik) ...{'tarih': _tarih, 'bas': _tek.$1, 'bit': _tek.$2},
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
  Widget build(BuildContext context) {
    final haftalik = _tekrar == 'haftalik';
    return Scaffold(
      appBar: AppBar(title: Text(widget.gorev == null ? 'Yeni nöbet / görev' : 'Nöbet / görevi düzenle')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          DropdownButtonFormField<int>(
            initialValue: _kisi,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Öğretmen'),
            items: [
              for (final o in widget.yapi.tekilOgretmenler)
                DropdownMenuItem(
                  value: o.n('userId'),
                  child: Text(o.s('ad'), overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (x) => setState(() => _kisi = x),
          ),
          const SizedBox(height: 12),
          Sekmeler(secenekler: const [('nobet', 'Nöbet'), ('gorev', 'Görev')], secili: _tur, degisti: (d) => setState(() => _tur = d)),
          const SizedBox(height: 12),
          TextField(
            controller: _ad,
            maxLength: 60,
            decoration: const InputDecoration(labelText: 'Ad', hintText: 'Örn. Bahçe nöbeti'),
          ),
          TextField(
            controller: _yer,
            maxLength: 60,
            decoration: const InputDecoration(labelText: 'Yer (isteğe bağlı)'),
          ),
          const SizedBox(height: 8),
          Sekmeler(secenekler: const [('haftalik', 'Her hafta'), ('tek', 'Tek tarih')], secili: _tekrar, degisti: (d) => setState(() => _tekrar = d)),
          const SizedBox(height: 12),
          if (haftalik) ...[
            Wrap(
              spacing: 8,
              children: [
                for (final g in widget.yapi.acikGunler)
                  FilterChip(
                    label: Text(_kisa[g.n('no')] ?? ''),
                    selected: _gunSaat.containsKey(g.n('no')),
                    onSelected: (x) => setState(() => x ? _gunSaat[g.n('no')] = _son : _gunSaat.remove(g.n('no'))),
                  ),
              ],
            ),
            if (_gunSaat.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Önce gün seçin.', style: TextStyle(color: context.soluk)),
              ),
            for (final g in widget.yapi.acikGunler)
              if (_gunSaat.containsKey(g.n('no')))
                _SaatSatiri(
                  etiket: _uzun[g.n('no')] ?? '',
                  bas: _gunSaat[g.n('no')]!.$1,
                  bit: _gunSaat[g.n('no')]!.$2,
                  basSec: () => _saatAyarla(g.n('no'), true),
                  bitSec: () => _saatAyarla(g.n('no'), false),
                ),
          ] else ...[
            OutlinedButton.icon(onPressed: _tarihSec, icon: const Icon(Icons.event), label: Text(_tarih.isEmpty ? 'Tarih seçin' : uzunTarih(_tarih))),
            _SaatSatiri(etiket: 'Saat', bas: _tek.$1, bit: _tek.$2, basSec: () => _saatAyarla(null, true), bitSec: () => _saatAyarla(null, false)),
          ],
          const SizedBox(height: 16),
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

class _SaatSatiri extends StatelessWidget {
  const _SaatSatiri({required this.etiket, required this.bas, required this.bit, required this.basSec, required this.bitSec});

  final String etiket;
  final String bas;
  final String bit;
  final VoidCallback basSec;
  final VoidCallback bitSec;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      children: [
        SizedBox(width: 92, child: Text(etiket, overflow: TextOverflow.ellipsis)),
        Expanded(
          child: OutlinedButton(onPressed: basSec, child: Text(bas.isEmpty ? '--:--' : bas)),
        ),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('–')),
        Expanded(
          child: OutlinedButton(onPressed: bitSec, child: Text(bit.isEmpty ? '--:--' : bit)),
        ),
      ],
    ),
  );
}

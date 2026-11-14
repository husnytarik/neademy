import 'package:flutter/material.dart';

import '../bilesenler/ortak.dart';
import '../cekirdek/api.dart';
import '../cekirdek/foto.dart';
import '../cekirdek/tema.dart';

Set<int> _idler(dynamic l) => {for (final x in (l as List? ?? const [])) (x as num).toInt()};

/// SQLite/ISO zamanını "14.11.2026 09:30" biçimine çevirir.
String _zaman(String s) {
  var t = s.trim();
  if (t.isEmpty) return '';
  if (!t.contains('T')) t = t.replaceFirst(' ', 'T');
  if (!t.endsWith('Z') && !RegExp(r'[+-]\d\d:?\d\d$').hasMatch(t)) t = '${t}Z';
  final d = DateTime.tryParse(t)?.toLocal();
  if (d == null) return s;
  String i(int x) => x.toString().padLeft(2, '0');
  return '${i(d.day)}.${i(d.month)}.${d.year} ${i(d.hour)}:${i(d.minute)}';
}

/// Görev düzenlerken yapılan seçimler; Kaydet'e basılana dek sunucuya gitmez.
class _Taslak {
  _Taslak({required this.yon, required this.ogr, required this.mudur, required this.roller, required this.rolOkul});

  final Map<int, bool> yon;
  final Map<int, bool> ogr;
  final Map<int, String> mudur;
  final Set<int> roller;
  final Set<int> veliCikar = {};
  final List<({int id, String yakinlik, String metin})> veliEkle = [];
  int rolOkul;
}

/// Kişi dosyası (web: kisi.js): kimlik, görevler, branş/dersler, okullar, durum ve geçmiş.
/// Yanlış okul / görev burada düzeltilir ve Geçmiş bölümünden geri alınır.
class KisiDosyasi extends StatefulWidget {
  const KisiDosyasi({super.key, required this.api, required this.kisiId, this.yeni = false, this.mevcut = false});

  final Api api;
  final int kisiId;

  /// Kişi az önce eklendi (yanlışsa düzeltme yolunu hatırlatır).
  final bool yeni;

  /// Kimlik zaten kayıtlıydı; görev mevcut hesaba eklendi.
  final bool mevcut;

  @override
  State<KisiDosyasi> createState() => _KisiDosyasiState();
}

class _KisiDosyasiState extends State<KisiDosyasi> {
  int _n = 0;
  Map<String, dynamic>? _kv;
  Map<String, dynamic>? _sv;
  int _zumreRolu = 0;

  bool _kimlikDuzen = false, _gorevDuzen = false, _dersDuzen = false, _veliAcik = false;
  TextEditingController? _ad, _kimlik, _tel;
  _Taslak? _t;
  final Map<int, Set<int>> _dersSecili = {};
  final Map<int, int?> _bransSecili = {};
  final Map<int, bool> _baskanSecili = {};
  bool _ilkIleti = true;

  Api get api => widget.api;
  Map<String, dynamic> get _k => _kv!;
  Map<String, dynamic> get _sec => _sv!;
  List<Map<String, dynamic>> get _uyelikler => _k.l('uyelikler');
  List<Map<String, dynamic>> get _okullar => _sec.l('okullar');
  List<Map<String, dynamic>> get _roller => [for (final r in _sec.l('roller')) if (r.s('kod') != 'zumre') r];
  Set<int> get _kRoller => _idler(_k['roller']).where((x) => x != _zumreRolu).toSet();
  Map<String, dynamic> get _gorevAd => _sec.m('gorevler');
  bool get _kendisi => _k['kendisi'] == true;

  bool get _calisiyor => _uyelikler.any((m) => m.s('durum') == 'aktif');
  bool get _kurumda => _uyelikler.any((m) => m.s('rol') == 'yonetim' && m.s('gorev') == 'kurum' && m.s('durum') == 'aktif');
  String _dersAd(int id) => _sec.l('dersler').where((d) => d.n('id') == id).firstOrNull?.s('ad') ?? '';
  String _gAd(String kod) => _gorevAd[kod]?.toString() ?? kod;

  @override
  void dispose() {
    _ad?.dispose();
    _kimlik?.dispose();
    _tel?.dispose();
    super.dispose();
  }

  void _bildir(String metin) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(metin)));
  }

  void _yenile() {
    if (mounted) setState(() => _n++);
  }

  Future<bool> _yap(String yol, Map<String, dynamic> govde, {String? basari}) async {
    try {
      await api.post(yol, govde);
      if (!mounted) return true;
      if (basari != null) _bildir(basari);
      return true;
    } catch (e) {
      if (mounted) hataGoster(context, e);
      return false;
    }
  }

  Future<dynamic> _getir() async {
    final sec = await api.get('/api/yonetim/kullanici-secenek') as Map<String, dynamic>;
    final k = await api.get('/api/yonetim/kullanici-detay?id=${widget.kisiId}') as Map<String, dynamic>;
    _sv = sec;
    _kv = k;
    _zumreRolu = sec.l('roller').where((r) => r.s('kod') == 'zumre').firstOrNull?.n('id') ?? 0;
    if (_gorevDuzen) _t = _taslakKur();
    return {'k': k, 'sec': sec};
  }

  // ---- Unvanlar ----
  List<String> _unvanlar() {
    final aktif = _uyelikler.where((m) => m.s('durum') == 'aktif').toList();
    final cokOkul = _okullar.length > 1;
    final liste = <String>[];
    if (aktif.any((m) => m.s('rol') == 'yonetim' && m.s('gorev') == 'kurum')) liste.add('Kurum yönetimi');
    for (final g in _k.l('okulGorevleri')) {
      liste.add(_gAd(g.s('gorev')) + (cokOkul ? ' · ${g.s('okul')}' : ''));
    }
    if (liste.isEmpty && aktif.any((m) => m.s('rol') == 'yonetim')) liste.add('Yönetici');
    final ogretmenler = aktif.where((m) => m.s('rol') == 'ogretmen').toList();
    if (ogretmenler.isNotEmpty) {
      final branslar = {for (final m in ogretmenler) if (m.n('bransId') != 0 && _dersAd(m.n('bransId')).isNotEmpty) _dersAd(m.n('bransId'))};
      liste.add(branslar.isEmpty ? 'Öğretmen' : '${branslar.join(' / ')} öğretmeni');
      if (ogretmenler.any((m) => m['baskan'] == true)) liste.add('Zümre başkanı');
    }
    for (final m in _k.l('diger').where((m) => m.s('durum') == 'aktif')) {
      liste.add(m.s('rol') == 'ogrenci' ? 'Öğrenci' : 'Veli');
    }
    return liste;
  }

  // ---- Görev taslağı ----
  ({Map<String, dynamic>? yon, Map<String, dynamic>? ogr, bool yonAcik, bool ogrAcik, String mudur}) _okulDurum(int okulId) {
    Map<String, dynamic>? uye(String rol) => _uyelikler.where((m) => m.s('rol') == rol && m.n('subeId') == okulId).firstOrNull;
    final yon = uye('yonetim'), ogr = uye('ogretmen');
    final mudur = _k.l('okulGorevleri').where((g) => g.n('okulId') == okulId).firstOrNull?.s('gorev') ?? '';
    return (yon: yon, ogr: ogr, yonAcik: yon?.s('durum') == 'aktif', ogrAcik: ogr?.s('durum') == 'aktif', mudur: mudur);
  }

  /// Ek görevin okulu: kişinin tek aktif yönetim okulu ya da kurumdaki tek okul; belirsizse kullanıcı seçer.
  int _rolOkulVarsayilan() {
    final yon = {
      for (final m in _uyelikler)
        if (m.s('rol') == 'yonetim' && m.s('durum') == 'aktif' && m.s('gorev') != 'kurum' && m.n('subeId') != 0) m.n('subeId'),
    };
    if (yon.length == 1) return yon.first;
    if (_okullar.length == 1) return _okullar.first.n('id');
    final aktif = {
      for (final m in _uyelikler)
        if (m.s('durum') == 'aktif' && m.n('subeId') != 0) m.n('subeId'),
    };
    return aktif.length == 1 ? aktif.first : 0;
  }

  _Taslak _taslakKur() {
    final t = _Taslak(yon: {}, ogr: {}, mudur: {}, roller: {..._kRoller}, rolOkul: _rolOkulVarsayilan());
    for (final okul in _okullar) {
      final d = _okulDurum(okul.n('id'));
      t.yon[okul.n('id')] = d.yonAcik;
      t.ogr[okul.n('id')] = d.ogrAcik;
      t.mudur[okul.n('id')] = d.mudur;
    }
    return t;
  }

  // ---- Fotoğraf ----
  Future<void> _fotoYukle() async {
    try {
      final bayt = await galeridenFotoSec();
      if (bayt == null) return;
      await api.postBayt('/api/foto?id=${widget.kisiId}', bayt);
      _bildir('Fotoğraf güncellendi.');
      _yenile();
    } catch (e) {
      if (mounted) hataGoster(context, e);
    }
  }

  // ---- Bölüm çerçevesi ----
  Widget _bilgi(String etiket, String deger) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(etiket, style: TextStyle(color: context.soluk, fontSize: 13.5)),
        ),
        Expanded(
          child: Text(deger.isEmpty ? '—' : deger, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );

  Widget _not(String metin) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Text(metin, style: TextStyle(color: context.soluk, fontSize: 12.5)),
  );

  Widget _kucukBaslik(String metin) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 4),
    child: Text(metin, style: TextStyle(color: context.soluk, fontSize: 12.5, fontWeight: FontWeight.w700)),
  );

  Widget _link(String metin, VoidCallback? onTap, {bool tehlike = false}) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6), minimumSize: const Size(0, 36), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
    child: Text(metin, style: tehlike ? TextStyle(color: Colors.red.shade600) : null),
  );

  Widget _sabitCip(String ad) => Cip(ad);

  Widget _kart(List<Widget> cocuklar) => KartKutu(
    padding: const EdgeInsets.all(14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: cocuklar),
  );

  // ---- Başlık ----
  List<Widget> _baslik() {
    final foto = _k.s('foto');
    final unvan = _unvanlar();
    final etiketler = <Widget>[
      for (final r in _roller) if (_kRoller.contains(r.n('id'))) _sabitCip(r.s('ad')),
      if (!_calisiyor) const Cip('Okuldan ayrıldı', renk: Colors.red),
    ];
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KisiAvatari(ad: _k.s('ad'), foto: foto, api: api, yaricap: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_k.s('ad'), style: serif.copyWith(fontSize: 22, fontWeight: FontWeight.w600)),
                if (unvan.isNotEmpty) Text(unvan.join(' · '), style: TextStyle(color: context.soluk, fontSize: 13.5)),
                if (etiketler.isNotEmpty) ...[const SizedBox(height: 6), Wrap(spacing: 6, runSpacing: 4, children: etiketler)],
                Wrap(
                  children: [
                    _link(foto.isEmpty ? 'Fotoğraf ekle' : 'Fotoğrafı değiştir', _fotoYukle),
                    if (foto.isNotEmpty)
                      _link('Kaldır', () async {
                        if (await _yap('/api/foto-sil?id=${widget.kisiId}', {}, basari: 'Fotoğraf kaldırıldı.')) _yenile();
                      }),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ];
  }

  // ---- Kimlik ----
  List<Widget> _kimlikBolumu() {
    final pasaport = _k.s('kimlikTuru') == 'Pasaport';
    final kimlikEtiket = pasaport ? 'Pasaport no' : 'T.C. kimlik no';
    if (!_kimlikDuzen) {
      return [
        const Baslik('Kimlik ve iletişim'),
        _kart([
          _bilgi('Ad soyad', _k.s('ad')),
          _bilgi(kimlikEtiket, _k.s('kimlik')),
          _bilgi('Giriş telefonu', _k.s('telefon')),
          _link('Düzenle', () {
            _ad = TextEditingController(text: _k.s('ad'));
            _kimlik = TextEditingController();
            _tel = TextEditingController();
            setState(() => _kimlikDuzen = true);
          }),
        ]),
      ];
    }
    return [
      const Baslik('Kimlik ve iletişim'),
      _kart([
        TextField(
          controller: _ad,
          maxLength: 80,
          decoration: const InputDecoration(labelText: 'Ad soyad'),
        ),
        TextField(
          controller: _kimlik,
          maxLength: 20,
          decoration: InputDecoration(labelText: kimlikEtiket, hintText: '${_k.s('kimlik')} (değişmeyecekse boş bırakın)'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _tel,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(labelText: 'Giriş telefonu', hintText: '${_k.s('telefon')} (değişmeyecekse boş bırakın)'),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: () async {
                  final ok = await _yap('/api/yonetim/kullanici-kimlik', {'userId': _k.n('id'), 'ad': _ad!.text, 'kimlik': _kimlik!.text, 'telefon': _tel!.text}, basari: 'Bilgiler güncellendi.');
                  if (!ok) return;
                  setState(() => _kimlikDuzen = false);
                  _yenile();
                },
                child: const Text('Kaydet'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(onPressed: () => setState(() => _kimlikDuzen = false), child: const Text('Vazgeç')),
            ),
          ],
        ),
      ]),
    ];
  }

  // ---- Görevler ----
  String _veliMetin(Map<String, dynamic> o) => [o.s('ad'), o.s('yakinlik'), o.s('sinif').isNotEmpty ? o.s('sinif') : o.s('sube')].where((e) => e.isNotEmpty).join(' · ');

  List<Widget> _gorevOku() {
    final kurumda = _kurumda;
    final cokOkul = _okullar.length > 1;
    final w = <Widget>[];
    var var_ = false;
    if (kurumda) {
      var_ = true;
      w.add(_not('Kurum yönetimi üyesi: tüm okullarda yönetim yetkisi vardır.'));
    }
    for (final okul in _okullar) {
      final d = _okulDurum(okul.n('id'));
      final adlar = [
        if (d.yonAcik && !kurumda) 'Yönetim',
        if (d.mudur.isNotEmpty) _gAd(d.mudur),
        if (d.ogrAcik) 'Öğretmen',
      ];
      if (adlar.isEmpty) continue;
      var_ = true;
      w.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (cokOkul) Text(okul.s('ad'), style: const TextStyle(fontWeight: FontWeight.w700)),
              Wrap(spacing: 6, runSpacing: 4, children: [for (final a in adlar) _sabitCip(a)]),
            ],
          ),
        ),
      );
    }
    final ogr = _k.l('diger').where((m) => m.s('rol') == 'ogrenci' && m.s('durum') == 'aktif').firstOrNull;
    final veliler = _k.l('veliOgrenciler');
    if (ogr != null || veliler.isNotEmpty) {
      var_ = true;
      w.add(_kucukBaslik('Öğrenci ve veli'));
      w.add(Wrap(spacing: 6, runSpacing: 4, children: [if (ogr != null) _sabitCip('Öğrenci'), if (veliler.isNotEmpty) _sabitCip('Veli')]));
      for (final o in veliler) {
        w.add(_not(_veliMetin(o)));
      }
    }
    if (_kRoller.isNotEmpty) {
      var_ = true;
      w.add(_kucukBaslik('Ek görevler'));
      w.add(Wrap(spacing: 6, runSpacing: 4, children: [for (final r in _roller) if (_kRoller.contains(r.n('id'))) _sabitCip(r.s('ad'))]));
    }
    if (!var_) w.add(_not('Henüz görev verilmemiş.'));
    w.add(
      _link('Düzenle', () {
        setState(() {
          _gorevDuzen = true;
          _veliAcik = false;
          _t = _taslakKur();
        });
      }),
    );
    return w;
  }

  Widget _gorevCip(String ad, bool acik, VoidCallback? tikla) => FilterChip(label: Text(ad), selected: acik, onSelected: tikla == null ? null : (_) => tikla());

  List<Widget> _gorevDuzenle() {
    final t = _t!;
    final kurumda = _kurumda;
    final cokOkul = _okullar.length > 1;
    final aktifOkul = {
      for (final m in _uyelikler)
        if (m.s('durum') == 'aktif' && m.n('subeId') != 0) m.n('subeId'),
    };
    final w = <Widget>[];
    if (kurumda) w.add(_not('Kurum yönetimi üyesi: tüm okullarda yönetim yetkisi vardır.'));
    for (final okul in _okullar) {
      final oid = okul.n('id');
      final d = _okulDurum(oid);
      final mudur = t.mudur[oid] ?? '';
      var kilit = '';
      final ogrKilit = d.ogrAcik && d.ogr != null && (_k.l('atamalar').any((a) => a.n('uyelikId') == d.ogr!.n('id')) || _k.l('sinifOgretmenligi').isNotEmpty)
          ? 'Öğretmenlik için önce sınıf atamalarını ve sınıf öğretmenliğini başkasına verin.'
          : '';
      if (!kurumda) {
        kilit = mudur.isNotEmpty ? 'Müdürlük görevi yönetim yetkisini içerir.' : (_kendisi && d.yonAcik ? 'Kendi yönetim yetkinizi kaldıramazsınız.' : '');
      }
      w.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (cokOkul) Text(okul.s('ad'), style: const TextStyle(fontWeight: FontWeight.w700)),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (!kurumda)
                    _gorevCip('Yönetim', mudur.isNotEmpty || (t.yon[oid] ?? false), kilit.isNotEmpty ? null : () => setState(() => t.yon[oid] = !(t.yon[oid] ?? false))),
                  for (final kod in _gorevAd.keys) _gorevCip(_gAd(kod), mudur == kod, () => setState(() => t.mudur[oid] = mudur == kod ? '' : kod)),
                  _gorevCip('Öğretmen', t.ogr[oid] ?? false, ogrKilit.isNotEmpty ? null : () => setState(() => t.ogr[oid] = !(t.ogr[oid] ?? false))),
                ],
              ),
              if (kilit.isNotEmpty) _not(kilit),
              if (ogrKilit.isNotEmpty) _not(ogrKilit),
            ],
          ),
        ),
      );
    }

    // Veli
    w.add(_kucukBaslik('Veli'));
    final kalan = [for (final o in _k.l('veliOgrenciler')) if (!t.veliCikar.contains(o.n('id'))) o];
    final veliVar = kalan.length + t.veliEkle.length > 0;
    w.add(
      Wrap(
        spacing: 6,
        children: [
          _gorevCip('Veli', veliVar || _veliAcik, () {
            setState(() {
              if (veliVar) {
                for (final o in kalan) {
                  t.veliCikar.add(o.n('id'));
                }
                t.veliEkle.clear();
                _veliAcik = false;
              } else {
                _veliAcik = !_veliAcik;
              }
            });
          }),
        ],
      ),
    );
    if (veliVar || _veliAcik || t.veliCikar.isNotEmpty) {
      for (final o in _k.l('veliOgrenciler')) {
        final cikacak = t.veliCikar.contains(o.n('id'));
        w.add(
          Row(
            children: [
              Expanded(
                child: Text(
                  _veliMetin(o) + (cikacak ? ' (çıkarılacak)' : ''),
                  style: TextStyle(decoration: cikacak ? TextDecoration.lineThrough : null, color: cikacak ? context.soluk : null),
                ),
              ),
              _link(cikacak ? 'Geri al' : 'Çıkar', () => setState(() => cikacak ? t.veliCikar.remove(o.n('id')) : t.veliCikar.add(o.n('id'))), tehlike: !cikacak),
            ],
          ),
        );
      }
      for (final e in t.veliEkle) {
        w.add(
          Row(
            children: [
              Expanded(child: Text('${e.metin} · ${e.yakinlik} (eklenecek)')),
              _link('Vazgeç', () => setState(() => t.veliEkle.remove(e))),
            ],
          ),
        );
      }
      w.add(
        _link('+ Öğrenci ekle', () async {
          final mevcut = {for (final o in _k.l('veliOgrenciler')) o.n('id'), for (final e in t.veliEkle) e.id};
          final s = await showDialog<({int id, String yakinlik, String metin})>(context: context, builder: (_) => _VeliSecici(api: api, mevcut: mevcut));
          if (s != null && mounted) setState(() => t.veliEkle.add(s));
        }),
      );
    }

    // Ek görevler
    if (_calisiyor && aktifOkul.isNotEmpty && _roller.isNotEmpty) {
      w.add(_kucukBaslik('Ek görevler (Güvenlik, Rehber vb.)'));
      w.add(
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final r in _roller)
              _gorevCip(r.s('ad'), t.roller.contains(r.n('id')), () => setState(() => t.roller.contains(r.n('id')) ? t.roller.remove(r.n('id')) : t.roller.add(r.n('id')))),
          ],
        ),
      );
      if (_okullar.length > 1) {
        w.add(const SizedBox(height: 8));
        w.add(
          DropdownButtonFormField<int>(
            initialValue: t.rolOkul == 0 ? null : t.rolOkul,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Yeni verilecek ek görev hangi okulda geçerli?'),
            hint: const Text('Okul seçin'),
            items: [for (final o in _okullar) DropdownMenuItem(value: o.n('id'), child: Text(o.s('ad'), overflow: TextOverflow.ellipsis))],
            onChanged: (x) => t.rolOkul = x ?? 0,
          ),
        );
        w.add(_not('Ek görev, seçilen okulda kişiye yönetim paneli girişi açar.'));
      }
    }

    w.add(const SizedBox(height: 12));
    w.add(
      Row(
        children: [
          Expanded(child: FilledButton(onPressed: _gorevKaydet, child: const Text('Kaydet'))),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() {
                _gorevDuzen = false;
                _t = null;
              }),
              child: const Text('Vazgeç'),
            ),
          ),
        ],
      ),
    );
    return w;
  }

  /// Taslağı özgün durumla karşılaştırır, değişenleri özetleyip onay alır ve sırayla sunucuya gönderir.
  Future<void> _gorevKaydet() async {
    final t = _t!;
    final kurumda = _kurumda;
    final islemler = <(String, Map<String, dynamic>)>[];
    final ozet = <String>[];
    var onay = '';
    void ekle(String satir, String yol, Map<String, dynamic> govde) {
      ozet.add(satir);
      islemler.add((yol, govde));
    }

    String okulAd(int id) => _okullar.where((o) => o.n('id') == id).firstOrNull?.s('ad') ?? 'okul';
    final kr = _kRoller;
    final verilecek = [for (final r in _roller) if (t.roller.contains(r.n('id')) && !kr.contains(r.n('id'))) r];
    if (verilecek.any((r) => r.s('kod') != 'kurucu') && t.rolOkul == 0) {
      _bildir('Ek görev için okul seçin: rol hangi okulda geçerli olacak?');
      return;
    }
    for (final r in _roller) {
      final ver = t.roller.contains(r.n('id'));
      if (ver == kr.contains(r.n('id'))) continue;
      final okulluRol = ver && r.s('kod') != 'kurucu';
      ekle(
        ver ? '${r.s('ad')} görevi verilecek${r.s('kod') == 'kurucu' ? '' : ' (${okulAd(t.rolOkul)})'}' : '${r.s('ad')} görevi alınacak',
        '/api/yonetim/kullanici-rol',
        {'userId': _k.n('id'), 'rolId': r.n('id'), 'ver': ver, if (okulluRol) 'subeId': t.rolOkul},
      );
    }
    for (final okul in _okullar) {
      final oid = okul.n('id');
      final d = _okulDurum(oid);
      final mudur = t.mudur[oid] ?? '';
      if (mudur != d.mudur) {
        ekle(
          mudur.isNotEmpty ? '${okul.s('ad')}: ${_gAd(mudur)} görevi verilecek' : '${okul.s('ad')}: müdür / yardımcı görevi kaldırılacak',
          '/api/yonetim/kullanici-mudur',
          {'userId': _k.n('id'), 'okulId': oid, 'gorev': mudur},
        );
      }
      if (!kurumda && mudur.isEmpty) {
        final yon = t.yon[oid] ?? false;
        // Müdürlük kalkınca sunucu o okuldaki yönetim üyeliğini de kapatır; yönetim seçili kaldıysa yeniden açılır
        if (yon != d.yonAcik || (d.mudur.isNotEmpty && yon)) {
          if (yon) {
            ekle(
              '${okul.s('ad')}: yönetim girişi açılacak',
              d.yon != null ? '/api/yonetim/uyelik-durum' : '/api/yonetim/uyelik-ekle',
              d.yon != null ? {'uyelikId': d.yon!.n('id'), 'durum': 'aktif'} : {'userId': _k.n('id'), 'subeId': oid, 'rol': 'yonetim'},
            );
          } else {
            ekle('${okul.s('ad')}: yönetim girişi kapatılacak', '/api/yonetim/uyelik-durum', {'uyelikId': d.yon!.n('id'), 'durum': 'pasif'});
            if (kr.isNotEmpty) onay = 'Yönetim kaldırılırsa kişinin ek görevleri (rol) de çalışmaz.';
          }
        }
      }
      final ogr = t.ogr[oid] ?? false;
      if (ogr != d.ogrAcik) {
        if (ogr) {
          ekle(
            '${okul.s('ad')}: öğretmen olarak eklenecek',
            d.ogr != null ? '/api/yonetim/uyelik-durum' : '/api/yonetim/uyelik-ekle',
            d.ogr != null ? {'uyelikId': d.ogr!.n('id'), 'durum': 'aktif'} : {'userId': _k.n('id'), 'subeId': oid, 'rol': 'ogretmen'},
          );
        } else {
          ekle('${okul.s('ad')}: öğretmenlik kapatılacak', '/api/yonetim/uyelik-durum', {'uyelikId': d.ogr!.n('id'), 'durum': 'pasif'});
        }
      }
    }
    for (final oid in t.veliCikar) {
      ekle('Bir öğrencinin veli bağlantısı kaldırılacak', '/api/yonetim/kullanici-veli', {'userId': _k.n('id'), 'ogrenciId': oid, 'ver': false});
    }
    for (final e in t.veliEkle) {
      ekle('Veli bağlantısı eklenecek: ${e.metin}', '/api/yonetim/kullanici-veli', {'userId': _k.n('id'), 'ogrenciId': e.id, 'yakinlik': e.yakinlik});
    }

    if (islemler.isEmpty) {
      setState(() {
        _gorevDuzen = false;
        _t = null;
      });
      return;
    }
    final soru = '${_k.s('ad')} için şu değişiklikler yapılacak:\n\n• ${ozet.join('\n• ')}${onay.isNotEmpty ? '\n\n$onay' : ''}\n\nDoğru mu? Yanlış çıkarsa Geçmiş bölümünden geri alabilirsiniz.';
    if (!await onayIste(context, soru, evet: 'Doğru, kaydet')) return;
    for (final (yol, govde) in islemler) {
      try {
        await api.post(yol, govde);
      } catch (e) {
        if (!mounted) return;
        hataGoster(context, e is ApiHata && islemler.length > 1 ? ApiHata(e.kod, '${e.mesaj} (öncesindeki değişiklikler kaydedildi)') : e);
        _yenile();
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _gorevDuzen = false;
      _t = null;
    });
    _bildir('Görevler güncellendi.');
    _yenile();
  }

  // ---- Branş ve dersler ----
  List<Widget> _dersBolumu() {
    final uyeler = _uyelikler.where((m) => m.s('rol') == 'ogretmen').toList();
    if (uyeler.isEmpty) return const [];
    final dersler = _sec.l('dersler');
    final w = <Widget>[];
    for (final m in uyeler) {
      final uid = m.n('id');
      final secili = _dersSecili.putIfAbsent(uid, () => {for (final d in _k.l('dersler')) if (d.n('uyelikId') == uid) d.n('dersId')});
      final brans = _bransSecili.containsKey(uid) ? _bransSecili[uid] : (m.n('bransId') == 0 ? null : m.n('bransId'));
      final baskan = _baskanSecili.containsKey(uid) ? _baskanSecili[uid]! : m['baskan'] == true;
      if (uyeler.length > 1) w.add(Text(m.s('sube'), style: const TextStyle(fontWeight: FontWeight.w700)));
      if (!_dersDuzen) {
        w.add(_bilgi('Branş', brans != null ? _dersAd(brans) + (baskan ? ' · Zümre başkanı' : '') : 'Branş seçilmemiş'));
        final diger = [for (final d in secili) if (d != brans) _dersAd(d)].where((e) => e.isNotEmpty);
        if (diger.isNotEmpty) {
          w.add(_kucukBaslik('Verdiği diğer dersler'));
          w.add(Wrap(spacing: 6, runSpacing: 4, children: [for (final a in diger) _sabitCip(a)]));
        }
      } else {
        w.add(
          DropdownButtonFormField<int?>(
            key: ValueKey('brans-$uid-$brans'),
            initialValue: brans,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Branş'),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('Branş seçin')),
              for (final d in dersler) DropdownMenuItem<int?>(value: d.n('id'), child: Text(d.s('ad'), overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (x) => setState(() {
              _bransSecili[uid] = x;
              if (x != null) secili.add(x);
              if (x != (m.n('bransId') == 0 ? null : m.n('bransId'))) _baskanSecili[uid] = false;
            }),
          ),
        );
        if (brans != null) {
          w.add(const SizedBox(height: 8));
          w.add(Wrap(children: [_gorevCip('Zümre başkanı (${_dersAd(brans)} zümresi)', baskan, () => setState(() => _baskanSecili[uid] = !baskan))]));
        }
        w.add(_kucukBaslik('Verdiği dersler'));
        w.add(
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [for (final d in dersler) _gorevCip(d.s('ad'), secili.contains(d.n('id')), d.n('id') == brans ? null : () => setState(() => secili.contains(d.n('id')) ? secili.remove(d.n('id')) : secili.add(d.n('id'))))],
          ),
        );
      }
      w.add(const SizedBox(height: 6));
    }
    void bitir() {
      _dersDuzen = false;
      _dersSecili.clear();
      _bransSecili.clear();
      _baskanSecili.clear();
    }

    if (!_dersDuzen) {
      w.add(_link('Düzenle', () => setState(() => _dersDuzen = true)));
    } else {
      w.add(
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: () async {
                  var hepsi = true;
                  Future<bool> dene(String yol, Map<String, dynamic> govde) async {
                    final ok = await _yap(yol, {'userId': _k.n('id'), ...govde});
                    if (!ok) hepsi = false;
                    return ok;
                  }

                  for (final m in uyeler) {
                    final uid = m.n('id');
                    final onceBrans = m.n('bransId') == 0 ? null : m.n('bransId');
                    final brans = _bransSecili.containsKey(uid) ? _bransSecili[uid] : onceBrans;
                    final baskan = _baskanSecili.containsKey(uid) ? _baskanSecili[uid]! : m['baskan'] == true;
                    if (brans != null && brans != onceBrans && !await dene('/api/yonetim/kullanici-brans', {'uyelikId': uid, 'bransId': brans})) break;
                    final s = _dersSecili[uid];
                    if (s != null && !await dene('/api/yonetim/kullanici-dersler', {'uyelikId': uid, 'dersIds': s.toList()})) break;
                    final baskanOnce = brans == onceBrans ? m['baskan'] == true : false;
                    if (brans != null && baskan != baskanOnce && !await dene('/api/yonetim/kullanici-zumre', {'uyelikId': uid, 'baskan': baskan})) break;
                  }
                  if (!mounted) return;
                  if (hepsi) {
                    setState(bitir);
                    _bildir('Branş ve dersler güncellendi.');
                  }
                  _yenile();
                },
                child: const Text('Kaydet'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton(onPressed: () => setState(bitir), child: const Text('Vazgeç'))),
          ],
        ),
      );
    }
    final atamalar = _k.l('atamalar');
    if (atamalar.isNotEmpty) {
      w.add(_kucukBaslik('Sınıf atamaları'));
      for (final a in atamalar) {
        w.add(_not('${a.s('sinif')} · ${a.s('ders')} · haftada ${a.n('saat')} saat'));
      }
    }
    final siniflar = _k.l('sinifOgretmenligi');
    for (final etiket in {for (final s in siniflar) s.s('etiket')}) {
      w.add(_not('$etiket: ${[for (final s in siniflar) if (s.s('etiket') == etiket) s.s('sinif')].join(', ')}'));
    }
    return [const Baslik('Branş ve dersler'), _kart(w)];
  }

  // ---- Okullar: okulunu değiştir, tek okuldan ayrıl, yanlış kaydı sil ----
  Future<int?> _okulSec(List<Map<String, dynamic>> liste) {
    int? sec;
    return showDialog<int>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Taşınacağı okul'),
          content: DropdownButtonFormField<int>(
            initialValue: sec,
            isExpanded: true,
            hint: const Text('Yeni okulu seçin'),
            items: [for (final o in liste) DropdownMenuItem(value: o.n('id'), child: Text(o.s('ad'), overflow: TextOverflow.ellipsis))],
            onChanged: (x) => set(() => sec = x),
          ),
          actions: [
            DiyalogEylemleri(
              children: [
                TextButton(onPressed: () => Navigator.pop(c), child: const Text('Vazgeç')),
                FilledButton(onPressed: sec == null ? null : () => Navigator.pop(c, sec), child: const Text('Devam')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _okulBolumu() {
    final gruplar = <int, ({String sube, List<Map<String, dynamic>> uyeler})>{};
    for (final m in _uyelikler) {
      if (m.n('subeId') == 0 || m.s('gorev') == 'kurum') continue;
      gruplar.putIfAbsent(m.n('subeId'), () => (sube: m.s('sube'), uyeler: <Map<String, dynamic>>[])).uyeler.add(m);
    }
    if (gruplar.isEmpty) return const [];
    final aktifOkulSayisi = gruplar.values.where((g) => g.uyeler.any((m) => m.s('durum') == 'aktif')).length;
    final w = <Widget>[_not('Yanlış okula yazıldıysa "Okulunu değiştir" ile doğru okula taşıyın; geçmiş kayıtlar korunur. Taşıma geri alınabilir (Geçmiş bölümü).')];
    gruplar.forEach((subeId, g) {
      final aktif = g.uyeler.any((m) => m.s('durum') == 'aktif');
      final mudur = _k.l('okulGorevleri').where((x) => x.n('okulId') == subeId).firstOrNull;
      w.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(g.sube + (aktif ? '' : ' (pasif)'), style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      );
      w.add(
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final m in g.uyeler) _sabitCip((m.s('rol') == 'yonetim' ? 'Yönetim' : 'Öğretmen') + (m.s('durum') == 'aktif' ? '' : ' · pasif')),
            if (mudur != null) _sabitCip(_gAd(mudur.s('gorev'))),
          ],
        ),
      );
      if (_kendisi) return;
      w.add(
        Wrap(
          children: [
            if (aktif)
              _link('Okulunu değiştir', () async {
                final hedef = await _okulSec([for (final o in _okullar) if (o.n('id') != subeId) o]);
                if (hedef == null || !mounted) return;
                final hedefAd = _okullar.where((o) => o.n('id') == hedef).firstOrNull?.s('ad') ?? '';
                final ogr = g.uyeler.where((m) => m.s('rol') == 'ogretmen' && m.s('durum') == 'aktif').firstOrNull;
                final satirlar = ['${_k.s('ad')}: ${g.sube} → $hedefAd okuluna taşınacak.', '• Ek görevleri (rol) kişide kalır.'];
                if (mudur != null) satirlar.add('• ${_gAd(mudur.s('gorev'))} görevi de $hedefAd okuluna taşınır.');
                if (ogr != null && (ogr.n('atama') > 0 || ogr.n('sinif') > 0)) {
                  satirlar.add('• ${ogr.n('atama')} ders ataması ve ${ogr.n('sinif')} sınıf öğretmenliği boşa alınır; ${g.sube} okulunda yenisini atamanız gerekir.');
                }
                if (!await onayIste(context, '${satirlar.join('\n')}\n\nDevam edilsin mi?', evet: 'Taşı')) return;
                try {
                  final r = await api.post('/api/yonetim/kullanici-okul-tasi', {'userId': _k.n('id'), 'kaynakSubeId': subeId, 'hedefSubeId': hedef}) as Map<String, dynamic>?;
                  final ders = r?.n('boslananDers') ?? 0, sinif = r?.n('sinifOgretmenligi') ?? 0;
                  _bildir('Okul değiştirildi: $hedefAd.${ders + sinif > 0 ? ' $ders ders ve $sinif sınıf öğretmenliği boşta; yenisini atayın.' : ''}');
                  _yenile();
                } catch (e) {
                  if (mounted) hataGoster(context, e);
                }
              }),
            if (aktif && aktifOkulSayisi > 1)
              _link('Bu okuldan ayrıldı', () async {
                if (!await onayIste(context, '${_k.s('ad')}, ${g.sube} okulundan ayrıldı olarak işaretlensin mi? Diğer okullardaki görevleri etkilenmez.', evet: 'Ayrıldı')) return;
                if (await _yap('/api/yonetim/kullanici-ayril', {'userId': _k.n('id'), 'subeId': subeId}, basari: '${g.sube} okulundan ayrıldı olarak işaretlendi.')) _yenile();
              }, tehlike: true),
            _link('Bu okuldaki kaydı sil', () async {
              if (!await onayIste(context, '${g.sube} okulundaki kayıt silinsin mi? Yalnızca yanlış girilmiş, hiç işlemi olmayan kayıtlar silinebilir; geçmişi olan kayıt için "Okulunu değiştir" kullanın.', evet: 'Sil')) return;
              for (final m in g.uyeler) {
                if (!await _yap('/api/yonetim/kullanici-uyelik-sil', {'userId': _k.n('id'), 'uyelikId': m.n('id')})) {
                  _yenile();
                  return;
                }
              }
              _bildir('Kayıt silindi.');
              _yenile();
            }, tehlike: true),
          ],
        ),
      );
    });
    return [const Baslik('Okullar'), _kart(w)];
  }

  // ---- Okulla ilişki ----
  List<Widget> _durumBolumu() {
    final w = <Widget>[];
    if (_kendisi) {
      w.add(_not('Kendi hesabınızı buradan okuldan çıkaramazsınız.'));
      return [const Baslik('Okulla ilişki'), _kart(w)];
    }
    if (_calisiyor) {
      w.add(_not('Okuldan ayrılan kişi giremez ve derslerden, sınıf öğretmenliğinden alınır; geçmiş kayıtları (not, yoklama, ödev) korunur.'));
      w.add(
        _link('Okuldan ayrıldı olarak işaretle', () async {
          if (!await onayIste(context, '${_k.s('ad')} okuldan ayrıldı olarak işaretlensin mi? Giriş yetkisi kapanır, dersleri ve sınıf öğretmenliği boşa alınır.', evet: 'Ayrıldı')) return;
          try {
            final r = await api.post('/api/yonetim/kullanici-ayril', {'userId': _k.n('id')}) as Map<String, dynamic>?;
            final ders = r?.n('boslananDers') ?? 0, sinif = r?.n('sinifOgretmenligi') ?? 0;
            _bildir(ders + sinif > 0 ? 'Ayrıldı olarak işaretlendi. $ders ders ve $sinif sınıf öğretmenliği boşta; yenisini atamayı unutmayın.' : 'Ayrıldı olarak işaretlendi.');
            _yenile();
          } catch (e) {
            if (mounted) hataGoster(context, e);
          }
        }, tehlike: true),
      );
    } else {
      w.add(_not('Bu kişi okuldan ayrıldı; giriş yapamaz.'));
      w.add(
        _link('Göreve geri al', () async {
          if (await _yap('/api/yonetim/kullanici-geri', {'userId': _k.n('id')}, basari: 'Kişi göreve geri alındı.')) _yenile();
        }),
      );
    }
    w.add(
      _link('Kaydı sil', () async {
        if (!await onayIste(context, '${_k.s('ad')} kaydı tamamen silinsin mi? Bu işlem geri alınamaz. Geçmişi olan kişi silinemez, ayrıldı olarak işaretleyin.', evet: 'Sil')) return;
        if (await _yap('/api/yonetim/kullanici-sil', {'userId': _k.n('id')}) && mounted) Navigator.pop(context, true);
      }, tehlike: true),
    );
    return [const Baslik('Okulla ilişki'), _kart(w)];
  }

  @override
  Widget build(BuildContext context) => VeriSayfasi(
    key: ValueKey(_n),
    baslik: 'Kişi dosyası',
    getir: _getir,
    cizim: (context, raw) {
      if (_ilkIleti) {
        _ilkIleti = false;
        final ileti = widget.mevcut
            ? 'Bu kişinin hesabı zaten vardı; yeni görev mevcut hesaba eklendi.'
            : widget.yeni
            ? 'Kişi eklendi. Okul ya da görev yanlışsa "Okullar" bölümünden okulunu değiştirebilir veya "Geçmiş" bölümünden işlemi geri alabilirsiniz.'
            : '';
        if (ileti.isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => _bildir(ileti));
      }
      return [
        ..._baslik(),
        ..._kimlikBolumu(),
        const Baslik('Görevler'),
        _kart(_gorevDuzen && _t != null ? _gorevDuzenle() : _gorevOku()),
        ..._dersBolumu(),
        ..._okulBolumu(),
        ..._durumBolumu(),
        const Baslik('Geçmiş'),
        _Gecmis(api: api, kisiId: widget.kisiId, degisti: (m) {
          _bildir(m);
          _yenile();
        }, silindi: () {
          if (mounted) Navigator.pop(context, true);
        }),
      ];
    },
  );
}

/// Kişinin işlem geçmişi: kim, ne zaman, ne yaptı; yanlış işlem "Geri al" ile döndürülür.
class _Gecmis extends StatefulWidget {
  const _Gecmis({required this.api, required this.kisiId, required this.degisti, required this.silindi});

  final Api api;
  final int kisiId;
  final void Function(String mesaj) degisti;
  final VoidCallback silindi;

  @override
  State<_Gecmis> createState() => _GecmisState();
}

class _GecmisState extends State<_Gecmis> {
  late final Future<List<Map<String, dynamic>>> _liste = _yukle();

  Future<List<Map<String, dynamic>>> _yukle() async {
    final r = await widget.api.get('/api/yonetim/kullanici-denetim?id=${widget.kisiId}') as Map<String, dynamic>;
    return r.l('gecmis');
  }

  Future<void> _geriAl(Map<String, dynamic> x) async {
    if (!await onayIste(
      context,
      'Bu işlem geri alınsın mı?\n\n${x.s('ozet')}\n\nKişi bu işlemden önceki durumuna döner. Sonradan başka değişiklik yapıldıysa önce en yeni işlemi geri almanız gerekir.',
      evet: 'Geri al',
    )) {
      return;
    }
    try {
      final y = await widget.api.post('/api/yonetim/kullanici-geri-al', {'userId': widget.kisiId, 'denetimId': x.n('id')}) as Map<String, dynamic>?;
      if (y?['silindi'] == true) {
        widget.silindi();
        return;
      }
      final n = (y?.n('atlananAtama') ?? 0) + (y?.n('atlananSinif') ?? 0);
      widget.degisti(n > 0 ? 'Geri alındı. $n ders / sınıf kaydı bu arada başkasına verildiği için eski haline getirilmedi.' : 'İşlem geri alındı.');
    } catch (e) {
      if (mounted) hataGoster(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: _liste,
    builder: (context, s) {
      if (s.connectionState != ConnectionState.done) {
        return const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
      }
      final g = s.data ?? const <Map<String, dynamic>>[];
      if (g.isEmpty) return const BosNot('Bu kişi için kayıtlı işlem yok.');
      return Column(
        children: [
          for (final x in g)
            KartKutu(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_zaman(x.s('zaman'))}${x.s('aktor').isEmpty ? '' : ' · ${x.s('aktor')}'}', style: TextStyle(color: context.soluk, fontSize: 12)),
                        const SizedBox(height: 2),
                        Text(x.s('ozet') + (x['geriAlindi'] == true ? ' (geri alındı)' : ''), style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  if (x['geriAlinabilir'] == true)
                    TextButton(onPressed: () => _geriAl(x), child: Text('Geri al', style: TextStyle(color: Colors.red.shade600))),
                ],
              ),
            ),
        ],
      );
    },
  );
}

/// Veli bağlantısı için öğrenci arama ve yakınlık seçimi.
class _VeliSecici extends StatefulWidget {
  const _VeliSecici({required this.api, required this.mevcut});

  final Api api;
  final Set<int> mevcut;

  @override
  State<_VeliSecici> createState() => _VeliSeciciState();
}

class _VeliSeciciState extends State<_VeliSecici> {
  List<Map<String, dynamic>> _ogrenciler = [];
  List<String> _yakinlik = [];
  bool _yukleniyor = true;
  String _ara = '';
  String _yak = '';
  int _secili = 0;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final l = await widget.api.get('/api/ogrenci/liste') as Map<String, dynamic>;
      final s = await widget.api.get('/api/ogrenci/kayit') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _ogrenciler = [for (final o in l.l('ogrenciler')) if (o.s('durum') == 'aktif') o];
        _yakinlik = [for (final y in (s.m('secenekler')['yakinlik'] as List? ?? const [])) '$y'];
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _yukleniyor = false);
      hataGoster(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _ara.trim().toLowerCase();
    final uygun = [
      for (final o in _ogrenciler)
        if (!widget.mevcut.contains(o.n('id')) && (q.isEmpty || o.s('ad').toLowerCase().contains(q) || o.s('okulNo').contains(q))) o,
    ].take(40).toList();
    return AlertDialog(
      title: const Text('Veli bağlantısı ekle'),
      content: SizedBox(
        width: double.maxFinite,
        child: _yukleniyor
            ? const SizedBox(height: 80, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(hintText: 'Öğrenci adı ya da okul no', prefixIcon: Icon(Icons.search)),
                    onChanged: (x) => setState(() => _ara = x),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: uygun.isEmpty
                        ? const BosNot('Eşleşen öğrenci yok.')
                        : ListView(
                            shrinkWrap: true,
                            children: [
                              for (final o in uygun)
                                ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  selected: _secili == o.n('id'),
                                  title: Text(o.s('ad')),
                                  subtitle: Text([o.s('sinif').isEmpty ? 'Sınıfsız' : o.s('sinif'), if (o.s('okulNo').isNotEmpty) 'No ${o.s('okulNo')}'].join(' · ')),
                                  onTap: () => setState(() => _secili = o.n('id')),
                                ),
                            ],
                          ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _yak.isEmpty ? null : _yak,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Yakınlık'),
                    items: [for (final y in _yakinlik) DropdownMenuItem(value: y, child: Text(y))],
                    onChanged: (x) => setState(() => _yak = x ?? ''),
                  ),
                ],
              ),
      ),
      actions: [
        DiyalogEylemleri(
          children: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
            FilledButton(
              onPressed: _secili == 0 || _yak.isEmpty
                  ? null
                  : () {
                      final o = _ogrenciler.firstWhere((x) => x.n('id') == _secili);
                      Navigator.pop(context, (id: _secili, yakinlik: _yak, metin: o.s('ad')));
                    },
              child: const Text('Ekle'),
            ),
          ],
        ),
      ],
    );
  }
}

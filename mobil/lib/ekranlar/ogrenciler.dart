import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../bilesenler/ortak.dart';
import '../cekirdek/api.dart';
import '../cekirdek/foto.dart';
import '../cekirdek/takvim_model.dart';
import '../cekirdek/tema.dart';
import 'karne.dart';
import 'notlarim.dart';
import 'ogrencilerim.dart';

const _cinsiyet = {'kiz': 'Kız', 'erkek': 'Erkek'};
const _yemek = {'alacak': 'Yemek alacak', 'almayacak': 'Yemek almayacak'};

void _uyar(BuildContext context, String metin) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(metin)));

(String, String) _bol(String ad) {
  final p = ad.trim().split(RegExp(r'\s+'));
  return p.length > 1 ? (p.sublist(0, p.length - 1).join(' '), p.last) : (ad, '');
}

int _trKarsilastir(String a, String b) {
  String duz(String s) => s
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('İ', 'i')
      .replaceAll('ç', 'c')
      .replaceAll('ğ', 'g')
      .replaceAll('ö', 'o')
      .replaceAll('ş', 's')
      .replaceAll('ü', 'u');
  return duz(a).compareTo(duz(b));
}

/// Öğrenciler (yönetim): liste, süzgeçler, öğrenci dosyası ve kayıt formu.
class OgrencilerEkrani extends StatefulWidget {
  const OgrencilerEkrani({super.key, required this.api});

  final Api api;

  @override
  State<OgrencilerEkrani> createState() => _OgrencilerEkraniState();
}

class _OgrencilerEkraniState extends State<OgrencilerEkrani> {
  int _okul = 0;
  String _sinif = '';
  String _durum = '';
  String _ara = '';
  int _n = 0;

  Future<void> _git(Widget sayfa) async {
    await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => sayfa));
    if (mounted) setState(() => _n++);
  }

  @override
  Widget build(BuildContext context) => VeriSayfasi(
    key: ValueKey(_n),
    baslik: 'Öğrenciler',
    getir: () async => await widget.api.get('/api/ogrenci/liste'),
    cizim: (context, raw) {
      final v = raw as Map<String, dynamic>;
      final subeler = v.l('subeler');
      final siniflar = [
        for (final s in v.l('siniflar'))
          if (_okul == 0 || s.n('subeId') == _okul) s,
      ];
      if (_sinif.isNotEmpty && _sinif != 'yok' && !siniflar.any((s) => '${s.n('id')}' == _sinif)) _sinif = '';
      final q = _ara.trim().toLowerCase();
      final liste =
          [
            for (final o in v.l('ogrenciler'))
              if ((q.isEmpty || o.s('ad').toLowerCase().contains(q) || o.s('okulNo').contains(q)) &&
                  (_durum.isEmpty || o.s('durum') == _durum) &&
                  (_okul == 0 || o.n('subeId') == _okul) &&
                  (_sinif.isEmpty || (_sinif == 'yok' ? o['sinifId'] == null : '${o['sinifId']}' == _sinif)))
                o,
          ]..sort((a, b) {
            final x = _bol(a.s('ad')), y = _bol(b.s('ad'));
            final c = _trKarsilastir(x.$2, y.$2);
            return c != 0 ? c : _trKarsilastir(a.s('ad'), b.s('ad'));
          });
      return [
        TextField(
          decoration: const InputDecoration(hintText: 'Ad ya da okul no ara…', prefixIcon: Icon(Icons.search)),
          onChanged: (x) => setState(() => _ara = x),
        ),
        const SizedBox(height: 10),
        if (subeler.length > 1) ...[
          DropdownButtonFormField<int>(
            initialValue: _okul,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Okul'),
            items: [
              const DropdownMenuItem(value: 0, child: Text('Tüm okullar')),
              for (final s in subeler)
                DropdownMenuItem(
                  value: s.n('id'),
                  child: Text(s.s('ad'), overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (x) => setState(() => _okul = x ?? 0),
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _sinif,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Sınıf'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Tüm sınıflar')),
                  const DropdownMenuItem(value: 'yok', child: Text('Sınıfsız')),
                  for (final s in siniflar)
                    DropdownMenuItem(
                      value: '${s.n('id')}',
                      child: Text(s.s('ad'), overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (x) => setState(() => _sinif = x ?? ''),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _durum,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Durum'),
                items: const [
                  DropdownMenuItem(value: '', child: Text('Tümü')),
                  DropdownMenuItem(value: 'aktif', child: Text('Okuyor')),
                  DropdownMenuItem(value: 'pasif', child: Text('Ayrıldı')),
                ],
                onChanged: (x) => setState(() => _durum = x ?? ''),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Text('${liste.length} öğrenci', style: TextStyle(color: context.soluk)),
            ),
            if (int.tryParse(_sinif) != null)
              TextButton(
                onPressed: () => _git(SinifKarneEkrani(api: widget.api, sinifId: int.parse(_sinif))),
                child: const Text('Sınıf karneleri'),
              ),
            FilledButton(
              onPressed: () => _git(OgrenciFormu(api: widget.api)),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
              child: const Text('+ Yeni öğrenci'),
            ),
          ],
        ),
        if (liste.isEmpty) const BosNot('Gösterilecek öğrenci yok.'),
        for (final o in liste)
          KartKutu(
            onTap: () => _git(OgrenciDosyaEkrani(api: widget.api, id: o.n('id'))),
            child: Row(
              children: [
                KisiAvatari(ad: o.s('ad'), foto: o.s('foto'), api: widget.api),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(o.s('ad'), style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
                      Text(
                        [
                          if (subeler.length > 1) o.s('sube'),
                          o.s('sinif').isEmpty ? 'Sınıfsız' : o.s('sinif'),
                          if (o.s('okulNo').isNotEmpty) 'No ${o.s('okulNo')}',
                        ].join(' · '),
                        style: TextStyle(color: context.soluk, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  flex: 0,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        if (o.s('durum') != 'aktif') const Cip('Ayrıldı'),
                        if (o.s('yemek') == 'almayacak') const Cip('Yemek yok'),
                        if (o.n('ozelSayisi') > 0) Cip('Özel durum', renk: Colors.orange.shade800),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ];
    },
  );
}

/// Bir öğrencinin dosyası: genel durum, sınavlar ve kayıt bilgileri.
class OgrenciDosyaEkrani extends StatefulWidget {
  const OgrenciDosyaEkrani({super.key, required this.api, required this.id});

  final Api api;
  final int id;

  @override
  State<OgrenciDosyaEkrani> createState() => _OgrenciDosyaEkraniState();
}

class _OgrenciDosyaEkraniState extends State<OgrenciDosyaEkrani> {
  String _sekme = 'genel';
  int _n = 0;

  Future<Map<String, dynamic>> _getir() async {
    final api = widget.api;
    final s = await Future.wait([
      api.get('/api/ogrenci/rapor?id=${widget.id}'),
      api.get('/api/ogrenci/kayit?id=${widget.id}'),
      api.get('/api/sinav/ogrenci?id=${widget.id}').catchError((_) => <String, dynamic>{}),
      api.get('/api/ogrenci/teslim?id=${widget.id}').catchError((_) => <String, dynamic>{}),
    ]);
    return {'rapor': s[0], 'kayit': s[1], 'sinav': s[2], 'teslim': s[3]};
  }

  Future<void> _duzenle() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => OgrenciFormu(api: widget.api, id: widget.id),
      ),
    );
    if (mounted) setState(() => _n++);
  }

  Future<void> _durum(Map<String, dynamic> kayit) async {
    final aktif = kayit.m('ogrenci').s('durum') == 'aktif';
    final ad = kayit.m('ogrenci').s('ad');
    if (aktif &&
        !await onayIste(
          context,
          '$ad okuldan ayrıldı olarak işaretlensin mi? Sınıf listelerinden çıkar; not, yoklama ve ödev geçmişi korunur.',
          evet: 'Ayrıldı',
        )) {
      return;
    }
    try {
      await widget.api.post('/api/ogrenci/durum', {'ogrenciId': widget.id, 'durum': aktif ? 'pasif' : 'aktif'});
      if (mounted) setState(() => _n++);
    } catch (e) {
      if (mounted) hataGoster(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => VeriSayfasi(
    key: ValueKey(_n),
    baslik: 'Öğrenci dosyası',
    getir: _getir,
    cizim: (context, raw) {
      final v = raw as Map<String, dynamic>;
      final rapor = v.m('rapor');
      final kayit = v.m('kayit');
      final sinavlar = v.m('sinav').l('sinavlar');
      final duzenleyebilir = kayit['duzenleyebilir'] == true;
      final aktif = kayit.m('ogrenci').s('durum') == 'aktif';
      return [
        Sekmeler(
          secenekler: const [('genel', 'Genel'), ('sinav', 'Sınavlar'), ('teslim', 'Teslim'), ('kayit', 'Kayıt')],
          secili: _sekme,
          degisti: (d) => setState(() => _sekme = d),
        ),
        const SizedBox(height: 8),
        if (!aktif)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Cip('Okuldan ayrıldı', renk: Colors.red.shade700),
          ),
        if (duzenleyebilir)
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              OutlinedButton(onPressed: _duzenle, child: const Text('Düzenle')),
              OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => KarneEkrani(api: widget.api, ogrenciId: widget.id),
                  ),
                ),
                child: const Text('Dönem karnesi'),
              ),
              OutlinedButton(onPressed: () => _durum(kayit), child: Text(aktif ? 'Okuldan ayrıldı' : 'Geri al')),
            ],
          ),
        if (_sekme == 'genel') ..._genel(context, rapor, kayit, sinavlar),
        if (_sekme == 'sinav') ..._sinav(sinavlar),
        if (_sekme == 'teslim') ..._teslim(context, v.m('teslim').l('kayitlar')),
        if (_sekme == 'kayit') ..._kayit(context, kayit),
      ];
    },
  );

  /// Öğrenciyi okuldan kim, ne zaman teslim aldı (gün gün gruplanır).
  List<Widget> _teslim(BuildContext context, List<Map<String, dynamic>> kayitlar) {
    if (kayitlar.isEmpty) return const [BosNot('Henüz teslim kaydı yok.')];
    final cikti = <Widget>[];
    String gun = '';
    for (final k in kayitlar) {
      final z = DateTime.fromMillisecondsSinceEpoch(k.n('zaman'), isUtc: true).add(const Duration(hours: 3));
      final g = uzunTarih(tarihYaz(z));
      if (g != gun) {
        gun = g;
        cikti.add(Baslik(g, ust: 14));
      }
      final alt = [k.s('yakinlik'), if (k.s('guvenlik').isNotEmpty) 'Güvenlik: ${k.s('guvenlik')}'].where((x) => x.isNotEmpty).join(' · ');
      cikti.add(
        KartKutu(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(k.s('kisi'), style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (alt.isNotEmpty) Text(alt, style: TextStyle(color: context.soluk, fontSize: 12.5)),
                  ],
                ),
              ),
              Text('${z.hour.toString().padLeft(2, '0')}:${z.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );
    }
    return cikti;
  }

  List<Widget> _genel(BuildContext context, Map<String, dynamic> rapor, Map<String, dynamic> kayit, List<Map<String, dynamic>> sinavlar) {
    final dv = rapor.m('devam');
    final toplam = dv.n('toplam');
    final yuzde = toplam == 0 ? null : ((toplam - dv.n('gelmedi')) / toplam * 100).round();
    final denemeler = [
      for (final s in sinavlar)
        if (s['yazili'] != true) s,
    ]..sort((a, b) => a.s('tarih').compareTo(b.s('tarih')));
    final son = denemeler.isEmpty ? null : denemeler.last;
    final sira = son == null ? const <String, dynamic>{} : son.m('siralama').m('sinif');
    final bek = rapor.m('bekleyenOdev');
    final notlar = <(String, bool)>[
      for (final x in kayit.l('ozelDurumlar')) ('${x.s('baslik')}${x.s('aciklama').isEmpty ? '' : ' — ${x.s('aciklama')}'}', false),
      if (kayit.m('kayit').s('yemek') == 'almayacak') ('Okul yemeği almıyor.', false),
      if (dv.n('gelmedi') >= 5) ('${dv.n('gelmedi')} ders saati devamsızlığı var.', true),
      if (bek.n('geciken') > 0) ('${bek.n('geciken')} ödevin teslim tarihi geçti.', true),
    ];
    Widget kutu(String deger, String etiket) => Expanded(
      child: KartKutu(
        child: Column(
          children: [
            Text(deger, style: serif.copyWith(fontSize: 20, fontWeight: FontWeight.w700)),
            Text(
              etiket,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.soluk, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
    return [
      const SizedBox(height: 8),
      Row(
        children: [
          kutu(yuzde == null ? '—' : '%$yuzde', 'devam'),
          kutu(son == null ? '—' : '${son.n('ortalama')}', 'son deneme'),
          kutu(sira.isEmpty ? '—' : '${sira.n('sira')}.', 'sınıf sırası'),
          kutu('${bek.n('bekleyen')}', 'bekleyen ödev'),
        ],
      ),
      if (notlar.isNotEmpty) ...[
        const Baslik('Dikkat edilecekler', ust: 8),
        KartKutu(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final n in notlar)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text('• ${n.$1}', style: TextStyle(color: n.$2 ? Colors.red.shade700 : null, height: 1.3)),
                ),
            ],
          ),
        ),
      ],
      for (final d in rapor.l('donemKarsilastirma').where((x) => x.m('devam').n('toplam') > 0 || x.m('odev').n('toplam') > 0)) ...[
        Baslik('Dönem · ${d.s('ad')}', ust: 8),
        KartKutu(
          child: Row(
            children: [
              Expanded(child: Text('Devam ${d.m('devam')['yuzde'] == null ? '—' : '%${d.m('devam')['yuzde']}'}')),
              Expanded(child: Text('Ödev ${d.m('odev')['oran'] == null ? '—' : '%${d.m('odev')['oran']}'}')),
              Text('${d.n('gozlem')} gözlem', style: TextStyle(color: context.soluk)),
            ],
          ),
        ),
      ],
      ...profilIcerik(context, {...rapor, 'veliler': kayit.l('aile')}, rapor),
    ];
  }

  List<Widget> _sinav(List<Map<String, dynamic>> sinavlar) {
    if (sinavlar.isEmpty) return const [BosNot('Yayınlanmış sınav sonucu yok.')];
    return [const SizedBox(height: 8), if (sinavlar.length > 1) SinavGelisimi(sinavlar), for (final (i, s) in sinavlar.indexed) SinavKarti(s, acik: i == 0)];
  }

  List<Widget> _kayit(BuildContext context, Map<String, dynamic> kayit) {
    final o = kayit.m('ogrenci'), y = kayit.m('kayit'), i = kayit.m('iletisim');
    final dogum = y.s('dogumTarihi').isEmpty
        ? (y.s('dogumYeri').isEmpty ? '—' : y.s('dogumYeri'))
        : '${uzunTarih(y.s('dogumTarihi'))}${y.s('dogumYeri').isEmpty ? '' : ' · ${y.s('dogumYeri')}'}';
    final kayitTuru = kayit.m('secenekler').m('kayitTuru')[y.s('kayitTuru')]?.toString() ?? '';
    final adres = [i.s('adres'), i.s('ilce'), i.s('il')].where((e) => e.isNotEmpty).join(', ');
    final ozelTur = kayit.m('secenekler').m('ozelTur');
    return [
      const Baslik('Öğrenci', ust: 8),
      KartKutu(
        child: Column(
          children: [
            _Sat(o.s('kimlikTuru'), o.s('kimlik')),
            _Sat('Okul', o.s('sube')),
            _Sat('Sınıf', o.s('sinif').isEmpty ? 'Sınıfsız' : o.s('sinif')),
            _Sat('Okul no', o.s('okulNo')),
            _Sat('Doğum', dogum),
            _Sat('Cinsiyet', _cinsiyet[y.s('cinsiyet')] ?? ''),
            _Sat('Kan grubu', y.s('kanGrubu')),
            _Sat('Kayıt', [kayitTuru, if (y.s('kayitTarihi').isNotEmpty) uzunTarih(y.s('kayitTarihi'))].where((e) => e.isNotEmpty).join(' · ')),
            if (y.s('oncekiOkul').isNotEmpty) _Sat('Önceki okul', y.s('oncekiOkul')),
            _Sat('Yemek', _yemek[y.s('yemek')] ?? 'Belirtilmemiş'),
          ],
        ),
      ),
      const Baslik('Özel durum', ust: 8),
      if (kayit.l('ozelDurumlar').isEmpty) const BosNot('Kayıtlı özel durum yok.'),
      for (final x in kayit.l('ozelDurumlar'))
        KartKutu(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(x.s('baslik'), style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (x.s('aciklama').isNotEmpty) Text(x.s('aciklama'), style: TextStyle(color: context.soluk, fontSize: 13)),
                  ],
                ),
              ),
              Cip(ozelTur[x.s('tur')]?.toString() ?? x.s('tur')),
            ],
          ),
        ),
      const Baslik('Aile ve iletişim', ust: 8),
      KartKutu(
        child: Column(
          children: [
            if (kayit.l('aile').isEmpty) Text('Bağlı veli kaydı yok.', style: TextStyle(color: context.soluk)),
            for (final v in kayit.l('aile')) _Sat('${v.s('yakinlik').isEmpty ? 'Veli' : v.s('yakinlik')} · ${v.s('ad')}', v.s('telefon')),
            if (i.s('yakinAd').isNotEmpty)
              _Sat('Acil · ${i.s('yakinAd')}${i.s('yakinYakinlik').isEmpty ? '' : ' (${i.s('yakinYakinlik')})'}', i.s('yakinTelefon')),
            _Sat('Öğrenci telefonu', o.s('telefon')),
            if (i.s('email').isNotEmpty) _Sat('E-posta', i.s('email')),
            if (adres.isNotEmpty) _Sat('Adres', adres),
          ],
        ),
      ),
    ];
  }
}

class _Sat extends StatelessWidget {
  const _Sat(this.etiket, this.deger);

  final String etiket;
  final String deger;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(etiket, style: TextStyle(color: context.soluk, fontSize: 13.5)),
        ),
        Expanded(
          flex: 5,
          child: Text(
            deger.isEmpty ? '—' : deger,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _VeliSatir {
  _VeliSatir({this.uyelikId, this.yakinlik = '', String ad = '', String telefon = '', String eposta = '', String meslek = ''})
    : ad = TextEditingController(text: ad),
      kimlik = TextEditingController(),
      telefon = TextEditingController(text: telefon),
      eposta = TextEditingController(text: eposta),
      meslek = TextEditingController(text: meslek);

  final int? uyelikId;
  String yakinlik;
  final TextEditingController ad, kimlik, telefon, eposta, meslek;

  bool get kayitli => uyelikId != null;
  bool get bos => !kayitli && [ad, telefon, kimlik, eposta].every((c) => c.text.trim().isEmpty);

  void kapat() {
    for (final c in [ad, kimlik, telefon, eposta, meslek]) {
      c.dispose();
    }
  }

  Map<String, dynamic> veri() => {
    'yakinlik': yakinlik,
    'ad': ad.text,
    'kimlik': kimlik.text,
    'telefon': telefon.text,
    'email': eposta.text,
    'meslek': meslek.text,
  };
}

class _OzelSatir {
  _OzelSatir({this.id, this.tur = 'saglik', String baslik = '', String aciklama = ''})
    : baslik = TextEditingController(text: baslik),
      aciklama = TextEditingController(text: aciklama);

  final int? id;
  String tur;
  final TextEditingController baslik, aciklama;

  void kapat() {
    baslik.dispose();
    aciklama.dispose();
  }
}

/// Öğrenci kayıt formu: yeni kayıt ya da (id verilirse) kayıt bilgilerini düzenleme.
class OgrenciFormu extends StatefulWidget {
  const OgrenciFormu({super.key, required this.api, this.id});

  final Api api;
  final int? id;

  @override
  State<OgrenciFormu> createState() => _OgrenciFormuState();
}

class _OgrenciFormuState extends State<OgrenciFormu> {
  Map<String, dynamic>? _d;
  Object? _hata;
  bool _mesgul = false;
  final _c = <String, TextEditingController>{};
  final _veliler = <_VeliSatir>[];
  final _ozeller = <_OzelSatir>[];
  int _sube = 0;
  int? _sinif;
  int _userId = 0;
  String _mevcutFoto = '';
  Uint8List? _foto;
  String _cinsiyetD = '', _kan = '', _kayitTuru = 'yeni', _yemekD = '', _yakinlik = '';

  bool get _duzenleme => widget.id != null;

  TextEditingController _k(String ad, [String? deger]) => _c.putIfAbsent(ad, () => TextEditingController(text: deger ?? ''));
  String _t(String ad) => (_c[ad]?.text ?? '').trim();

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    for (final v in _veliler) {
      v.kapat();
    }
    for (final o in _ozeller) {
      o.kapat();
    }
    super.dispose();
  }

  Future<void> _yukle() async {
    try {
      final d = await widget.api.get('/api/ogrenci/kayit${_duzenleme ? '?id=${widget.id}' : ''}') as Map<String, dynamic>;
      final o = d.m('ogrenci'), y = d.m('kayit'), i = d.m('iletisim');
      final subeler = d.l('subeler');
      _userId = o.n('userId');
      _mevcutFoto = o.s('foto');
      _sube = _duzenleme ? o.n('subeId') : (subeler.isEmpty ? 0 : subeler.first.n('id'));
      _sinif = _duzenleme && o['sinifId'] != null ? o.n('sinifId') : null;
      _k('ad', o.s('ad'));
      _k('telefon', o.s('telefon'));
      _k('okulNo', o.s('okulNo'));
      _k('kimlik');
      _k('dogumTarihi', y.s('dogumTarihi'));
      _k('dogumYeri', y.s('dogumYeri'));
      _k('kayitTarihi', y.s('kayitTarihi').isNotEmpty ? y.s('kayitTarihi') : (_duzenleme ? '' : tarihYaz(DateTime.now())));
      _k('oncekiOkul', y.s('oncekiOkul'));
      _k('email', i.s('email'));
      _k('il', i.s('il'));
      _k('ilce', i.s('ilce'));
      _k('adres', i.s('adres'));
      _k('yakinAd', i.s('yakinAd'));
      _k('yakinTelefon', i.s('yakinTelefon'));
      _cinsiyetD = y.s('cinsiyet');
      _kan = y.s('kanGrubu');
      _kayitTuru = y.s('kayitTuru').isEmpty ? 'yeni' : y.s('kayitTuru');
      _yemekD = y.s('yemek');
      _yakinlik = i.s('yakinYakinlik');
      for (final v in d.l('aile')) {
        _veliler.add(
          _VeliSatir(uyelikId: v.n('uyelikId'), yakinlik: v.s('yakinlik'), ad: v.s('ad'), telefon: v.s('telefon'), eposta: v.s('email'), meslek: v.s('meslek')),
        );
      }
      if (!_duzenleme) _veliler.add(_VeliSatir(yakinlik: 'Anne'));
      for (final x in d.l('ozelDurumlar')) {
        _ozeller.add(_OzelSatir(id: x.n('id'), tur: x.s('tur'), baslik: x.s('baslik'), aciklama: x.s('aciklama')));
      }
      if (mounted) setState(() => _d = d);
    } catch (e) {
      if (mounted) setState(() => _hata = e);
    }
  }

  Future<void> _tarihSec(String ad) async {
    final bugun = DateTime.now();
    final mevcut = _t(ad).isEmpty ? null : tarihCoz(_t(ad));
    final s = await showDatePicker(
      context: context,
      initialDate: mevcut ?? (ad == 'dogumTarihi' ? DateTime(bugun.year - 10) : bugun),
      firstDate: DateTime(1990),
      lastDate: ad == 'dogumTarihi' ? bugun : DateTime(bugun.year + 2),
    );
    if (s != null) setState(() => _k(ad).text = tarihYaz(s));
  }

  Future<void> _kaydet() async {
    if (_t('ad').isEmpty || (!_duzenleme && _t('kimlik').isEmpty) || _t('telefon').isEmpty) {
      _uyar(context, 'Ad soyad, kimlik numarası ve telefon gerekli.');
      return;
    }
    if (_yemekD.isEmpty) {
      _uyar(context, 'Yemek tercihini seçin: yemek alacak ya da almayacak.');
      return;
    }
    setState(() => _mesgul = true);
    final api = widget.api;
    try {
      final govde = <String, dynamic>{
        'id': widget.id,
        'subeId': _sube,
        'sinifId': _sinif,
        for (final a in [
          'ad',
          'telefon',
          'okulNo',
          'dogumTarihi',
          'dogumYeri',
          'kayitTarihi',
          'oncekiOkul',
          'email',
          'il',
          'ilce',
          'adres',
          'yakinAd',
          'yakinTelefon',
        ])
          a: _t(a),
        'cinsiyet': _cinsiyetD,
        'kanGrubu': _kan,
        'kayitTuru': _kayitTuru,
        'yemek': _yemekD,
        'yakinYakinlik': _yakinlik,
      };
      if (!_duzenleme) {
        govde['kimlik'] = _t('kimlik');
        govde['aile'] = [for (final v in _veliler.where((v) => !v.bos)) v.veri()];
        govde['ozelDurumlar'] = [
          for (final o in _ozeller.where((o) => o.baslik.text.trim().isNotEmpty)) {'tur': o.tur, 'baslik': o.baslik.text, 'aciklama': o.aciklama.text},
        ];
      }
      final kayitSonuc = await api.post('/api/ogrenci/kaydet', govde) as Map<String, dynamic>?;
      if (_duzenleme) {
        for (final v in _veliler.where((v) => !v.bos)) {
          if (v.kayitli) {
            await api.post('/api/ogrenci/veli-guncelle', {'ogrenciId': widget.id, 'veliUyelikId': v.uyelikId, 'yakinlik': v.yakinlik, 'meslek': v.meslek.text});
          } else {
            await api.post('/api/ogrenci/veli-ekle', {'ogrenciId': widget.id, ...v.veri()});
          }
        }
        for (final o in _ozeller.where((o) => o.baslik.text.trim().isNotEmpty)) {
          await api.post('/api/ogrenci/ozel-durum-kaydet', {
            'ogrenciId': widget.id,
            'id': o.id,
            'tur': o.tur,
            'baslik': o.baslik.text,
            'aciklama': o.aciklama.text,
          });
        }
      }
      final foto = _foto;
      final userId = (kayitSonuc?['userId'] as num?)?.toInt() ?? _userId;
      if (foto != null && userId > 0) {
        try {
          await api.postBayt('/api/foto?id=$userId', foto);
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Öğrenci kaydedildi ancak fotoğraf yüklenemedi. Düzenleme ekranından yeniden deneyebilirsiniz.')));
          }
        }
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _mesgul = false);
        hataGoster(context, e);
      }
    }
  }

  Future<void> _veliKaldir(_VeliSatir v) async {
    if (v.kayitli) {
      if (!await onayIste(context, '${v.ad.text} bu öğrencinin velilerinden çıkarılsın mı? (Hesabı silinmez, yalnızca bağ kalkar.)', evet: 'Kaldır')) return;
      try {
        await widget.api.post('/api/ogrenci/veli-cikar', {'ogrenciId': widget.id, 'veliUyelikId': v.uyelikId});
      } catch (e) {
        if (mounted) hataGoster(context, e);
        return;
      }
    }
    setState(() => _veliler.remove(v));
  }

  Future<void> _ozelKaldir(_OzelSatir o) async {
    if (o.id != null) {
      if (!await onayIste(context, 'Bu özel durum kaydı silinsin mi?', evet: 'Sil')) return;
      try {
        await widget.api.post('/api/ogrenci/ozel-durum-sil', {'ogrenciId': widget.id, 'id': o.id});
      } catch (e) {
        if (mounted) hataGoster(context, e);
        return;
      }
    }
    setState(() => _ozeller.remove(o));
  }

  Future<void> _fotoSec() async {
    try {
      final bayt = await galeridenFotoSec();
      if (bayt != null && mounted) setState(() => _foto = bayt);
    } catch (e) {
      if (mounted) hataGoster(context, e);
    }
  }

  Widget _fotoBolumu() {
    final ad = _t('ad');
    final fotoVar = _foto != null || _mevcutFoto.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: context.icZemin,
            foregroundImage: _foto != null
                ? MemoryImage(_foto!)
                : (_mevcutFoto.isEmpty ? null : NetworkImage('${Api.taban}$_mevcutFoto', headers: widget.api.kimlik) as ImageProvider),
            child: Text(ad.isEmpty ? '?' : ad.characters.first.toUpperCase(), style: serif.copyWith(fontSize: 24)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton(onPressed: _fotoSec, child: Text(fotoVar ? 'Fotoğrafı değiştir' : 'Fotoğraf ekle')),
                Text('Vesikalık ya da yüzün net göründüğü bir fotoğraf.', style: TextStyle(color: context.soluk, fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _alan(String etiket, String ad, {TextInputType? tip, int? uzunluk, String? ipucu}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: _k(ad),
      keyboardType: tip,
      maxLength: uzunluk,
      decoration: InputDecoration(labelText: etiket, hintText: ipucu, counterText: ''),
    ),
  );

  Widget _tarih(String etiket, String ad) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: _k(ad),
      readOnly: true,
      onTap: () => _tarihSec(ad),
      decoration: InputDecoration(labelText: etiket, suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18)),
    ),
  );

  Widget _liste(String etiket, String deger, Map<String, String> secenek, ValueChanged<String> degisti, {String? bos}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: DropdownButtonFormField<String>(
      initialValue: secenek.containsKey(deger) || bos != null ? deger : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: etiket),
      items: [
        if (bos != null) DropdownMenuItem(value: '', child: Text(bos)),
        for (final e in secenek.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
      ],
      onChanged: (x) => setState(() => degisti(x ?? '')),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final baslik = _duzenleme ? 'Kayıt bilgilerini düzenle' : 'Yeni öğrenci';
    final d = _d;
    if (d == null) {
      return Scaffold(
        appBar: AppBar(title: Text(baslik)),
        body: Center(
          child: _hata == null
              ? const CircularProgressIndicator()
              : Padding(padding: const EdgeInsets.all(24), child: Text(_hata is ApiHata ? (_hata as ApiHata).mesaj : 'Yüklenemedi.')),
        ),
      );
    }
    final sec = d.m('secenekler');
    final yakinlar = {for (final x in (sec['yakinlik'] as List? ?? const [])) '$x': '$x'};
    final kanlar = {for (final x in (sec['kanGrubu'] as List? ?? const [])) '$x': '$x'};
    final ozelTur = {for (final e in sec.m('ozelTur').entries) e.key: '${e.value}'};
    final kayitTuru = {for (final e in sec.m('kayitTuru').entries) e.key: '${e.value}'};
    final subeler = d.l('subeler');
    final siniflar = [
      for (final s in d.l('siniflar'))
        if (s.n('subeId') == _sube) s,
    ];
    final sinifDeger = siniflar.any((s) => s.n('id') == _sinif) ? _sinif : null;
    return Scaffold(
      appBar: AppBar(title: Text(baslik)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const Baslik('Öğrenci', ust: 4),
          _fotoBolumu(),
          _alan('Ad soyad *', 'ad', uzunluk: 80),
          if (!_duzenleme) _alan('T.C. / pasaport no *', 'kimlik', uzunluk: 20) else _alan(d.m('ogrenci').s('kimlikTuru'), 'kimlikGoster'),
          _alan('Öğrenci / yakın telefonu *', 'telefon', tip: TextInputType.phone, uzunluk: 20, ipucu: '5XX XXX XX XX'),
          _alan('Okul no (boşsa otomatik)', 'okulNo', tip: TextInputType.number, uzunluk: 10),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DropdownButtonFormField<int>(
              initialValue: _sube == 0 ? null : _sube,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Okul *'),
              items: [
                for (final s in subeler)
                  DropdownMenuItem(
                    value: s.n('id'),
                    child: Text(s.s('ad'), overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: _duzenleme
                  ? null
                  : (x) => setState(() {
                      _sube = x ?? _sube;
                      _sinif = null;
                    }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DropdownButtonFormField<int?>(
              initialValue: sinifDeger,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Sınıf'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Sınıfsız (sonra atanır)')),
                for (final s in siniflar)
                  DropdownMenuItem<int?>(
                    value: s.n('id'),
                    child: Text('${s.s('kademe')} · ${s.s('ad')}', overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (x) => setState(() => _sinif = x),
            ),
          ),
          _tarih('Doğum tarihi', 'dogumTarihi'),
          _alan('Doğum yeri', 'dogumYeri', uzunluk: 60),
          _liste('Cinsiyet', _cinsiyetD, _cinsiyet, (x) => _cinsiyetD = x, bos: 'Seçin'),
          _liste('Kan grubu', _kan, kanlar, (x) => _kan = x, bos: 'Bilinmiyor'),
          _liste('Kayıt türü', _kayitTuru, kayitTuru, (x) => _kayitTuru = x),
          _tarih('Kayıt tarihi', 'kayitTarihi'),
          _alan('Önceki okul', 'oncekiOkul', uzunluk: 100),
          const Baslik('Yemek'),
          Wrap(
            spacing: 8,
            children: [
              for (final e in _yemek.entries) ChoiceChip(label: Text(e.value), selected: _yemekD == e.key, onSelected: (_) => setState(() => _yemekD = e.key)),
            ],
          ),
          Baslik('Özel durum', ust: 16),
          Text(
            'Sağlık, alerji ya da özel eğitim gibi bilinmesi gereken bir durum varsa ekleyin; yoksa boş bırakın.',
            style: TextStyle(color: context.soluk, fontSize: 12.5),
          ),
          for (final o in _ozeller)
            KartKutu(
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Özel durum', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      TextButton(onPressed: () => _ozelKaldir(o), child: const Text('Kaldır')),
                    ],
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: ozelTur.containsKey(o.tur) ? o.tur : null,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Tür'),
                    items: [for (final e in ozelTur.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                    onChanged: (x) => setState(() => o.tur = x ?? o.tur),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: o.baslik,
                    maxLength: 80,
                    decoration: const InputDecoration(labelText: 'Başlık', hintText: 'Örn. Fıstık alerjisi', counterText: ''),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: o.aciklama,
                    maxLength: 500,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Açıklama', counterText: ''),
                  ),
                ],
              ),
            ),
          TextButton(
            onPressed: () {
              if (_ozeller.length >= 10) return _uyar(context, 'En çok 10 özel durum eklenebilir.');
              setState(() => _ozeller.add(_OzelSatir(tur: ozelTur.keys.isEmpty ? 'saglik' : ozelTur.keys.first)));
            },
            child: const Text('+ Özel durum ekle'),
          ),
          const Baslik('Adres ve acil durum', ust: 12),
          _alan('E-posta', 'email', tip: TextInputType.emailAddress, uzunluk: 120),
          _alan('İl', 'il', uzunluk: 40),
          _alan('İlçe', 'ilce', uzunluk: 40),
          _alan('Adres', 'adres', uzunluk: 250),
          _alan('Acil durumda aranacak kişi', 'yakinAd', uzunluk: 80),
          _liste('Yakınlığı', _yakinlik, yakinlar, (x) => _yakinlik = x, bos: 'Seçin'),
          _alan('Acil durum telefonu', 'yakinTelefon', tip: TextInputType.phone, uzunluk: 20, ipucu: '5XX XXX XX XX'),
          const Baslik('Aile (veli hesapları)', ust: 12),
          Text(
            'Veliler kimlik numarası ve telefonlarıyla giriş yapar; aynı veli birden fazla çocuğa bağlanabilir.',
            style: TextStyle(color: context.soluk, fontSize: 12.5),
          ),
          for (final v in _veliler)
            KartKutu(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(v.kayitli ? v.ad.text : 'Yeni kişi', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      TextButton(onPressed: () => _veliKaldir(v), child: Text(v.kayitli ? 'Bağı kaldır' : 'Kaldır')),
                    ],
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: yakinlar.containsKey(v.yakinlik) ? v.yakinlik : null,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Yakınlık'),
                    hint: const Text('Yakınlık seçin'),
                    items: [for (final e in yakinlar.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                    onChanged: (x) => setState(() => v.yakinlik = x ?? ''),
                  ),
                  if (!v.kayitli) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: v.ad,
                      maxLength: 80,
                      decoration: const InputDecoration(labelText: 'Ad soyad', counterText: ''),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: v.kimlik,
                      keyboardType: TextInputType.number,
                      maxLength: 20,
                      decoration: const InputDecoration(labelText: 'T.C. / pasaport no', counterText: ''),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: v.telefon,
                      keyboardType: TextInputType.phone,
                      maxLength: 20,
                      decoration: const InputDecoration(labelText: 'Telefon', hintText: '5XX XXX XX XX', counterText: ''),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: v.eposta,
                      keyboardType: TextInputType.emailAddress,
                      maxLength: 120,
                      decoration: const InputDecoration(labelText: 'E-posta', counterText: ''),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    controller: v.meslek,
                    maxLength: 60,
                    decoration: const InputDecoration(labelText: 'Meslek', counterText: ''),
                  ),
                ],
              ),
            ),
          TextButton(
            onPressed: () {
              if (_veliler.length >= (_duzenleme ? 6 : 4)) return _uyar(context, 'Daha fazla kişi eklenemez.');
              setState(() => _veliler.add(_VeliSatir()));
            },
            child: const Text('+ Veli / yakın ekle'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _mesgul ? null : _kaydet,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: Text(_mesgul ? 'Kaydediliyor…' : (_duzenleme ? 'Değişiklikleri kaydet' : 'Öğrenciyi kaydet')),
          ),
        ],
      ),
    );
  }
}

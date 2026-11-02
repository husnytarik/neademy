import 'package:flutter/material.dart';

import '../bilesenler/ortak.dart';
import '../cekirdek/api.dart';
import '../cekirdek/foto.dart';
import '../cekirdek/tema.dart';

const _sayiAdlari = [
  ('sinif', 'Sınıf'),
  ('ogrenci', 'Öğrenci'),
  ('ogretmen', 'Öğretmen'),
  ('veli', 'Veli'),
  ('yeniKayit', 'Yeni kayıt'),
  ('yenileme', 'Yenileme'),
  ('nakil', 'Nakil'),
  ('kayitsiz', 'Kayıtsız'),
];

int _topla(List<Map<String, dynamic>> okullar, String k) => okullar.fold(0, (a, o) => a + o.n(k));

List<Map<String, dynamic>> _tumOkullar(Map<String, dynamic> v) => [for (final c in v.l('kampusler')) ...c.l('okullar')];

String _sade(String ad) => ad.replaceAll(RegExp(r'\s+kampüsü$', caseSensitive: false), '');

Widget _sayilar(BuildContext context, List<Map<String, dynamic>> okullar, {int? kampus}) {
  final yoklama = _topla(okullar, 'yoklamaToplam');
  final gelmedi = _topla(okullar, 'gelmedi');
  final parcalar = <(String, String)>[
    if (kampus != null) ('Kampüs', '$kampus'),
    ('Okul', '${okullar.length}'),
    for (final (k, ad) in _sayiAdlari) (ad, '${_topla(okullar, k)}'),
    if (yoklama > 0) ('Devamsızlık', '%${(gelmedi * 100 / yoklama).toStringAsFixed(1)}'),
  ];
  return Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final (ad, deger) in parcalar)
        Container(
          width: 92,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          decoration: BoxDecoration(color: context.icZemin, borderRadius: BorderRadius.circular(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(deger, style: serif.copyWith(fontSize: 20, fontWeight: FontWeight.w600)),
              Text(ad, style: TextStyle(color: context.soluk, fontSize: 12)),
            ],
          ),
        ),
    ],
  );
}

Widget _bilgi(BuildContext context, List<(String, String)> satirlar) {
  final dolu = [
    for (final s in satirlar)
      if (s.$2.trim().isNotEmpty) s,
  ];
  if (dolu.isEmpty) return const SizedBox.shrink();
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final (ad, deger) in dolu)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 78,
                child: Text(ad, style: TextStyle(color: context.soluk, fontSize: 13)),
              ),
              Expanded(child: Text(deger, style: const TextStyle(fontSize: 14))),
            ],
          ),
        ),
    ],
  );
}

List<(String, String)> _tanitimSatirlari(Map<String, dynamic> x, Map<String, dynamic> v) {
  final sosyal = ((x['sosyal'] as Map?) ?? const {}).cast<String, dynamic>();
  final adlar = {for (final a in v.l('sosyalAlanlar')) a.s('kod'): a.s('ad')};
  return [
    ('Web', x.s('web')),
    for (final e in sosyal.entries)
      if ('${e.value}'.isNotEmpty) (adlar[e.key] ?? e.key, '${e.value}'),
  ];
}

Widget _tanitim(BuildContext context, Map<String, dynamic> x, Map<String, dynamic> v) {
  final satirlar = _tanitimSatirlari(x, v);
  final aciklama = x.s('aciklama');
  if (satirlar.every((s) => s.$2.isEmpty) && aciklama.isEmpty) return const SizedBox.shrink();
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (aciklama.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 6),
          child: Text(aciklama, style: const TextStyle(height: 1.4)),
        ),
      _bilgi(context, satirlar),
    ],
  );
}

Widget _logoKutusu(BuildContext context, String ad, {Api? api, String? yol, double boyut = 46}) {
  final harf = Text(
    ad.isEmpty ? '?' : ad.trim().characters.first.toUpperCase(),
    style: serif.copyWith(fontSize: boyut * .43, fontWeight: FontWeight.w600, color: context.ana),
  );
  return Container(
    width: boyut,
    height: boyut,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(color: context.ana.withValues(alpha: .14), shape: BoxShape.circle),
    alignment: Alignment.center,
    child: api == null || yol == null
        ? harf
        : Image.network('${Api.taban}$yol', headers: api.kimlik, width: boyut, height: boyut, fit: BoxFit.contain, errorBuilder: (_, _, _) => harf),
  );
}

String? _okulLogoYolu(Map<String, dynamic> o) => o.s('logo').isEmpty ? null : '/api/okul-logo?id=${o.n('id')}&v=${o.s('logo')}';

/// Kurum ya da okul logosunu gösterir; yükleme ve kaldırma düğmeleri. Değişince sayfa kapanıp liste yenilenir.
class _LogoAlani extends StatefulWidget {
  const _LogoAlani({required this.api, required this.ad, required this.yol, required this.yukle, required this.sil});

  final Api api;
  final String ad;
  final String? yol;
  final String yukle;
  final String sil;

  @override
  State<_LogoAlani> createState() => _LogoAlaniState();
}

class _LogoAlaniState extends State<_LogoAlani> {
  Future<void> _yukle() async {
    try {
      final bayt = await galeridenLogoSec();
      if (bayt == null) {
        return;
      }
      await widget.api.postBayt(widget.yukle, bayt, tur: 'image/png');
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        hataGoster(context, e);
      }
    }
  }

  Future<void> _kaldir() async {
    try {
      await widget.api.post(widget.sil, {});
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        hataGoster(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        _logoKutusu(context, widget.ad, api: widget.api, yol: widget.yol, boyut: 64),
        const SizedBox(width: 14),
        Expanded(
          child: Wrap(
            spacing: 8,
            children: [
              OutlinedButton(onPressed: _yukle, child: Text(widget.yol == null ? 'Logo ekle' : 'Logoyu değiştir')),
              if (widget.yol != null) TextButton(onPressed: _kaldir, child: const Text('Kaldır')),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _okulSatiri(BuildContext context, Api api, Map<String, dynamic> o, VoidCallback ac) {
  final mudur = o.l('yoneticiler').where((y) => y.s('gorev') == 'mudur').firstOrNull;
  final alt = [o.s('tur'), if (o.n('sinif') > 0) '${o.n('sinif')} sınıf', '${o.n('ogrenci')} öğrenci'].where((e) => e.isNotEmpty).join(' · ');
  return KartKutu(
    onTap: ac,
    child: Row(
      children: [
        _logoKutusu(context, o.s('ad'), api: api, yol: _okulLogoYolu(o)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(o.s('ad'), style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
              Text(alt, style: TextStyle(color: context.soluk, fontSize: 12.5)),
              Text(
                mudur != null ? 'Müdür: ${mudur.s('ad')}' : 'Müdür atanmadı',
                style: TextStyle(color: mudur != null ? context.ana : context.soluk, fontSize: 12.5),
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right, color: context.soluk),
      ],
    ),
  );
}

Widget _yoneticiler(BuildContext context, Map<String, dynamic> o, Map<String, dynamic> v, {Future<void> Function(Map<String, dynamic>)? kaldir}) {
  final gorevler = ((v['gorevler'] as Map?) ?? const {}).cast<String, dynamic>();
  final liste = o.l('yoneticiler');
  final sirali = [...liste.where((y) => y.s('gorev') == 'mudur'), ...liste.where((y) => y.s('gorev') != 'mudur')];
  if (liste.isEmpty) return const BosNot('Henüz müdür ya da müdür yardımcısı atanmadı.');
  return Column(
    children: [
      for (final y in sirali)
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: _logoKutusu(context, y.s('ad')),
          title: Text(y.s('ad')),
          subtitle: Text([gorevler[y.s('gorev')] ?? y.s('gorev'), y.s('telefon')].where((e) => '$e'.isNotEmpty).join(' · ')),
          trailing: kaldir == null
              ? null
              : TextButton(
                  onPressed: () => kaldir(y),
                  child: Text('Kaldır', style: TextStyle(color: Colors.red.shade600)),
                ),
        ),
    ],
  );
}

Widget _zumreler(BuildContext context, Map<String, dynamic> o) {
  final z = o.l('zumreler');
  final g = o.l('gorevliler');
  if (z.isEmpty && g.isEmpty) return const SizedBox.shrink();
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (z.isNotEmpty) ...[
        const Baslik('Zümreler'),
        for (final x in z)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Expanded(child: Text(x.s('brans'))),
                Text(
                  '${x.n('ogretmen')} öğretmen${x.s('baskan').isEmpty ? '' : ' · ${x.s('baskan')}'}',
                  style: TextStyle(color: context.soluk, fontSize: 12.5),
                ),
              ],
            ),
          ),
      ],
      if (g.isNotEmpty) ...[
        const Baslik('Görevliler'),
        for (final x in g)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Expanded(child: Text(x.s('ad'))),
                Flexible(
                  child: Text(
                    x.s('gorev'),
                    textAlign: TextAlign.end,
                    style: TextStyle(color: context.soluk, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
      ],
    ],
  );
}

/// Gezinme kabuğu: veriyi sunucudan alır, değişince `yenile` ile tazelenir.
class _Sayfa extends StatefulWidget {
  const _Sayfa({required this.api, required this.baslik, required this.cizim});

  final Api api;
  final String baslik;
  final List<Widget> Function(BuildContext context, Map<String, dynamic> v, VoidCallback yenile) cizim;

  @override
  State<_Sayfa> createState() => _SayfaState();
}

class _SayfaState extends State<_Sayfa> {
  int _n = 0;

  @override
  Widget build(BuildContext context) => VeriSayfasi(
    key: ValueKey(_n),
    baslik: widget.baslik,
    getir: () => widget.api.get('/api/yonetim/kurum'),
    cizim: (context, v) => widget.cizim(context, v as Map<String, dynamic>, () => setState(() => _n++)),
  );
}

Future<bool> _ac(BuildContext context, Widget sayfa) async => (await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => sayfa))) == true;

// ---------------------------------------------------------------------------------------------
// Kampüs ve okullar: salt okunur özet

class KampuslerEkrani extends StatelessWidget {
  const KampuslerEkrani({super.key, required this.api});

  final Api api;

  @override
  Widget build(BuildContext context) => _Sayfa(
    api: api,
    baslik: 'Kampüs ve okullar',
    cizim: (context, v, yenile) {
      final k = (v['kurum'] as Map).cast<String, dynamic>();
      final okullar = _tumOkullar(v);
      final kampusler = v.l('kampusler');
      final kurucu = v.l('kurucular').map((c) => c.s('ad')).join(', ');
      return [
        KartKutu(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(k.s('ad'), style: serif.copyWith(fontSize: 21, fontWeight: FontWeight.w600)),
              Text(
                '${kampusler.length} kampüs · ${okullar.length} okul${kurucu.isEmpty ? '' : ' · Kurucu: $kurucu'}',
                style: TextStyle(color: context.soluk, fontSize: 13),
              ),
              const SizedBox(height: 12),
              _sayilar(context, okullar, kampus: kampusler.length),
              _tanitim(context, k, v),
            ],
          ),
        ),
        if (kampusler.isEmpty) const BosNot('Henüz kampüs eklenmedi.'),
        for (final c in kampusler) ...[
          Baslik('${c.s('ad')} · ${c.l('okullar').length} okul'),
          for (final o in c.l('okullar')) _okulSatiri(context, api, o, () => _ac(context, _OkulOzeti(api: api, okulId: o.n('id')))),
          if (c.l('okullar').isEmpty) const BosNot('Bu kampüse henüz okul eklenmedi.'),
        ],
      ];
    },
  );
}

class _OkulOzeti extends StatelessWidget {
  const _OkulOzeti({required this.api, required this.okulId});

  final Api api;
  final int okulId;

  @override
  Widget build(BuildContext context) => _Sayfa(
    api: api,
    baslik: 'Okul',
    cizim: (context, v, yenile) {
      final o = _tumOkullar(v).where((x) => x.n('id') == okulId).firstOrNull;
      if (o == null) return const [BosNot('Okul bulunamadı.')];
      return [
        KartKutu(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(o.s('ad'), style: serif.copyWith(fontSize: 21, fontWeight: FontWeight.w600)),
              if (o.s('tur').isNotEmpty) Text(o.s('tur'), style: TextStyle(color: context.soluk)),
              const SizedBox(height: 12),
              _sayilar(context, [o]),
              const SizedBox(height: 8),
              _bilgi(context, [('Kurum kodu', o.s('kurumKodu')), ('Telefon', o.s('telefon')), ('E-posta', o.s('eposta')), ('Adres', o.s('adres'))]),
              _tanitim(context, o, v),
              const Baslik('Okul yönetimi'),
              _yoneticiler(context, o, v),
              _zumreler(context, o),
            ],
          ),
        ),
      ];
    },
  );
}

// ---------------------------------------------------------------------------------------------
// Kurum ve okul kurulumu: düzenlenebilir

class KurumEkrani extends StatefulWidget {
  const KurumEkrani({super.key, required this.api});

  final Api api;

  @override
  State<KurumEkrani> createState() => _KurumEkraniState();
}

class _KurumEkraniState extends State<KurumEkrani> {
  int _kampus = 0; // 0 = Kurum sekmesi
  int _n = 0;

  Api get api => widget.api;

  Future<void> _ekran(Widget sayfa) async {
    if (await _ac(context, sayfa) && mounted) setState(() => _n++);
  }

  @override
  Widget build(BuildContext context) => VeriSayfasi(
    key: ValueKey(_n),
    baslik: 'Okul kurulumu',
    getir: () => api.get('/api/yonetim/kurum'),
    cizim: (context, raw) {
      final v = raw as Map<String, dynamic>;
      final yonetim = v['kurumYonetimi'] == true;
      final kampusler = v.l('kampusler');
      final c = kampusler.where((x) => x.n('id') == _kampus).firstOrNull;
      return [
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _Pil('Kurum', c == null, () => setState(() => _kampus = 0)),
              for (final x in kampusler) _Pil(_sade(x.s('ad')), c?.n('id') == x.n('id'), () => setState(() => _kampus = x.n('id'))),
              if (yonetim) _Pil('+ Kampüs', false, () => _ekran(_KampusFormu(api: api))),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (c == null) ..._kurum(context, v, yonetim) else ..._kampusSekmesi(context, v, c, yonetim),
      ];
    },
  );

  List<Widget> _kurum(BuildContext context, Map<String, dynamic> v, bool yonetim) {
    final k = (v['kurum'] as Map).cast<String, dynamic>();
    final kurucular = v.l('kurucular');
    return [
      KartKutu(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _logoKutusu(context, k.s('ad'), api: api, yol: v.s('logo').isEmpty ? null : '/api/kurum-logo?v=${v.s('logo')}'),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(k.s('ad'), style: serif.copyWith(fontSize: 19, fontWeight: FontWeight.w600)),
                      Text(k.s('kisaAd').isEmpty ? 'Kısa ad girilmedi' : k.s('kisaAd'), style: TextStyle(color: context.soluk, fontSize: 13)),
                    ],
                  ),
                ),
                if (yonetim)
                  TextButton(
                    onPressed: () => _ekran(_KurumFormu(api: api, v: v)),
                    child: const Text('Düzenle'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _bilgi(context, [('Telefon', k.s('telefon')), ('E-posta', k.s('eposta')), ('Adres', k.s('adres'))]),
            _tanitim(context, k, v),
            if (kurucular.isNotEmpty) ...[
              const Baslik('Kurucu'),
              for (final x in kurucular)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: _logoKutusu(context, x.s('ad')),
                  title: Text(x.s('ad')),
                  subtitle: const Text('Kurucu'),
                ),
            ],
          ],
        ),
      ),
      if (v.l('kampusler').isEmpty) const BosNot('Henüz kampüs eklenmedi. Kampüs sayısında sınır yoktur; her kampüste istediğiniz kadar okul olabilir.'),
    ];
  }

  List<Widget> _kampusSekmesi(BuildContext context, Map<String, dynamic> v, Map<String, dynamic> c, bool yonetim) {
    final okullar = c.l('okullar');
    return [
      KartKutu(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('KAMPÜS', style: TextStyle(color: context.soluk, fontSize: 11, letterSpacing: 1)),
                  Text(c.s('ad'), style: serif.copyWith(fontSize: 19, fontWeight: FontWeight.w600)),
                  Text(
                    [c.s('adres'), c.s('telefon')].where((e) => e.isNotEmpty).join(' · ').isEmpty
                        ? '${okullar.length} okul'
                        : [c.s('adres'), c.s('telefon')].where((e) => e.isNotEmpty).join(' · '),
                    style: TextStyle(color: context.soluk, fontSize: 13),
                  ),
                ],
              ),
            ),
            if (yonetim)
              TextButton(
                onPressed: () => _ekran(_KampusFormu(api: api, kampus: c)),
                child: const Text('Düzenle'),
              ),
          ],
        ),
      ),
      for (final o in okullar) _okulSatiri(context, api, o, () => _ekran(_OkulSayfasi(api: api, okulId: o.n('id'), yonetim: yonetim))),
      if (okullar.isEmpty) const BosNot('Bu kampüse henüz okul eklenmedi.'),
      if (yonetim)
        OutlinedButton(
          onPressed: () => _ekran(_OkulFormu(api: api, v: v, kampusId: c.n('id'))),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: const Text('+ Okul ekle'),
        ),
    ];
  }
}

class _Pil extends StatelessWidget {
  const _Pil(this.ad, this.secili, this.onTap);

  final String ad;
  final bool secili;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(label: Text(ad), selected: secili, onSelected: (_) => onTap(), showCheckmark: false, shape: const StadiumBorder()),
  );
}

class _OkulSayfasi extends StatefulWidget {
  const _OkulSayfasi({required this.api, required this.okulId, required this.yonetim});

  final Api api;
  final int okulId;
  final bool yonetim;

  @override
  State<_OkulSayfasi> createState() => _OkulSayfasiState();
}

class _OkulSayfasiState extends State<_OkulSayfasi> {
  int _n = 0;

  @override
  Widget build(BuildContext context) => VeriSayfasi(
    key: ValueKey(_n),
    baslik: 'Okul',
    getir: () => widget.api.get('/api/yonetim/kurum'),
    cizim: (context, raw) {
      final v = raw as Map<String, dynamic>;
      final o = _tumOkullar(v).where((x) => x.n('id') == widget.okulId).firstOrNull;
      if (o == null) return const [BosNot('Okul bulunamadı.')];
      final yonetim = widget.yonetim;
      return [
        KartKutu(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _logoKutusu(context, o.s('ad'), api: widget.api, yol: _okulLogoYolu(o)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(o.s('ad'), style: serif.copyWith(fontSize: 19, fontWeight: FontWeight.w600)),
                        if (o.s('tur').isNotEmpty) Text(o.s('tur'), style: TextStyle(color: context.soluk, fontSize: 13)),
                      ],
                    ),
                  ),
                  if (yonetim)
                    TextButton(
                      onPressed: () async {
                        if (await _ac(context, _OkulFormu(api: widget.api, v: v, kampusId: o.n('kampusId'), okul: o)) && mounted) setState(() => _n++);
                      },
                      child: const Text('Düzenle'),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              _sayilar(context, [o]),
              const SizedBox(height: 8),
              _bilgi(context, [('Kurum kodu', o.s('kurumKodu')), ('Telefon', o.s('telefon')), ('E-posta', o.s('eposta')), ('Adres', o.s('adres'))]),
              _tanitim(context, o, v),
              const Baslik('Okul yönetimi'),
              _yoneticiler(
                context,
                o,
                v,
                kaldir: yonetim
                    ? (y) async {
                        final gorevler = ((v['gorevler'] as Map?) ?? const {}).cast<String, dynamic>();
                        final soru = '${y.s('ad')}, ${o.s('ad')} ${'${gorevler[y.s('gorev')]}'.toLowerCase()} görevinden kaldırılsın mı?';
                        if (!await onayIste(context, soru, evet: 'Kaldır')) {
                          return;
                        }
                        try {
                          await widget.api.post('/api/yonetim/yonetici-kaldir', {'id': y.n('id')});
                          if (mounted) setState(() => _n++);
                        } catch (e) {
                          if (context.mounted) hataGoster(context, e);
                        }
                      }
                    : null,
              ),
              if (yonetim)
                TextButton(
                  onPressed: () async {
                    if (await _ac(context, _YoneticiFormu(api: widget.api, v: v, okul: o)) && mounted) setState(() => _n++);
                  },
                  child: const Text('+ Yönetici ekle'),
                ),
              _zumreler(context, o),
            ],
          ),
        ),
      ];
    },
  );
}

// ---------------------------------------------------------------------------------------------
// Formlar

/// Web sitesi, hakkında yazısı ve sosyal medya alanları.
class _Tanitim {
  _Tanitim(Map<String, dynamic>? x, Map<String, dynamic> v)
    : web = TextEditingController(text: x?.s('web') ?? ''),
      aciklama = TextEditingController(text: x?.s('aciklama') ?? ''),
      azami = (v['tanitimAzami'] as num?)?.toInt() ?? 600,
      alanlar = [
        for (final a in v.l('sosyalAlanlar')) (a.s('kod'), a.s('ad'), TextEditingController(text: '${((x?['sosyal'] as Map?) ?? const {})[a.s('kod')] ?? ''}')),
      ];

  final TextEditingController web;
  final TextEditingController aciklama;
  final int azami;
  final List<(String, String, TextEditingController)> alanlar;

  void bitir() {
    web.dispose();
    aciklama.dispose();
    for (final a in alanlar) {
      a.$3.dispose();
    }
  }

  Map<String, dynamic> oku() => {
    'web': web.text,
    'aciklama': aciklama.text,
    'sosyal': {for (final a in alanlar) a.$1: a.$3.text},
  };

  List<Widget> alan() => [
    TextField(
      controller: web,
      keyboardType: TextInputType.url,
      decoration: const InputDecoration(labelText: 'Web sitesi', hintText: 'ornek.com'),
    ),
    const SizedBox(height: 10),
    TextField(
      controller: aciklama,
      minLines: 4,
      maxLines: 8,
      maxLength: azami,
      decoration: const InputDecoration(labelText: 'Hakkında', alignLabelWithHint: true),
    ),
    for (final a in alanlar) ...[
      const SizedBox(height: 10),
      TextField(
        controller: a.$3,
        decoration: InputDecoration(labelText: a.$2, hintText: '@kullanıcı ya da bağlantı'),
      ),
    ],
  ];
}

mixin _Kaydet<T extends StatefulWidget> on State<T> {
  bool mesgul = false;

  Future<void> gonder(Api api, String yol, Map<String, dynamic> govde) async {
    setState(() => mesgul = true);
    try {
      await api.post(yol, govde);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => mesgul = false);
        hataGoster(context, e);
      }
    }
  }

  Future<void> sil(Api api, String yol, Map<String, dynamic> govde, String soru, {bool ikiKat = false}) async {
    if (!await onayIste(context, soru, evet: 'Sil')) return;
    await gonder(api, yol, govde);
    if (ikiKat && mounted) {
      // Silinen kaydın sayfası da kapansın
    }
  }
}

class _KurumFormu extends StatefulWidget {
  const _KurumFormu({required this.api, required this.v});

  final Api api;
  final Map<String, dynamic> v;

  @override
  State<_KurumFormu> createState() => _KurumFormuState();
}

class _KurumFormuState extends State<_KurumFormu> with _Kaydet {
  late final Map<String, dynamic> _k = (widget.v['kurum'] as Map).cast<String, dynamic>();
  late final _ad = TextEditingController(text: _k.s('ad'));
  late final _kisa = TextEditingController(text: _k.s('kisaAd'));
  late final _tel = TextEditingController(text: _k.s('telefon'));
  late final _ep = TextEditingController(text: _k.s('eposta'));
  late final _adr = TextEditingController(text: _k.s('adres'));
  late final _Tanitim _t = _Tanitim(_k, widget.v);
  String _sekme = 'b';

  @override
  void dispose() {
    for (final c in [_ad, _kisa, _tel, _ep, _adr]) {
      c.dispose();
    }
    _t.bitir();
    super.dispose();
  }

  Future<void> _kurucuKaldir(Map<String, dynamic> c) async {
    if (!await onayIste(context, '${c.s('ad')} kurucu kaydından çıkarılsın mı?', evet: 'Kaldır')) return;
    try {
      await widget.api.post('/api/yonetim/kurucu-kaldir', {'userId': c.n('userId')});
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) hataGoster(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kurucular = widget.v.l('kurucular');
    return Scaffold(
      appBar: AppBar(title: const Text('Kurum profili')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Sekmeler(secenekler: const [('b', 'Bilgiler'), ('t', 'Tanıtım'), ('k', 'Kurucu')], secili: _sekme, degisti: (d) => setState(() => _sekme = d)),
          const SizedBox(height: 14),
          if (_sekme == 'b') ...[
            _LogoAlani(
              api: widget.api,
              ad: _k.s('ad'),
              yol: widget.v.s('logo').isEmpty ? null : '/api/kurum-logo?v=${widget.v.s('logo')}',
              yukle: '/api/yonetim/kurum-logo',
              sil: '/api/yonetim/kurum-logo-sil',
            ),
            TextField(
              controller: _ad,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Kurum adı'),
            ),
            TextField(
              controller: _kisa,
              maxLength: 30,
              decoration: const InputDecoration(labelText: 'Kısa ad', hintText: 'İsteğe bağlı'),
            ),
            TextField(
              controller: _tel,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telefon'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _ep,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-posta'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _adr,
              decoration: const InputDecoration(labelText: 'Adres'),
            ),
          ],
          if (_sekme == 't') ..._t.alan(),
          if (_sekme == 'k') ...[
            Text('Kurucu yalnızca kayıttır; giriş ya da yetki vermez.', style: TextStyle(color: context.soluk, fontSize: 13)),
            for (final c in kurucular)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(c.s('ad')),
                subtitle: const Text('Kurucu'),
                trailing: TextButton(
                  onPressed: () => _kurucuKaldir(c),
                  child: Text('Kaldır', style: TextStyle(color: Colors.red.shade600)),
                ),
              ),
            if (kurucular.isEmpty) const BosNot('Kurucu kaydedilmedi.'),
            TextButton(
              onPressed: () async {
                final sayfa = _KisiFormu(api: widget.api, v: widget.v, baslik: 'Kurucu ekle', yol: '/api/yonetim/kurucu-ekle');
                final eklendi = await _ac(context, sayfa);
                if (eklendi && context.mounted) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('+ Kurucu ekle'),
            ),
          ],
          if (_sekme != 'k') ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: mesgul
                  ? null
                  : () => gonder(widget.api, '/api/yonetim/kurum-kaydet', {
                      'ad': _ad.text,
                      'kisaAd': _kisa.text,
                      'telefon': _tel.text,
                      'eposta': _ep.text,
                      'adres': _adr.text,
                      ..._t.oku(),
                    }),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: Text(mesgul ? 'Kaydediliyor…' : 'Kaydet'),
            ),
          ],
        ],
      ),
    );
  }
}

class _KampusFormu extends StatefulWidget {
  const _KampusFormu({required this.api, this.kampus});

  final Api api;
  final Map<String, dynamic>? kampus;

  @override
  State<_KampusFormu> createState() => _KampusFormuState();
}

class _KampusFormuState extends State<_KampusFormu> with _Kaydet {
  late final _ad = TextEditingController(text: widget.kampus?.s('ad') ?? '');
  late final _adr = TextEditingController(text: widget.kampus?.s('adres') ?? '');
  late final _tel = TextEditingController(text: widget.kampus?.s('telefon') ?? '');

  @override
  void dispose() {
    _ad.dispose();
    _adr.dispose();
    _tel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.kampus;
    return Scaffold(
      appBar: AppBar(title: Text(k == null ? 'Yeni kampüs' : 'Kampüsü düzenle')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          TextField(
            controller: _ad,
            maxLength: 80,
            decoration: const InputDecoration(labelText: 'Kampüs adı'),
          ),
          TextField(
            controller: _adr,
            decoration: const InputDecoration(labelText: 'Adres'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _tel,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Telefon'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: mesgul
                ? null
                : () => gonder(widget.api, '/api/yonetim/kampus-kaydet', {'id': k?.n('id'), 'ad': _ad.text, 'adres': _adr.text, 'telefon': _tel.text}),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: Text(mesgul ? 'Kaydediliyor…' : 'Kaydet'),
          ),
          if (k != null)
            TextButton(
              onPressed: mesgul ? null : () => sil(widget.api, '/api/yonetim/kampus-sil', {'id': k.n('id')}, '${k.s('ad')} kampüsü silinsin mi?'),
              child: Text('Kampüsü sil', style: TextStyle(color: Colors.red.shade600)),
            ),
        ],
      ),
    );
  }
}

class _OkulFormu extends StatefulWidget {
  const _OkulFormu({required this.api, required this.v, required this.kampusId, this.okul});

  final Api api;
  final Map<String, dynamic> v;
  final int kampusId;
  final Map<String, dynamic>? okul;

  @override
  State<_OkulFormu> createState() => _OkulFormuState();
}

class _OkulFormuState extends State<_OkulFormu> with _Kaydet {
  late final _ad = TextEditingController(text: widget.okul?.s('ad') ?? '');
  late final _kod = TextEditingController(text: widget.okul?.s('kurumKodu') ?? '');
  late final _tel = TextEditingController(text: widget.okul?.s('telefon') ?? '');
  late final _ep = TextEditingController(text: widget.okul?.s('eposta') ?? '');
  late final _adr = TextEditingController(text: widget.okul?.s('adres') ?? '');
  late final _Tanitim _t = _Tanitim(widget.okul, widget.v);
  late String _tur = widget.okul?.s('tur') ?? '';
  String _sekme = 'b';

  @override
  void dispose() {
    for (final c in [_ad, _kod, _tel, _ep, _adr]) {
      c.dispose();
    }
    _t.bitir();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final okul = widget.okul;
    final turler = [for (final t in (widget.v['turler'] as List? ?? const [])) '$t'];
    return Scaffold(
      appBar: AppBar(title: Text(okul == null ? 'Yeni okul' : 'Okulu düzenle')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Sekmeler(secenekler: const [('b', 'Bilgiler'), ('t', 'Tanıtım')], secili: _sekme, degisti: (d) => setState(() => _sekme = d)),
          const SizedBox(height: 14),
          if (_sekme == 'b') ...[
            if (okul != null)
              _LogoAlani(
                api: widget.api,
                ad: okul.s('ad'),
                yol: _okulLogoYolu(okul),
                yukle: '/api/okul-logo?id=${okul.n('id')}',
                sil: '/api/okul-logo-sil?id=${okul.n('id')}',
              ),
            TextField(
              controller: _ad,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Okul adı'),
            ),
            DropdownButtonFormField<String>(
              initialValue: turler.contains(_tur) ? _tur : '',
              decoration: const InputDecoration(labelText: 'Okul türü'),
              items: [
                const DropdownMenuItem(value: '', child: Text('Seçilmedi')),
                for (final t in turler) DropdownMenuItem(value: t, child: Text(t)),
              ],
              onChanged: (v) => setState(() => _tur = v ?? ''),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _kod,
              maxLength: 30,
              decoration: const InputDecoration(labelText: 'Kurum kodu'),
            ),
            TextField(
              controller: _tel,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telefon'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _ep,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-posta'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _adr,
              decoration: const InputDecoration(labelText: 'Adres'),
            ),
          ] else
            ..._t.alan(),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: mesgul
                ? null
                : () => gonder(widget.api, '/api/yonetim/okul-kaydet', {
                    'id': okul?.n('id'),
                    'kampusId': widget.kampusId,
                    'ad': _ad.text,
                    'tur': _tur,
                    'kurumKodu': _kod.text,
                    'telefon': _tel.text,
                    'eposta': _ep.text,
                    'adres': _adr.text,
                    ..._t.oku(),
                  }),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: Text(mesgul ? 'Kaydediliyor…' : 'Kaydet'),
          ),
          if (okul != null)
            TextButton(
              onPressed: mesgul
                  ? null
                  : () => sil(widget.api, '/api/yonetim/okul-sil', {
                      'id': okul.n('id'),
                    }, '${okul.s('ad')} silinsin mi? Okulda sınıf ya da kayıtlı kişi varsa silinemez.'),
              child: Text('Okulu sil', style: TextStyle(color: Colors.red.shade600)),
            ),
        ],
      ),
    );
  }
}

class _YoneticiFormu extends StatelessWidget {
  const _YoneticiFormu({required this.api, required this.v, required this.okul});

  final Api api;
  final Map<String, dynamic> v;
  final Map<String, dynamic> okul;

  @override
  Widget build(BuildContext context) => _KisiFormu(
    api: api,
    v: v,
    baslik: 'Yönetici ekle',
    yol: '/api/yonetim/yonetici-ekle',
    ek: {'okulId': okul.n('id')},
    mevcutlar: {for (final y in okul.l('yoneticiler')) y.n('userId')},
    gorevSec: true,
    mudurVar: okul.l('yoneticiler').any((y) => y.s('gorev') == 'mudur'),
  );
}

/// Kurucu ya da okul yöneticisi eklerken kişi seçimi: listeden aday ya da yeni kişi.
class _KisiFormu extends StatefulWidget {
  const _KisiFormu({
    required this.api,
    required this.v,
    required this.baslik,
    required this.yol,
    this.ek = const {},
    this.mevcutlar,
    this.gorevSec = false,
    this.mudurVar = false,
  });

  final Api api;
  final Map<String, dynamic> v;
  final String baslik;
  final String yol;
  final Map<String, dynamic> ek;
  final Set<int>? mevcutlar;
  final bool gorevSec;
  final bool mudurVar;

  @override
  State<_KisiFormu> createState() => _KisiFormuState();
}

class _KisiFormuState extends State<_KisiFormu> with _Kaydet {
  final _ad = TextEditingController();
  final _kimlik = TextEditingController();
  final _tel = TextEditingController();
  String _kisi = 'yeni';
  late String _gorev = widget.mudurVar ? 'mudur_yrd' : 'mudur';

  @override
  void dispose() {
    _ad.dispose();
    _kimlik.dispose();
    _tel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gorevler = ((widget.v['gorevler'] as Map?) ?? const {}).cast<String, dynamic>();
    final adaylar = [
      for (final a in widget.v.l('adaylar'))
        if (!(widget.mevcutlar ?? const {}).contains(a.n('userId'))) a,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(widget.baslik)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (widget.gorevSec) ...[
            DropdownButtonFormField<String>(
              initialValue: _gorev,
              decoration: const InputDecoration(labelText: 'Görev'),
              items: [for (final e in gorevler.entries) DropdownMenuItem(value: e.key, child: Text('${e.value}'))],
              onChanged: (v) => setState(() => _gorev = v ?? _gorev),
            ),
            const SizedBox(height: 12),
          ],
          DropdownButtonFormField<String>(
            initialValue: _kisi,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Kişi'),
            items: [
              const DropdownMenuItem(value: 'yeni', child: Text('Yeni kişi ekle…')),
              for (final a in adaylar)
                DropdownMenuItem(
                  value: '${a.n('userId')}',
                  child: Text('${a.s('ad')} · ${a.s('rol')}${a.s('okul').isEmpty ? '' : ' · ${a.s('okul')}'}', overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => _kisi = v ?? 'yeni'),
          ),
          if (_kisi == 'yeni') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _ad,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Ad soyad'),
            ),
            TextField(
              controller: _kimlik,
              maxLength: 20,
              decoration: const InputDecoration(labelText: 'T.C. kimlik / pasaport no'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _tel,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telefon', hintText: '5XX XXX XX XX'),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: mesgul
                ? null
                : () => gonder(widget.api, widget.yol, {
                    ...widget.ek,
                    if (widget.gorevSec) 'gorev': _gorev,
                    if (_kisi == 'yeni') ...{'ad': _ad.text, 'kimlik': _kimlik.text, 'telefon': _tel.text} else 'userId': int.parse(_kisi),
                  }),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: Text(mesgul ? 'Ekleniyor…' : 'Ekle'),
          ),
        ],
      ),
    );
  }
}

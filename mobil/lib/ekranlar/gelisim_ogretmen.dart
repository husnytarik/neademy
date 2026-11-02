import 'package:flutter/material.dart';

import '../bilesenler/ortak.dart';
import '../cekirdek/api.dart';
import '../cekirdek/takvim_model.dart';
import '../cekirdek/tema.dart';

String _kisaAd(String ad) => ad.split(' (').first;

(String, Color) _durumEtiketi(String durum) => switch (durum) {
  'acik' => ('Giriş açık', Colors.green.shade700),
  'yaklasan' => ('Yaklaşan', Colors.blueGrey),
  _ => ('Kapandı', Colors.grey),
};

String _aralik(Map<String, dynamic> d) => '${kisaTarih(d.s('baslangic'))} – ${kisaTarih(d.s('bitis'))}';

/// Öğretmen: dönem açıkken öğrencileri için yönetimin belirlediği başlıklarda gözlem girer;
/// geçmiş dönemleri ve veli toplantısı / görüşme notlarını görür.
class GelisimOgretmenEkrani extends StatefulWidget {
  const GelisimOgretmenEkrani({super.key, required this.api});

  final Api api;

  @override
  State<GelisimOgretmenEkrani> createState() => _GelisimOgretmenEkraniState();
}

class _GelisimOgretmenEkraniState extends State<GelisimOgretmenEkrani> {
  int? _donemId;
  int _yenile = 0;
  final _acik = <int>{};

  Future<void> _ogrenciAc(Map<String, dynamic> o, Map<String, dynamic> sinif, Map<String, dynamic> donem, List<Map<String, dynamic>> basliklar) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GelisimOgrenciEkrani(api: widget.api, ogrenci: o, sinifAd: sinif.s('ad'), donemId: donem.n('id'), aktifBasliklar: basliklar),
      ),
    );
    if (mounted) setState(() => _yenile++);
  }

  @override
  Widget build(BuildContext context) => VeriSayfasi(
    key: ValueKey('$_yenile-$_donemId'),
    baslik: 'Gelişim gözlemi',
    getir: () => widget.api.get('/api/gelisim/ogretmen${_donemId == null ? '' : '?donemId=$_donemId'}'),
    cizim: (context, veri) {
      final v = veri as Map<String, dynamic>;
      final donemler = v.l('donemler');
      final siniflar = v.l('siniflar');
      final basliklar = v.l('basliklar');
      if (donemler.isEmpty) return [const BosNot('Yönetim henüz bir gözlem dönemi tanımlamadı.')];
      if (siniflar.isEmpty) return [const BosNot('Size bağlı sınıf bulunamadı.')];
      final secili = v.n('donemId');
      final d = donemler.firstWhere((x) => x.n('id') == secili, orElse: () => donemler.first);
      final toplam = basliklar.length;
      bool tam(Map<String, dynamic> o) => toplam > 0 && o.n('girilen') >= toplam;
      final ogrSay = siniflar.fold<int>(0, (t, s) => t + s.l('ogrenciler').length);
      final tamSay = siniflar.fold<int>(0, (t, s) => t + s.l('ogrenciler').where(tam).length);
      final (etiket, renk) = _durumEtiketi(d.s('durum'));
      final not = switch (d.s('durum')) {
        'acik' => 'Giriş ${uzunTarih(d.s('bitis'))} tarihine kadar açık',
        'yaklasan' => '${uzunTarih(d.s('baslangic'))} tarihinde açılacak',
        _ => 'Girişler yalnızca görüntülenir',
      };
      return [
        const SizedBox(height: 4),
        SuzgecCipleri(
          secenekler: [for (final x in donemler) ('${x.n('id')}', _kisaAd(x.s('ad')))],
          secili: '${d.n('id')}',
          degisti: (s) => setState(() => _donemId = int.parse(s)),
        ),
        const SizedBox(height: 12),
        KartKutu(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(_kisaAd(d.s('ad')), style: serif.copyWith(fontSize: 19, fontWeight: FontWeight.w600)),
                  ),
                  Cip(etiket, renk: renk),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${_aralik(d)}${d.s('toplantiTarihi').isEmpty ? '' : ' · Veli toplantısı ${kisaTarih(d.s('toplantiTarihi'))}'}',
                style: TextStyle(color: context.soluk, fontSize: 13),
              ),
              Text(not, style: TextStyle(color: context.soluk, fontSize: 13)),
              if (d.s('durum') != 'yaklasan') ...[
                const SizedBox(height: 10),
                _Ilerleme(oran: ogrSay == 0 ? 0 : tamSay / ogrSay),
                const SizedBox(height: 6),
                Text('$tamSay / $ogrSay öğrenci tamamlandı', style: TextStyle(color: context.soluk, fontSize: 12.5)),
              ],
            ],
          ),
        ),
        for (final s in siniflar)
          _SinifKarti(
            sinif: s,
            toplam: toplam,
            acik: _acik.contains(s.n('id')) || siniflar.length == 1,
            ac: () => setState(() => _acik.contains(s.n('id')) ? _acik.remove(s.n('id')) : _acik.add(s.n('id'))),
            ogrenciAc: (o) => _ogrenciAc(o, s, d, basliklar),
          ),
      ];
    },
  );
}

class _Ilerleme extends StatelessWidget {
  const _Ilerleme({required this.oran});

  final double oran;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(6),
    child: LinearProgressIndicator(value: oran, minHeight: 6, backgroundColor: context.icZemin, color: context.ana),
  );
}

class _SinifKarti extends StatelessWidget {
  const _SinifKarti({required this.sinif, required this.toplam, required this.acik, required this.ac, required this.ogrenciAc});

  final Map<String, dynamic> sinif;
  final int toplam;
  final bool acik;
  final VoidCallback ac;
  final void Function(Map<String, dynamic>) ogrenciAc;

  @override
  Widget build(BuildContext context) {
    final ogrenciler = sinif.l('ogrenciler');
    final tamam = ogrenciler.where((o) => toplam > 0 && o.n('girilen') >= toplam).length;
    return KartKutu(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: ac,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(sinif.s('ad'), style: serif.copyWith(fontSize: 17, fontWeight: FontWeight.w600)),
                            if (sinif.s('dersler').isNotEmpty) Text(sinif.s('dersler'), style: TextStyle(color: context.soluk, fontSize: 12.5)),
                          ],
                        ),
                      ),
                      Cip('$tamam/${ogrenciler.length}', renk: ogrenciler.isNotEmpty && tamam == ogrenciler.length ? Colors.green.shade700 : null),
                      Icon(acik ? Icons.expand_less : Icons.expand_more, color: context.soluk),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _Ilerleme(oran: ogrenciler.isEmpty ? 0 : tamam / ogrenciler.length),
                ],
              ),
            ),
          ),
          if (acik)
            for (final o in ogrenciler)
              InkWell(
                onTap: () => ogrenciAc(o),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: context.ince)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 15,
                        backgroundColor: context.icZemin,
                        child: Text(
                          _bas(o.s('ad')),
                          style: TextStyle(color: context.yazi, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(o.s('ad'), style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      o.n('girilen') == 0
                          ? const Cip('Girilmedi')
                          : toplam > 0 && o.n('girilen') >= toplam
                          ? Cip('Tamam', renk: Colors.green.shade700)
                          : Cip('${o.n('girilen')}/$toplam', renk: context.ana),
                      Icon(Icons.chevron_right, color: context.soluk),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

String _bas(String ad) => ad.trim().isEmpty ? '?' : ad.trim().substring(0, 1).toUpperCase();

/// Bir öğrencinin gözlemleri: seçili dönem, önceki dönemlerdeki girişlerim, veli toplantısı / görüşme notları.
class GelisimOgrenciEkrani extends StatefulWidget {
  const GelisimOgrenciEkrani({super.key, required this.api, required this.ogrenci, required this.sinifAd, required this.donemId, required this.aktifBasliklar});

  final Api api;
  final Map<String, dynamic> ogrenci;
  final String sinifAd;
  final int donemId;
  final List<Map<String, dynamic>> aktifBasliklar;

  @override
  State<GelisimOgrenciEkrani> createState() => _GelisimOgrenciEkraniState();
}

class _GelisimOgrenciEkraniState extends State<GelisimOgrenciEkrani> {
  int _yenile = 0;

  Future<void> _gozlem(Map<String, dynamic> donem, Map<String, String> mevcut) async {
    final kaydedildi = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _GozlemFormu(api: widget.api, ogrenci: widget.ogrenci, donem: donem, basliklar: widget.aktifBasliklar, mevcut: mevcut),
      ),
    );
    if (kaydedildi == true && mounted) setState(() => _yenile++);
  }

  Future<void> _gorusme(Map<String, dynamic> rapor, {Map<String, dynamic>? mevcut, String tur = 'gorusme'}) async {
    final kaydedildi = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            _GorusmeFormu(api: widget.api, ogrenciId: widget.ogrenci.n('id'), donemler: rapor.l('donemler'), bugun: rapor.s('bugun'), mevcut: mevcut, tur: tur),
      ),
    );
    if (kaydedildi == true && mounted) setState(() => _yenile++);
  }

  Future<void> _gorusmeSil(Map<String, dynamic> g) async {
    if (!await onayIste(context, 'Bu not silinsin mi?', evet: 'Sil')) return;
    try {
      await widget.api.post('/api/gelisim/gorusme-sil', {'id': g.n('id')});
      if (mounted) setState(() => _yenile++);
    } catch (e) {
      if (mounted) hataGoster(context, e);
    }
  }

  Widget _blok(BuildContext context, String ad, String yazi) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ad,
          style: TextStyle(color: context.soluk, fontSize: 12.5, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(yazi.isEmpty ? 'Girilmedi' : yazi, style: TextStyle(height: 1.35, color: yazi.isEmpty ? context.soluk : context.yazi)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final o = widget.ogrenci;
    return VeriSayfasi(
      key: ValueKey(_yenile),
      baslik: o.s('ad'),
      getir: () => widget.api.get('/api/gelisim/rapor?ogrenciId=${o.n('id')}'),
      cizim: (context, veri) {
        final v = veri as Map<String, dynamic>;
        final donemler = v.l('donemler');
        final rd = donemler.firstWhere((x) => x.n('id') == widget.donemId, orElse: () => <String, dynamic>{});
        final basliklar = v.l('basliklar');
        final girisler = <int, String>{for (final g in rd.l('girisler')) g.n('baslikId'): g.s('metin')};
        final durum = rd.s('durum');
        final (etiket, renk) = _durumEtiketi(durum);
        final dolu = widget.aktifBasliklar.where((b) => (girisler[b.n('id')] ?? '').isNotEmpty).length;
        final gorusmeler = [...donemler.expand((x) => x.l('gorusmeler')), ...v.l('donemsizGorusmeler')]
          ..sort((a, c) => c.s('tarih').compareTo(a.s('tarih')) != 0 ? c.s('tarih').compareTo(a.s('tarih')) : c.n('id').compareTo(a.n('id')));
        final onceki = donemler.reversed.where((x) => x.n('id') != widget.donemId && x.l('girisler').isNotEmpty).toList();
        return [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('${widget.sinifAd}${o.s('okulNo').isEmpty ? '' : ' · No ${o.s('okulNo')}'}', style: TextStyle(color: context.soluk)),
          ),
          const SizedBox(height: 12),
          if (rd.isNotEmpty)
            KartKutu(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(_kisaAd(rd.s('ad')), style: serif.copyWith(fontSize: 18, fontWeight: FontWeight.w600)),
                      ),
                      if (durum == 'acik') ...[Cip('$dolu/${widget.aktifBasliklar.length}'), const SizedBox(width: 6)],
                      Cip(etiket, renk: renk),
                    ],
                  ),
                  if (durum == 'yaklasan')
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Bu dönem ${uzunTarih(rd.s('baslangic'))} tarihinde açılacak.', style: TextStyle(color: context.soluk)),
                    )
                  else if (durum == 'acik') ...[
                    for (final b in widget.aktifBasliklar) _blok(context, b.s('ad'), girisler[b.n('id')] ?? ''),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: () => _gozlem(rd, {for (final e in girisler.entries) '${e.key}': e.value}),
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                      child: Text(dolu > 0 ? 'Düzenle' : 'Gözlem gir'),
                    ),
                  ] else ...[
                    if (girisler.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('Bu dönemde bu öğrenci için giriş yapmadınız.', style: TextStyle(color: context.soluk)),
                      ),
                    for (final b in basliklar)
                      if (girisler.containsKey(b.n('id'))) _blok(context, b.s('ad'), girisler[b.n('id')]!),
                  ],
                ],
              ),
            ),
          if (onceki.isNotEmpty) ...[
            const Baslik('Önceki dönemlerdeki girişlerim'),
            for (final x in onceki)
              KartKutu(
                padding: EdgeInsets.zero,
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 14),
                    childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    title: Text('${x.s('ad')} · ${_aralik(x)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                    children: [
                      for (final b in basliklar)
                        for (final g in x.l('girisler'))
                          if (g.n('baslikId') == b.n('id')) _blok(context, b.s('ad'), g.s('metin')),
                    ],
                  ),
                ),
              ),
          ],
          const Baslik('Veli toplantısı ve görüşmeler'),
          if (gorusmeler.isEmpty) const BosNot('Henüz toplantı ya da görüşme notu yok.'),
          for (final g in gorusmeler)
            KartKutu(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Cip(g.s('tur') == 'toplanti' ? 'Veli toplantısı' : 'Veli görüşmesi', renk: context.ana),
                      const SizedBox(width: 8),
                      Text(uzunTarih(g.s('tarih')), style: TextStyle(color: context.soluk, fontSize: 12.5)),
                      const Spacer(),
                      if (g['duzenlenebilir'] == true) ...[
                        InkWell(
                          onTap: () => _gorusme(v, mevcut: g),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(Icons.edit_outlined, size: 19, color: context.soluk),
                          ),
                        ),
                        InkWell(
                          onTap: () => _gorusmeSil(g),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(Icons.delete_outline, size: 19, color: context.soluk),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(g.s('notu'), style: const TextStyle(height: 1.35)),
                  if (g.s('yazan').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(g['benim'] == true ? 'Siz' : g.s('yazan'), style: TextStyle(color: context.soluk, fontSize: 12)),
                    ),
                ],
              ),
            ),
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
        ];
      },
    );
  }
}

class _GozlemFormu extends StatefulWidget {
  const _GozlemFormu({required this.api, required this.ogrenci, required this.donem, required this.basliklar, required this.mevcut});

  final Api api;
  final Map<String, dynamic> ogrenci;
  final Map<String, dynamic> donem;
  final List<Map<String, dynamic>> basliklar;
  final Map<String, String> mevcut;

  @override
  State<_GozlemFormu> createState() => _GozlemFormuState();
}

class _GozlemFormuState extends State<_GozlemFormu> {
  late final Map<int, TextEditingController> _alanlar = {
    for (final b in widget.basliklar) b.n('id'): TextEditingController(text: widget.mevcut['${b.n('id')}'] ?? ''),
  };
  bool _gonderiliyor = false;

  @override
  void dispose() {
    for (final c in _alanlar.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _kaydet() async {
    setState(() => _gonderiliyor = true);
    try {
      await widget.api.post('/api/gelisim/giris-kaydet', {
        'donemId': widget.donem.n('id'),
        'ogrenciId': widget.ogrenci.n('id'),
        'girisler': {for (final e in _alanlar.entries) '${e.key}': e.value.text},
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kaydedildi')));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _gonderiliyor = false);
        hataGoster(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.ogrenci.s('ad'))),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text('${_kisaAd(widget.donem.s('ad'))} · gözlem girişi', style: serif.copyWith(fontSize: 17, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        for (final b in widget.basliklar) ...[
          TextField(
            controller: _alanlar[b.n('id')],
            minLines: 3,
            maxLines: 8,
            maxLength: 1000,
            decoration: InputDecoration(
              labelText: b.s('ad'),
              hintText: b.s('aciklama').isEmpty ? 'Gözleminizi yazın' : b.s('aciklama'),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 6),
        ],
        const SizedBox(height: 10),
        FilledButton(
          onPressed: _gonderiliyor ? null : _kaydet,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          child: Text(_gonderiliyor ? 'Kaydediliyor…' : 'Kaydet'),
        ),
      ],
    ),
  );
}

class _GorusmeFormu extends StatefulWidget {
  const _GorusmeFormu({required this.api, required this.ogrenciId, required this.donemler, required this.bugun, required this.mevcut, required this.tur});

  final Api api;
  final int ogrenciId;
  final List<Map<String, dynamic>> donemler;
  final String bugun;
  final Map<String, dynamic>? mevcut;
  final String tur;

  @override
  State<_GorusmeFormu> createState() => _GorusmeFormuState();
}

class _GorusmeFormuState extends State<_GorusmeFormu> {
  late String _tur = widget.mevcut?.s('tur') ?? widget.tur;
  late String _tarih = widget.mevcut?.s('tarih') ?? widget.bugun;
  late int? _donem = widget.mevcut?['donemId'] as int?;
  late final _not = TextEditingController(text: widget.mevcut?.s('notu') ?? '');
  bool _gonderiliyor = false;

  @override
  void dispose() {
    _not.dispose();
    super.dispose();
  }

  Future<void> _tarihSec() async {
    final t = tarihCoz(_tarih);
    final s = await showDatePicker(
      context: context,
      initialDate: DateTime(t.year, t.month, t.day),
      firstDate: DateTime(t.year - 2),
      lastDate: DateTime(t.year + 2),
    );
    if (s != null) setState(() => _tarih = tarihYaz(s));
  }

  Future<void> _kaydet() async {
    if (_not.text.trim().length < 3) return hataGoster(context, ApiHata(0, 'Not en az 3 karakter olmalı.'));
    setState(() => _gonderiliyor = true);
    try {
      await widget.api.post('/api/gelisim/gorusme-kaydet', {
        if (widget.mevcut != null) 'id': widget.mevcut!.n('id'),
        'ogrenciId': widget.ogrenciId,
        'tur': _tur,
        'tarih': _tarih,
        'notu': _not.text.trim(),
        if (_donem != null) 'donemId': _donem,
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _gonderiliyor = false);
        hataGoster(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.mevcut == null ? 'Yeni not' : 'Notu düzenle')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Sekmeler(secenekler: const [('toplanti', 'Veli toplantısı'), ('gorusme', 'Veli görüşmesi')], secili: _tur, degisti: (s) => setState(() => _tur = s)),
        const SizedBox(height: 14),
        InkWell(
          onTap: _tarihSec,
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Tarih', suffixIcon: Icon(Icons.calendar_today_outlined, size: 18)),
            child: Text(uzunTarih(_tarih)),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int?>(
          initialValue: _donem,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Dönem'),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('Dönemden bağımsız')),
            for (final d in widget.donemler)
              DropdownMenuItem<int?>(
                value: d.n('id'),
                child: Text(_kisaAd(d.s('ad')), overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) => setState(() => _donem = v),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _not,
          minLines: 5,
          maxLines: 10,
          maxLength: 2000,
          decoration: const InputDecoration(labelText: 'Not', alignLabelWithHint: true),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: _gonderiliyor ? null : _kaydet,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          child: Text(_gonderiliyor ? 'Kaydediliyor…' : 'Kaydet'),
        ),
      ],
    ),
  );
}

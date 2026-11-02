import 'package:flutter/material.dart';

import '../bilesenler/ortak.dart';
import '../cekirdek/api.dart';
import '../cekirdek/takvim_model.dart';
import '../cekirdek/tema.dart';

String _bugun() => tarihYaz(DateTime.now());

String _kalanYazi(String t) {
  final n = tarihCoz(t).difference(tarihCoz(_bugun())).inDays;
  return n == 0
      ? 'Bugün'
      : n == 1
      ? 'Yarın'
      : '$n gün sonra';
}

String _zaman(Object? ms) {
  final d = DateTime.fromMillisecondsSinceEpoch((ms as num?)?.toInt() ?? 0);
  String iki(int n) => n.toString().padLeft(2, '0');
  return '${d.day} ${ayAdlari[d.month - 1]} ${iki(d.hour)}:${iki(d.minute)}';
}

/// Zümre: toplantılar ve kararlar, zümrede paylaşılan yazılar, öğretmenler; zümre başkanları ayrıca başkanlar toplantılarını görür.
class ZumremEkrani extends StatefulWidget {
  const ZumremEkrani({super.key, required this.api});

  final Api api;

  @override
  State<ZumremEkrani> createState() => _ZumremEkraniState();
}

class _ZumremEkraniState extends State<ZumremEkrani> {
  int? _secili;

  @override
  Widget build(BuildContext context) => VeriSayfasi(
    baslik: 'Zümrem',
    getir: () => widget.api.get('/api/zumre/benim'),
    cizim: (context, veri) {
      final v = veri as Map<String, dynamic>;
      final zumreler = v.l('zumreler');
      if (zumreler.isEmpty) return [const BosNot('Bir derse atanmadığınız için zümreniz yok.')];
      final id = zumreler.any((z) => z.n('id') == _secili) ? _secili! : zumreler.first.n('id');
      return [
        if (zumreler.length > 1) ...[
          const SizedBox(height: 4),
          SuzgecCipleri(
            secenekler: [for (final z in zumreler) ('${z.n('id')}', z.s('ad'))],
            secili: '$id',
            degisti: (s) => setState(() => _secili = int.parse(s)),
          ),
          const SizedBox(height: 10),
        ],
        _ZumreGovdesi(key: ValueKey(id), api: widget.api, courseId: id, baskanMi: v['baskan'] == true),
      ];
    },
  );
}

class _ZumreGovdesi extends StatefulWidget {
  const _ZumreGovdesi({super.key, required this.api, required this.courseId, required this.baskanMi});

  final Api api;
  final int courseId;
  final bool baskanMi;

  @override
  State<_ZumreGovdesi> createState() => _ZumreGovdesiState();
}

class _ZumreGovdesiState extends State<_ZumreGovdesi> {
  Map<String, dynamic>? _veri;
  Map<String, dynamic>? _baskanlar;
  String? _hata;
  String _sekme = 'toplanti';
  final _yazi = TextEditingController();

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    _yazi.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    try {
      final j = await widget.api.get('/api/zumre/detay?courseId=${widget.courseId}') as Map<String, dynamic>;
      if (mounted) setState(() => _veri = j);
    } on ApiHata catch (e) {
      if (mounted && !e.oturumYok) setState(() => _hata = e.mesaj);
    }
  }

  Future<void> _baskanlariYukle() async {
    try {
      final j = await widget.api.get('/api/zumre/baskanlar/liste') as Map<String, dynamic>;
      if (mounted) setState(() => _baskanlar = j);
    } on ApiHata catch (e) {
      if (mounted && !e.oturumYok) setState(() => _hata = e.mesaj);
    }
  }

  Future<void> _gonder(String yol, Map<String, dynamic> govde, {String? ileti}) async {
    try {
      await widget.api.post(yol, govde);
      if (!mounted) return;
      if (ileti != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ileti)));
      await _yukle();
      if (_sekme == 'baskanlar') await _baskanlariYukle();
    } catch (e) {
      if (mounted) hataGoster(context, e);
    }
  }

  Future<void> _sil(String yol, Map<String, dynamic> govde, String soru) async {
    if (!await onayIste(context, soru, evet: 'Sil')) return;
    await _gonder(yol, govde);
  }

  Future<void> _toplantiFormu(Map<String, dynamic>? mevcut) async {
    final v = _veri!;
    final tamam = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _ToplantiFormu(api: widget.api, courseId: widget.courseId, tekrarlar: (v['tekrarlar'] as Map).cast<String, dynamic>(), mevcut: mevcut),
      ),
    );
    if (tamam == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Toplantı kaydedildi.')));
      _yukle();
    }
  }

  Future<void> _karar({required String baslik, required String karar, required Future<void> Function(String) kaydet}) async {
    final metin = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _KararSayfasi(baslik: baslik, karar: karar),
      ),
    );
    if (metin != null) await kaydet(metin);
  }

  @override
  Widget build(BuildContext context) {
    final v = _veri;
    if (v == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Center(
          child: _hata == null ? const CircularProgressIndicator(strokeWidth: 2.5) : Text(_hata!, style: TextStyle(color: context.soluk)),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${(v['zumre'] as Map)['ad']} zümresi', style: serif.copyWith(fontSize: 21, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Sekmeler(
          secenekler: [('toplanti', 'Toplantılar'), ('yazi', 'Yazılar'), ('ogretmen', 'Öğretmenler'), if (widget.baskanMi) ('baskanlar', 'Başkanlar')],
          secili: _sekme,
          degisti: (s) {
            setState(() => _sekme = s);
            if (s == 'baskanlar' && _baskanlar == null) _baskanlariYukle();
          },
        ),
        const SizedBox(height: 12),
        ...switch (_sekme) {
          'toplanti' => _toplantilar(context, v),
          'yazi' => _yazilar(context, v),
          'ogretmen' => _ogretmenler(context, v),
          _ => _baskanlarSekmesi(context),
        },
      ],
    );
  }

  // ---- Toplantılar ve kararlar ----
  List<Widget> _toplantilar(BuildContext context, Map<String, dynamic> v) {
    final baskan = v['baskan'] == true;
    final tekrarlar = (v['tekrarlar'] as Map).cast<String, dynamic>();
    final toplantilar = v.l('toplantilar');
    final kararlar = v.l('kararlar');
    return [
      if (baskan) EkleDugmesi('+ Toplantı ekle', tam: true, onPressed: () => _toplantiFormu(null)),
      if (toplantilar.isEmpty)
        BosNot(
          baskan
              ? 'Henüz toplantı yok. Rutin toplantıyı ekleyin; zümre öğretmenlerinin paneline hatırlatma düşer.'
              : 'Zümre başkanı toplantı eklediğinde burada görünür ve panelinize hatırlatma düşer.',
        )
      else ...[
        const Baslik('Sıradaki toplantılar'),
        for (final t in toplantilar) _toplantiKarti(context, t, tekrarlar, baskan),
      ],
      if (kararlar.isNotEmpty) ...[
        const Baslik('Alınan kararlar'),
        for (final c in kararlar)
          KartKutu(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${c.s('baslik')} · ${uzunTarih(c.s('tarih'))} ${c.s('saat')}', style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(c.s('yazan'), style: TextStyle(color: context.soluk, fontSize: 12)),
                const SizedBox(height: 6),
                Text(c.s('karar'), style: const TextStyle(height: 1.35)),
                if (baskan)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => _karar(
                          baslik: '${c.s('baslik')} · ${uzunTarih(c.s('tarih'))}',
                          karar: c.s('karar'),
                          kaydet: (m) => _gonder('/api/zumre/karar', {
                            'courseId': widget.courseId,
                            'toplantiId': c.n('toplantiId'),
                            'tarih': c.s('tarih'),
                            'karar': m,
                          }, ileti: 'Karar kaydedildi.'),
                        ),
                        child: const Text('Düzenle'),
                      ),
                      TextButton(
                        onPressed: () => _sil('/api/zumre/karar-sil', {'courseId': widget.courseId, 'id': c.n('id')}, 'Bu toplantı kararı silinsin mi?'),
                        child: Text('Sil', style: TextStyle(color: Colors.red.shade600)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
      ],
    ];
  }

  Widget _toplantiKarti(BuildContext context, Map<String, dynamic> t, Map<String, dynamic> tekrarlar, bool baskan) {
    final sira = (t['siradaki'] as List? ?? const []).cast<String>();
    final ilk = sira.isEmpty ? null : sira.first;
    final bekleyen = t.s('bekleyen');
    final (gun, ay) = ilk == null ? ('–', 'bitti') : ('${tarihCoz(ilk).day}', ayAdlari[tarihCoz(ilk).month - 1].substring(0, 3));
    final ozet = [
      ilk == null ? t.s('saat') : '${gunAdlari[tarihCoz(ilk).weekday - 1]} ${t.s('saat')}',
      t.s('yer'),
      '${tekrarlar[t.s('tekrar')] ?? ''}',
    ].where((x) => x.isNotEmpty).join(' · ');
    return KartKutu(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(color: context.ana.withValues(alpha: .1), borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    Text(
                      gun,
                      style: TextStyle(color: context.ana, fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    Text(ay, style: TextStyle(color: context.ana, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.s('baslik'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                    Text(ozet, style: TextStyle(color: context.soluk, fontSize: 13)),
                    if (ilk != null)
                      Text(
                        _kalanYazi(ilk),
                        style: TextStyle(color: context.ana, fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    if (sira.length > 1) Text('Sonraki: ${sira.skip(1).map(uzunTarih).join(' · ')}', style: TextStyle(color: context.soluk, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          if (t.s('gundem').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(t.s('gundem'), style: const TextStyle(height: 1.35)),
            ),
          if (baskan && bekleyen.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text('${uzunTarih(bekleyen)} toplantısı yapıldı, kararı yazılmadı', style: TextStyle(color: context.soluk, fontSize: 12.5)),
                  ),
                  FilledButton(
                    onPressed: () => _karar(
                      baslik: '${t.s('baslik')} · ${uzunTarih(bekleyen)}',
                      karar: '',
                      kaydet: (m) => _gonder('/api/zumre/karar', {
                        'courseId': widget.courseId,
                        'toplantiId': t.n('id'),
                        'tarih': bekleyen,
                        'karar': m,
                      }, ileti: 'Karar kaydedildi.'),
                    ),
                    child: const Text('Toplantıyı bitir'),
                  ),
                ],
              ),
            ),
          if (baskan)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => _toplantiFormu(t), child: const Text('Düzenle')),
                TextButton(
                  onPressed: () =>
                      _sil('/api/zumre/toplanti-sil', {'courseId': widget.courseId, 'id': t.n('id')}, '"${t.s('baslik')}" toplantısı silinsin mi?'),
                  child: Text('Sil', style: TextStyle(color: Colors.red.shade600)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ---- Yazılar ----
  List<Widget> _yazilar(BuildContext context, Map<String, dynamic> v) {
    final baskan = v['baskan'] == true;
    final yazilar = v.l('yazilar');
    return [
      TextField(
        controller: _yazi,
        minLines: 2,
        maxLines: 6,
        maxLength: 1000,
        decoration: const InputDecoration(hintText: 'Zümreye bir not, duyuru ya da bilgi yazın…'),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton(
          onPressed: () async {
            if (_yazi.text.trim().isEmpty) return;
            final metin = _yazi.text;
            await _gonder('/api/zumre/yazi', {'courseId': widget.courseId, 'metin': metin});
            if (mounted && _veri!.l('yazilar').any((y) => y.s('metin').trim() == metin.trim())) _yazi.clear();
          },
          child: const Text('Paylaş'),
        ),
      ),
      const SizedBox(height: 8),
      if (yazilar.isEmpty) const BosNot('Henüz yazı yok. Zümredeki herkes yazabilir.'),
      for (final y in yazilar)
        KartKutu(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(y.s('yazan'), style: const TextStyle(fontWeight: FontWeight.w700)),
                        if (y['baskan'] == true) const Cip('Zümre başkanı'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(_zaman(y['zaman']), style: TextStyle(color: context.soluk, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 6),
              Text(y.s('metin'), style: const TextStyle(height: 1.35)),
              if (y['benim'] == true || baskan)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _sil('/api/zumre/yazi-sil', {'courseId': widget.courseId, 'id': y.n('id')}, 'Bu yazı silinsin mi?'),
                    child: Text('Sil', style: TextStyle(color: Colors.red.shade600)),
                  ),
                ),
            ],
          ),
        ),
    ];
  }

  // ---- Öğretmenler ----
  List<Widget> _ogretmenler(BuildContext context, Map<String, dynamic> v) {
    final liste = v.l('ogretmenler');
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text('${(v['zumre'] as Map)['ad']} zümresinde ${liste.length} öğretmen var.', style: TextStyle(color: context.soluk)),
      ),
      for (final o in liste)
        KartKutu(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${o.s('ad')}${o['ben'] == true ? ' (siz)' : ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(o['baskan'] == true ? 'Zümre başkanı' : 'Öğretmen', style: TextStyle(color: context.soluk, fontSize: 12.5)),
                  ],
                ),
              ),
              if (o.s('telefon').isNotEmpty && o['ben'] != true)
                Text(
                  o.s('telefon'),
                  style: TextStyle(color: context.ana, fontWeight: FontWeight.w600),
                ),
            ],
          ),
        ),
    ];
  }

  // ---- Başkanlar toplantıları ----
  List<Widget> _baskanlarSekmesi(BuildContext context) {
    final b = _baskanlar;
    if (b == null) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 30),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: context.ana)),
        ),
      ];
    }
    final liste = b.l('toplantilar');
    if (liste.isEmpty) {
      return [const BosNot('Yönetim zümre başkanları toplantısı kurduğunda burada görünür; toplantıdan sonra alınan kararlar da burada yazılır.')];
    }
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text('Bu toplantılar ve kararları yalnızca yönetim ile zümre başkanlarına görünür.', style: TextStyle(color: context.soluk, fontSize: 12.5)),
      ),
      for (final t in liste)
        KartKutu(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.s('baslik'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
              Text(
                '${uzunTarih(t.s('tarih'))} ${t.s('saat')}${t.s('yer').isEmpty ? '' : ' · ${t.s('yer')}'}',
                style: TextStyle(color: context.soluk, fontSize: 12.5),
              ),
              if (t.s('gundem').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(t.s('gundem'), style: const TextStyle(height: 1.35)),
                ),
              if (t.s('karar').isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Alınan kararlar',
                  style: TextStyle(color: context.soluk, fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                Text(t.s('karar'), style: const TextStyle(height: 1.35)),
                Text('${t.s('kararYazan')} · ${_zaman(t['kararZamani'])}', style: TextStyle(color: context.soluk, fontSize: 12)),
              ] else if (t['basladi'] == true)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Karar henüz yazılmadı.', style: TextStyle(color: context.soluk)),
                ),
              if (t['basladi'] == true)
                Align(
                  alignment: Alignment.centerRight,
                  child: t.s('karar').isEmpty
                      ? FilledButton(onPressed: () => _baskanKarar(t), child: const Text('Toplantıyı bitir'))
                      : OutlinedButton(onPressed: () => _baskanKarar(t), child: const Text('Kararı düzenle')),
                ),
            ],
          ),
        ),
    ];
  }

  Future<void> _baskanKarar(Map<String, dynamic> t) => _karar(
    baslik: t.s('baslik'),
    karar: t.s('karar'),
    kaydet: (m) => _gonder('/api/zumre/baskanlar/karar', {'id': t.n('id'), 'karar': m}, ileti: 'Karar kaydedildi.'),
  );
}

class _KararSayfasi extends StatefulWidget {
  const _KararSayfasi({required this.baslik, required this.karar});

  final String baslik;
  final String karar;

  @override
  State<_KararSayfasi> createState() => _KararSayfasiState();
}

class _KararSayfasiState extends State<_KararSayfasi> {
  late final _metin = TextEditingController(text: widget.karar);

  @override
  void dispose() {
    _metin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Alınan kararlar')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text(widget.baslik, style: serif.copyWith(fontSize: 17, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        TextField(
          controller: _metin,
          minLines: 6,
          maxLines: 14,
          maxLength: 2000,
          decoration: const InputDecoration(hintText: 'Toplantıda alınan kararlar, görevler, sonraki adımlar…', alignLabelWithHint: true),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: () => Navigator.pop(context, _metin.text),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          child: const Text('Kaydet'),
        ),
      ],
    ),
  );
}

class _ToplantiFormu extends StatefulWidget {
  const _ToplantiFormu({required this.api, required this.courseId, required this.tekrarlar, required this.mevcut});

  final Api api;
  final int courseId;
  final Map<String, dynamic> tekrarlar;
  final Map<String, dynamic>? mevcut;

  @override
  State<_ToplantiFormu> createState() => _ToplantiFormuState();
}

class _ToplantiFormuState extends State<_ToplantiFormu> {
  late final _baslik = TextEditingController(text: widget.mevcut?.s('baslik') ?? 'Zümre toplantısı');
  late final _yer = TextEditingController(text: widget.mevcut?.s('yer') ?? '');
  late final _gundem = TextEditingController(text: widget.mevcut?.s('gundem') ?? '');
  late String _tekrar = widget.mevcut?.s('tekrar').isNotEmpty == true ? widget.mevcut!.s('tekrar') : 'haftalik';
  late String _tarih = widget.mevcut?.s('baslangic').isNotEmpty == true ? widget.mevcut!.s('baslangic') : _bugun();
  late String _saat = widget.mevcut?.s('saat').isNotEmpty == true ? widget.mevcut!.s('saat') : '15:00';
  bool _gonderiliyor = false;

  @override
  void dispose() {
    _baslik.dispose();
    _yer.dispose();
    _gundem.dispose();
    super.dispose();
  }

  Future<void> _tarihSec() async {
    final t = tarihCoz(_tarih);
    final s = await showDatePicker(
      context: context,
      initialDate: DateTime(t.year, t.month, t.day),
      firstDate: DateTime(t.year - 1),
      lastDate: DateTime(t.year + 3),
    );
    if (s != null) setState(() => _tarih = tarihYaz(s));
  }

  Future<void> _saatSec() async {
    final s = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.tryParse(_saat.substring(0, 2)) ?? 15, minute: int.tryParse(_saat.substring(3, 5)) ?? 0),
      builder: (context, c) => MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: c!),
    );
    if (s != null) setState(() => _saat = '${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')}');
  }

  Future<void> _kaydet() async {
    setState(() => _gonderiliyor = true);
    try {
      await widget.api.post('/api/zumre/toplanti', {
        if (widget.mevcut != null) 'id': widget.mevcut!.n('id'),
        'courseId': widget.courseId,
        'baslik': _baslik.text,
        'tekrar': _tekrar,
        'tarih': _tarih,
        'saat': _saat,
        'yer': _yer.text,
        'gundem': _gundem.text,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _gonderiliyor = false);
        hataGoster(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.mevcut == null ? 'Yeni toplantı' : 'Toplantıyı düzenle')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        TextField(
          controller: _baslik,
          maxLength: 80,
          decoration: const InputDecoration(labelText: 'Başlık'),
        ),
        TextField(
          controller: _yer,
          maxLength: 60,
          decoration: const InputDecoration(labelText: 'Yer', hintText: 'Örn. Öğretmenler odası'),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: _tarihSec,
                child: InputDecorator(
                  decoration: InputDecoration(labelText: widget.mevcut == null ? 'İlk toplantı' : 'Başlangıç tarihi'),
                  child: Text(uzunTarih(_tarih)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 110,
              child: InkWell(
                onTap: _saatSec,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Saat'),
                  child: Text(_saat),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: widget.tekrarlar.containsKey(_tekrar) ? _tekrar : null,
          decoration: const InputDecoration(labelText: 'Tekrar'),
          items: [for (final e in widget.tekrarlar.entries) DropdownMenuItem(value: e.key, child: Text('${e.value}'))],
          onChanged: (s) => setState(() => _tekrar = s ?? _tekrar),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _gundem,
          minLines: 3,
          maxLines: 8,
          maxLength: 500,
          decoration: const InputDecoration(labelText: 'Gündem', hintText: 'Gündem maddeleri (isteğe bağlı)', alignLabelWithHint: true),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: _gonderiliyor ? null : _kaydet,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          child: Text(_gonderiliyor ? 'Kaydediliyor…' : (widget.mevcut == null ? 'Toplantıyı ekle' : 'Kaydet')),
        ),
      ],
    ),
  );
}

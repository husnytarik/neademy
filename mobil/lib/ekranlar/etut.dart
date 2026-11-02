import 'package:flutter/material.dart';

import '../bilesenler/ortak.dart';
import '../cekirdek/api.dart';
import '../cekirdek/takvim_model.dart';
import '../cekirdek/tema.dart';

const _yesil = Color(0xFF2E9E5B);
const _kirmizi = Color(0xFFD64545);
const _yanitAd = {'bekliyor': 'Yanıt bekleniyor', 'gelecek': 'Gelecek', 'gelmeyecek': 'Gelmeyecek'};
const _devamAd = {'geldi': 'Geldi', 'gelmedi': 'Gelmedi', 'izinli': 'İzinli'};

String _bugun() => tarihYaz(DateTime.now());

String _tarihEtiket(String t) {
  final d = tarihCoz(t);
  return '${d.day} ${ayAdlari[d.month - 1]} ${gunAdlari[d.weekday - 1]}';
}

/// Etüt: öğretmen açar ve yoklama alır, veli "gelecek / gelmeyecek" bildirir, öğrenci davetlerini görür.
class EtutEkrani extends StatefulWidget {
  const EtutEkrani({super.key, required this.api, required this.rol});

  final Api api;

  /// 'ogretmen' | 'veli' | 'ogrenci'
  final String rol;

  @override
  State<EtutEkrani> createState() => _EtutEkraniState();
}

class _EtutEkraniState extends State<EtutEkrani> {
  int _surum = 0;

  Future<void> _islem(Future<dynamic> Function() is_, {String? basari}) async {
    try {
      await is_();
      if (!mounted) return;
      if (basari != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(basari)));
      }
      setState(() => _surum++);
    } catch (e) {
      if (mounted) hataGoster(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ogretmen = widget.rol == 'ogretmen';
    final sayfa = VeriSayfasi(
      key: ValueKey(_surum),
      baslik: widget.rol == 'veli' ? 'Etüt onayları' : widget.rol == 'ogrenci' ? 'Etütlerim' : 'Etüt',
      getir: () => widget.api.get('/api/etut/liste'),
      cizim: (context, veri) {
        final etutler = (veri as Map<String, dynamic>).l('etutler');
        final bugun = _bugun();
        final yaklasan = [for (final e in etutler) if (e.s('durum') == 'planli' && e.s('tarih').compareTo(bugun) >= 0) e]
          ..sort((a, b) => '${a.s('tarih')}${a.s('saat')}'.compareTo('${b.s('tarih')}${b.s('saat')}'));
        final gecmis = [for (final e in etutler) if (!yaklasan.contains(e)) e];
        Widget kart(Map<String, dynamic> e) => switch (widget.rol) {
              'ogretmen' => _OgretmenEtut(e, bugun: bugun, iptal: () => _iptal(e), yoklama: () => _yoklama(e)),
              'veli' => _VeliEtut(e, bugun: bugun, yanit: (y) => _yanit(e, y)),
              _ => _OgrenciEtut(e),
            };
        return [
          if (etutler.isEmpty) BosNot(ogretmen ? 'Henüz etüt açmadınız.' : 'Etüt daveti yok.'),
          if (yaklasan.isNotEmpty) const Baslik('Yaklaşan', ust: 8),
          for (final e in yaklasan) kart(e),
          if (gecmis.isNotEmpty) const Baslik('Geçmiş ve iptal edilenler'),
          for (final e in gecmis) kart(e),
        ];
      },
    );
    if (!ogretmen) return sayfa;
    return Stack(children: [
      sayfa,
      Positioned(
        right: 16,
        bottom: 16 + MediaQuery.of(context).padding.bottom,
        child: FloatingActionButton.extended(onPressed: _yeni, icon: const Icon(Icons.add), label: const Text('Etüt aç')),
      ),
    ]);
  }

  Future<void> _yanit(Map<String, dynamic> e, String y) => _islem(
        () => widget.api.post('/api/etut/yanit', {'etutId': e.n('id'), 'ogrenciId': e.n('ogrenciId'), 'yanit': y}),
        basari: y == 'gelecek' ? 'Katılım bildirildi.' : 'Katılmayacağınız bildirildi.',
      );

  Future<void> _iptal(Map<String, dynamic> e) async {
    if (!await onayIste(context, '"${e.s('konu')}" etütü iptal edilsin mi?', evet: 'İptal et')) return;
    await _islem(() => widget.api.post('/api/etut/iptal', {'etutId': e.n('id')}), basari: 'Etüt iptal edildi.');
  }

  Future<void> _yoklama(Map<String, dynamic> e) async {
    final durum = <int, String>{
      for (final k in e.l('katilimcilar')) k.n('ogrenciId'): k.s('devam').isEmpty ? 'geldi' : k.s('devam'),
    };
    final tamam = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: .75,
          maxChildSize: .95,
          builder: (c, kaydir) => Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(alignment: Alignment.centerLeft, child: Text('Yoklama · ${e.s('konu')}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
            ),
            Expanded(
              child: ListView(controller: kaydir, padding: const EdgeInsets.fromLTRB(20, 8, 20, 8), children: [
                for (final k in e.l('katilimcilar'))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(k.s('ad'), style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      SegmentedButton<String>(
                        showSelectedIcon: false,
                        segments: [for (final d in _devamAd.entries) ButtonSegment(value: d.key, label: Text(d.value))],
                        selected: {durum[k.n('ogrenciId')]!},
                        onSelectionChanged: (s) => set(() => durum[k.n('ogrenciId')] = s.first),
                      ),
                    ]),
                  ),
              ]),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + MediaQuery.of(c).padding.bottom),
              child: FilledButton(onPressed: () => Navigator.pop(c, true), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)), child: const Text('Kaydet')),
            ),
          ]),
        ),
      ),
    );
    if (tamam != true) return;
    await _islem(
      () => widget.api.post('/api/etut/yoklama', {
        'etutId': e.n('id'),
        'kayitlar': [for (final d in durum.entries) {'ogrenciId': d.key, 'durum': d.value}],
      }),
      basari: 'Yoklama kaydedildi.',
    );
  }

  Future<void> _yeni() async {
    Map<String, dynamic> secenek;
    try {
      secenek = await widget.api.get('/api/etut/secenek') as Map<String, dynamic>;
    } catch (e) {
      if (mounted) hataGoster(context, e);
      return;
    }
    if (!mounted) return;
    final govde = await Navigator.of(context).push<Map<String, dynamic>>(MaterialPageRoute(builder: (_) => _EtutFormu(secenek: secenek)));
    if (govde == null) return;
    try {
      await widget.api.post('/api/etut/ekle', govde);
    } on ApiHata catch (e) {
      if (!mounted) return;
      if (e.kod == 409 && e.mesaj.contains('ders programı')) {
        if (!await onayIste(context, '${e.mesaj}. Yine de etüt açılsın mı?', evet: 'Yine de aç')) return;
        await _islem(() => widget.api.post('/api/etut/ekle', {...govde, 'cakismayiOnayla': true}), basari: 'Etüt açıldı.');
      } else {
        hataGoster(context, e);
      }
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Etüt açıldı; veliler bilgilendirilecek.')));
      setState(() => _surum++);
    }
  }
}

class _Baslik extends StatelessWidget {
  const _Baslik(this.e);

  final Map<String, dynamic> e;

  @override
  Widget build(BuildContext context) {
    final iptal = e.s('durum') == 'iptal';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Text(
            e.s('ders').isEmpty ? e.s('konu') : '${e.s('ders')} · ${e.s('konu')}',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, decoration: iptal ? TextDecoration.lineThrough : null),
          ),
        ),
        if (iptal) const Cip('İptal', renk: _kirmizi),
      ]),
      const SizedBox(height: 3),
      Text('${_tarihEtiket(e.s('tarih'))} · ${e.s('saat')} · ${e.n('sureDk')} dk${e.s('yer').isEmpty ? '' : ' · ${e.s('yer')}'}', style: TextStyle(color: context.soluk, fontSize: 13.5)),
      if (e.s('ogretmen').isNotEmpty) Text(e.s('ogretmen'), style: TextStyle(color: context.soluk, fontSize: 13.5)),
      if (e.s('not').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(e.s('not'), style: const TextStyle(fontSize: 13.5, height: 1.35))),
    ]);
  }
}

class _OgrenciEtut extends StatelessWidget {
  const _OgrenciEtut(this.e);

  final Map<String, dynamic> e;

  @override
  Widget build(BuildContext context) => KartKutu(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Baslik(e),
          const SizedBox(height: 8),
          Wrap(spacing: 6, children: [
            if (e.s('devam').isNotEmpty) Cip('Devam: ${_devamAd[e.s('devam')] ?? e.s('devam')}', renk: e.s('devam') == 'gelmedi' ? _kirmizi : _yesil),
            if (e.s('devam').isEmpty && e.s('durum') == 'planli') Cip('Velinin yanıtı: ${_yanitAd[e.s('yanit')] ?? e.s('yanit')}'),
          ]),
        ]),
      );
}

class _VeliEtut extends StatelessWidget {
  const _VeliEtut(this.e, {required this.bugun, required this.yanit});

  final Map<String, dynamic> e;
  final String bugun;
  final void Function(String) yanit;

  @override
  Widget build(BuildContext context) {
    final acik = e.s('durum') == 'planli' && e.s('tarih').compareTo(bugun) >= 0;
    final y = e.s('yanit');
    return KartKutu(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (e.s('ogrenci').isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 4), child: Cip(e.s('ogrenci'), renk: context.ana)),
        _Baslik(e),
        const SizedBox(height: 10),
        if (acik)
          Row(children: [
            Expanded(
              child: FilledButton.tonal(
                onPressed: () => yanit('gelecek'),
                style: y == 'gelecek' ? FilledButton.styleFrom(backgroundColor: _yesil, foregroundColor: Colors.white) : null,
                child: const Text('Gelecek'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonal(
                onPressed: () => yanit('gelmeyecek'),
                style: y == 'gelmeyecek' ? FilledButton.styleFrom(backgroundColor: _kirmizi, foregroundColor: Colors.white) : null,
                child: const Text('Gelmeyecek'),
              ),
            ),
          ])
        else if (e.s('devam').isNotEmpty)
          Cip('Devam: ${_devamAd[e.s('devam')] ?? e.s('devam')}', renk: e.s('devam') == 'gelmedi' ? _kirmizi : _yesil)
        else if (e.s('durum') == 'planli')
          Cip('Yanıt: ${_yanitAd[y] ?? y}'),
      ]),
    );
  }
}

class _OgretmenEtut extends StatelessWidget {
  const _OgretmenEtut(this.e, {required this.bugun, required this.iptal, required this.yoklama});

  final Map<String, dynamic> e;
  final String bugun;
  final VoidCallback iptal;
  final VoidCallback yoklama;

  @override
  Widget build(BuildContext context) {
    final planli = e.s('durum') == 'planli';
    final kat = e.l('katilimcilar');
    int say(String y) => kat.where((k) => k.s('yanit') == y).length;
    return KartKutu(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Baslik(e),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          Cip('${kat.length} öğrenci'),
          if (planli) ...[Cip('${say('gelecek')} gelecek', renk: _yesil), Cip('${say('gelmeyecek')} gelmeyecek', renk: _kirmizi), Cip('${say('bekliyor')} bekliyor')],
        ]),
        if (kat.isNotEmpty)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              dense: true,
              title: Text('Öğrenciler', style: TextStyle(color: context.soluk, fontSize: 13.5)),
              children: [
                for (final k in kat)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(k.s('ad')),
                    trailing: Text(k.s('devam').isNotEmpty ? _devamAd[k.s('devam')] ?? '' : _yanitAd[k.s('yanit')] ?? '', style: TextStyle(color: context.soluk, fontSize: 12.5)),
                  ),
              ],
            ),
          ),
        if (planli)
          Wrap(spacing: 8, children: [
            if (e.s('tarih').compareTo(bugun) <= 0) OutlinedButton(onPressed: yoklama, child: const Text('Yoklama al')),
            TextButton(onPressed: iptal, style: TextButton.styleFrom(foregroundColor: _kirmizi), child: const Text('İptal et')),
          ]),
      ]),
    );
  }
}

/// Yeni etüt formu; doldurulunca `/api/etut/ekle` gövdesini döndürür.
class _EtutFormu extends StatefulWidget {
  const _EtutFormu({required this.secenek});

  final Map<String, dynamic> secenek;

  @override
  State<_EtutFormu> createState() => _EtutFormuState();
}

class _EtutFormuState extends State<_EtutFormu> {
  final _konu = TextEditingController();
  final _yer = TextEditingController();
  final _not = TextEditingController();
  DateTime _tarih = DateTime.now();
  TimeOfDay _saat = const TimeOfDay(hour: 15, minute: 30);
  late int _sure = (widget.secenek['sureler'] as List?)?.map((e) => e as num).map((e) => e.toInt()).firstOrNull ?? 40;
  int? _ders;
  final _siniflar = <int>{};
  final _ogrenciler = <int>{};
  String? _hata;

  @override
  void dispose() {
    _konu.dispose();
    _yer.dispose();
    _not.dispose();
    super.dispose();
  }

  void _gonder() {
    if (_konu.text.trim().length < 2) return setState(() => _hata = 'Konuyu yazın.');
    if (_siniflar.isEmpty && _ogrenciler.isEmpty) return setState(() => _hata = 'En az bir sınıf ya da öğrenci seçin.');
    Navigator.pop(context, {
      'konu': _konu.text.trim(),
      'tarih': tarihYaz(_tarih),
      'saat': '${_saat.hour.toString().padLeft(2, '0')}:${_saat.minute.toString().padLeft(2, '0')}',
      'sureDk': _sure,
      'dersId': _ders,
      'yer': _yer.text.trim(),
      'not': _not.text.trim(),
      'sinifIds': _siniflar.toList(),
      'ogrenciIds': _ogrenciler.toList(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final sureler = [for (final s in (widget.secenek['sureler'] as List? ?? const [40])) (s as num).toInt()];
    final dersler = widget.secenek.l('dersler');
    final siniflar = widget.secenek.l('siniflar');
    final ogrenciler = widget.secenek.l('ogrenciler');
    return Scaffold(
      appBar: AppBar(title: const Text('Yeni etüt')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
          TextField(controller: _konu, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Konu')),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.event_outlined),
                label: Text(_tarihEtiket(tarihYaz(_tarih))),
                onPressed: () async {
                  final d = await showDatePicker(context: context, initialDate: _tarih, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 180)));
                  if (d != null) setState(() => _tarih = d);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.schedule_outlined),
                label: Text(_saat.format(context)),
                onPressed: () async {
                  final s = await showTimePicker(context: context, initialTime: _saat);
                  if (s != null) setState(() => _saat = s);
                },
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: sureler.contains(_sure) ? _sure : null,
                decoration: const InputDecoration(labelText: 'Süre'),
                items: [for (final s in sureler) DropdownMenuItem(value: s, child: Text('$s dk'))],
                onChanged: (s) => setState(() => _sure = s ?? _sure),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<int?>(
                initialValue: _ders,
                decoration: const InputDecoration(labelText: 'Ders'),
                items: [const DropdownMenuItem<int?>(value: null, child: Text('Belirtme')), for (final d in dersler) DropdownMenuItem<int?>(value: d.n('id'), child: Text(d.s('ad')))],
                onChanged: (d) => setState(() => _ders = d),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          TextField(controller: _yer, decoration: const InputDecoration(labelText: 'Yer (isteğe bağlı)')),
          const SizedBox(height: 12),
          TextField(controller: _not, maxLines: 2, decoration: const InputDecoration(labelText: 'Not (isteğe bağlı)')),
          const Baslik('Sınıflar'),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final s in siniflar)
              FilterChip(
                label: Text(s.s('ad')),
                selected: _siniflar.contains(s.n('id')),
                onSelected: (v) => setState(() => v ? _siniflar.add(s.n('id')) : _siniflar.remove(s.n('id'))),
              ),
          ]),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('Tek tek öğrenci seç${_ogrenciler.isEmpty ? '' : ' (${_ogrenciler.length})'}', style: const TextStyle(fontWeight: FontWeight.w600)),
              children: [
                for (final o in ogrenciler)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(o.s('ad')),
                    value: _ogrenciler.contains(o.n('id')),
                    onChanged: (v) => setState(() => v == true ? _ogrenciler.add(o.n('id')) : _ogrenciler.remove(o.n('id'))),
                  ),
              ],
            ),
          ),
          if (_hata != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_hata!, style: const TextStyle(color: _kirmizi, fontWeight: FontWeight.w600))),
          const SizedBox(height: 16),
          FilledButton(onPressed: _gonder, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)), child: const Text('Etüt aç')),
        ]),
      ),
    );
  }
}

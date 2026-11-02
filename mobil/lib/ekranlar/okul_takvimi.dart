import 'package:flutter/material.dart';

import '../bilesenler/ortak.dart';
import '../cekirdek/api.dart';
import '../cekirdek/tema.dart';

const _kisa = {1: 'Pzt', 2: 'Sal', 3: 'Çar', 4: 'Per', 5: 'Cum', 6: 'Cmt', 0: 'Paz'};

int _dk(String s) => (int.tryParse(s.substring(0, 2)) ?? 0) * 60 + (int.tryParse(s.substring(3, 5)) ?? 0);

String _saatYaz(int n) => '${((n ~/ 60) % 24).toString().padLeft(2, '0')}:${(n % 60).toString().padLeft(2, '0')}';

/// Okul takvimi: ders günleri ve zil saatleri.
class OkulTakvimiEkrani extends StatefulWidget {
  const OkulTakvimiEkrani({super.key, required this.api});

  final Api api;

  @override
  State<OkulTakvimiEkrani> createState() => _OkulTakvimiEkraniState();
}

class _OkulTakvimiEkraniState extends State<OkulTakvimiEkrani> {
  int _n = 0;
  bool _duzenle = false;
  bool _mesgul = false;
  List<Map<String, dynamic>> _gunler = [];
  List<Map<String, String>> _saatler = [];

  void _baslat(Map<String, dynamic> v) {
    _gunler = [
      for (final g in v.l('gunler')) {...g},
    ];
    _saatler = [
      for (final s in v.l('saatler')) {'bas': s.s('bas'), 'bit': s.s('bit')},
    ];
    _duzenle = true;
  }

  Future<void> _saatSec(int i, String alan) async {
    final mevcut = _saatler[i][alan]!;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.tryParse(mevcut.split(':').first) ?? 8, minute: int.tryParse(mevcut.split(':').last) ?? 0),
      builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: w!),
    );
    if (t != null) setState(() => _saatler[i][alan] = _saatYaz(t.hour * 60 + t.minute));
  }

  void _saatEkle() {
    if (_saatler.length >= 14) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('En fazla 14 ders saati tanımlanabilir')));
      return;
    }
    var bas = '08:00';
    var bit = '08:40';
    if (_saatler.isNotEmpty && _saatler.last['bit']!.length == 5) {
      bas = _saatYaz(_dk(_saatler.last['bit']!) + 10);
      bit = _saatYaz(_dk(_saatler.last['bit']!) + 50);
    }
    setState(() => _saatler.add({'bas': bas, 'bit': bit}));
  }

  Future<void> _kaydet() async {
    setState(() => _mesgul = true);
    try {
      await widget.api.post('/api/yonetim/okul-ayar', {
        'gunler': [
          for (final g in _gunler)
            if (g['acik'] == true) g.n('no'),
        ],
        'saatler': _saatler,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Okul takvimi kaydedildi.')));
      setState(() {
        _duzenle = false;
        _mesgul = false;
        _n++;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _mesgul = false);
      hataGoster(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => VeriSayfasi(
    key: ValueKey(_n),
    baslik: 'Okul takvimi',
    getir: () async => await widget.api.get('/api/okul/ayar'),
    cizim: (context, raw) {
      final v = raw as Map<String, dynamic>;
      if (!_duzenle) return _goruntu(context, v);
      return _form(context);
    },
  );

  List<Widget> _goruntu(BuildContext context, Map<String, dynamic> v) => [
    Align(
      alignment: Alignment.centerRight,
      child: TextButton(onPressed: () => setState(() => _baslat(v)), child: const Text('Düzenle')),
    ),
    const Baslik('Ders günleri'),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [for (final g in v.l('gunler')) _GunCipi(etiket: _kisa[g.n('no')] ?? g.s('ad'), acik: g['acik'] == true)],
    ),
    const Baslik('Ders saatleri', ust: 18),
    if (v.l('saatler').isEmpty) const BosNot('Ders saati tanımlı değil.'),
    for (final (i, s) in v.l('saatler').indexed)
      KartKutu(
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: context.ana.withValues(alpha: .14),
              child: Text(
                '${i + 1}',
                style: TextStyle(color: context.ana, fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12),
            Text('${s.s('bas')} – ${s.s('bit')}', style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
  ];

  List<Widget> _form(BuildContext context) => [
    const Baslik('Ders günleri'),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final g in _gunler)
          _GunCipi(etiket: _kisa[g.n('no')] ?? g.s('ad'), acik: g['acik'] == true, onTap: () => setState(() => g['acik'] = g['acik'] != true)),
      ],
    ),
    const Baslik('Ders saatleri', ust: 18),
    for (final (i, s) in _saatler.indexed)
      KartKutu(
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text(
                '${i + 1}',
                style: TextStyle(color: context.soluk, fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(
              child: OutlinedButton(onPressed: () => _saatSec(i, 'bas'), child: Text(s['bas']!.isEmpty ? '--:--' : s['bas']!)),
            ),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('–')),
            Expanded(
              child: OutlinedButton(onPressed: () => _saatSec(i, 'bit'), child: Text(s['bit']!.isEmpty ? '--:--' : s['bit']!)),
            ),
            IconButton(
              tooltip: 'Bu ders saatini kaldır',
              icon: const Icon(Icons.close, size: 20),
              onPressed: _saatler.length < 2 ? null : () => setState(() => _saatler.removeAt(i)),
            ),
          ],
        ),
      ),
    TextButton(onPressed: _saatEkle, child: const Text('+ Ders saati ekle')),
    const SizedBox(height: 12),
    FilledButton(
      onPressed: _mesgul ? null : _kaydet,
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
      child: Text(_mesgul ? 'Kaydediliyor…' : 'Kaydet'),
    ),
    TextButton(onPressed: _mesgul ? null : () => setState(() => _duzenle = false), child: const Text('Vazgeç')),
  ];
}

class _GunCipi extends StatelessWidget {
  const _GunCipi({required this.etiket, required this.acik, this.onTap});

  final String etiket;
  final bool acik;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: acik ? context.ana : context.icZemin,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: acik ? context.ana : context.ince),
      ),
      child: Text(
        etiket,
        style: TextStyle(color: acik ? Colors.white : context.soluk, fontWeight: FontWeight.w600),
      ),
    ),
  );
}

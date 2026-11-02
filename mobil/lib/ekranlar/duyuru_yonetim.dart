import 'package:flutter/material.dart';

import '../bilesenler/ortak.dart';
import '../cekirdek/api.dart';
import '../cekirdek/takvim_model.dart';
import '../cekirdek/tema.dart';

String _gunAy(num ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms.toInt());
  return '${d.day} ${ayAdlari[d.month - 1].substring(0, 3)}';
}

/// Yönetim: okul duyurusu yayınla, yayınlananları (kaç kişi okudu) gör ve sil.
class DuyuruYonetimEkrani extends StatefulWidget {
  const DuyuruYonetimEkrani({super.key, required this.api});

  final Api api;

  @override
  State<DuyuruYonetimEkrani> createState() => _DuyuruYonetimEkraniState();
}

class _DuyuruYonetimEkraniState extends State<DuyuruYonetimEkrani> {
  int _yenile = 0;

  Future<void> _yaz() async {
    final tamam = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => _DuyuruFormu(api: widget.api)));
    if (tamam == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Duyuru yayınlandı.')));
      setState(() => _yenile++);
    }
  }

  Future<void> _sil(Map<String, dynamic> x) async {
    if (!await onayIste(context, '"${x.s('baslik')}" silinsin mi?', evet: 'Sil')) return;
    try {
      await widget.api.post('/api/duyuru/sil', {'id': x.n('id')});
      if (mounted) setState(() => _yenile++);
    } catch (e) {
      if (mounted) hataGoster(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => VeriSayfasi(
    key: ValueKey(_yenile),
    baslik: 'Duyurular',
    getir: () => widget.api.get('/api/duyuru/liste'),
    cizim: (context, veri) {
      final liste = (veri as Map<String, dynamic>).l('duyurular');
      return [
        Row(
          children: [
            const Expanded(child: Baslik('Yayınlanan duyurular')),
            EkleDugmesi('+ Duyuru yaz', onPressed: _yaz),
          ],
        ),
        if (liste.isEmpty) const BosNot('Henüz duyuru yayınlanmadı.'),
        for (final x in liste)
          KartKutu(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(x.s('baslik'), style: serif.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                    if (x['tarih'] is num) Text(_gunAy(x['tarih'] as num), style: TextStyle(color: context.soluk, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(x.s('metin'), style: const TextStyle(height: 1.4)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text('${x.s('hedef')} · ${x.n('okunan')}/${x.n('alici')} okudu', style: TextStyle(color: context.soluk, fontSize: 12.5)),
                    ),
                    OutlinedButton(
                      onPressed: () => _sil(x),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD64545),
                        side: const BorderSide(color: Color(0xFFD64545)),
                        minimumSize: const Size(0, 34),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Sil', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ];
    },
  );
}

class _DuyuruFormu extends StatefulWidget {
  const _DuyuruFormu({required this.api});

  final Api api;

  @override
  State<_DuyuruFormu> createState() => _DuyuruFormuState();
}

class _DuyuruFormuState extends State<_DuyuruFormu> {
  final _baslik = TextEditingController();
  final _metin = TextEditingController();
  Map<String, dynamic>? _secenek;
  String _sube = '';
  String _kitle = 'hepsi';
  bool _gonderiliyor = false;
  String? _hata;

  @override
  void initState() {
    super.initState();
    widget.api
        .get('/api/duyuru/secenek')
        .then((j) {
          if (mounted) setState(() => _secenek = j as Map<String, dynamic>);
        })
        .catchError((Object e) {
          if (mounted) setState(() => _hata = e is ApiHata ? e.mesaj : 'Seçenekler alınamadı');
        });
  }

  @override
  void dispose() {
    _baslik.dispose();
    _metin.dispose();
    super.dispose();
  }

  Future<void> _yayinla() async {
    setState(() => _gonderiliyor = true);
    try {
      await widget.api.post('/api/duyuru/ekle', {'baslik': _baslik.text, 'metin': _metin.text, 'sube': _sube, 'rol': _kitle});
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _gonderiliyor = false);
        hataGoster(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _secenek;
    final okullar = s?.l('okullar') ?? const [];
    final roller = ((s?['roller'] as Map?) ?? const {}).cast<String, dynamic>();
    return Scaffold(
      appBar: AppBar(title: const Text('Duyuru yaz')),
      body: s == null
          ? Center(
              child: _hata == null ? const CircularProgressIndicator(strokeWidth: 2.5) : Text(_hata!, style: TextStyle(color: context.soluk)),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                TextField(
                  controller: _baslik,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: 'Başlık'),
                ),
                TextField(
                  controller: _metin,
                  minLines: 5,
                  maxLines: 12,
                  maxLength: 2000,
                  decoration: const InputDecoration(labelText: 'Duyuru', alignLabelWithHint: true),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _sube,
                  decoration: const InputDecoration(labelText: 'Kime (okul)'),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Tüm okullar')),
                    for (final o in okullar) DropdownMenuItem(value: '${o.n('id')}', child: Text(o.s('ad'))),
                  ],
                  onChanged: (v) => setState(() => _sube = v ?? ''),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: roller.containsKey(_kitle) ? _kitle : null,
                  decoration: const InputDecoration(labelText: 'Kitle'),
                  items: [for (final e in roller.entries) DropdownMenuItem(value: e.key, child: Text('${e.value}'))],
                  onChanged: (v) => setState(() => _kitle = v ?? _kitle),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _gonderiliyor ? null : _yayinla,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  child: Text(_gonderiliyor ? 'Yayınlanıyor…' : 'Yayınla'),
                ),
              ],
            ),
    );
  }
}

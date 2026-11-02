import 'package:flutter/material.dart';

import '../bilesenler/ortak.dart';
import '../cekirdek/api.dart';
import '../cekirdek/tema.dart';

/// Öğretmen: bir sınıfın velilerine ya da tek bir öğrencinin velisine mesaj gönderir; gönderilenler listelenir.
class VeliBilgilendirmeEkrani extends StatefulWidget {
  const VeliBilgilendirmeEkrani({super.key, required this.api});

  final Api api;

  @override
  State<VeliBilgilendirmeEkrani> createState() => _VeliBilgilendirmeEkraniState();
}

class _VeliBilgilendirmeEkraniState extends State<VeliBilgilendirmeEkrani> {
  int _yenile = 0;

  Future<void> _yaz() async {
    final gitti = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => _MesajYaz(api: widget.api)));
    if (gitti == true && mounted) setState(() => _yenile++);
  }

  Future<void> _sil(int id) async {
    if (!await onayIste(context, 'Bu mesaj silinsin mi?', evet: 'Sil')) return;
    try {
      await widget.api.post('/api/duyuru/sil', {'id': id});
      if (mounted) setState(() => _yenile++);
    } catch (e) {
      if (mounted) hataGoster(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
        VeriSayfasi(
          key: ValueKey(_yenile),
          baslik: 'Veli bilgilendirme',
          getir: () => widget.api.get('/api/duyuru/liste'),
          cizim: (context, veri) {
            final mesajlar = (veri as Map<String, dynamic>).l('mesajlar');
            return [
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _yaz,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Yeni mesaj'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              ),
              const Baslik('Gönderilenler'),
              if (mesajlar.isEmpty) const BosNot('Henüz mesaj göndermediniz.'),
              for (final m in mesajlar)
                KartKutu(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(m.s('baslik'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5))),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: context.soluk, size: 20),
                        tooltip: 'Sil',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _sil(m.n('id')),
                      ),
                    ]),
                    Text(m.s('metin'), style: const TextStyle(height: 1.35)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 4, children: [
                      Cip(m.s('hedef')),
                      Cip(m.s('tarih')),
                      if (m.n('okunan') > 0) Cip('${m.n('okunan')} okudu', renk: Colors.green.shade700),
                    ]),
                  ]),
                ),
            ];
          },
        ),
      ]);
}

class _MesajYaz extends StatefulWidget {
  const _MesajYaz({required this.api});

  final Api api;

  @override
  State<_MesajYaz> createState() => _MesajYazState();
}

class _MesajYazState extends State<_MesajYaz> {
  final _baslik = TextEditingController();
  final _metin = TextEditingController();
  Map<String, dynamic>? _secenek;
  String? _hata;
  int? _sinif;
  int? _ogrenci;
  bool _gonderiliyor = false;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    _baslik.dispose();
    _metin.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    try {
      final j = await widget.api.get('/api/duyuru/secenek') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _secenek = j;
        final s = j.l('siniflar');
        if (s.length == 1) _sinif = s.first.n('id');
      });
    } on ApiHata catch (e) {
      if (mounted && !e.oturumYok) setState(() => _hata = e.mesaj);
    }
  }

  Future<void> _gonder() async {
    if (_sinif == null) return hataGoster(context, ApiHata(0, 'Sınıf seçin.'));
    if (_baslik.text.trim().isEmpty || _metin.text.trim().isEmpty) return hataGoster(context, ApiHata(0, 'Başlık ve mesajı yazın.'));
    setState(() => _gonderiliyor = true);
    try {
      final r = await widget.api.post('/api/duyuru/mesaj', {
        'baslik': _baslik.text.trim(),
        'metin': _metin.text.trim(),
        'sinifId': _sinif,
        if (_ogrenci != null) 'ogrenciId': _ogrenci,
      }) as Map<String, dynamic>?;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Mesaj gönderildi${r == null ? '' : ' · ${r['veli'] ?? 0} veli'}')));
      Navigator.pop(context, true);
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
    final siniflar = s?.l('siniflar') ?? const <Map<String, dynamic>>[];
    final ogrenciler = [for (final o in s?.l('ogrenciler') ?? const <Map<String, dynamic>>[]) if (o.n('sinifId') == _sinif) o];
    return Scaffold(
      appBar: AppBar(title: const Text('Yeni mesaj')),
      body: s == null
          ? Center(child: _hata == null ? const CircularProgressIndicator(strokeWidth: 2.5) : Text(_hata!, style: TextStyle(color: context.soluk)))
          : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
              DropdownButtonFormField<int>(
                initialValue: _sinif,
                decoration: const InputDecoration(labelText: 'Sınıf'),
                items: [for (final x in siniflar) DropdownMenuItem(value: x.n('id'), child: Text(x.s('ad')))],
                onChanged: (v) => setState(() {
                  _sinif = v;
                  _ogrenci = null;
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                key: ValueKey(_sinif),
                initialValue: _ogrenci,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Kime'),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Sınıfın tüm velileri')),
                  for (final o in ogrenciler) DropdownMenuItem<int?>(value: o.n('id'), child: Text('${o.s('ad')} velisi', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _ogrenci = v),
              ),
              const SizedBox(height: 12),
              TextField(controller: _baslik, maxLength: 100, decoration: const InputDecoration(labelText: 'Başlık')),
              const SizedBox(height: 4),
              TextField(controller: _metin, maxLength: 2000, minLines: 5, maxLines: 10, decoration: const InputDecoration(labelText: 'Mesaj', alignLabelWithHint: true)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _gonderiliyor ? null : _gonder,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                child: Text(_gonderiliyor ? 'Gönderiliyor…' : 'Gönder'),
              ),
            ]),
    );
  }
}

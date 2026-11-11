import 'package:flutter/material.dart';

import '../bilesenler/ortak.dart';
import '../cekirdek/api.dart';
import '../cekirdek/takvim_model.dart';
import '../cekirdek/tema.dart';

String _tarihSaat(Map<String, dynamic> t) {
  final d = tarihCoz(t.s('tarih'));
  return '${d.day} ${ayAdlari[d.month - 1]} ${gunAdlari[d.weekday - 1]} ${t.s('saat')}${t.s('yer').isEmpty ? '' : ' · ${t.s('yer')}'}';
}

/// Yönetim: zümre başkanları toplantısı kur, katılan okulları seç, karar yaz.
class BaskanToplantiEkrani extends StatefulWidget {
  const BaskanToplantiEkrani({super.key, required this.api});

  final Api api;

  @override
  State<BaskanToplantiEkrani> createState() => _BaskanToplantiEkraniState();
}

class _BaskanToplantiEkraniState extends State<BaskanToplantiEkrani> {
  int _yenile = 0;

  Future<void> _form(Map<String, dynamic> veri, [Map<String, dynamic>? t]) async {
    final tamam = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _ToplantiFormu(api: widget.api, veri: veri, toplanti: t),
      ),
    );
    if (tamam == true && mounted) setState(() => _yenile++);
  }

  Future<void> _karar(Map<String, dynamic> t) async {
    final c = TextEditingController(text: t.s('karar'));
    final tamam = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Alınan kararlar', style: serif.copyWith(fontSize: 19, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            TextField(
              controller: c,
              autofocus: true,
              minLines: 4,
              maxLines: 10,
              maxLength: 2000,
              decoration: const InputDecoration(hintText: 'Toplantıda alınan kararlar…'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
    final metin = c.text;
    c.dispose();
    if (tamam != true) return;
    try {
      await widget.api.post('/api/zumre/baskanlar/karar', {'id': t.n('id'), 'karar': metin});
      if (mounted) setState(() => _yenile++);
    } catch (e) {
      if (mounted) hataGoster(context, e);
    }
  }

  Future<void> _sil(Map<String, dynamic> t) async {
    if (!await onayIste(context, '"${t.s('baslik')}" toplantısı ve varsa kararı silinsin mi?', evet: 'Sil')) return;
    try {
      await widget.api.post('/api/zumre/baskanlar/sil', {'id': t.n('id')});
      if (mounted) setState(() => _yenile++);
    } catch (e) {
      if (mounted) hataGoster(context, e);
    }
  }

  Widget _kart(BuildContext context, Map<String, dynamic> veri, Map<String, dynamic> t) {
    final okullar = t.l('okullar');
    return KartKutu(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.s('baslik'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(_tarihSaat(t), style: TextStyle(color: context.soluk, fontSize: 13)),
          Text(okullar.length > 1 ? '${okullar.length} okul: ${t.s('okul')}' : t.s('okul'), style: TextStyle(color: context.soluk, fontSize: 12.5)),
          if (t.s('gundem').isNotEmpty) ...[const SizedBox(height: 8), Text(t.s('gundem'), style: const TextStyle(height: 1.4))],
          if (t.s('karar').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Alınan kararlar',
              style: TextStyle(color: context.soluk, fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 3),
            Text(t.s('karar'), style: const TextStyle(height: 1.4)),
            if (t['kararZamani'] is num)
              Text(
                '${t.s('kararYazan')} · ${kisaTarih(tarihYaz(DateTime.fromMillisecondsSinceEpoch((t['kararZamani'] as num).toInt())))}',
                style: TextStyle(color: context.soluk, fontSize: 12),
              ),
          ] else if (t['basladi'] == true)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Karar henüz yazılmadı.', style: TextStyle(color: context.soluk, fontSize: 13)),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (t['basladi'] == true) TextButton(onPressed: () => _karar(t), child: Text(t.s('karar').isEmpty ? 'Toplantıyı bitir' : 'Kararı düzenle')),
              if (t['duzenleyebilir'] == true) TextButton(onPressed: () => _form(veri, t), child: const Text('Düzenle')),
              if (t['duzenleyebilir'] == true)
                TextButton(
                  onPressed: () => _sil(t),
                  child: Text('Sil', style: TextStyle(color: Colors.red.shade600)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => VeriSayfasi(
    key: ValueKey(_yenile),
    baslik: 'Başkanlar toplantısı',
    getir: () => widget.api.get('/api/zumre/baskanlar/liste'),
    cizim: (context, v) {
      final veri = v as Map<String, dynamic>;
      final liste = veri.l('toplantilar');
      final gelecek = [
        for (final t in liste.reversed)
          if (t['basladi'] != true) t,
      ];
      final gecmis = [
        for (final t in liste)
          if (t['basladi'] == true) t,
      ];
      return [
        EkleDugmesi('+ Toplantı ekle', onPressed: () => _form(veri)),
        if (liste.isEmpty) const BosNot('Henüz toplantı yok. Toplantıyı ekleyin; o okulun zümre başkanlarının paneline hatırlatma düşer.'),
        if (gelecek.isNotEmpty) ...[const Baslik('Yaklaşan toplantılar'), for (final t in gelecek) _kart(context, veri, t)],
        if (gecmis.isNotEmpty) ...[const Baslik('Yapılan toplantılar'), for (final t in gecmis) _kart(context, veri, t)],
      ];
    },
  );
}

class _ToplantiFormu extends StatefulWidget {
  const _ToplantiFormu({required this.api, required this.veri, this.toplanti});

  final Api api;
  final Map<String, dynamic> veri;
  final Map<String, dynamic>? toplanti;

  @override
  State<_ToplantiFormu> createState() => _ToplantiFormuState();
}

class _ToplantiFormuState extends State<_ToplantiFormu> {
  late final _baslik = TextEditingController(text: widget.toplanti?.s('baslik') ?? 'Zümre başkanları toplantısı');
  late final _yer = TextEditingController(text: widget.toplanti?.s('yer') ?? '');
  late final _gundem = TextEditingController(text: widget.toplanti?.s('gundem') ?? '');
  late String _tarih = widget.toplanti?.s('tarih') ?? tarihYaz(DateTime.now());
  late String _saat = widget.toplanti?.s('saat') ?? '15:00';
  late final Set<int> _okullar = {for (final x in ((widget.toplanti?['okulIds'] ?? widget.veri['varsayilan']) as List? ?? const [])) (x as num).toInt()};
  bool _mesgul = false;

  @override
  void dispose() {
    _baslik.dispose();
    _yer.dispose();
    _gundem.dispose();
    super.dispose();
  }

  Future<void> _tarihSec() async {
    final s = await showDatePicker(context: context, initialDate: tarihCoz(_tarih), firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (s != null) setState(() => _tarih = tarihYaz(s));
  }

  Future<void> _saatSec() async {
    final p = _saat.split(':');
    final s = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.tryParse(p[0]) ?? 15, minute: int.tryParse(p[1]) ?? 0),
    );
    if (s != null) setState(() => _saat = '${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')}');
  }

  Future<void> _kaydet() async {
    if (_okullar.isEmpty) {
      hataGoster(context, ApiHata(400, 'En az bir okul seçin'));
      return;
    }
    setState(() => _mesgul = true);
    try {
      await widget.api.post('/api/zumre/baskanlar/kaydet', {
        'id': widget.toplanti?.n('id'),
        'okulIds': _okullar.toList(),
        'baslik': _baslik.text,
        'tarih': _tarih,
        'saat': _saat,
        'yer': _yer.text,
        'gundem': _gundem.text,
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
    final okullar = widget.veri.l('okullar');
    final gruplar = <String, List<Map<String, dynamic>>>{};
    for (final o in okullar) {
      gruplar.putIfAbsent(o.s('tur').isEmpty ? 'Diğer' : o.s('tur'), () => []).add(o);
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.toplanti == null ? 'Yeni toplantı' : 'Toplantıyı düzenle')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          TextField(
            controller: _baslik,
            maxLength: 80,
            decoration: const InputDecoration(labelText: 'Başlık'),
          ),
          const Baslik('Katılan okullar', ust: 4),
          if (okullar.isEmpty) Text('Seçilebilir okul yok.', style: TextStyle(color: context.soluk)),
          for (final e in gruplar.entries) ...[
            Row(
              children: [
                Expanded(
                  child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                if (e.value.length > 1)
                  TextButton(
                    onPressed: () => setState(() {
                      final ids = [for (final o in e.value) o.n('id')];
                      if (ids.every(_okullar.contains)) {
                        _okullar.removeAll(ids);
                      } else {
                        _okullar.addAll(ids);
                      }
                    }),
                    child: const Text('Tümü'),
                  ),
              ],
            ),
            for (final o in e.value)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _okullar.contains(o.n('id')),
                onChanged: (v) => setState(() => v == true ? _okullar.add(o.n('id')) : _okullar.remove(o.n('id'))),
                title: Text(o.s('ad')),
                subtitle: o.s('kampus').isEmpty ? null : Text(o.s('kampus')),
              ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _tarihSec,
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  child: Text(kisaTarih(_tarih)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: _saatSec,
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  child: Text(_saat),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _yer,
            maxLength: 60,
            decoration: const InputDecoration(labelText: 'Yer', hintText: 'Örn. Toplantı salonu'),
          ),
          TextField(
            controller: _gundem,
            minLines: 3,
            maxLines: 8,
            maxLength: 500,
            decoration: const InputDecoration(labelText: 'Gündem', alignLabelWithHint: true),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _mesgul ? null : _kaydet,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: Text(_mesgul ? 'Kaydediliyor…' : (widget.toplanti == null ? 'Toplantıyı ekle' : 'Kaydet')),
          ),
        ],
      ),
    );
  }
}

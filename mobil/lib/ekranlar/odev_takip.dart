import 'package:flutter/material.dart';

import '../bilesenler/ortak.dart';
import '../cekirdek/api.dart';
import '../cekirdek/takvim_model.dart';
import '../cekirdek/tema.dart';

const _durumRenk = {
  'verildi': Color(0xFF8A867D),
  'yapildi': Color(0xFF1F6FEB),
  'yapilamadi': Color(0xFFD64545),
  'dogrulandi': Color(0xFF2E9E5B),
  'duzeltme': Color(0xFFE0A100),
};

String _durumAd(Map<String, dynamic> durumlar, String kod) => durumlar.m(kod).s('ad').isEmpty ? kod : durumlar.m(kod).s('ad');

/// Öğretmen: verdiği ödevler, bekleyen onay/sorular ve öğrenci bazında doğrulama.
class OdevTakipOgretmenEkrani extends StatefulWidget {
  const OdevTakipOgretmenEkrani({super.key, required this.api});

  final Api api;

  @override
  State<OdevTakipOgretmenEkrani> createState() => _OdevTakipOgretmenEkraniState();
}

class _OdevTakipOgretmenEkraniState extends State<OdevTakipOgretmenEkrani> {
  String _suzgec = 'bekleyen';
  int _surum = 0;

  @override
  Widget build(BuildContext context) => VeriSayfasi(
        key: ValueKey(_surum),
        baslik: 'Ödev takibi',
        getir: () => widget.api.get('/api/odev/ogretmen'),
        cizim: (context, veri) {
          final j = veri as Map<String, dynamic>;
          final tum = j.l('odevler');
          final bekleyenSayi = tum.where((o) => o.n('bekleyen') > 0).length;
          final liste = _suzgec == 'bekleyen' ? [for (final o in tum) if (o.n('bekleyen') > 0) o] : tum;
          return [
            SuzgecCipleri(
              secenekler: [('bekleyen', 'Bekleyenler ($bekleyenSayi)'), ('tum', 'Tümü (${tum.length})')],
              secili: _suzgec,
              degisti: (v) => setState(() => _suzgec = v),
            ),
            const SizedBox(height: 12),
            if (liste.isEmpty) BosNot(_suzgec == 'bekleyen' ? 'Onay ya da cevap bekleyen ödev yok.' : 'Henüz ödev vermediniz.'),
            for (final o in liste)
              _OdevKarti(o, bugun: j.s('bugun'), onTap: () async {
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => _OdevTakipDetay(api: widget.api, odevId: o.n('id'))));
                if (mounted) setState(() => _surum++);
              }),
          ];
        },
      );
}

class _OdevKarti extends StatelessWidget {
  const _OdevKarti(this.o, {required this.bugun, required this.onTap});

  final Map<String, dynamic> o;
  final String bugun;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gecti = o.s('sonTarih').compareTo(bugun) < 0;
    return KartKutu(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(o.s('baslik'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5))),
          if (o.n('bekleyen') > 0) Cip('${o.n('bekleyen')} bekliyor', renk: const Color(0xFFE0A100)),
        ]),
        const SizedBox(height: 3),
        Text('${o.s('sinif')} · ${o.s('ders')} · son ${kisaTarih(o.s('sonTarih'))}${gecti ? ' (geçti)' : ''}', style: TextStyle(color: context.soluk, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          Cip('${o.n('dogrulandi')}/${o.n('toplam')} doğrulandı', renk: _durumRenk['dogrulandi']),
          if (o.n('yapildi') > 0) Cip('${o.n('yapildi')} yaptım dedi', renk: _durumRenk['yapildi']),
          if (o.n('yapilamadi') > 0) Cip('${o.n('yapilamadi')} yapamadı', renk: _durumRenk['yapilamadi']),
          if (o.n('duzeltme') > 0) Cip('${o.n('duzeltme')} düzeltmede', renk: _durumRenk['duzeltme']),
          if (o.n('soru') > 0) Cip('${o.n('soru')} soru', renk: context.ana),
        ]),
      ]),
    );
  }
}

class _OdevTakipDetay extends StatefulWidget {
  const _OdevTakipDetay({required this.api, required this.odevId});

  final Api api;
  final int odevId;

  @override
  State<_OdevTakipDetay> createState() => _OdevTakipDetayState();
}

class _OdevTakipDetayState extends State<_OdevTakipDetay> {
  int _surum = 0;

  Future<void> _topluDogrula(int adet) async {
    if (!await onayIste(context, '"Yaptım" diyen $adet öğrencinin ödevi doğrulansın mı?', evet: 'Doğrula')) return;
    try {
      await widget.api.post('/api/odev/toplu-dogrula', {'odevId': widget.odevId});
      if (mounted) setState(() => _surum++);
    } catch (e) {
      if (mounted) hataGoster(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => VeriSayfasi(
        key: ValueKey(_surum),
        baslik: 'Ödev',
        getir: () => widget.api.get('/api/odev/takip?odevId=${widget.odevId}'),
        cizim: (context, veri) {
          final j = veri as Map<String, dynamic>;
          final odev = j.m('odev');
          final durumlar = j.m('durumlar');
          final yapildi = j.m('sayilar').n('yapildi');
          return [
            KartKutu(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(odev.s('baslik'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                const SizedBox(height: 3),
                Text('${odev.s('sinif')} · ${odev.s('ders')} · son ${uzunTarih(odev.s('sonTarih'))}', style: TextStyle(color: context.soluk, fontSize: 13.5)),
                if (odev.s('aciklama').isNotEmpty) ...[const SizedBox(height: 8), Text(odev.s('aciklama'), style: const TextStyle(height: 1.35))],
                if (odev.s('kazanim').isNotEmpty) ...[const SizedBox(height: 8), Text(odev.s('kazanim'), style: TextStyle(color: context.soluk, fontSize: 13, height: 1.3))],
              ]),
            ),
            if (yapildi > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FilledButton.icon(
                  onPressed: () => _topluDogrula(yapildi),
                  icon: const Icon(Icons.done_all),
                  label: Text('"Yaptım" diyen $yapildi öğrenciyi doğrula'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                ),
              ),
            const Baslik('Öğrenciler', ust: 6),
            for (final o in j.l('ogrenciler'))
              KartKutu(
                alt: 8,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => _OgrenciOdev(api: widget.api, odevId: widget.odevId, ogrenciId: o.n('id'))));
                  if (mounted) setState(() => _surum++);
                },
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(o.s('ad'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      if (o.s('ogrenciNotu').isNotEmpty)
                        Text('“${o.s('ogrenciNotu')}”', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.soluk, fontSize: 13)),
                    ]),
                  ),
                  if (o.n('dosya') > 0) Padding(padding: const EdgeInsets.only(right: 8), child: Icon(Icons.photo_outlined, size: 19, color: context.soluk)),
                  if (o['soru'] == true) Padding(padding: const EdgeInsets.only(right: 8), child: Icon(Icons.chat_bubble_outline, size: 19, color: context.ana)),
                  Cip(_durumAd(durumlar, o.s('durum')), renk: _durumRenk[o.s('durum')]),
                ]),
              ),
          ];
        },
      );
}

/// Tek öğrencinin ödevi: durum, fotoğraflar, doğrulama işlemleri ve soru/cevap yazışması.
class _OgrenciOdev extends StatefulWidget {
  const _OgrenciOdev({required this.api, required this.odevId, required this.ogrenciId});

  final Api api;
  final int odevId;
  final int ogrenciId;

  @override
  State<_OgrenciOdev> createState() => _OgrenciOdevState();
}

class _OgrenciOdevState extends State<_OgrenciOdev> {
  int _surum = 0;
  final _mesaj = TextEditingController();
  bool _isliyor = false;

  @override
  void dispose() {
    _mesaj.dispose();
    super.dispose();
  }

  Future<void> _dogrula(String islem, {String not = ''}) async {
    setState(() => _isliyor = true);
    try {
      await widget.api.post('/api/odev/dogrula', {'odevId': widget.odevId, 'ogrenciId': widget.ogrenciId, 'islem': islem, 'not': not});
      if (mounted) setState(() => _surum++);
    } catch (e) {
      if (mounted) hataGoster(context, e);
    } finally {
      if (mounted) setState(() => _isliyor = false);
    }
  }

  Future<void> _duzeltmeIste() async {
    final c = TextEditingController();
    final not = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Düzeltme iste'),
        content: TextField(controller: c, autofocus: true, maxLength: 300, maxLines: 3, decoration: const InputDecoration(hintText: 'Neyin düzeltileceğini yazın')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(d, c.text.trim()), child: const Text('Gönder')),
        ],
      ),
    );
    c.dispose();
    if (not != null && mounted) await _dogrula('duzeltme', not: not);
  }

  Future<void> _yanitla() async {
    final metin = _mesaj.text.trim();
    if (metin.length < 2) return;
    setState(() => _isliyor = true);
    try {
      await widget.api.post('/api/odev/mesaj-gonder', {'odevId': widget.odevId, 'ogrenciId': widget.ogrenciId, 'metin': metin});
      _mesaj.clear();
      if (mounted) setState(() => _surum++);
    } catch (e) {
      if (mounted) hataGoster(context, e);
    } finally {
      if (mounted) setState(() => _isliyor = false);
    }
  }

  void _buyut(String url) => showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          insetPadding: const EdgeInsets.all(12),
          clipBehavior: Clip.antiAlias,
          child: InteractiveViewer(child: Image.network(url, headers: widget.api.kimlik, fit: BoxFit.contain)),
        ),
      );

  Widget _resimler(List<dynamic> idler) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final id in idler)
          GestureDetector(
            onTap: () => _buyut('${Api.taban}/api/odev/dosya?id=$id'),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                '${Api.taban}/api/odev/dosya?id=$id',
                headers: widget.api.kimlik,
                width: 88,
                height: 88,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(width: 88, height: 88, color: context.icZemin, child: Icon(Icons.broken_image_outlined, color: context.soluk)),
              ),
            ),
          ),
      ]);

  @override
  Widget build(BuildContext context) => VeriSayfasi(
        key: ValueKey(_surum),
        baslik: 'Öğrenci ödevi',
        getir: () => widget.api.get('/api/odev/detay?odevId=${widget.odevId}&ogrenciId=${widget.ogrenciId}'),
        cizim: (context, veri) {
          final j = veri as Map<String, dynamic>;
          final odev = j.m('odev');
          final durum = j.m('durum');
          final kod = durum.s('kod');
          final durumlar = j.m('durumlar');
          final dosyalar = j.l('dosyalar');
          final aciklama = durumlar.m(kod).s('aciklama');
          return [
            Text(j.m('ogrenci').s('ad'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('${odev.s('baslik')} · ${odev.s('ders')}', style: TextStyle(color: context.soluk)),
            const SizedBox(height: 12),
            KartKutu(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Cip(_durumAd(durumlar, kod), renk: _durumRenk[kod]),
                  const SizedBox(width: 10),
                  if (aciklama.isNotEmpty) Flexible(child: Text(aciklama, style: TextStyle(color: context.soluk, fontSize: 12.5))),
                ]),
                if (durum.s('ogrenciNotu').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('Öğrencinin notu', style: TextStyle(color: context.soluk, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  Text(durum.s('ogrenciNotu'), style: const TextStyle(height: 1.35)),
                ],
                if (durum.s('ogretmenNotu').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('Sizin notunuz', style: TextStyle(color: context.soluk, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  Text(durum.s('ogretmenNotu'), style: const TextStyle(height: 1.35)),
                ],
                if (dosyalar.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _resimler([for (final d in dosyalar) d['id']]),
                ],
              ]),
            ),
            if (kod != 'verildi')
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  if (kod != 'dogrulandi') Expanded(child: FilledButton(onPressed: _isliyor ? null : () => _dogrula('dogrula'), child: const Text('Doğrula'))),
                  if (kod != 'dogrulandi' && kod != 'duzeltme') const SizedBox(width: 8),
                  if (kod != 'dogrulandi' && kod != 'duzeltme') Expanded(child: OutlinedButton(onPressed: _isliyor ? null : _duzeltmeIste, child: const Text('Düzeltme iste'))),
                  if (kod == 'dogrulandi' || kod == 'duzeltme') Expanded(child: OutlinedButton(onPressed: _isliyor ? null : () => _dogrula('geri'), child: const Text('Onayı geri al'))),
                ]),
              ),
            const Baslik('Sorular ve cevaplar'),
            if (j.l('mesajlar').isEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Henüz mesaj yok.', style: TextStyle(color: context.soluk))),
            for (final m in j.l('mesajlar'))
              Align(
                alignment: m.s('yazanRol') == 'ogretmen' ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .78),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: m.s('yazanRol') == 'ogretmen' ? context.ana.withValues(alpha: .12) : context.icZemin,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.s('yazan'), style: TextStyle(color: context.soluk, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(m.s('metin'), style: const TextStyle(height: 1.35)),
                    if ((m['dosyalar'] as List? ?? const []).isNotEmpty) ...[const SizedBox(height: 8), _resimler(m['dosyalar'] as List)],
                  ]),
                ),
              ),
            const SizedBox(height: 4),
            TextField(
              controller: _mesaj,
              maxLength: 800,
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'Cevap yazın',
                suffixIcon: IconButton(onPressed: _isliyor ? null : _yanitla, icon: const Icon(Icons.send_rounded), tooltip: 'Gönder'),
              ),
            ),
          ];
        },
      );
}

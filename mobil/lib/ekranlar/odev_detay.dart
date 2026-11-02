import 'package:flutter/material.dart';

import '../bilesenler/ortak.dart';
import '../cekirdek/api.dart';
import '../cekirdek/foto.dart';
import '../cekirdek/takvim_model.dart';
import '../cekirdek/tema.dart';

const _durumRenk = {
  'verildi': Color(0xFF1F6FEB),
  'duzeltme': Color(0xFFD97706),
  'yapilamadi': Color(0xFFD64545),
  'yapildi': Color(0xFF7C3AED),
  'dogrulandi': Color(0xFF2E9E5B),
};

/// Öğrenci: ödevi işaretler, çalışmasının fotoğrafını ekler, öğretmene soru sorar. Veli: yalnızca görür.
class OdevDetayEkrani extends StatefulWidget {
  const OdevDetayEkrani({super.key, required this.api, required this.odevId, this.ogrenciId});

  final Api api;
  final int odevId;
  final int? ogrenciId;

  @override
  State<OdevDetayEkrani> createState() => _OdevDetayEkraniState();
}

class _OdevDetayEkraniState extends State<OdevDetayEkrani> {
  int _surum = 0;
  bool _isliyor = false;
  bool _notHazir = false;
  final _not = TextEditingController();
  final _soru = TextEditingController();
  final _ekler = <int>[];

  @override
  void dispose() {
    _not.dispose();
    _soru.dispose();
    super.dispose();
  }

  String get _sorgu => 'odevId=${widget.odevId}${widget.ogrenciId == null ? '' : '&ogrenciId=${widget.ogrenciId}'}';

  Future<void> _yap(Future<void> Function() islem, {String? bilgi}) async {
    setState(() => _isliyor = true);
    try {
      await islem();
      if (!mounted) return;
      setState(() => _surum++);
      if (bilgi != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(bilgi)));
    } catch (e) {
      if (mounted) hataGoster(context, e);
    } finally {
      if (mounted) setState(() => _isliyor = false);
    }
  }

  Future<void> _isaretle(String durum, {String? bilgi}) => _yap(() async {
    await widget.api.post('/api/odev/isaretle', {'odevId': widget.odevId, 'durum': durum, 'not': _not.text.trim()});
  }, bilgi: bilgi);

  Future<int?> _fotoYukle(String amac) async {
    final bayt = await galeridenFotoSec();
    if (bayt == null) return null;
    final r = await widget.api.postBayt('/api/odev/dosya-yukle?odevId=${widget.odevId}&amac=$amac', bayt);
    return (r as Map<String, dynamic>)['id'] as int?;
  }

  Future<void> _teslimEkle() => _yap(() async {
    await _fotoYukle('teslim');
  });

  Future<void> _dosyaSil(int id) => _yap(() async {
    await widget.api.post('/api/odev/dosya-sil', {'id': id});
    _ekler.remove(id);
  });

  Future<void> _soruFotoEkle() async {
    setState(() => _isliyor = true);
    try {
      final id = await _fotoYukle('soru');
      if (id != null && mounted) setState(() => _ekler.add(id));
    } catch (e) {
      if (mounted) hataGoster(context, e);
    } finally {
      if (mounted) setState(() => _isliyor = false);
    }
  }

  Future<void> _soruGonder() async {
    final metin = _soru.text.trim();
    if (metin.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sorunuzu en az 2 karakterle yazın.')));
      return;
    }
    await _yap(() async {
      await widget.api.post('/api/odev/mesaj-gonder', {'odevId': widget.odevId, 'ogrenciId': widget.ogrenciId, 'metin': metin, 'dosyaIds': _ekler});
      _soru.clear();
      _ekler.clear();
    }, bilgi: 'Sorunuz öğretmeninize gönderildi');
  }

  void _buyut(String url) => showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(12),
      clipBehavior: Clip.antiAlias,
      child: InteractiveViewer(
        child: Image.network(url, headers: widget.api.kimlik, fit: BoxFit.contain),
      ),
    ),
  );

  Widget _resimler(List<dynamic> idler, {bool silinir = false}) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final id in idler)
        Stack(
          clipBehavior: Clip.none,
          children: [
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
                  errorBuilder: (_, _, _) => Container(
                    width: 88,
                    height: 88,
                    color: context.icZemin,
                    child: Icon(Icons.broken_image_outlined, color: context.soluk),
                  ),
                ),
              ),
            ),
            if (silinir)
              Positioned(
                top: -6,
                right: -6,
                child: InkWell(
                  onTap: _isliyor ? null : () => _dosyaSil(id as int),
                  child: Tooltip(
                    message: 'Fotoğrafı sil',
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: const Color(0xFFD64545),
                      child: const Icon(Icons.close, size: 15, color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
    ],
  );

  @override
  Widget build(BuildContext context) => VeriSayfasi(
    key: ValueKey(_surum),
    baslik: 'Ödev',
    getir: () => widget.api.get('/api/odev/detay?$_sorgu'),
    cizim: (context, veri) {
      final j = veri as Map<String, dynamic>;
      final odev = j.m('odev');
      final durum = j.m('durum');
      final kod = durum.s('kod');
      final durumlar = j.m('durumlar');
      final rol = j.s('rol');
      final ogrenciMi = rol == 'ogrenci';
      final bugun = j.s('bugun');
      final bitti = kod == 'dogrulandi';
      final gecti = odev.s('sonTarih').compareTo(bugun) < 0;
      final dosyalar = j.l('dosyalar');
      final salt = !ogrenciMi || bitti;
      if (!_notHazir) {
        _not.text = durum.s('ogrenciNotu');
        _notHazir = true;
      }
      final aciklama = durumlar.m(kod).s('aciklama');
      return [
        Text(odev.s('baslik'), style: serif.copyWith(fontSize: 24)),
        const SizedBox(height: 2),
        Text([odev.s('ders'), odev.s('ogretmen')].where((e) => e.isNotEmpty).join(' · '), style: TextStyle(color: context.soluk)),
        if (rol == 'veli') Text('${j.m('ogrenci').s('ad')} · ${odev.s('sinif')}', style: TextStyle(color: context.soluk)),
        const SizedBox(height: 10),
        Text(
          'Son tarih: ${uzunTarih(odev.s('sonTarih'))}${gecti
              ? ' (geçti)'
              : odev.s('sonTarih') == bugun
              ? ' (bugün)'
              : ''}',
          style: TextStyle(color: gecti && !bitti ? const Color(0xFFD64545) : context.soluk, fontWeight: FontWeight.w600),
        ),
        if (odev.s('aciklama').isNotEmpty) ...[const SizedBox(height: 10), Text(odev.s('aciklama'), style: const TextStyle(height: 1.45))],
        if (odev.s('kazanim').isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Kazanım: ${odev.s('kazanim')}', style: TextStyle(color: context.soluk, height: 1.4)),
        ],
        const Baslik('Durum'),
        KartKutu(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Cip(durumlar.m(kod).s('ad').isEmpty ? kod : durumlar.m(kod).s('ad'), renk: _durumRenk[kod]),
                  if (aciklama.isNotEmpty) Text(aciklama, style: TextStyle(color: context.soluk, fontSize: 12.5)),
                ],
              ),
              if (durum.s('ogretmenNotu').isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Öğretmen notu',
                  style: TextStyle(color: context.soluk, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                Text(durum.s('ogretmenNotu'), style: const TextStyle(height: 1.35)),
              ],
              if (!ogrenciMi && durum.s('ogrenciNotu').isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Öğrenci notu',
                  style: TextStyle(color: context.soluk, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                Text(durum.s('ogrenciNotu'), style: const TextStyle(height: 1.35)),
              ],
              if (ogrenciMi && bitti) ...[
                const SizedBox(height: 10),
                Text('Öğretmeniniz bu ödevi doğruladı; artık değiştirilemez.', style: TextStyle(color: context.soluk, fontSize: 12.5)),
                if (durum.s('ogrenciNotu').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Notunuz: ${durum.s('ogrenciNotu')}', style: const TextStyle(height: 1.35)),
                ],
              ],
              if (ogrenciMi && !bitti) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _not,
                  maxLength: 300,
                  decoration: const InputDecoration(labelText: 'Not (isteğe bağlı)', hintText: 'İsterseniz kısa bir not yazın'),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed: _isliyor ? null : () => _isaretle('yapildi', bilgi: 'Öğretmenin onayına gönderildi'),
                      child: Text(kod == 'yapildi' ? 'Yaptım ✓' : 'Yaptım'),
                    ),
                    OutlinedButton(
                      onPressed: _isliyor ? null : () => _isaretle('yapilamadi', bilgi: 'Kaydedildi'),
                      child: const Text('Yapamadım'),
                    ),
                    if (kod == 'yapildi' || kod == 'yapilamadi')
                      OutlinedButton(
                        onPressed: _isliyor ? null : () => _isaretle('verildi', bilgi: 'İşaret kaldırıldı'),
                        child: const Text('Geri al'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (dosyalar.isNotEmpty || !salt) ...[
          Baslik(dosyalar.isEmpty ? 'Fotoğraflar' : 'Fotoğraflar (${dosyalar.length})'),
          KartKutu(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (dosyalar.isEmpty)
                  Text('Yaptığınız çalışmanın fotoğrafını ekleyebilirsiniz.', style: TextStyle(color: context.soluk))
                else
                  _resimler([for (final d in dosyalar) d['id']], silinir: !salt),
                if (!salt) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _isliyor ? null : _teslimEkle,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Fotoğraf ekle'),
                  ),
                ],
              ],
            ),
          ),
        ],
        Baslik(ogrenciMi ? 'Sorular' : 'Öğretmene sorulan sorular'),
        if (j.l('mesajlar').isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(ogrenciMi ? 'Takıldığınız yeri öğretmeninize sorabilirsiniz.' : 'Henüz soru yok.', style: TextStyle(color: context.soluk)),
          ),
        for (final m in j.l('mesajlar')) _balon(context, m, benim: ogrenciMi && m.s('yazanRol') == 'ogrenci'),
        if (ogrenciMi) ...[
          const SizedBox(height: 6),
          TextField(
            controller: _soru,
            maxLength: 800,
            maxLines: 3,
            minLines: 2,
            decoration: const InputDecoration(hintText: 'Sorunuzu yazın'),
          ),
          if (_ekler.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: _resimler(_ekler, silinir: true)),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_ekler.length < 3)
                OutlinedButton.icon(onPressed: _isliyor ? null : _soruFotoEkle, icon: const Icon(Icons.photo_outlined), label: const Text('Fotoğraf')),
              FilledButton(onPressed: _isliyor ? null : _soruGonder, child: const Text('Soruyu gönder')),
            ],
          ),
        ],
      ];
    },
  );

  Widget _balon(BuildContext context, Map<String, dynamic> m, {required bool benim}) => Align(
    alignment: benim ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .78),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: benim ? context.ana.withValues(alpha: .12) : context.icZemin,
        borderRadius: BorderRadius.circular(14),
        border: m['yeni'] == true ? Border.all(color: const Color(0xFFA4161A)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            m.s('yazan'),
            style: TextStyle(color: context.soluk, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(m.s('metin'), style: const TextStyle(height: 1.35)),
          if ((m['dosyalar'] as List? ?? const []).isNotEmpty) ...[const SizedBox(height: 8), _resimler(m['dosyalar'] as List)],
        ],
      ),
    ),
  );
}

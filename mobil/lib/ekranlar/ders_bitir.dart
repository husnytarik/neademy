import 'package:flutter/material.dart';

import '../bilesenler/kazanim_secici.dart';
import '../bilesenler/ortak.dart';
import '../cekirdek/api.dart';
import '../cekirdek/takvim_model.dart';
import '../cekirdek/tema.dart';

/// Tek başına açılan "Dersi bitir" sayfası (ders detayındaki sekmenin aynısını bir sayfa olarak sarar).
class DersBitirEkrani extends StatelessWidget {
  const DersBitirEkrani({super.key, required this.api, required this.ders, required this.tarih});

  final Api api;
  final Map<String, dynamic> ders;
  final String tarih;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('${ders.s('sinif')} · ${ders.s('ders')}')),
    body: DersBitirGovde(api: api, ders: ders, tarih: tarih, bitti: () => Navigator.pop(context, true)),
  );
}

/// Bir dersin yoklaması, işlenen konu (kazanım) ve ödevi; kayıtlıysa düzenleme, ayrıca dersi iptal etme.
class DersBitirGovde extends StatefulWidget {
  const DersBitirGovde({super.key, required this.api, required this.ders, required this.tarih, required this.bitti});

  final Api api;
  final Map<String, dynamic> ders;
  final String tarih;

  /// Ders bitirilince ya da iptal edilince çağrılır.
  final VoidCallback bitti;

  @override
  State<DersBitirGovde> createState() => _DersBitirGovdeState();
}

class _DersBitirGovdeState extends State<DersBitirGovde> {
  static const _durumlar = [
    ('geldi', 'Geldi', Color(0xFF2E9E5B)),
    ('gelmedi', 'Gelmedi', Color(0xFFD64545)),
    ('gec', 'Geç', Color(0xFFE0A100)),
    ('izinli', 'İzinli', Color(0xFF8A867D)),
  ];

  Map<String, dynamic>? _veri;
  String? _hata;
  bool _kaydediyor = false;
  final _durum = <int, String>{};
  final _konu = TextEditingController();
  final _aciklama = TextEditingController();
  final _odevBaslik = TextEditingController();
  final _odevAciklama = TextEditingController();
  late final KazanimSecimi _kazanim;
  late final KazanimSecimi _odevKazanim;
  String _sonTarih = '';

  int get _sinifId => widget.ders.n('sinifId');
  int get _saat => widget.ders.n('dersSaati');

  @override
  void initState() {
    super.initState();
    _kazanim = KazanimSecimi();
    _odevKazanim = KazanimSecimi(tek: true);
    _yukle();
  }

  @override
  void dispose() {
    for (final c in [_konu, _aciklama, _odevBaslik, _odevAciklama]) {
      c.dispose();
    }
    _kazanim.dispose();
    _odevKazanim.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    setState(() => _hata = null);
    try {
      final j = await widget.api.get('/api/yoklama/ogrenciler?tarih=${widget.tarih}&sinifId=$_sinifId&dersSaati=$_saat') as Map<String, dynamic>;
      if (!mounted) return;
      final odev = j.m('odev');
      setState(() {
        _veri = j;
        for (final o in j.l('ogrenciler')) {
          _durum[o.n('ogrenciId')] = o.s('durum').isEmpty ? 'geldi' : o.s('durum');
        }
        _konu.text = j.s('konu');
        _aciklama.text = j.s('aciklama');
        _odevBaslik.text = odev.s('baslik');
        _odevAciklama.text = odev.s('aciklama');
        _sonTarih = odev.s('sonTarih').isNotEmpty ? odev.s('sonTarih') : gunKaydir(widget.tarih, 7);
        _kazanim.kodlar
          ..clear()
          ..addAll([for (final k in (j['kazanimKodlari'] as List? ?? const [])) k.toString()]);
        _odevKazanim.kodlar
          ..clear()
          ..addAll(odev.s('kazanimKod').isEmpty ? const [] : [odev.s('kazanimKod')]);
      });
      final dersAd = widget.ders.s('ders');
      _kazanim.yukle(widget.api, sinifId: _sinifId, ders: dersAd);
      _odevKazanim.yukle(widget.api, sinifId: _sinifId, ders: dersAd);
    } on ApiHata catch (e) {
      if (mounted && !e.oturumYok) setState(() => _hata = e.mesaj);
    }
  }

  Future<void> _kaydet() async {
    setState(() => _kaydediyor = true);
    try {
      final s =
          await widget.api.post('/api/yoklama/kaydet', {
                'tarih': widget.tarih,
                'sinifId': _sinifId,
                'dersSaati': _saat,
                'kayitlar': [
                  for (final e in _durum.entries) {'ogrenciId': e.key, 'durum': e.value},
                ],
                'konu': _konu.text,
                'kazanimlar': _kazanim.kodlar,
                'aciklama': _aciklama.text,
                'odev': {
                  'baslik': _odevBaslik.text,
                  'aciklama': _odevAciklama.text,
                  'kazanimKod': _odevKazanim.kodlar.firstOrNull ?? '',
                  'sonTarih': _sonTarih,
                },
              })
              as Map<String, dynamic>;
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ders tamamlandı: ${s.n('gelmedi')} gelmedi, ${s.n('gec')} geç, ${s.n('izinli')} izinli.')));
      widget.bitti();
    } catch (e) {
      if (mounted) hataGoster(context, e);
    } finally {
      if (mounted) setState(() => _kaydediyor = false);
    }
  }

  Future<void> _iptalEt() async {
    if (!await onayIste(context, 'Bu ders iptal edilsin mi? Girilen yoklama, konu ve ödev silinir.', evet: 'Dersi iptal et')) return;
    try {
      await widget.api.post('/api/yoklama/iptal', {'tarih': widget.tarih, 'sinifId': _sinifId, 'dersSaati': _saat});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ders iptal edildi.')));
      widget.bitti();
    } catch (e) {
      if (mounted) hataGoster(context, e);
    }
  }

  Future<void> _sonTarihSec() async {
    final t = tarihCoz(_sonTarih);
    final d = await showDatePicker(context: context, initialDate: DateTime(t.year, t.month, t.day), firstDate: DateTime(2024), lastDate: DateTime(2030));
    if (d != null) setState(() => _sonTarih = tarihYaz(DateTime.utc(d.year, d.month, d.day)));
  }

  @override
  Widget build(BuildContext context) {
    final j = _veri;
    if (j == null) {
      return _hata == null
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _hata!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.soluk),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton(onPressed: _yukle, child: const Text('Tekrar dene')),
                  ],
                ),
              ),
            );
    }
    final ogrenciler = j.l('ogrenciler');
    final say = {for (final d in _durumlar) d.$1: 0};
    for (final o in ogrenciler) {
      say[_durum[o.n('ogrenciId')] ?? 'geldi'] = (say[_durum[o.n('ogrenciId')] ?? 'geldi'] ?? 0) + 1;
    }
    final tamam = j['tamam'] == true && j['iptal'] != true;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        if (j['iptal'] == true)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Cip('Bu ders iptal edilmiş', renk: Color(0xFF8A867D)),
          ),
        const Baslik('Yoklama', ust: 12),
        KartKutu(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(spacing: 8, runSpacing: 6, children: [for (final d in _durumlar) Cip('${d.$2} ${say[d.$1]}', renk: d.$3)]),
              if (ogrenciler.isNotEmpty && say['geldi'] != ogrenciler.length)
                TextButton.icon(
                  onPressed: () => setState(() {
                    for (final o in ogrenciler) {
                      _durum[o.n('ogrenciId')] = 'geldi';
                    }
                  }),
                  icon: const Icon(Icons.done_all, size: 18),
                  label: const Text('Hepsini geldi yap'),
                ),
              if (ogrenciler.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Bu sınıfta aktif öğrenci yok.', style: TextStyle(color: context.soluk)),
                ),
              for (final o in ogrenciler)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      Expanded(child: Text(o.s('ad'), style: const TextStyle(fontSize: 15.5))),
                      PopupMenuButton<String>(
                        tooltip: 'Durum',
                        onSelected: (v) => setState(() => _durum[o.n('ogrenciId')] = v),
                        itemBuilder: (_) => [for (final d in _durumlar) PopupMenuItem(value: d.$1, child: Text(d.$2))],
                        child: _DurumHapi(_durumlar.firstWhere((d) => d.$1 == (_durum[o.n('ogrenciId')] ?? 'geldi'))),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const Baslik('İşlenen konu'),
        KartKutu(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KazanimAlani(secim: _kazanim),
              ListenableBuilder(
                listenable: _kazanim,
                builder: (_, _) => _kazanim.yuklendi && !_kazanim.var_
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TextField(
                          controller: _konu,
                          maxLength: 120,
                          decoration: const InputDecoration(labelText: 'Konu', hintText: 'Örn. Atölye çalışması'),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _aciklama,
                maxLength: 500,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Açıklama (isteğe bağlı)', hintText: 'Derste neler yapıldı'),
              ),
            ],
          ),
        ),
        const Baslik('Ödev (isteğe bağlı)'),
        KartKutu(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _odevBaslik,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Ödev', hintText: 'Örn. Sayfa 40-41 alıştırmaları'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _odevAciklama,
                maxLength: 500,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Açıklama'),
              ),
              const SizedBox(height: 8),
              KazanimAlani(secim: _odevKazanim),
              const SizedBox(height: 8),
              OutlinedButton.icon(onPressed: _sonTarihSec, icon: const Icon(Icons.event, size: 20), label: Text('Son teslim: ${uzunTarih(_sonTarih)}')),
            ],
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _kaydediyor ? null : _kaydet,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: _kaydediyor
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : Text(tamam ? 'Değişiklikleri kaydet' : 'Dersi bitir'),
        ),
        if (j['alindi'] == true)
          TextButton(
            onPressed: _iptalEt,
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFD64545), minimumSize: const Size.fromHeight(48)),
            child: const Text('Dersi iptal et'),
          ),
      ],
    );
  }
}

class _DurumHapi extends StatelessWidget {
  const _DurumHapi(this.d);

  final (String, String, Color) d;

  @override
  Widget build(BuildContext context) => Container(
    width: 96,
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(color: d.$3.withValues(alpha: .13), borderRadius: BorderRadius.circular(20)),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            d.$2,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: d.$3, fontWeight: FontWeight.w700, fontSize: 13.5),
          ),
        ),
        Icon(Icons.arrow_drop_down, size: 18, color: d.$3),
      ],
    ),
  );
}

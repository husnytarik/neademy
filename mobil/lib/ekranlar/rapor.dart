import 'package:flutter/material.dart';

import '../bilesenler/ortak.dart';
import '../cekirdek/api.dart';
import '../cekirdek/tema.dart';
import '../cekirdek/yazdir.dart';

/// Raporlar (yönetim): okul ya da tüm kurum için devam, eksik ders, ödev ve kulüp özetleri.
class RaporEkrani extends StatefulWidget {
  const RaporEkrani({super.key, required this.api});

  final Api api;

  @override
  State<RaporEkrani> createState() => _RaporEkraniState();
}

class _RaporEkraniState extends State<RaporEkrani> {
  String _okul = '';

  @override
  Widget build(BuildContext context) => VeriSayfasi(
    key: ValueKey(_okul),
    baslik: 'Raporlar',
    eylemler: (context, raw) => [YazdirDugmesi(onPressed: () => _yazdir(context, raw as Map<String, dynamic>))],
    getir: () async => await widget.api.get('/api/rapor/ozet${_okul.isEmpty ? '' : '?okul=$_okul'}'),
    cizim: (context, raw) {
      final v = raw as Map<String, dynamic>;
      final ozet = v.m('ozet');
      final devam = v.m('devam');
      final odev = v.m('odev');
      final eksik = v.m('eksikDersler');
      final kulupler = v.l('kulupler');
      final okulSecili = v['okul'] != null;
      return [
        DropdownButtonFormField<String>(
          initialValue: _okul,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Okul'),
          items: [
            const DropdownMenuItem(value: '', child: Text('Tüm okullar')),
            for (final o in v.l('okullar'))
              DropdownMenuItem(
                value: '${o.n('id')}',
                child: Text(o.s('ad'), overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (x) => setState(() => _okul = x ?? ''),
        ),
        const SizedBox(height: 12),
        Row(children: [_Sayac('${ozet.n('ogrenci')}', 'Öğrenci'), _Sayac('${ozet.n('ogretmen')}', 'Öğretmen'), _Sayac('${ozet.n('sinif')}', 'Sınıf')]),
        const SizedBox(height: 8),
        Row(
          children: [
            _Sayac('%${devam.n('yuzde')}', 'Devam', kirmizi: devam.n('yuzde') < 90),
            _Sayac('%${odev.n('yuzde')}', 'Ödev', kirmizi: odev.n('yuzde') < 60),
            _Sayac('${eksik.n('toplam')}', 'Eksik ders', kirmizi: eksik.n('oran') > 20),
          ],
        ),
        _Cubuklar(
          baslik: 'Devamsızlığı en yüksek sınıflar',
          bos: 'Henüz yoklama yok.',
          satirlar: [for (final s in devam.l('siniflar')) (s.s('ad'), s.n('oran'), '%${s.n('oran')}')],
        ),
        _Cubuklar(
          baslik: 'En çok devamsızlık yapan öğrenciler',
          bos: 'Devamsızlık kaydı yok.',
          satirlar: [for (final s in v.l('devamsizlar')) ('${s.s('ad')} · ${s.s('sinif')}', s.n('gelmedi'), '${s.n('gelmedi')} ders')],
        ),
        _Cubuklar(
          baslik: 'Dersi tamamlamayan öğretmenler (son 14 gün)',
          bos: 'Eksik ders yok.',
          satirlar: [for (final s in eksik.l('ogretmenler')) (s.s('ad'), s.n('sayi'), '${s.n('sayi')} ders')],
        ),
        _Cubuklar(
          baslik: 'Ödev tamamlaması en düşük sınıflar',
          bos: 'Ödev yok.',
          tavan: 100,
          satirlar: [for (final s in odev.l('siniflar')) (s.s('ad'), s.n('oran'), '%${s.n('oran')}')],
        ),
        _Cubuklar(
          baslik: 'Kulüp doluluğu',
          bos: 'Kulüp yok.',
          tavan: kulupler.fold<int>(1, (t, k) => k.n('kontenjan') > t ? k.n('kontenjan') : t),
          satirlar: [for (final k in kulupler) (okulSecili ? k.s('ad') : '${k.s('ad')} · ${k.s('okul')}', k.n('uye'), '${k.n('uye')}/${k.n('kontenjan')}')],
        ),
      ];
    },
  );

  void _yazdir(BuildContext context, Map<String, dynamic> v) {
    final ozet = v.m('ozet');
    final devam = v.m('devam');
    final odev = v.m('odev');
    final eksik = v.m('eksikDersler');
    final kulupler = v.l('kulupler');
    final okulSecili = v['okul'] != null;
    String okulAdi = 'Tüm okullar';
    for (final o in v.l('okullar')) {
      if ('${o.n('id')}' == _okul) okulAdi = o.s('ad');
    }
    raporYazdir(
      context,
      widget.api,
      baslik: 'Okul raporu',
      alt: okulAdi,
      bolumler: [
        RaporBolumu(
          baslik: 'Genel durum',
          ozet: [
            ('Öğrenci', '${ozet.n('ogrenci')}'),
            ('Öğretmen', '${ozet.n('ogretmen')}'),
            ('Sınıf', '${ozet.n('sinif')}'),
            ('Devam oranı', '%${devam.n('yuzde')}'),
            ('Ödev tamamlama', '%${odev.n('yuzde')}'),
            ('Eksik ders (son 14 gün)', '${eksik.n('toplam')}'),
          ],
        ),
        RaporBolumu(
          baslik: 'Devamsızlığı en yüksek sınıflar',
          sutunlar: const ['Sınıf', 'Devamsızlık'],
          satirlar: [for (final s in devam.l('siniflar')) [s.s('ad'), '%${s.n('oran')}']],
          bos: 'Henüz yoklama yok.',
        ),
        RaporBolumu(
          baslik: 'En çok devamsızlık yapan öğrenciler',
          sutunlar: const ['Öğrenci', 'Sınıf', 'Gelmediği ders'],
          satirlar: [for (final s in v.l('devamsizlar')) [s.s('ad'), s.s('sinif'), '${s.n('gelmedi')}']],
          bos: 'Devamsızlık kaydı yok.',
        ),
        RaporBolumu(
          baslik: 'Dersi tamamlamayan öğretmenler (son 14 gün)',
          sutunlar: const ['Öğretmen', 'Tamamlanmayan ders'],
          satirlar: [for (final s in eksik.l('ogretmenler')) [s.s('ad'), '${s.n('sayi')}']],
          bos: 'Eksik ders yok.',
        ),
        RaporBolumu(
          baslik: 'Ödev tamamlaması en düşük sınıflar',
          sutunlar: const ['Sınıf', 'Tamamlama'],
          satirlar: [for (final s in odev.l('siniflar')) [s.s('ad'), '%${s.n('oran')}']],
          bos: 'Ödev yok.',
        ),
        RaporBolumu(
          baslik: 'Kulüp doluluğu',
          sutunlar: okulSecili ? const ['Kulüp', 'Üye / kontenjan'] : const ['Kulüp', 'Okul', 'Üye / kontenjan'],
          satirlar: [
            for (final k in kulupler) [k.s('ad'), if (!okulSecili) k.s('okul'), '${k.n('uye')}/${k.n('kontenjan')}'],
          ],
          bos: 'Kulüp yok.',
        ),
      ],
    );
  }
}

class _Sayac extends StatelessWidget {
  const _Sayac(this.deger, this.ad, {this.kirmizi = false});

  final String deger;
  final String ad;
  final bool kirmizi;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: context.kart,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.ince),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              deger,
              style: serif.copyWith(fontSize: 22, fontWeight: FontWeight.w700, color: kirmizi ? Colors.red.shade600 : null),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            ad,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, color: context.soluk),
          ),
        ],
      ),
    ),
  );
}

/// Yatay çubuklar: (ad, değer, yazı); en büyük değere (ya da `tavan`a) göre ölçeklenir.
class _Cubuklar extends StatelessWidget {
  const _Cubuklar({required this.baslik, required this.satirlar, required this.bos, this.tavan});

  final String baslik;
  final List<(String, int, String)> satirlar;
  final String bos;
  final int? tavan;

  @override
  Widget build(BuildContext context) {
    final en = tavan ?? satirlar.fold<int>(1, (t, s) => s.$2 > t ? s.$2 : t);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Baslik(baslik, ust: 18),
        if (satirlar.isEmpty) BosNot(bos),
        for (final s in satirlar)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(s.$1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5)),
                    ),
                    const SizedBox(width: 8),
                    Text(s.$3, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: s.$2 <= 0 ? 0 : (s.$2 / en).clamp(.03, 1).toDouble(),
                    minHeight: 7,
                    backgroundColor: context.icZemin,
                    color: context.ana,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../bilesenler/ortak.dart';
import '../cekirdek/api.dart';
import '../cekirdek/tema.dart';

Color _puanRenk(num p) => p < 40 ? const Color(0xFFD64545) : p < 70 ? const Color(0xFFE0A100) : const Color(0xFF2E9E5B);

String _tarihYaz(String t) => t.split('-').reversed.join('.');

/// Öğrenci ve veli: yayınlanan sınav sonuçları, ders bazlı puanlar ve eksik kazanımlar.
class NotlarimEkrani extends StatelessWidget {
  const NotlarimEkrani({super.key, required this.api});

  final Api api;

  @override
  Widget build(BuildContext context) => VeriSayfasi(
        baslik: 'Sınav sonuçları',
        getir: () => api.get('/api/sinav/notlarim'),
        cizim: (context, veri) {
          final ogrenciler = (veri as Map<String, dynamic>).l('ogrenciler');
          if (ogrenciler.isEmpty) return const [BosNot('Bağlı öğrenci bulunamadı.')];
          return [
            for (final o in ogrenciler) ...[
              Baslik(o.s('ad'), ust: 10),
              if (o.l('sinavlar').isEmpty) const BosNot('Henüz yayınlanmış sınav sonucu yok. Öğretmen yayınladığında burada görünür.'),
              if (o.l('sinavlar').length > 1) _Gelisim(o.l('sinavlar')),
              for (final (i, s) in o.l('sinavlar').indexed) _Sinav(s, acik: i == 0),
            ],
          ];
        },
      );
}

/// Son sınavların ortalama puanı (en eski solda).
class _Gelisim extends StatelessWidget {
  const _Gelisim(this.sinavlar);

  final List<Map<String, dynamic>> sinavlar;

  @override
  Widget build(BuildContext context) {
    final son = sinavlar.take(5).toList().reversed.toList();
    return KartKutu(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Ortalama puan', style: TextStyle(color: context.soluk, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (final s in son)
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text('${(s['ortalama'] as num? ?? 0).round()}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 3),
                  Container(
                    width: 26,
                    height: 4 + 64 * ((s['ortalama'] as num? ?? 0).clamp(0, 100) / 100),
                    decoration: BoxDecoration(color: _puanRenk(s['ortalama'] as num? ?? 0), borderRadius: BorderRadius.circular(6)),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    s.s('ad').replaceAll(RegExp(r' Sınavı$'), '').replaceAll(RegExp(r'^\d\. Dönem \d\. '), '').replaceAll(RegExp(r' Yazılısı$'), ''),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.soluk, fontSize: 10.5),
                  ),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _Sinav extends StatelessWidget {
  const _Sinav(this.s, {required this.acik});

  final Map<String, dynamic> s;
  final bool acik;

  @override
  Widget build(BuildContext context) {
    final yazili = s['yazili'] == true;
    final dersler = s.l('dersler');
    final sira = s.m('siralama');
    final ortalama = (s['ortalama'] as num? ?? 0);
    final kapsam = [for (final x in (s['kapsam'] as List? ?? const [])) x.toString()];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: context.kart,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: context.ince)),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: acik,
            tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            title: Text(s.s('ad'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5)),
            subtitle: Text(
              yazili ? _tarihYaz(s.s('tarih')) : '${_tarihYaz(s.s('tarih'))} · ${s.n('giren')} öğrenci içinde ${s.n('sira')}. sıra',
              style: TextStyle(color: context.soluk, fontSize: 13),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(color: _puanRenk(ortalama).withValues(alpha: .14), borderRadius: BorderRadius.circular(10)),
              child: Text(ortalama.toStringAsFixed(ortalama % 1 == 0 ? 0 : 1), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: _puanRenk(ortalama))),
            ),
            children: [
              if (!yazili && (sira.m('sinif').isNotEmpty || sira.m('okul').isNotEmpty || sira.m('genel').isNotEmpty))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final (ad, k) in [('Sınıfta', 'sinif'), ('Okulda', 'okul'), ('Genelde', 'genel')])
                      if (sira.m(k).isNotEmpty) Cip('$ad ${sira.m(k).n('sira')}/${sira.m(k).n('sayi')}', renk: context.ana),
                  ]),
                ),
              for (final d in dersler) _DersSatiri(d, yanlisKat: s.n('yanlisKat')),
              if (kapsam.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('Sınavın kazanımları', style: TextStyle(color: context.soluk, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                for (final k in kapsam) Padding(padding: const EdgeInsets.only(top: 3), child: Text('• $k', style: const TextStyle(height: 1.3))),
              ],
              for (final d in dersler)
                if (d.l('kazanimlar').isNotEmpty) _Kazanimlar(d),
            ],
          ),
        ),
      ),
    );
  }
}

class _DersSatiri extends StatelessWidget {
  const _DersSatiri(this.d, {required this.yanlisKat});

  final Map<String, dynamic> d;
  final int yanlisKat;

  @override
  Widget build(BuildContext context) {
    final puan = (d['puan'] as num? ?? 0);
    final netVar = d['net'] != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(d.s('ders'), style: const TextStyle(fontWeight: FontWeight.w600))),
          Text(puan.toStringAsFixed(puan % 1 == 0 ? 0 : 1), style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: puan.clamp(0, 100) / 100, minHeight: 7, color: _puanRenk(puan), backgroundColor: context.ince),
        ),
        if (netVar) ...[
          const SizedBox(height: 4),
          Text(
            '${d.n('dogru')} doğru · ${d.n('yanlis')} yanlış · ${d.n('bos')} boş · net ${d['net']}',
            style: TextStyle(color: context.soluk, fontSize: 12.5),
          ),
        ],
      ]),
    );
  }
}

/// Dersin edinilmemiş kazanımları (edinilenler sayıyla özetlenir).
class _Kazanimlar extends StatelessWidget {
  const _Kazanimlar(this.d);

  final Map<String, dynamic> d;

  static const _durumRenk = {'Kısmen': Color(0xFFB45309), 'Eksik': Color(0xFFC62828)};

  @override
  Widget build(BuildContext context) {
    final tum = d.l('kazanimlar');
    final eksik = [for (final k in tum) if (k.s('durum') != 'Edinildi') k];
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: Text('${d.s('ders')} · ${tum.length - eksik.length} edinildi, ${eksik.length} eksik', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          children: [
            if (eksik.isEmpty) Text('Bu dersteki tüm kazanımlar edinildi.', style: TextStyle(color: context.soluk)),
            for (final k in eksik)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(color: context.icZemin, borderRadius: BorderRadius.circular(10)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: Text(k.s('kazanim'), style: const TextStyle(fontSize: 13.5, height: 1.3))),
                    const SizedBox(width: 8),
                    Cip(k.s('durum'), renk: _durumRenk[k.s('durum')]),
                  ]),
                  const SizedBox(height: 4),
                  Text('Soru ${[for (final x in (k['sorular'] as List? ?? const [])) x].join(', ')} · ${k.n('dogru')}/${k.n('toplam')} doğru',
                      style: TextStyle(color: context.soluk, fontSize: 12.5)),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

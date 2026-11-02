import 'package:flutter/material.dart';

import '../bilesenler/ortak.dart';
import '../cekirdek/api.dart';
import '../cekirdek/tema.dart';
import 'karne.dart';

/// Veli: çocuğun bilgileri, devam ve ödev özeti, öğretmenleri.
class OgrencimEkrani extends StatelessWidget {
  const OgrencimEkrani({super.key, required this.api});

  final Api api;

  @override
  Widget build(BuildContext context) => VeriSayfasi(
        baslik: 'Öğrencim',
        getir: () => api.get('/api/ogrencim'),
        cizim: (context, veri) {
          final ogrenciler = (veri as Map<String, dynamic>).l('ogrenciler');
          if (ogrenciler.isEmpty) return const [BosNot('Bağlı öğrenci bulunamadı.')];
          return [for (final o in ogrenciler) _Ogrenci(api, o)];
        },
      );
}

class _Ogrenci extends StatelessWidget {
  const _Ogrenci(this.api, this.o);

  final Api api;
  final Map<String, dynamic> o;

  @override
  Widget build(BuildContext context) {
    final devam = o.m('devam');
    final odev = o.m('odev');
    final rehber = o.m('rehber');
    final ogretmenler = o.l('ogretmenler');
    final veliler = o.l('veliler');
    final ad = o.s('ad');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 8),
      KartKutu(
        child: Row(children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: context.ana.withValues(alpha: .14),
            child: Text(ad.isEmpty ? '?' : ad.characters.first.toUpperCase(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: context.ana)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ad, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text([o.s('okul'), o.s('sinif')].where((e) => e.isNotEmpty).join(' · '), style: TextStyle(color: context.soluk)),
              if (o.s('okulNo').isNotEmpty) Text('Okul no: ${o.s('okulNo')}', style: TextStyle(color: context.soluk, fontSize: 13.5)),
            ]),
          ),
        ]),
      ),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: _Ozet(
            baslik: 'Devam',
            buyuk: '%${devam.n('yuzde')}',
            satirlar: ['${devam.n('gelmedi')} gelmedi', '${devam.n('gec')} geç', '${devam.n('izinli')} izinli'],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Ozet(
            baslik: 'Ödev',
            buyuk: '${odev.n('yapilacak')}',
            satirlar: ['yapılacak', '${odev.n('onayda')} onayda', '${odev.n('geciken')} geciken'],
          ),
        ),
      ]),
      KartKutu(
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => KarneEkrani(api: api, ogrenciId: o.n('id')))),
        child: Row(children: [
          Icon(Icons.description_outlined, color: context.soluk),
          const SizedBox(width: 12),
          const Expanded(child: Text('Dönem karnesi')),
          Icon(Icons.chevron_right, color: context.soluk),
        ]),
      ),
      if (o.s('kulup').isNotEmpty)
        KartKutu(child: Row(children: [
          Icon(Icons.groups_outlined, color: context.soluk),
          const SizedBox(width: 12),
          Expanded(child: Text('Kulüp: ${o.s('kulup')}')),
        ])),
      if (rehber.s('ad').isNotEmpty) ...[
        const Baslik('Sınıf / mentor öğretmeni', ust: 8),
        KartKutu(child: _Kisi(rehber.s('ad'), [rehber.s('etiket'), rehber.s('telefon')].where((e) => e.isNotEmpty).join(' · '))),
      ],
      if (ogretmenler.isNotEmpty) ...[
        const Baslik('Öğretmenler', ust: 8),
        KartKutu(
          child: Column(children: [
            for (final (i, t) in ogretmenler.indexed) ...[
              if (i > 0) Divider(height: 18, color: context.ince),
              Row(children: [
                Expanded(child: Text(t.s('ders'), style: TextStyle(color: context.soluk))),
                Text(t.s('ad'), style: const TextStyle(fontWeight: FontWeight.w600)),
              ]),
            ],
          ]),
        ),
      ],
      if (veliler.isNotEmpty) ...[
        const Baslik('Veliler', ust: 8),
        KartKutu(
          child: Column(children: [
            for (final (i, v) in veliler.indexed) ...[
              if (i > 0) Divider(height: 18, color: context.ince),
              _Kisi(v.s('ad'), v.s('telefon')),
            ],
          ]),
        ),
      ],
      const SizedBox(height: 12),
    ]);
  }
}

class _Ozet extends StatelessWidget {
  const _Ozet({required this.baslik, required this.buyuk, required this.satirlar});

  final String baslik;
  final String buyuk;
  final List<String> satirlar;

  @override
  Widget build(BuildContext context) => KartKutu(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(baslik, style: TextStyle(color: context.soluk, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(buyuk, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -.5)),
          const SizedBox(height: 4),
          for (final s in satirlar) Text(s, style: TextStyle(color: context.soluk, fontSize: 13.5)),
        ]),
      );
}

class _Kisi extends StatelessWidget {
  const _Kisi(this.ad, this.alt);

  final String ad;
  final String alt;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(ad, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5)),
        if (alt.isNotEmpty) Text(alt, style: TextStyle(color: context.soluk, fontSize: 13.5)),
      ]);
}

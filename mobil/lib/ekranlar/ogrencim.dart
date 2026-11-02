import 'package:flutter/material.dart';

import '../bilesenler/ortak.dart';
import '../cekirdek/api.dart';
import '../cekirdek/tema.dart';
import 'devamsizlik.dart';
import 'karne.dart';
import 'kulup.dart';
import 'notlarim.dart';
import 'odevler.dart';
import 'program.dart';

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

  void _ac(BuildContext context, Widget Function() ekran) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ekran()));

  @override
  Widget build(BuildContext context) {
    final devam = o.m('devam');
    final odev = o.m('odev');
    final rehber = o.m('rehber');
    final ogretmenler = o.l('ogretmenler');
    final veliler = o.l('veliler');
    final geciken = odev.n('geciken');
    final yuzde = devam.n('yuzde');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        KartKutu(
          child: Column(
            children: [
              Row(
                children: [
                  KisiAvatari(ad: o.s('ad'), foto: o.s('foto'), api: api, yaricap: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(o.s('ad'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          [o.s('sinif'), if (o.s('okulNo').isNotEmpty) 'No ${o.s('okulNo')}', o.s('okul')].where((e) => e.isNotEmpty).join(' · '),
                          style: TextStyle(color: context.soluk, fontSize: 13.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _Sayac('%$yuzde', 'Devam', yuzde < 90),
                  const SizedBox(width: 8),
                  _Sayac('${devam.n('gelmedi')}', 'Gelmediği ders', devam.n('gelmedi') > 5),
                  const SizedBox(width: 8),
                  _Sayac('${odev.n('yapilacak')}', 'Yapılacak ödev', geciken > 0),
                ],
              ),
            ],
          ),
        ),
        if (rehber.s('ad').isNotEmpty || veliler.isNotEmpty) ...[
          const _AltBaslik('Kişiler'),
          KartKutu(
            child: Column(
              children: [
                if (rehber.s('ad').isNotEmpty)
                  _Satir('${rehber.s('etiket').isEmpty ? 'Sınıf öğretmeni' : rehber.s('etiket')} · ${rehber.s('ad')}', rehber.s('telefon'), tel: true),
                for (final v in veliler) _Satir('Veli · ${v.s('ad')}', v.s('telefon'), tel: true),
              ],
            ),
          ),
        ],
        const _AltBaslik('Durum'),
        KartKutu(
          child: Column(
            children: [
              _Satir(
                'Devamsızlık',
                '${devam.n('gelmedi')} gelmedi · ${devam.n('gec')} geç · ${devam.n('izinli')} izinli',
                ac: () => _ac(context, () => DevamsizlikEkrani(api: api)),
              ),
              _Satir(
                'Ödevler',
                geciken > 0 ? '${odev.n('yapilacak')} yapılacak · $geciken gecikmiş' : '${odev.n('yapilacak')} yapılacak · ${odev.n('onayda')} onay bekliyor',
                ac: () => _ac(context, () => OdevlerEkrani(api: api)),
              ),
              _Satir('Sınav sonuçları', 'Yayınlanan sonuçlar', ac: () => _ac(context, () => NotlarimEkrani(api: api))),
              _Satir(
                'Dönem karnesi',
                'Dersler, sınavlar, ödevler, gelişim',
                ac: () => _ac(context, () => KarneEkrani(api: api, ogrenciId: o.n('id'))),
              ),
              _Satir('Ders programı', 'Haftalık çizelge', ac: () => _ac(context, () => ProgramEkrani(api: api))),
              if (o.s('kulup').isNotEmpty) _Satir('Kulüp', o.s('kulup'), ac: () => _ac(context, () => KulupOgrenciEkrani(api: api))),
            ],
          ),
        ),
        if (ogretmenler.isNotEmpty) ...[
          const _AltBaslik('Öğretmenler'),
          KartKutu(child: Column(children: [for (final t in ogretmenler) _Satir(t.s('ders'), t.s('ad'))])),
        ],
        const SizedBox(height: 12),
      ],
    );
  }
}

class _AltBaslik extends StatelessWidget {
  const _AltBaslik(this.metin);

  final String metin;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
    child: Text(
      metin,
      style: serif.copyWith(fontSize: 14, fontWeight: FontWeight.w700, color: context.soluk),
    ),
  );
}

class _Sayac extends StatelessWidget {
  const _Sayac(this.deger, this.ad, this.uyari);

  final String deger;
  final String ad;
  final bool uyari;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
      decoration: BoxDecoration(color: context.icZemin, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text(
            deger,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: uyari ? const Color(0xFFD64545) : null),
          ),
          const SizedBox(height: 2),
          Text(
            ad,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.soluk, fontSize: 11.5),
          ),
        ],
      ),
    ),
  );
}

/// Etiket solda, değer sağda; `tel` ise telefon kutucuğu, `ac` ise ok ile açılır.
class _Satir extends StatelessWidget {
  const _Satir(this.etiket, this.deger, {this.ac, this.tel = false});

  final String etiket;
  final String deger;
  final VoidCallback? ac;
  final bool tel;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: ac,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.ince)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(etiket, style: TextStyle(color: context.soluk, fontSize: 14)),
          ),
          if (tel && deger.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: context.icZemin,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.ince),
              ),
              child: Text(deger, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
            )
          else
            Expanded(
              flex: 5,
              child: Text(
                deger,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          if (ac != null) Icon(Icons.chevron_right, size: 18, color: context.soluk),
        ],
      ),
    ),
  );
}

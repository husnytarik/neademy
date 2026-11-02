import 'package:flutter/material.dart';

import '../bilesenler/ortak.dart';
import '../cekirdek/api.dart';
import '../cekirdek/takvim_model.dart';
import '../cekirdek/tema.dart';

/// Mentor (sınıf) öğretmeni: sorumlu olduğu sınıflar ve öğrencileri.
class OgrencilerimEkrani extends StatelessWidget {
  const OgrencilerimEkrani({super.key, required this.api});

  final Api api;

  @override
  Widget build(BuildContext context) => VeriSayfasi(
    baslik: 'Öğrencilerim',
    getir: () => api.get('/api/ogrencilerim'),
    cizim: (context, veri) {
      final siniflar = (veri as Map<String, dynamic>).l('siniflar');
      if (siniflar.isEmpty) return const [BosNot('Sorumlu olduğunuz sınıf yok.')];
      return [
        for (final s in siniflar) ...[
          Baslik('${s.s('ad')} · ${s.l('ogrenciler').length} öğrenci'),
          if (s.l('ogrenciler').isEmpty) const BosNot('Bu sınıfta öğrenci yok.'),
          for (final o in s.l('ogrenciler')) _OgrenciSatiri(api: api, o: o),
        ],
      ];
    },
  );
}

class _OgrenciSatiri extends StatelessWidget {
  const _OgrenciSatiri({required this.api, required this.o});

  final Api api;
  final Map<String, dynamic> o;

  @override
  Widget build(BuildContext context) {
    final toplam = o.n('toplam');
    final yuzde = toplam == 0 ? null : ((o.n('geldi') + o.n('gec')) * 100 / toplam).round();
    return KartKutu(
      alt: 8,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OgrenciProfilEkrani(api: api, id: o.n('id'), ad: o.s('ad')),
        ),
      ),
      child: Row(
        children: [
          _Bas(o.s('ad')),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.s('ad'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5)),
                Text(
                  [if (o.s('okulNo').isNotEmpty) 'No ${o.s('okulNo')}', if (o.n('gelmedi') > 0) '${o.n('gelmedi')} gelmedi'].join(' · '),
                  style: TextStyle(color: context.soluk, fontSize: 13.5),
                ),
              ],
            ),
          ),
          if (yuzde != null) Cip('%$yuzde', renk: yuzde >= 90 ? Colors.green.shade700 : (yuzde >= 75 ? Colors.orange.shade800 : Colors.red.shade700)),
          Icon(Icons.chevron_right, color: context.soluk),
        ],
      ),
    );
  }
}

class _Bas extends StatelessWidget {
  const _Bas(this.ad, {this.yaricap = 20});

  final String ad;
  final double yaricap;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: yaricap,
    backgroundColor: context.ana.withValues(alpha: .14),
    child: Text(
      ad.isEmpty ? '?' : ad.characters.first.toUpperCase(),
      style: TextStyle(fontSize: yaricap * .8, fontWeight: FontWeight.w700, color: context.ana),
    ),
  );
}

const _durumAd = {'geldi': 'Geldi', 'gelmedi': 'Gelmedi', 'gec': 'Geç', 'izinli': 'İzinli'};

/// Öğrencinin profili ve dosyası: veliler, devam, gelişim dönemleri, ödev, kulüp, etüt.
class OgrenciProfilEkrani extends StatelessWidget {
  const OgrenciProfilEkrani({super.key, required this.api, required this.id, required this.ad});

  final Api api;
  final int id;
  final String ad;

  @override
  Widget build(BuildContext context) => VeriSayfasi(
    baslik: ad,
    getir: () async {
      final s = await Future.wait([api.get('/api/ogrencilerim/profil?id=$id'), api.get('/api/ogrencilerim/dosya?id=$id')]);
      return {'profil': s[0], 'dosya': s[1]};
    },
    cizim: (context, veri) => profilIcerik(context, (veri as Map<String, dynamic>).m('profil'), veri.m('dosya')),
  );
}

/// Öğrenci dosyasının gövdesi: iletişim, devam, gelişim, ödev, kulüp, etüt (öğretmen ve yönetim ortak kullanır).
List<Widget> profilIcerik(BuildContext context, Map<String, dynamic> p, Map<String, dynamic> d) {
  final ogr = p.m('ogrenci');
  final devam = p.m('devam');
  final veliler = p.l('veliler');
  final bilgi = d.m('bilgi');
  final dersler = p.l('dersler');
  final son = p.l('son');
  final donemler = d.l('donemler');
  final odevler = d.l('odevler');
  final etutler = d.l('etutler');
  final kulup = d.m('kulup');
  return [
    const SizedBox(height: 8),
    KartKutu(
      child: Row(
        children: [
          _Bas(ogr.s('ad'), yaricap: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ogr.s('ad'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                Text([ogr.s('sinif'), if (ogr.s('okulNo').isNotEmpty) 'No ${ogr.s('okulNo')}'].join(' · '), style: TextStyle(color: context.soluk)),
              ],
            ),
          ),
        ],
      ),
    ),
    if (veliler.isNotEmpty || bilgi.s('yakinAd').isNotEmpty || bilgi.s('ogrenciTelefon').isNotEmpty) ...[
      const Baslik('İletişim', ust: 8),
      KartKutu(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final v in veliler) _Satir('Veli · ${v.s('ad')}', v.s('telefon')),
            if (bilgi.s('yakinAd').isNotEmpty)
              _Satir('Yakın · ${bilgi.s('yakinAd')}${bilgi.s('yakinYakinlik').isEmpty ? '' : ' (${bilgi.s('yakinYakinlik')})'}', bilgi.s('yakinTelefon')),
            if (bilgi.s('ogrenciTelefon').isNotEmpty) _Satir('Öğrenci', bilgi.s('ogrenciTelefon')),
            if (bilgi.s('email').isNotEmpty) _Satir('E-posta', bilgi.s('email')),
            if ([bilgi.s('il'), bilgi.s('ilce'), bilgi.s('adres')].any((e) => e.isNotEmpty))
              _Satir('Adres', [bilgi.s('adres'), bilgi.s('ilce'), bilgi.s('il')].where((e) => e.isNotEmpty).join(', ')),
          ],
        ),
      ),
    ],
    const Baslik('Devam', ust: 8),
    KartKutu(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Cip('${devam.n('toplam')} ders'),
              Cip('${devam.n('geldi')} geldi', renk: Colors.green.shade700),
              Cip('${devam.n('gelmedi')} gelmedi', renk: Colors.red.shade700),
              Cip('${devam.n('gec')} geç', renk: Colors.orange.shade800),
              Cip('${devam.n('izinli')} izinli'),
            ],
          ),
          for (final x in dersler.where((x) => x.n('gelmedi') + x.n('gec') > 0))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(x.s('ders'), style: TextStyle(color: context.soluk)),
                  ),
                  Text('${x.n('gelmedi')} gelmedi · ${x.n('gec')} geç', style: const TextStyle(fontSize: 13.5)),
                ],
              ),
            ),
        ],
      ),
    ),
    if (son.isNotEmpty) ...[
      const Baslik('Son devamsızlıklar', ust: 8),
      KartKutu(
        child: Column(
          children: [
            for (final (i, x) in son.indexed) ...[
              if (i > 0) Divider(height: 16, color: context.ince),
              Row(
                children: [
                  Expanded(child: Text('${kisaTarih(x.s('tarih'))} · ${x.n('dersSaati')}. ders${x.s('ders').isEmpty ? '' : ' · ${x.s('ders')}'}')),
                  Cip(_durumAd[x.s('durum')] ?? x.s('durum'), renk: x.s('durum') == 'gelmedi' ? Colors.red.shade700 : Colors.orange.shade800),
                ],
              ),
            ],
          ],
        ),
      ),
    ],
    for (final dn in donemler.where((x) => x.l('girisler').isNotEmpty || x.l('gorusmeler').isNotEmpty)) ...[
      Baslik('Gelişim · ${dn.s('ad')}', ust: 8),
      KartKutu(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final g in dn.l('girisler'))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.s('baslik'), style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text([g.s('ogretmen'), g.s('ders')].where((e) => e.isNotEmpty).join(' · '), style: TextStyle(color: context.soluk, fontSize: 12.5)),
                    const SizedBox(height: 2),
                    Text(g.s('metin'), style: const TextStyle(height: 1.35)),
                  ],
                ),
              ),
            for (final g in dn.l('gorusmeler'))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${g.s('tur')} görüşmesi · ${g.s('tarih')} · ${g.s('yazan')}\n${g.s('notu')}',
                  style: TextStyle(color: context.soluk, height: 1.35),
                ),
              ),
          ],
        ),
      ),
    ],
    if (odevler.isNotEmpty) ...[
      const Baslik('Son ödevler', ust: 8),
      KartKutu(
        child: Column(
          children: [
            for (final (i, x) in odevler.indexed) ...[
              if (i > 0) Divider(height: 16, color: context.ince),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(x.s('baslik'), style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text('${x.s('ders')} · ${x.s('son')}', style: TextStyle(color: context.soluk, fontSize: 13)),
                      ],
                    ),
                  ),
                  Cip(_odevDurum[x.s('durum')] ?? x.s('durum')),
                ],
              ),
            ],
          ],
        ),
      ),
    ],
    if (kulup.isNotEmpty) ...[
      const Baslik('Kulüp', ust: 8),
      KartKutu(
        child: Row(
          children: [
            Icon(Icons.groups_outlined, color: context.soluk),
            const SizedBox(width: 12),
            Expanded(
              child: Text(kulup.s('ad'), style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Text('${kulup.n('geldi')}/${kulup.n('toplam')} katılım', style: TextStyle(color: context.soluk, fontSize: 13.5)),
          ],
        ),
      ),
    ],
    if (etutler.isNotEmpty) ...[
      const Baslik('Etütler', ust: 8),
      KartKutu(
        child: Column(
          children: [
            for (final (i, x) in etutler.indexed) ...[
              if (i > 0) Divider(height: 16, color: context.ince),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(x.s('konu'), style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text('${x.s('ders')} · ${x.s('tarih')}', style: TextStyle(color: context.soluk, fontSize: 13)),
                      ],
                    ),
                  ),
                  if (x.s('devam').isNotEmpty) Cip(_durumAd[x.s('devam')] ?? x.s('devam')),
                ],
              ),
            ],
          ],
        ),
      ),
    ],
    const SizedBox(height: 12),
  ];
}

const _odevDurum = {'verildi': 'Verildi', 'yapildi': 'Yaptı', 'yapilamadi': 'Yapamadı', 'dogrulandi': 'Doğrulandı', 'duzeltme': 'Düzeltme'};

class _Satir extends StatelessWidget {
  const _Satir(this.etiket, this.deger);

  final String etiket;
  final String deger;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(etiket, style: TextStyle(color: context.soluk, fontSize: 13.5)),
        ),
        Expanded(
          flex: 5,
          child: Text(
            deger.isEmpty ? '—' : deger,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

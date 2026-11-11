import 'package:flutter/material.dart';

import '../bilesenler/ortak.dart';
import '../cekirdek/api.dart';
import '../cekirdek/takvim_model.dart';
import '../cekirdek/tema.dart';
import '../cekirdek/yazdir.dart';

const _kirmizi = Color(0xFFD64545);
const _yesil = Color(0xFF2E9E5B);

String _say(Object? n) {
  if (n is! num) return '–';
  return n == n.roundToDouble() ? '${n.toInt()}' : n.toStringAsFixed(1);
}

String _yuzde(Object? n) => n is num ? '%${n.toInt()}' : '–';

Widget _donemSecici(List<Map<String, dynamic>> donemler, int secili, ValueChanged<int> degisti) {
  if (donemler.length < 2) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: DropdownButtonFormField<int>(
      initialValue: secili,
      decoration: const InputDecoration(isDense: true, labelText: 'Dönem'),
      items: [for (final d in donemler) DropdownMenuItem(value: d.n('id'), child: Text(d.s('ad')))],
      onChanged: (d) {
        if (d != null) degisti(d);
      },
    ),
  );
}

/// Bir öğrencinin dönem karnesi: dersler, sınavlar, ödevler, etütler ve öğretmen gözlemleri (yalnız okuma).
class KarneEkrani extends StatefulWidget {
  const KarneEkrani({super.key, required this.api, required this.ogrenciId, this.donemId});

  final Api api;
  final int ogrenciId;
  final int? donemId;

  @override
  State<KarneEkrani> createState() => _KarneEkraniState();
}

class _KarneEkraniState extends State<KarneEkrani> {
  int? _donem;

  @override
  void initState() {
    super.initState();
    _donem = widget.donemId;
  }

  @override
  Widget build(BuildContext context) => VeriSayfasi(
    key: ValueKey(_donem),
    baslik: 'Dönem karnesi',
    eylemler: (context, veri) {
      final v = veri as Map<String, dynamic>;
      if (v.l('ogrenciler').isEmpty) return const [];
      return [YazdirDugmesi(onPressed: () => _yazdir(context, v))];
    },
    getir: () => widget.api.get('/api/karne?id=${widget.ogrenciId}${_donem == null ? '' : '&donemId=$_donem'}'),
    cizim: (context, veri) {
      final v = veri as Map<String, dynamic>;
      final ogrenciler = v.l('ogrenciler');
      if (ogrenciler.isEmpty) return const [BosNot('Karne bulunamadı.')];
      final donem = v.m('donem');
      return [
        _donemSecici(v.l('donemler'), donem.n('id'), (d) => setState(() => _donem = d)),
        Text('${donem.s('ad')} · ${kisaTarih(donem.s('baslangic'))} – ${kisaTarih(donem.s('bitis'))}', style: TextStyle(color: context.soluk, fontSize: 13)),
        ..._ogrenci(context, ogrenciler.first),
      ];
    },
  );

  /// Web'deki karne çıktısı: öğrenci bilgisi, özet, dersler, sınavlar, ödev, etüt ve gözlemler.
  void _yazdir(BuildContext context, Map<String, dynamic> v) {
    final k = v.l('ogrenciler').first;
    final donem = v.m('donem');
    final o = k.m('ogrenci');
    final g = k.m('genel');
    final sinav = k.m('sinav');
    final odev = k.m('odev');
    final ot = odev.m('toplam');
    final etut = k.m('etut');
    final eo = etut.m('ozet');
    final gelisim = k.m('gelisim');
    raporYazdir(
      context,
      widget.api,
      baslik: 'Dönem karnesi',
      alt: '${o.s('ad')} · ${[o.s('sinif'), if (o.s('okulNo').isNotEmpty) 'No ${o.s('okulNo')}'].where((e) => e.isNotEmpty).join(' · ')} · ${donem.s('ad')} (${kisaTarih(donem.s('baslangic'))} – ${kisaTarih(donem.s('bitis'))})',
      bolumler: [
        RaporBolumu(
          baslik: 'Öğrenci',
          ozet: [
            ('Ad soyad', o.s('ad')),
            ('Sınıf', o.s('sinif')),
            if (o.s('mentor').isNotEmpty) (o.s('mentorEtiket').isEmpty ? 'Sınıf öğretmeni' : o.s('mentorEtiket'), o.s('mentor')),
            if (o.s('veli').isNotEmpty) ('Veli', o.s('veli')),
          ],
        ),
        RaporBolumu(
          baslik: 'Dönem özeti',
          ozet: [
            ('Yazılı ortalaması', _say(g['ortalama'])),
            ('Deneme ortalaması', _say(g['denemeOrtalama'])),
            ('Devamsızlık', '${g.n('devamsiz')}'),
            ('Geç', '${g.n('gec')}'),
            ('İzinli', '${g.n('izinli')}'),
            ('Ödev', _yuzde(g['odevYuzde'])),
            ('Etüt', '${g.n('etut')}'),
          ],
        ),
        RaporBolumu(
          baslik: 'Dersler',
          sutunlar: const ['Ders', 'Öğretmen', 'Not', 'Yazılılar', 'Devamsızlık'],
          satirlar: [
            for (final d in k.l('dersler'))
              [
                d.s('ders'),
                d.s('ogretmen'),
                d['not'] == null ? '–' : _say(d['not']),
                d.l('yazililar').map((y) => '${y.s('ad')}: ${_say(y['puan'])}').join(', '),
                d.m('devam').n('toplam') > 0 ? '${d.m('devam').n('gelmedi')} gelmedi / ${d.m('devam').n('toplam')} saat' : '–',
              ],
          ],
          bos: 'Bu sınıfa ders atanmamış.',
        ),
        RaporBolumu(
          baslik: 'Sınavlar',
          sutunlar: const ['Sınav', 'Tarih', 'Ortalama', 'Sınıf sırası'],
          satirlar: [
            for (final d in sinav.l('denemeler'))
              [
                d.s('ad'),
                kisaTarih(d.s('tarih')),
                _say(d['ortalama']),
                d.m('siralama').m('sinif').n('sira') > 0 ? '${d.m('siralama').m('sinif').n('sira')}/${d.m('siralama').m('sinif').n('sayi')}' : '–',
              ],
          ],
          bos: 'Bu dönemde yayınlanmış deneme yok.',
        ),
        if (sinav.l('tekrar').isNotEmpty)
          RaporBolumu(
            baslik: 'Tekrar edilmesi gereken konular',
            sutunlar: const ['Kazanım', 'Ders', 'Başarı'],
            satirlar: [for (final t in sinav.l('tekrar')) [t.s('kazanim'), t.s('ders'), _yuzde(t['oran'])]],
          ),
        RaporBolumu(
          baslik: 'Ödevler',
          metin: ot.n('verilen') == 0
              ? 'Bu dönemde son tarihi gelen ödev yok.'
              : '${ot.n('yapildi')}/${ot.n('verilen')} ödev yapıldı (${_yuzde(ot['yuzde'])}). ${ot.n('yapilmadi')} yapılmadı, ${ot.n('duzeltme')} düzeltmede, ${ot.n('isaretsiz')} işaretsiz.',
          sutunlar: const ['Ders', 'Yapılan / verilen', 'Oran'],
          satirlar: [for (final d in odev.l('dersler')) [d.s('ders'), '${d.n('yapildi')}/${d.n('verilen')}', _yuzde(d['yuzde'])]],
        ),
        RaporBolumu(
          baslik: 'Etütler',
          metin: eo.n('toplam') == 0
              ? 'Bu dönemde etüt yok.'
              : '${eo.n('toplam')} etüt: ${eo.n('geldi')} geldi, ${eo.n('gelmedi')} gelmedi, ${eo.n('izinli')} izinli, ${eo.n('bekliyor')} bekliyor.',
        ),
        RaporBolumu(
          baslik: 'Öğretmen gözlemleri',
          sutunlar: const ['Konu', 'Yazan', 'Görüş'],
          satirlar: [
            for (final x in gelisim.l('gozlemler')) [x.s('baslik'), [x.s('ogretmen'), x.s('ders')].where((e) => e.isNotEmpty).join(' · '), x.s('metin')],
            for (final x in gelisim.l('gorusmeler')) ['${x.s('tur')} görüşmesi · ${kisaTarih(x.s('tarih'))}', x.s('yazan'), x.s('notu')],
          ],
          bos: 'Bu dönem için gözlem girilmemiş.',
        ),
      ],
    );
  }

  List<Widget> _ogrenci(BuildContext context, Map<String, dynamic> k) {
    final o = k.m('ogrenci');
    final g = k.m('genel');
    final sinav = k.m('sinav');
    final odev = k.m('odev');
    final etut = k.m('etut');
    final gelisim = k.m('gelisim');
    final denemeler = sinav.l('denemeler');
    final tekrar = sinav.l('tekrar');
    final katilmadi = sinav.l('katilmadi');
    return [
      const SizedBox(height: 8),
      KartKutu(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(o.s('ad'), style: serif.copyWith(fontSize: 22)),
            const SizedBox(height: 2),
            Text(
              [o.s('sinif'), if (o.s('okulNo').isNotEmpty) 'No ${o.s('okulNo')}'].where((e) => e.isNotEmpty).join(' · '),
              style: TextStyle(color: context.soluk),
            ),
            if (o.s('mentor').isNotEmpty)
              Text(
                '${o.s('mentorEtiket').isEmpty ? 'Sınıf öğretmeni' : o.s('mentorEtiket')}: ${o.s('mentor')}',
                style: TextStyle(color: context.soluk, fontSize: 13.5),
              ),
            if (o.s('veli').isNotEmpty) Text('Veli: ${o.s('veli')}', style: TextStyle(color: context.soluk, fontSize: 13.5)),
          ],
        ),
      ),
      const SizedBox(height: 4),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _Kutu(_say(g['ortalama']), 'Yazılı ortalaması'),
          _Kutu(_say(g['denemeOrtalama']), 'Deneme ortalaması'),
          _Kutu('${g.n('devamsiz')}', 'Devamsızlık', renk: g.n('devamsiz') > 0 ? _kirmizi : null),
          _Kutu('${g.n('gec')}', 'Geç'),
          _Kutu('${g.n('izinli')}', 'İzinli'),
          _Kutu(_yuzde(g['odevYuzde']), 'Ödev'),
          _Kutu('${g.n('etut')}', 'Etüt'),
        ],
      ),
      const Baslik('Dersler', ust: 14),
      if (k.l('dersler').isEmpty) const BosNot('Bu sınıfa ders atanmamış.'),
      for (final d in k.l('dersler')) _ders(context, d),
      const Baslik('Sınavlar', ust: 14),
      if (denemeler.isEmpty) const BosNot('Bu dönemde yayınlanmış deneme yok.'),
      for (final d in denemeler) _deneme(context, d),
      if (katilmadi.isNotEmpty)
        KartKutu(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Girilmeyen sınavlar',
                style: TextStyle(color: context.soluk, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              for (final s in katilmadi) Text('${s.s('ad')} · ${kisaTarih(s.s('tarih'))}'),
            ],
          ),
        ),
      if (tekrar.isNotEmpty) ...[
        const Baslik('Tekrar edilmesi gereken konular', ust: 14),
        KartKutu(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, t) in tekrar.indexed) ...[
                if (i > 0) Divider(height: 16, color: context.ince),
                Text(t.s('kazanim'), style: const TextStyle(height: 1.3)),
                Text('${t.s('ders')} · ${_yuzde(t['oran'])} başarı', style: TextStyle(color: context.soluk, fontSize: 12.5)),
              ],
            ],
          ),
        ),
      ],
      const Baslik('Ödevler', ust: 14),
      ..._odev(context, odev),
      const Baslik('Etütler', ust: 14),
      ..._etut(context, etut),
      const Baslik('Öğretmen gözlemleri', ust: 14),
      if (gelisim.l('gozlemler').isEmpty && gelisim.l('gorusmeler').isEmpty) const BosNot('Bu dönem için gözlem girilmemiş.'),
      for (final x in gelisim.l('gozlemler'))
        KartKutu(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(x.s('baslik'), style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text([x.s('ogretmen'), x.s('ders')].where((e) => e.isNotEmpty).join(' · '), style: TextStyle(color: context.soluk, fontSize: 12.5)),
              const SizedBox(height: 6),
              Text(x.s('metin'), style: const TextStyle(height: 1.4)),
            ],
          ),
        ),
      for (final x in gelisim.l('gorusmeler'))
        KartKutu(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${x.s('tur')} görüşmesi · ${kisaTarih(x.s('tarih'))}', style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(x.s('yazan'), style: TextStyle(color: context.soluk, fontSize: 12.5)),
              const SizedBox(height: 6),
              Text(x.s('notu'), style: const TextStyle(height: 1.4)),
            ],
          ),
        ),
      const SizedBox(height: 12),
    ];
  }

  Widget _ders(BuildContext context, Map<String, dynamic> d) {
    final dv = d.m('devam');
    final yazililar = d.l('yazililar');
    return KartKutu(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.s('ders'), style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
                    if (d.s('ogretmen').isNotEmpty) Text(d.s('ogretmen'), style: TextStyle(color: context.soluk, fontSize: 13)),
                  ],
                ),
              ),
              if (d['not'] != null) Cip('Not ${_say(d['not'])}', renk: context.ana),
            ],
          ),
          if (yazililar.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final y in yazililar)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('${y.s('ad')} · ${kisaTarih(y.s('tarih'))}', style: TextStyle(color: context.soluk, fontSize: 13)),
                    ),
                    Text(_say(y['puan']), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
          ],
          if (dv.n('toplam') > 0) ...[
            const SizedBox(height: 8),
            Text(
              '${dv.n('toplam')} ders saati · ${dv.n('gelmedi')} gelmedi · ${dv.n('gec')} geç · ${dv.n('izinli')} izinli',
              style: TextStyle(color: dv.n('gelmedi') > 0 ? _kirmizi : context.soluk, fontSize: 12.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _deneme(BuildContext context, Map<String, dynamic> d) {
    final sinif = d.m('siralama').m('sinif');
    final degisim = d.m('degisim');
    final fark = degisim['fark'];
    return KartKutu(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.s('ad'), style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(kisaTarih(d.s('tarih')), style: TextStyle(color: context.soluk, fontSize: 12.5)),
                if (sinif.n('sira') > 0) Text('Sınıfta ${sinif.n('sira')}/${sinif.n('sayi')}', style: TextStyle(color: context.soluk, fontSize: 12.5)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_say(d['ortalama']), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              if (fark is num && fark != 0)
                Text(
                  '${fark > 0 ? '+' : ''}${_say(fark)}',
                  style: TextStyle(color: fark > 0 ? _yesil : _kirmizi, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _odev(BuildContext context, Map<String, dynamic> odev) {
    final t = odev.m('toplam');
    if (t.n('verilen') == 0) return const [BosNot('Bu dönemde son tarihi gelen ödev yok.')];
    return [
      KartKutu(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${t.n('yapildi')}/${t.n('verilen')} ödev yapıldı · ${_yuzde(t['yuzde'])}', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(
              '${t.n('yapilmadi')} yapılmadı · ${t.n('duzeltme')} düzeltmede · ${t.n('isaretsiz')} işaretsiz',
              style: TextStyle(color: context.soluk, fontSize: 12.5),
            ),
            for (final d in odev.l('dersler')) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(d.s('ders'), style: TextStyle(color: context.soluk, fontSize: 13.5)),
                  ),
                  Text('${d.n('yapildi')}/${d.n('verilen')} · ${_yuzde(d['yuzde'])}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                ],
              ),
            ],
          ],
        ),
      ),
      if (odev.l('eksik').isNotEmpty)
        KartKutu(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tamamlanmamış ödevler',
                style: TextStyle(color: context.soluk, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              for (final e in odev.l('eksik'))
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('${e.s('baslik')} · ${e.s('ders')} · ${kisaTarih(e.s('son'))}', style: const TextStyle(height: 1.3)),
                ),
            ],
          ),
        ),
    ];
  }

  List<Widget> _etut(BuildContext context, Map<String, dynamic> etut) {
    final o = etut.m('ozet');
    if (o.n('toplam') == 0) return const [BosNot('Bu dönemde etüt yok.')];
    return [
      KartKutu(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${o.n('toplam')} etüt · ${o.n('geldi')} geldi · ${o.n('gelmedi')} gelmedi · ${o.n('izinli')} izinli · ${o.n('bekliyor')} bekliyor',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            for (final e in etut.l('liste'))
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${kisaTarih(e.s('tarih'))} ${e.s('saat')} · ${[e.s('ders'), e.s('konu')].where((x) => x.isNotEmpty).join(' · ')}',
                  style: TextStyle(color: context.soluk, fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    ];
  }
}

class _Kutu extends StatelessWidget {
  const _Kutu(this.deger, this.ad, {this.renk});

  final String deger;
  final String ad;
  final Color? renk;

  @override
  Widget build(BuildContext context) => Container(
    width: 104,
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    decoration: BoxDecoration(
      color: context.icZemin,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: context.ince),
    ),
    child: Column(
      children: [
        Text(
          deger,
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: renk),
        ),
        const SizedBox(height: 2),
        Text(
          ad,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.soluk, fontSize: 12),
        ),
      ],
    ),
  );
}

/// Bir sınıfın öğrencileri ve karne özetleri; dokununca o öğrencinin karnesi açılır.
class SinifKarneEkrani extends StatefulWidget {
  const SinifKarneEkrani({super.key, required this.api, required this.sinifId});

  final Api api;
  final int sinifId;

  @override
  State<SinifKarneEkrani> createState() => _SinifKarneEkraniState();
}

class _SinifKarneEkraniState extends State<SinifKarneEkrani> {
  int? _donem;

  @override
  Widget build(BuildContext context) => VeriSayfasi(
    key: ValueKey(_donem),
    baslik: 'Sınıf karneleri',
    getir: () => widget.api.get('/api/karne?sinifId=${widget.sinifId}${_donem == null ? '' : '&donemId=$_donem'}'),
    cizim: (context, veri) {
      final v = veri as Map<String, dynamic>;
      final ogrenciler = v.l('ogrenciler');
      if (v['donem'] == null) return const [BosNot('Bu sınıfta öğrenci yok.')];
      final donem = v.m('donem');
      return [
        Text('${v.m('sinif').s('ad')} sınıfı', style: serif.copyWith(fontSize: 22)),
        const SizedBox(height: 8),
        _donemSecici(v.l('donemler'), donem.n('id'), (d) => setState(() => _donem = d)),
        for (final k in ogrenciler) _satir(context, k, donem.n('id')),
      ];
    },
  );

  Widget _satir(BuildContext context, Map<String, dynamic> k, int donemId) {
    final o = k.m('ogrenci');
    final g = k.m('genel');
    return KartKutu(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => KarneEkrani(api: widget.api, ogrenciId: o.n('id'), donemId: donemId),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.s('ad'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5)),
                Text(
                  'Not ${_say(g['ortalama'])} · Deneme ${_say(g['denemeOrtalama'])} · Devamsız ${g.n('devamsiz')} · Ödev ${_yuzde(g['odevYuzde'])}',
                  style: TextStyle(color: context.soluk, fontSize: 12.5),
                ),
              ],
            ),
          ),
          if (o.s('okulNo').isNotEmpty) Text(o.s('okulNo'), style: TextStyle(color: context.soluk)),
          Icon(Icons.chevron_right, color: context.soluk),
        ],
      ),
    );
  }
}

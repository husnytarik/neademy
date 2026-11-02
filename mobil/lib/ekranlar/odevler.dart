import 'package:flutter/material.dart';

import '../bilesenler/ortak.dart';
import '../cekirdek/api.dart';
import '../cekirdek/takvim_model.dart';
import '../cekirdek/tema.dart';

const _durumSuz = [
  ('', 'Tüm ödevler'),
  ('yapilacak', 'Yapılacak'),
  ('onay', 'Onay bekliyor'),
  ('bitti', 'Tamamlandı'),
  ('gecmis', 'Süresi dolan'),
];
const _yapilacak = ['verildi', 'duzeltme', 'yapilamadi'];
const _durumRenk = {
  'verildi': Color(0xFF1F6FEB),
  'duzeltme': Color(0xFFD97706),
  'yapilamadi': Color(0xFFD64545),
  'yapildi': Color(0xFF7C3AED),
  'dogrulandi': Color(0xFF2E9E5B),
};

/// Öğrenci ve veli: verilen ödevler, son tarihleri ve durumları.
class OdevlerEkrani extends StatefulWidget {
  const OdevlerEkrani({super.key, required this.api});

  final Api api;

  @override
  State<OdevlerEkrani> createState() => _OdevlerEkraniState();
}

class _OdevlerEkraniState extends State<OdevlerEkrani> {
  String _durum = '';
  String _ders = '';

  @override
  Widget build(BuildContext context) => VeriSayfasi(
        baslik: 'Ödevler',
        getir: () => widget.api.get('/api/ders/odevlerim'),
        cizim: (context, veri) {
          final v = veri as Map<String, dynamic>;
          final bugun = v.s('bugun');
          final durumlar = v.m('durumlar');
          final ogrenciler = v.l('ogrenciler');
          if (ogrenciler.isEmpty) return const [BosNot('Bağlı öğrenci bulunamadı.')];
          final dersler = {for (final o in ogrenciler) for (final x in o.l('odevler')) x.s('ders')}.toList()..sort((a, b) => a.compareTo(b));
          if (_ders.isNotEmpty && !dersler.contains(_ders)) _ders = '';
          return [
            SuzgecCipleri(secenekler: _durumSuz, secili: _durum, degisti: (k) => setState(() => _durum = k)),
            if (dersler.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: DropdownButtonFormField<String>(
                  initialValue: _ders,
                  decoration: const InputDecoration(isDense: true),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Tüm dersler')),
                    for (final d in dersler) DropdownMenuItem(value: d, child: Text(d)),
                  ],
                  onChanged: (d) => setState(() => _ders = d ?? ''),
                ),
              ),
            for (final o in ogrenciler) ..._ogrenci(context, o, bugun, durumlar),
          ];
        },
      );

  int _fark(String son, String bugun) => tarihCoz(son).difference(tarihCoz(bugun)).inDays;

  List<Widget> _ogrenci(BuildContext context, Map<String, dynamic> o, String bugun, Map<String, dynamic> durumlar) {
    final odevler = o.l('odevler');
    int say(List<String> d) => odevler.where((x) => d.contains(x.s('durum'))).length;
    final gorunen = odevler.where((x) {
      if (_ders.isNotEmpty && x.s('ders') != _ders) return false;
      final bitti = x.s('durum') == 'dogrulandi';
      return switch (_durum) {
        'yapilacak' => _yapilacak.contains(x.s('durum')),
        'onay' => x.s('durum') == 'yapildi',
        'bitti' => bitti,
        'gecmis' => x.s('sonTarih').compareTo(bugun) < 0 && !bitti,
        _ => true,
      };
    }).toList();
    return [
      Baslik(o.s('ad')),
      Row(children: [
        _Sayac(say(_yapilacak), 'Yapılacak'),
        const SizedBox(width: 10),
        _Sayac(say(['yapildi']), 'Onay bekliyor'),
        const SizedBox(width: 10),
        _Sayac(say(['dogrulandi']), 'Tamamlandı'),
      ]),
      const SizedBox(height: 12),
      if (gorunen.isEmpty) BosNot(odevler.isEmpty ? 'Verilmiş ödev yok.' : 'Bu süzgece uyan ödev yok.'),
      for (final x in gorunen) _OdevKarti(x, bugun: bugun, fark: _fark(x.s('sonTarih'), bugun), durumlar: durumlar),
    ];
  }
}

class _Sayac extends StatelessWidget {
  const _Sayac(this.sayi, this.ad);

  final int sayi;
  final String ad;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: context.icZemin, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.ince)),
          child: Column(children: [
            Text('$sayi', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(ad, style: TextStyle(color: context.soluk, fontSize: 12.5)),
          ]),
        ),
      );
}

class _OdevKarti extends StatelessWidget {
  const _OdevKarti(this.x, {required this.bugun, required this.fark, required this.durumlar});

  final Map<String, dynamic> x;
  final String bugun;
  final int fark;
  final Map<String, dynamic> durumlar;

  @override
  Widget build(BuildContext context) {
    final bitti = x.s('durum') == 'dogrulandi';
    final gecmis = x.s('sonTarih').compareTo(bugun) < 0 && !bitti;
    final son = tarihCoz(x.s('sonTarih'));
    final durum = x.s('durum');
    return KartKutu(
      onTap: () => _detay(context),
      child: Opacity(
        opacity: bitti ? .7 : 1,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              color: (gecmis ? const Color(0xFFD64545) : context.ana).withValues(alpha: .12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(children: [
              Text('${son.day}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
              Text(ayAdlari[son.month - 1].substring(0, 3), style: TextStyle(color: context.soluk, fontSize: 12)),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(x.s('baslik'), style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text([x.s('ders'), x.s('ogretmen')].where((e) => e.isNotEmpty).join(' · '), style: TextStyle(color: context.soluk, fontSize: 13.5)),
              if (x.s('aciklama').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(x.s('aciklama'), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.soluk, fontSize: 13.5, height: 1.3)),
              ],
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                Cip(durumlar.m(durum).s('ad').isEmpty ? durum : durumlar.m(durum).s('ad'), renk: _durumRenk[durum]),
                if (!bitti) Cip(gecmis ? 'Süresi doldu' : fark == 0 ? 'Bugün' : fark == 1 ? 'Yarın' : '$fark gün', renk: gecmis ? const Color(0xFFD64545) : null),
                if (x.n('dosya') > 0) Cip('${x.n('dosya')} fotoğraf'),
                if (x.n('yeniMesaj') > 0) const Cip('Yeni yanıt', renk: Color(0xFFA4161A)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  void _detay(BuildContext context) {
    final durum = x.s('durum');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(x.s('baslik'), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text([x.s('ders'), x.s('ogretmen')].where((e) => e.isNotEmpty).join(' · '), style: TextStyle(color: context.soluk)),
            const SizedBox(height: 14),
            Row(children: [
              Cip(durumlar.m(durum).s('ad'), renk: _durumRenk[durum]),
              const SizedBox(width: 8),
              Text('Son tarih: ${uzunTarih(x.s('sonTarih'))}', style: TextStyle(color: context.soluk, fontSize: 13.5)),
            ]),
            if (durumlar.m(durum).s('aciklama').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(durumlar.m(durum).s('aciklama'), style: TextStyle(color: context.soluk, fontSize: 13.5)),
            ],
            if (x.s('aciklama').isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(x.s('aciklama'), style: const TextStyle(height: 1.45)),
            ],
            if (x.s('kazanim').isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Kazanım', style: TextStyle(color: context.soluk, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(x.s('kazanim'), style: const TextStyle(height: 1.4)),
            ],
          ]),
        ),
      ),
    );
  }
}

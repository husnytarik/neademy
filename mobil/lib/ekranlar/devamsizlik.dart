import 'package:flutter/material.dart';

import '../bilesenler/ortak.dart';
import '../cekirdek/api.dart';
import '../cekirdek/takvim_model.dart';
import '../cekirdek/tema.dart';

const _geldiRenk = Color(0xFF2E9E5B);
const _renkler = {'gelmedi': Color(0xFFD64545), 'gec': Color(0xFFE0A100), 'izinli': Color(0xFF8A867D)};
const _simge = {'gelmedi': '✗', 'gec': '◔', 'izinli': 'i'};
const _adlar = {'gelmedi': 'Gelmedi', 'gec': 'Geç', 'izinli': 'İzinli'};

/// Öğrenci ve veli: ders devamsızlıkları (özet, derse göre dağılım, gün gün kayıtlar).
class DevamsizlikEkrani extends StatelessWidget {
  const DevamsizlikEkrani({super.key, required this.api, this.baslik = 'Devamsızlık'});

  final Api api;
  final String baslik;

  @override
  Widget build(BuildContext context) => VeriSayfasi(
    baslik: baslik,
    getir: () => api.get('/api/yoklama/devam'),
    cizim: (context, veri) {
      final cocuklar = (veri as Map<String, dynamic>).l('cocuklar');
      if (cocuklar.isEmpty) return const [BosNot('Bağlı öğrenci bulunamadı.')];
      return [for (final c in cocuklar) _CocukDevam(c)];
    },
  );
}

class _CocukDevam extends StatefulWidget {
  const _CocukDevam(this.c);

  final Map<String, dynamic> c;

  @override
  State<_CocukDevam> createState() => _CocukDevamState();
}

class _CocukDevamState extends State<_CocukDevam> {
  String _durum = '';
  String? _ders;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final say = c.m('say');
    final toplam = c.n('toplam');
    final gelmedi = say.n('gelmedi'), gec = say.n('gec'), izinli = say.n('izinli');
    final geldi = (toplam - gelmedi - gec - izinli).clamp(0, toplam);
    final yuzde = toplam == 0 ? 100 : ((toplam - gelmedi) / toplam * 100).round();
    final kayitlar = c.l('kayitlar');

    // Derse göre sayım
    final dersSay = <String, Map<String, int>>{};
    for (final k in kayitlar) {
      final d = dersSay.putIfAbsent(k.s('ders'), () => {'gelmedi': 0, 'gec': 0, 'izinli': 0});
      d[k.s('durum')] = (d[k.s('durum')] ?? 0) + 1;
    }
    final dersler = dersSay.entries.toList()..sort((a, b) => b.value.values.fold(0, (x, y) => x + y).compareTo(a.value.values.fold(0, (x, y) => x + y)));
    final enCok = dersler.isEmpty ? 1 : dersler.first.value.values.fold(0, (x, y) => x + y).clamp(1, 1 << 30);

    final gorunen = [
      for (final k in kayitlar)
        if ((_durum.isEmpty || k.s('durum') == _durum) && (_ders == null || k.s('ders') == _ders)) k,
    ];
    final gunler = <String, List<Map<String, dynamic>>>{};
    for (final k in gorunen) {
      gunler.putIfAbsent(k.s('tarih'), () => []).add(k);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Baslik(c.s('ad'), ust: 10),
        KartKutu(
          child: Row(
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: CustomPaint(
                  painter: _Halka([(geldi, _geldiRenk), (gec, _renkler['gec']!), (izinli, _renkler['izinli']!), (gelmedi, _renkler['gelmedi']!)], context.ince),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('%$yuzde', style: serif.copyWith(fontSize: 21, fontWeight: FontWeight.w700)),
                        Text('DEVAM', style: TextStyle(color: context.soluk, fontSize: 9.5, letterSpacing: .6)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Gosterge('Geldi', geldi, _geldiRenk),
                    _Gosterge('Geç', gec, _renkler['gec']!),
                    _Gosterge('İzinli', izinli, _renkler['izinli']!),
                    _Gosterge('Gelmedi', gelmedi, _renkler['gelmedi']!),
                    const SizedBox(height: 4),
                    Text('$toplam yoklamada', style: TextStyle(color: context.soluk, fontSize: 13.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (kayitlar.isEmpty)
          const BosNot('Kayıtlı devamsızlık yok.')
        else ...[
          const Baslik('Derslere göre', ust: 8),
          KartKutu(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
            child: Column(
              children: [
                for (final e in dersler)
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => _ders = _ders == e.key ? null : e.key),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(color: _ders == e.key ? context.ana.withValues(alpha: .12) : null, borderRadius: BorderRadius.circular(10)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                              ),
                              Text(
                                [
                                  if (e.value['gelmedi']! > 0) '${e.value['gelmedi']} gelmedi',
                                  if (e.value['gec']! > 0) '${e.value['gec']} geç',
                                  if (e.value['izinli']! > 0) '${e.value['izinli']} izinli',
                                ].join(' · '),
                                style: TextStyle(color: context.soluk, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: e.value.values.fold(0, (x, y) => x + y) / enCok,
                              minHeight: 6,
                              color: context.ana,
                              backgroundColor: context.ince,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Baslik('Kayıtlar', ust: 8),
          SuzgecCipleri(
            secenekler: [
              ('', 'Tümü · ${kayitlar.length}'),
              if (gelmedi > 0) ('gelmedi', 'Gelmedi · $gelmedi'),
              if (gec > 0) ('gec', 'Geç · $gec'),
              if (izinli > 0) ('izinli', 'İzinli · $izinli'),
            ],
            secili: _durum,
            degisti: (v) => setState(() => _durum = v),
          ),
          if (_ders != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Text('$_ders dersi', style: TextStyle(color: context.soluk)),
                  TextButton(onPressed: () => setState(() => _ders = null), child: const Text('Süzmeyi kaldır')),
                ],
              ),
            ),
          const SizedBox(height: 10),
          if (gunler.isEmpty) const BosNot('Bu süzmeye uyan kayıt yok.'),
          for (final g in gunler.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
              child: Text(
                uzunTarih(g.key),
                style: TextStyle(color: context.soluk, fontWeight: FontWeight.w600, fontSize: 13.5),
              ),
            ),
            for (final k in (g.value..sort((a, b) => a.n('dersSaati').compareTo(b.n('dersSaati')))))
              KartKutu(
                alt: 6,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: _renkler[k.s('durum')], shape: BoxShape.circle),
                      child: Text(
                        _simge[k.s('durum')] ?? '',
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(k.s('ders'), style: serif.copyWith(fontSize: 15.5, fontWeight: FontWeight.w700)),
                          Text('${k.n('dersSaati')}. ders', style: TextStyle(color: context.soluk, fontSize: 13)),
                        ],
                      ),
                    ),
                    Text(
                      _adlar[k.s('durum')] ?? k.s('durum'),
                      style: TextStyle(color: _renkler[k.s('durum')], fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
          ],
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

class _Gosterge extends StatelessWidget {
  const _Gosterge(this.ad, this.sayi, this.renk);

  final String ad;
  final int sayi;
  final Color renk;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: renk, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text('$sayi', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(width: 6),
        Text(ad, style: TextStyle(color: context.soluk, fontSize: 13.5)),
      ],
    ),
  );
}

class _Halka extends CustomPainter {
  _Halka(this.dilimler, this.iz);

  final List<(int, Color)> dilimler;
  final Color iz;

  @override
  void paint(Canvas canvas, Size size) {
    const kalin = 11.0;
    final r = Rect.fromLTWH(kalin / 2, kalin / 2, size.width - kalin, size.height - kalin);
    final boya = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = kalin
      ..color = iz;
    canvas.drawArc(r, 0, 6.2832, false, boya);
    final toplam = dilimler.fold<int>(0, (a, d) => a + d.$1);
    if (toplam == 0) return;
    var bas = -1.5708;
    for (final (n, renk) in dilimler) {
      if (n == 0) continue;
      final aci = 6.2832 * n / toplam;
      canvas.drawArc(r, bas, aci, false, boya..color = renk);
      bas += aci;
    }
  }

  @override
  bool shouldRepaint(_Halka eski) => eski.dilimler != dilimler || eski.iz != iz;
}

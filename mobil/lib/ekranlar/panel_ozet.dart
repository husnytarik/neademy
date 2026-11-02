import 'package:flutter/material.dart';

import '../bilesenler/ikon.dart';
import '../bilesenler/ortak.dart';
import '../cekirdek/api.dart';
import '../cekirdek/oturum.dart';
import '../cekirdek/takvim_model.dart';
import '../cekirdek/tema.dart';
import 'derslerim.dart';

/// Panelin renkli üst bandı: avatar, ad, unvan (web: .bant.profil).
class PanelBandi extends StatelessWidget {
  const PanelBandi({super.key, required this.ben, required this.menu, required this.api});

  final Ben ben;
  final Widget menu;
  final Api api;

  String get _basHarfler => ben.ad.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).take(2).map((e) => e.characters.first).join().toUpperCase();

  @override
  Widget build(BuildContext context) {
    final renk = ben.renk ?? Renk.bant;
    final ust = MediaQuery.paddingOf(context).top;
    return Container(
      height: 168 + ust,
      decoration: BoxDecoration(
        color: renk,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(34)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(34)),
        child: CustomPaint(
          painter: _Daireler(),
          child: Stack(
            children: [
              Positioned(right: 10, top: ust + 6, child: menu),
              Positioned(
                left: 20,
                right: 18,
                top: ust + 44,
                child: Row(
                  children: [
                    Container(
                      width: 86,
                      height: 86,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: .16),
                        border: Border.all(color: Colors.white.withValues(alpha: .45), width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: ben.foto != null && ben.foto!.isNotEmpty
                          ? Image.network(
                              '${Api.taban}${ben.foto}',
                              headers: api.kimlik,
                              width: 86,
                              height: 86,
                              fit: BoxFit.cover,
                              alignment: const Alignment(0, -.64),
                              errorBuilder: (_, _, _) => _harf(),
                            )
                          : _harf(),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ben.ad,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: serif.copyWith(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [ben.unvan, if (ben.unvan.isEmpty) ben.sube].where((e) => e.isNotEmpty).join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white.withValues(alpha: .9), fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _harf() => Text(
    _basHarfler,
    style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700),
  );
}

class _Daireler extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(Offset(size.width * .94, -size.height * .05), 120, Paint()..color = Colors.white.withValues(alpha: .09));
    canvas.drawCircle(Offset(0, size.height), 85, Paint()..color = Colors.white.withValues(alpha: .06));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Öğretmen paneli: bugünkü en yakın ders ve bekleyen işler (web: #bugun-dersler, #bekleyenler).
class OgretmenOzeti extends StatefulWidget {
  const OgretmenOzeti({super.key, required this.api});

  final Api api;

  @override
  State<OgretmenOzeti> createState() => _OgretmenOzetiState();
}

class _OgretmenOzetiState extends State<OgretmenOzeti> {
  Map<String, dynamic>? _liste;
  final List<Widget> _bekleyenler = [];

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<dynamic> _al(String yol) async {
    try {
      return await widget.api.get(yol);
    } on ApiHata {
      return null;
    }
  }

  Future<void> _yukle() async {
    final s = await Future.wait([
      _al('/api/ders/liste'),
      _al('/api/ders/gecikenler'),
      _al('/api/mufredat/takip'),
      _al('/api/gelisim/bekleyen'),
      _al('/api/zumre/hatirlatma'),
    ]);
    if (!mounted) return;
    final liste = s[0] as Map<String, dynamic>?;
    final geciken = s[1] as Map<String, dynamic>?;
    final satirlar = <Widget>[];

    if (geciken != null && geciken.n('sayi') > 0) {
      satirlar.add(
        _BekleyenSatiri(
          ikon: 'ders',
          renk: const Color(0xFFEF4444),
          baslik: 'Tamamlanmamış ders',
          alt: 'Dersi bitirmeyi unuttuklarınız',
          sayi: '${geciken.n('sayi')}',
          detay: [
            for (final d in geciken.l('dersler'))
              _DetaySatiri('${_kisa(d.s('tarih'))} · ${d.n('dersSaati')}. ders · ${d['kulupId'] != null ? 'Kulüp · ' : ''}${d.s('sinif')}', () {
                if (d['kulupId'] != null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kulüp derslerini Kulüp bölümünden tamamlayın.')));
                  return;
                }
                Navigator.of(context)
                    .push(
                      MaterialPageRoute(
                        builder: (_) => DersBitirEkrani(api: widget.api, ders: d, tarih: d.s('tarih')),
                      ),
                    )
                    .then((_) => _yukle());
              }),
          ],
        ),
      );
    }

    final takip = s[2] as Map<String, dynamic>?;
    if (takip != null) {
      final kartlar = [
        for (final x in takip.l('siniflar')) (x, [for (final u in x.l('atlananUniteler')) ...u.l('eksik')]),
      ].where((e) => e.$2.isNotEmpty).toList();
      if (kartlar.isNotEmpty) {
        satirlar.add(
          _BekleyenSatiri(
            ikon: 'kazanim',
            renk: const Color(0xFFF59E0B),
            baslik: 'Atlanmış kazanım',
            alt: 'Sonraki üniteye geçildi, işlenmedi',
            sayi: '${kartlar.fold<int>(0, (t, e) => t + e.$2.length)}',
            detay: [for (final (x, eksik) in kartlar) _KazanimKarti('${x.s('sinif')} · ${x.s('ders')}', eksik)],
          ),
        );
      }
    }

    final gel = s[3] as Map<String, dynamic>?;
    if (gel != null) {
      int topla(String durum) => gel.l('donemler').where((d) => d.s('durum') == durum).fold(0, (t, d) => t + d.n('eksik'));
      final acik = topla('acik');
      final gecmis = topla('kapandi');
      if (acik + gecmis > 0) {
        satirlar.add(
          _BekleyenSatiri(
            ikon: 'gelisim-ogretmen',
            renk: const Color(0xFF22C55E),
            baslik: 'Gelişim gözlemi yazılmamış',
            alt: [if (acik > 0) '$acik bu dönem', if (gecmis > 0) '$gecmis geçmiş dönem'].join(' · '),
            sayi: '${acik + gecmis}',
          ),
        );
      }
    }

    final z = s[4] as Map<String, dynamic>?;
    if (z != null) {
      for (final t in z.l('toplantilar').reversed) {
        final kalan = t.n('kalanGun');
        satirlar.insert(
          0,
          _BekleyenSatiri(
            ikon: 'zumrem',
            renk: const Color(0xFFD946EF),
            baslik: t.s('baslik'),
            alt: [t['baskanlar'] == true ? t.s('zumre') : '${t.s('zumre')} zümresi', t.s('saat'), t.s('yer')].where((e) => e.isNotEmpty).join(' · '),
            sayi: kalan == 0 ? 'Bugün' : (kalan == 1 ? 'Yarın' : '$kalan gün sonra'),
          ),
        );
      }
    }

    setState(() {
      _liste = liste;
      _bekleyenler
        ..clear()
        ..addAll(satirlar);
    });
  }

  static String _kisa(String t) => t.split('-').reversed.take(2).join('.');

  @override
  Widget build(BuildContext context) {
    final liste = _liste;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (liste != null) _siradaki(context, liste),
        if (_bekleyenler.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: context.kart,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: context.ince),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                for (final (i, w) in _bekleyenler.indexed) ...[if (i > 0) Divider(height: 1, color: context.ince), w],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _siradaki(BuildContext context, Map<String, dynamic> liste) {
    if (liste['hafta_sonu'] == true) {
      return Text(
        liste.s('tatil').isNotEmpty ? '${liste.s('tatil')} · okul tatil' : 'Bugün ders günü değil.',
        textAlign: TextAlign.center,
        style: TextStyle(color: context.soluk),
      );
    }
    final dersler = liste.l('gunluk');
    if (dersler.isEmpty) {
      return Text(
        'Bugün dersiniz yok.',
        textAlign: TextAlign.center,
        style: TextStyle(color: context.soluk),
      );
    }
    final simdi = '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}';
    final i = dersler.indexWhere((d) => d.s('aralik').split('–').last.compareTo(simdi) >= 0);
    final bitti = i < 0;
    final d = dersler[bitti ? dersler.length - 1 : i];
    final renk = rengiCoz(d['renk'] as String?) ?? const Color(0xFF475569);
    final isaret = const {'tamam': '✓', 'gecikti': '!', 'iptal': 'İptal'}[d.s('durum')];
    return Material(
      color: Color.alphaBlend(renk.withValues(alpha: .09), context.kart),
      borderRadius: BorderRadius.circular(22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: renk.withValues(alpha: .22)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DerslerimEkrani(api: widget.api))).then((_) => _yukle()),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    bitti ? 'Bugünkü son dersiniz' : 'Sıradaki dersim',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: (context.koyu
                          ? Color.alphaBlend(Colors.white.withValues(alpha: .55), renk)
                          : Color.alphaBlend(Colors.black.withValues(alpha: .3), renk)),
                    ),
                  ),
                  Text(
                    'bugün ${dersler.length} ders',
                    style: TextStyle(
                      fontSize: 12.5,
                      color:
                          (context.koyu
                                  ? Color.alphaBlend(Colors.white.withValues(alpha: .55), renk)
                                  : Color.alphaBlend(Colors.black.withValues(alpha: .3), renk))
                              .withValues(alpha: .75),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    constraints: const BoxConstraints(minWidth: 66),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(color: renk, borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        Text(
                          d.s('aralik').split('–').first,
                          style: serif.copyWith(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600, height: 1.1),
                        ),
                        Text('${d.n('dersSaati')}. ders', style: const TextStyle(color: Colors.white, fontSize: 11.5)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.s('sinif'),
                          style: serif.copyWith(fontSize: 20, fontWeight: FontWeight.w600, color: context.yazi),
                        ),
                        Text(d['kulupId'] != null ? 'Kulüp dersi' : d.s('ders'), style: TextStyle(color: context.soluk, fontSize: 14)),
                      ],
                    ),
                  ),
                  if (isaret != null)
                    Text(
                      isaret,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: d.s('durum') == 'tamam' ? const Color(0xFF2E9E5B) : const Color(0xFFD64545),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetaySatiri {
  const _DetaySatiri(this.metin, this.ac);

  final String metin;
  final VoidCallback ac;
}

class _KazanimKarti extends StatelessWidget {
  const _KazanimKarti(this.baslik, this.eksik);

  final String baslik;
  final List<Map<String, dynamic>> eksik;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: context.icZemin, borderRadius: BorderRadius.circular(14)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(baslik, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            Text('${eksik.length} kazanım', style: TextStyle(color: context.soluk, fontSize: 12.5)),
          ],
        ),
        for (final k in eksik)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: k.s('kod'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: ' ${k.s('metin')}'),
                ],
              ),
              style: const TextStyle(fontSize: 13.5, height: 1.35),
            ),
          ),
      ],
    ),
  );
}

class _BekleyenSatiri extends StatelessWidget {
  const _BekleyenSatiri({required this.ikon, required this.renk, required this.baslik, required this.alt, required this.sayi, this.detay = const []});

  final String ikon;
  final Color renk;
  final String baslik;
  final String alt;
  final String sayi;
  final List<Object> detay;

  @override
  Widget build(BuildContext context) {
    final ust = Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: renk, borderRadius: BorderRadius.circular(11)),
          alignment: Alignment.center,
          child: CizgiIkon(ikon, boyut: 21, renk: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(baslik, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500)),
              if (alt.isNotEmpty) Text(alt, style: TextStyle(color: context.soluk, fontSize: 12.5)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(color: renk, borderRadius: BorderRadius.circular(6)),
          child: Text(
            sayi,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5),
          ),
        ),
        const SizedBox(width: 6),
        Icon(Icons.chevron_right, size: 20, color: context.soluk),
      ],
    );
    if (detay.isEmpty) return Padding(padding: const EdgeInsets.symmetric(vertical: 11), child: ust);
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 10),
        shape: const Border(),
        collapsedShape: const Border(),
        title: ust,
        trailing: const SizedBox.shrink(),
        children: [
          for (final x in detay)
            if (x is _DetaySatiri)
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.only(left: 50),
                title: Text(x.metin, style: const TextStyle(fontSize: 14)),
                onTap: x.ac,
              )
            else
              x as Widget,
        ],
      ),
    );
  }
}

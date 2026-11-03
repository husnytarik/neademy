import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../cekirdek/tema.dart';

/// Yoklama durumu: kod, etiket, simge ve renk (web'deki yoklama hapı ve pasta menüsüyle aynı).
typedef YoklamaDurumu = (String kod, String ad, String simge, Color renk);

const yoklamaDurumlari = <YoklamaDurumu>[
  ('geldi', 'Geldi', '✓', Color(0xFF2E9E5B)),
  ('gelmedi', 'Gelmedi', '✗', Color(0xFFD64545)),
  ('gec', 'Geç', 'G', Color(0xFFE0A100)),
  ('izinli', 'İzinli', 'İ', Color(0xFF8A867D)),
];

YoklamaDurumu yoklamaDurumu(String kod) => yoklamaDurumlari.firstWhere((d) => d.$1 == kod, orElse: () => yoklamaDurumlari.first);

/// Orantılı yığın çubuk ve altında renkli noktalı sayılar.
class YoklamaOzeti extends StatelessWidget {
  const YoklamaOzeti({super.key, required this.sayilar});

  final Map<String, int> sayilar;

  @override
  Widget build(BuildContext context) {
    final toplam = sayilar.values.fold<int>(0, (a, b) => a + b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (toplam == 0)
          Container(
            height: 12,
            decoration: BoxDecoration(color: context.icZemin, borderRadius: BorderRadius.circular(99)),
          )
        else
          SizedBox(
            height: 12,
            child: Row(
              children: [
                for (final d in yoklamaDurumlari)
                  if ((sayilar[d.$1] ?? 0) > 0)
                    Expanded(
                      flex: sayilar[d.$1]!,
                      child: Container(
                        margin: EdgeInsets.only(right: d == yoklamaDurumlari.last ? 0 : 3),
                        decoration: BoxDecoration(color: d.$4, borderRadius: BorderRadius.circular(99)),
                      ),
                    ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            for (final d in yoklamaDurumlari)
              if ((sayilar[d.$1] ?? 0) > 0 || d.$1 == 'geldi')
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(color: d.$4, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text('${sayilar[d.$1] ?? 0}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    Text(' ${d.$1 == 'gec' ? 'geç' : d.$1}', style: TextStyle(fontSize: 13, color: context.soluk)),
                  ],
                ),
          ],
        ),
      ],
    );
  }
}

/// "✓ Hepsini geldi yap" yumuşak düğmesi.
class TopluGeldiDugmesi extends StatelessWidget {
  const TopluGeldiDugmesi({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Material(
      color: context.icZemin,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 7, 16, 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: Color(0xFF2E9E5B), shape: BoxShape.circle),
                child: const Text(
                  '✓',
                  style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              const Text('Hepsini geldi yap', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Öğrenci hapı: adı ve sağda durum simgesi; dokununca pasta menü açılır.
class YoklamaHapi extends StatelessWidget {
  const YoklamaHapi({super.key, required this.ad, required this.durum, required this.degisti, this.secenekler, this.alt, this.altRenk});

  final String ad;
  final String durum;
  final ValueChanged<String> degisti;

  /// Halka menüde gösterilecek durum kodları (boşsa dördü de).
  final Set<String>? secenekler;

  /// Adın altındaki küçük etiket (etütte velinin yanıtı gibi).
  final String? alt;
  final Color? altRenk;

  @override
  Widget build(BuildContext context) {
    final d = yoklamaDurumu(durum);
    final zemin = Theme.of(context).colorScheme.surface;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () async {
        final kutu = context.findRenderObject() as RenderBox;
        final alan = kutu.localToGlobal(Offset.zero) & kutu.size;
        final secilen = await pastaAc(context, alan, ad, durum, secenekler: secenekler);
        if (secilen != null) degisti(secilen);
      },
      child: Container(
        height: alt == null ? 40 : 48,
        padding: const EdgeInsets.fromLTRB(12, 0, 5, 0),
        decoration: BoxDecoration(
          color: Color.alphaBlend(d.$4.withValues(alpha: .12), zemin),
          border: Border.all(color: Color.alphaBlend(d.$4.withValues(alpha: .35), zemin)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Expanded(
              child: alt == null
                  ? Text(ad, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, height: 1.15))
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ad, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, height: 1.15)),
                        Text(
                          alt!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10.5, height: 1.2, color: altRenk ?? context.soluk),
                        ),
                      ],
                    ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: d.$4, shape: BoxShape.circle),
              child: Text(
                d.$3,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Öğrenci hapı ızgarası: iki sütun.
class YoklamaIzgarasi extends StatelessWidget {
  const YoklamaIzgarasi({super.key, required this.cocuklar});

  final List<Widget> cocuklar;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final w = (c.maxWidth - 8) / 2;
      return Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [for (final x in cocuklar) SizedBox(width: w, child: x)],
      );
    },
  );
}

const _yon = {'geldi': Offset(0, -1), 'izinli': Offset(1, 0), 'gelmedi': Offset(0, 1), 'gec': Offset(-1, 0)};
const _ic = 40.0;
const _dis = 104.0;

/// Hedefin çevresinde dört dilimli halka menü açar; seçilen durum kodunu döndürür.
Future<String?> pastaAc(BuildContext context, Rect hedef, String ad, String mevcut, {Set<String>? secenekler}) => showGeneralDialog<String>(
  context: context,
  barrierDismissible: true,
  barrierLabel: 'Kapat',
  barrierColor: Theme.of(context).colorScheme.surface.withValues(alpha: .72),
  transitionDuration: const Duration(milliseconds: 160),
  transitionBuilder: (_, a, _, child) => FadeTransition(
    opacity: a,
    child: ScaleTransition(scale: Tween(begin: .75, end: 1.0).animate(a), child: child),
  ),
  pageBuilder: (ctx, _, _) {
    final boyut = MediaQuery.sizeOf(ctx);
    const pay = _dis + 8;
    final cx = hedef.center.dx.clamp(pay, math.max(pay, boyut.width - pay));
    final cy = hedef.center.dy.clamp(pay, math.max(pay, boyut.height - pay));
    return Stack(
      children: [
        Positioned(
          left: cx - pay,
          top: cy - pay,
          width: 2 * pay,
          height: 2 * pay,
          child: _Pasta(ad: ad, mevcut: mevcut, secenekler: secenekler),
        ),
      ],
    );
  },
);

class _Pasta extends StatelessWidget {
  const _Pasta({required this.ad, required this.mevcut, this.secenekler});

  final String ad;
  final String mevcut;
  final Set<String>? secenekler;

  String? _dilim(Offset p) {
    final r = p.distance;
    if (r < _ic - 4 || r > _dis + 14) return null;
    String? en;
    var enDeger = -2.0;
    for (final e in _yon.entries) {
      if (secenekler != null && !secenekler!.contains(e.key)) continue;
      final k = (p.dx * e.value.dx + p.dy * e.value.dy) / r;
      if (k > enDeger) {
        enDeger = k;
        en = e.key;
      }
    }
    return en;
  }

  @override
  Widget build(BuildContext context) {
    const pay = _dis + 8;
    final murekkep = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (t) {
        final s = _dilim(t.localPosition - const Offset(pay, pay));
        if (s != null) Navigator.pop(context, s);
      },
      child: CustomPaint(
        painter: _PastaCizici(mevcut, Theme.of(context).colorScheme.surface, murekkep, secenekler),
        child: Center(
          child: SizedBox(
            width: 70,
            child: Text(
              ad,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.15, color: murekkep, decoration: TextDecoration.none),
            ),
          ),
        ),
      ),
    );
  }
}

class _PastaCizici extends CustomPainter {
  _PastaCizici(this.mevcut, this.zemin, this.murekkep, this.secenekler);

  final Set<String>? secenekler;
  final String mevcut;
  final Color zemin;
  final Color murekkep;

  Path _yol(double a0, double a1) {
    Offset n(double r, double a) => Offset(r * math.cos(a), r * math.sin(a));
    return Path()
      ..moveTo(n(_dis, a0).dx, n(_dis, a0).dy)
      ..arcTo(Rect.fromCircle(center: Offset.zero, radius: _dis), a0, a1 - a0, false)
      ..lineTo(n(_ic, a1).dx, n(_ic, a1).dy)
      ..arcTo(Rect.fromCircle(center: Offset.zero, radius: _ic), a1, a0 - a1, false)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);
    const bosluk = 0.035;
    for (final d in yoklamaDurumlari) {
      if (secenekler != null && !secenekler!.contains(d.$1)) continue;
      final y = _yon[d.$1]!;
      final orta = math.atan2(y.dy, y.dx);
      final yol = _yol(orta - math.pi / 4 + bosluk, orta + math.pi / 4 - bosluk);
      final secili = d.$1 == mevcut;
      canvas.drawPath(yol, Paint()..color = d.$4.withValues(alpha: secili ? 1 : .88));
      canvas.drawPath(
        yol,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = secili ? 2.5 : 2
          ..color = secili ? murekkep : zemin,
      );
      final m = (_ic + _dis) / 2;
      _yaz(canvas, d.$3, Offset(m * y.dx, m * y.dy - 3), 22);
      _yaz(canvas, d.$2, Offset(m * y.dx, m * y.dy + 14), 10.5);
    }
  }

  void _yaz(Canvas canvas, String metin, Offset orta, double punto) {
    final tp = TextPainter(
      text: TextSpan(
        text: metin,
        style: TextStyle(color: Colors.white, fontSize: punto, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, orta - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_PastaCizici o) => o.mevcut != mevcut || o.zemin != zemin;
}

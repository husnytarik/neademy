import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

/// Web arayüzündeki çizgi ikonlar (public/panel.js IKON_YOL) — aynı SVG yolları.
const _yollar = <String, String>{
  'etut': 'M12 7v5l3 2M21 12a9 9 0 11-18 0 9 9 0 0118 0z',
  'derslerim': 'M4 5h16v14H4zM4 10h16M9 5v14',
  'takvimim': 'M4 6h16v14H4zM4 10h16M8 3v4M16 3v4M8 14h2M14 14h2M8 17.5h2',
  'not-girisi': 'M6 3h9l4 4v14H6zM14 3v5h5M9 13h7M9 17h5',
  'ogrenci-yonetim': 'M9 11a3 3 0 100-6 3 3 0 000 6zM3 20c.5-3.5 3-5 6-5s5.5 1.5 6 5M17 8v6M14 11h6',
  'ogrencilerim': 'M9 11a3 3 0 100-6 3 3 0 000 6zM3 20c.5-3.5 3-5 6-5s5.5 1.5 6 5M17 11a2.5 2.5 0 100-5M18 15c2 .4 3.2 1.8 3.5 5',
  'veli-bilgilendirme': 'M4 5h16v11H9l-5 4zM8 9h8M8 12h5',
  'kullanici-rol': 'M12 12a4 4 0 100-8 4 4 0 000 8zM4 21c.8-4.2 4-6 8-6s7.2 1.8 8 6',
  'okul-kurulum': 'M3 21V8l9-5 9 5v13M9 21v-6h6v6M3 21h18',
  'kampusler': 'M3 21V9l5-3 5 3v12M13 21V4l8 4v13M7 12h2M7 16h2M16 11h2M16 15h2',
  'kurum': 'M4 21V6l8-3 8 3v15M9 21v-5h6v5M8 9h2M14 9h2M8 12.5h2M14 12.5h2',
  'okul-takvimi': 'M12 21a9 9 0 100-18 9 9 0 000 18zM12 7v5l3.5 2',
  'ders-programi-yonetimi': 'M4 6h16v14H4zM4 10h16M8 3v4M16 3v4',
  'ders-programi': 'M4 6h16v14H4zM4 10h16M8 3v4M16 3v4',
  'duyuru': 'M4 10v4h3l7 4V6L7 10zM17 9a4 4 0 010 6',
  'duyurular': 'M4 10v4h3l7 4V6L7 10zM17 9a4 4 0 010 6',
  'rapor': 'M5 20V10M12 20V4M19 20v-7',
  'notlarim': 'M5 20V10M12 20V4M19 20v-7',
  'odev-takip': 'M6 3h12v18H6zM9 8h6M9 12h6M9 16h3',
  'odev-takip-ogretmen': 'M6 3h12v18H6zM9 8h6M9 13l2 2 4-4',
  'ogrencim': 'M2 9l10-5 10 5-10 5zM6 11.5V16c0 1.4 2.7 3 6 3s6-1.6 6-3v-4.5',
  'devamsizlik-veli': 'M9 12l2 2 4-4M12 21a9 9 0 100-18 9 9 0 000 18z',
  'devamsizlik-ogrenci': 'M9 12l2 2 4-4M12 21a9 9 0 100-18 9 9 0 000 18z',
  'teslim': 'M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z',
  'baskan-toplanti': 'M9 11a3 3 0 100-6 3 3 0 000 6zM3 20c.5-3.5 3-5 6-5s5.5 1.5 6 5M17 11a2.5 2.5 0 100-5M18 15c2 .4 3.2 1.8 3.5 5',
  'zumrem': 'M9 11a3 3 0 100-6 3 3 0 000 6zM3 20c.5-3.5 3-5 6-5s5.5 1.5 6 5M17 11a2.5 2.5 0 100-5M18 15c2 .4 3.2 1.8 3.5 5',
  'sinav-yonetim': 'M6 3h9l4 4v14H6zM14 3v5h5M9 13h7M9 17h5',
  'duyurular-ogretmen': 'M4 10v4h3l7 4V6L7 10zM17 9a4 4 0 010 6',
  'kulup-yonetimi': 'M12 3l2.4 5.2 5.6.7-4.1 3.9 1.1 5.6L12 15.6 7 18.4l1.1-5.6L4 8.9l5.6-.7z',
  'kulup-ogretmen': 'M12 3l2.4 5.2 5.6.7-4.1 3.9 1.1 5.6L12 15.6 7 18.4l1.1-5.6L4 8.9l5.6-.7z',
  'kulup-ogrenci': 'M12 3l2.4 5.2 5.6.7-4.1 3.9 1.1 5.6L12 15.6 7 18.4l1.1-5.6L4 8.9l5.6-.7z',
  'gelisim-yonetim': 'M3 17l6-6 4 4 8-8M15 7h6v6',
  'gelisim-ogretmen': 'M3 17l6-6 4 4 8-8M15 7h6v6',
  'etut-ogrenci': 'M12 7v5l3 2M21 12a9 9 0 11-18 0 9 9 0 0118 0z',
  'etut-veli': 'M12 7v5l3 2M21 12a9 9 0 11-18 0 9 9 0 0118 0z',
  // panel özet satırları
  'ders': 'M12 8v5M12 16.5v.01M10.3 3.9L2.4 18a2 2 0 001.7 3h15.8a2 2 0 001.7-3L13.7 3.9a2 2 0 00-3.4 0z',
  'kazanim': 'M4 12a8 8 0 018-8 8 8 0 015.7 2.3L20 8.5M20 4v4.5h-4.5M20 12a8 8 0 01-8 8 8 8 0 01-5.7-2.3L4 15.5M4 20v-4.5h4.5',
};

const _varsayilan = 'M12 3l2.5 6 6.5.5-5 4.2 1.7 6.3L12 16.8 6.3 20l1.7-6.3-5-4.2L9.5 9z';

/// Modül (ya da özet satırı) kimliğine göre çizgi ikon.
class CizgiIkon extends StatelessWidget {
  const CizgiIkon(this.kimlik, {super.key, this.boyut = 24, this.renk});

  final String kimlik;
  final double boyut;
  final Color? renk;

  @override
  Widget build(BuildContext context) {
    final yol = parseSvgPathData(_yollar[kimlik] ?? _varsayilan);
    return CustomPaint(size: Size.square(boyut), painter: _IkonBoyayici(yol, renk ?? IconTheme.of(context).color ?? Colors.black));
  }
}

class _IkonBoyayici extends CustomPainter {
  _IkonBoyayici(this.yol, this.renk);

  final Path yol;
  final Color renk;

  @override
  void paint(Canvas canvas, Size size) {
    final olcek = size.width / 24;
    canvas.save();
    canvas.scale(olcek);
    canvas.drawPath(
      yol,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = renk,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_IkonBoyayici o) => o.renk != renk || o.yol != yol;
}

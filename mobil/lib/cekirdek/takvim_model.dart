import 'package:flutter/material.dart';

const gunAdlari = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
const kisaGunAdlari = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
const ayAdlari = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];

/// Takvimde gösterilen öğe türleri: görünen ad ve renk (web ile aynı).
class TurBilgi {
  const TurBilgi(this.ad, this.renk);
  final String ad;
  final Color renk;
}

const turler = <String, TurBilgi>{
  'ders': TurBilgi('Ders', Color(0xFF1F6FEB)),
  'nobet': TurBilgi('Nöbet', Color(0xFFD97706)),
  'gorev': TurBilgi('Görevlendirme', Color(0xFF7C3AED)),
  'etut': TurBilgi('Etüt', Color(0xFF059669)),
  'toplanti': TurBilgi('Toplantı', Color(0xFFDB2777)),
  'odev': TurBilgi('Ödev', Color(0xFF06B6D4)),
  'sinav': TurBilgi('Sınav', Color(0xFFDC2626)),
  'kulup': TurBilgi('Kulüp çalışması', Color(0xFFA16207)),
  'rapor': TurBilgi('Gelişim raporu', Color(0xFF4F46E5)),
  'veli': TurBilgi('Veli toplantısı', Color(0xFFC026D3)),
  'gorusme': TurBilgi('Veli görüşmesi', Color(0xFF64748B)),
  'dogum': TurBilgi('Doğum günü', Color(0xFF65A30D)),
};

const durumAdlari = {'tamam': 'İşlendi', 'iptal': 'İptal'};

Color? rengiCoz(String? hex) {
  if (hex == null || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
  return Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));
}

class TakvimOgesi {
  TakvimOgesi({required this.tur, required this.bas, required this.bit, required this.baslik, required this.alt, this.renk, this.kisa, this.durum});

  factory TakvimOgesi.json(Map<String, dynamic> j) => TakvimOgesi(
        tur: j['tur'] as String? ?? '',
        bas: j['bas'] as String? ?? '',
        bit: j['bit'] as String? ?? '',
        baslik: j['baslik'] as String? ?? '',
        alt: j['alt'] as String? ?? '',
        renk: rengiCoz(j['renk'] as String?),
        kisa: j['kisa'] as String?,
        durum: j['durum'] as String?,
      );

  final String tur;
  final String bas;
  final String bit;
  final String baslik;
  final String alt;
  final Color? renk;
  final String? kisa;
  final String? durum;

  /// Çizgi/nokta rengi: derslerde dersin kendi rengi, diğerlerinde türün rengi.
  Color get cizgiRengi => renk ?? turler[tur]?.renk ?? const Color(0xFF475569);
}

class TakvimGunu {
  TakvimGunu({required this.tarih, required this.acik, required this.tatil, required this.ogeler});

  factory TakvimGunu.json(Map<String, dynamic> j) => TakvimGunu(
        tarih: j['tarih'] as String,
        acik: j['acik'] == true,
        tatil: j['tatil'] as String?,
        ogeler: [for (final o in (j['ogeler'] as List? ?? const [])) TakvimOgesi.json(o as Map<String, dynamic>)],
      );

  final String tarih;
  final bool acik;
  final String? tatil;
  final List<TakvimOgesi> ogeler;
}

class TakvimAyi {
  TakvimAyi({required this.ay, required this.bugun, required this.gunler}) : harita = {for (final g in gunler) g.tarih: g};

  factory TakvimAyi.json(Map<String, dynamic> j) => TakvimAyi(
        ay: j['ay'] as String,
        bugun: j['bugun'] as String,
        gunler: [for (final g in (j['gunler'] as List)) TakvimGunu.json(g as Map<String, dynamic>)],
      );

  final String ay;
  final String bugun;
  final List<TakvimGunu> gunler;
  final Map<String, TakvimGunu> harita;

  /// Bu ay/haftada görünen türler (renk açıklaması için), [turler] sırasıyla.
  List<String> gorunenTurler([Iterable<TakvimGunu>? kaynak]) {
    final var_ = {for (final g in kaynak ?? gunler) for (final o in g.ogeler) o.tur};
    return [for (final t in turler.keys) if (var_.contains(t)) t];
  }
}

// ---- Tarih yardımcıları ("YYYY-MM-DD" metinleri üzerinden, saat dilimi karışmasın diye UTC)

DateTime tarihCoz(String t) => DateTime.utc(int.parse(t.substring(0, 4)), int.parse(t.substring(5, 7)), int.parse(t.substring(8, 10)));

String tarihYaz(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String gunKaydir(String t, int n) => tarihYaz(tarihCoz(t).add(Duration(days: n)));

/// Haftanın pazartesisi.
String pazartesi(String t) => gunKaydir(t, -(tarihCoz(t).weekday - 1));

/// Ay kaydır; gün ayın son gününü aşarsa son güne çekilir (31 Ocak + 1 ay = 28/29 Şubat).
String ayKaydir(String t, int n) {
  final d = tarihCoz(t);
  final ilk = DateTime.utc(d.year, d.month + n, 1);
  final sonGun = DateTime.utc(ilk.year, ilk.month + 1, 0).day;
  return tarihYaz(DateTime.utc(ilk.year, ilk.month, d.day > sonGun ? sonGun : d.day));
}

String uzunTarih(String t) {
  final d = tarihCoz(t);
  return '${d.day} ${ayAdlari[d.month - 1]} ${gunAdlari[d.weekday - 1]}';
}

String kisaTarih(String t) {
  final d = tarihCoz(t);
  return '${d.day} ${ayAdlari[d.month - 1].substring(0, 3)}';
}

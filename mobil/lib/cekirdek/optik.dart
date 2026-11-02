/// Optik okuyucu çıktısı: her satır bir öğrenci (okul no + derslerin cevapları).
/// CSV: `okul_no;ders1;ders2…` (tek cevap sütunu da olur) · Sabit genişlik: ilk N karakter okul no, sonrası cevaplar.
class OptikKayit {
  const OptikKayit({required this.satir, required this.no, required this.cevap, this.uyari = ''});

  final int satir;
  final String no;
  final List<String> cevap;
  final String uyari;
}

String noSade(String s) => s.trim().replaceFirst(RegExp(r'^0+(?=\d)'), '');

/// Okuyucunun boş işareti ("*", boşluk) `-` olur; harfler büyütülür.
String cevapTemizle(String s) => s.replaceAll(RegExp(r'[*\s]'), '-').toUpperCase();

List<String> _dersBol(String metin, List<int> soruSayilari) {
  var konum = 0;
  final out = <String>[];
  for (final n in soruSayilari) {
    final bas = konum.clamp(0, metin.length);
    final son = (konum + n).clamp(0, metin.length);
    out.add(metin.substring(bas, son));
    konum += n;
  }
  return out;
}

List<OptikKayit> optikCoz(String metin, {required bool csv, required int noUzunluk, required List<int> soruSayilari}) {
  final toplam = soruSayilari.fold<int>(0, (t, n) => t + n);
  final satirlar = metin.replaceFirst('﻿', '').split(RegExp(r'\r?\n')).where((s) => s.trim().isNotEmpty).toList();
  final out = <OptikKayit>[];
  for (var i = 0; i < satirlar.length; i++) {
    final satir = satirlar[i];
    String no;
    List<String> cevap;
    if (csv) {
      final ayrac = [';', '\t', ','].firstWhere(satir.contains, orElse: () => ';');
      final h = satir.split(ayrac).map((x) => x.trim().replaceAll(RegExp(r'^"|"$'), '')).toList();
      if (i == 0 && !RegExp(r'^\d+$').hasMatch(h.first)) {
        continue; // başlık satırı
      }
      no = h.first;
      final c = h.sublist(1);
      cevap = c.length == soruSayilari.length ? c : _dersBol(c.join(), soruSayilari);
    } else {
      no = satir.length < noUzunluk ? satir : satir.substring(0, noUzunluk);
      final kalan = satir.length < noUzunluk ? '' : satir.substring(noUzunluk).replaceFirst(RegExp(r'\s+$'), '');
      cevap = _dersBol(kalan, soruSayilari);
    }
    final uzunluk = cevap.fold<int>(0, (t, c) => t + c.length);
    out.add(OptikKayit(satir: i + 1, no: noSade(no), cevap: cevap, uyari: uzunluk != toplam ? '$uzunluk cevap var, $toplam bekleniyordu' : ''));
  }
  return out;
}

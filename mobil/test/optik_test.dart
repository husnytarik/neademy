import 'package:flutter_test/flutter_test.dart';
import 'package:neademy/cekirdek/optik.dart';

void main() {
  test('CSV: başlık atlanır, başındaki sıfırlar silinir, tek sütun derslere bölünür', () {
    final k = optikCoz('okul_no;Fen;Mat\r\n012;ABC;DE\r\n7;ABCDE\r\n', csv: true, noUzunluk: 10, soruSayilari: [3, 2]);
    expect(k.length, 2);
    expect(k[0].no, '12');
    expect(k[0].cevap, ['ABC', 'DE']);
    expect(k[0].uyari, '');
    expect(k[1].cevap, ['ABC', 'DE']);
  });

  test('sabit genişlik: ilk N karakter okul no; eksik cevap uyarı verir', () {
    final k = optikCoz('0012ABCDE\n0013AB', csv: false, noUzunluk: 4, soruSayilari: [3, 2]);
    expect(k[0].no, '12');
    expect(k[0].cevap, ['ABC', 'DE']);
    expect(k[1].cevap, ['AB', '']);
    expect(k[1].uyari, '2 cevap var, 5 bekleniyordu');
  });

  test('boş işaretler tireye çevrilir', () {
    expect(cevapTemizle('ab*d e'), 'AB-D-E');
  });
}

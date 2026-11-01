import 'package:flutter_test/flutter_test.dart';
import 'package:neademy/cekirdek/api.dart';
import 'package:neademy/cekirdek/takvim_model.dart';

void main() {
  test('sürüm karşılaştırma', () {
    expect(surumKarsilastir('1.0.0', '1.0.0'), 0);
    expect(surumKarsilastir('1.0.0', '1.2.0') < 0, isTrue);
    expect(surumKarsilastir('2.0.0', '1.9.9') > 0, isTrue);
    expect(surumKarsilastir('1.0', '1.0.1') < 0, isTrue);
  });

  test('tarih yardımcıları', () {
    expect(pazartesi('2026-11-01'), '2026-10-26'); // Pazar
    expect(pazartesi('2026-10-26'), '2026-10-26');
    expect(gunKaydir('2026-12-31', 1), '2027-01-01');
    expect(ayKaydir('2026-01-31', 1), '2026-02-28');
    expect(ayKaydir('2026-01-15', -1), '2025-12-15');
    expect(uzunTarih('2026-11-01'), '1 Kasım Pazar');
    expect(kisaTarih('2026-08-03'), '3 Ağu');
  });

  test('takvim ayı ve görünen türler', () {
    final ay = TakvimAyi.json({
      'ay': '2026-11',
      'bugun': '2026-11-01',
      'gunler': [
        {
          'tarih': '2026-11-02',
          'acik': true,
          'tatil': null,
          'ogeler': [
            {'tur': 'sinav', 'bas': '', 'bit': '', 'baslik': 'Yazılı', 'alt': '7A'},
            {'tur': 'ders', 'bas': '09:00', 'bit': '09:40', 'baslik': 'Fen', 'alt': '1. ders', 'renk': '#16a34a', 'kisa': 'FEN'},
          ],
        },
        {'tarih': '2026-11-03', 'acik': false, 'tatil': 'Tatil', 'ogeler': []},
      ],
    });
    expect(ay.gorunenTurler(), ['ders', 'sinav']);
    expect(ay.harita['2026-11-03']!.tatil, 'Tatil');
    expect(ay.harita['2026-11-02']!.ogeler[1].cizgiRengi.toARGB32(), 0xFF16A34A);
    expect(ay.harita['2026-11-02']!.ogeler[0].cizgiRengi, turler['sinav']!.renk);
  });
}

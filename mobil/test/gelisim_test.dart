import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neademy/cekirdek/api.dart';
import 'package:neademy/ekranlar/gelisim_ogretmen.dart';

Api _api(Map<String, Object> yanitlar) => Api(
  istemci: MockClient((istek) async {
    return http.Response.bytes(utf8.encode(jsonEncode(yanitlar[istek.url.path] ?? {})), 200, headers: {'content-type': 'application/json'});
  }),
);

void main() {
  final donem = {'id': 1, 'ad': '1. Dönem (Eylül–Ocak)', 'baslangic': '2026-09-15', 'bitis': '2026-12-20', 'toplantiTarihi': '', 'durum': 'acik'};
  final ogretmen = {
    'bugun': '2026-11-02',
    'donemler': [donem],
    'donemId': 1,
    'basliklar': [
      {'id': 1, 'ad': 'Akademik', 'aciklama': ''},
      {'id': 2, 'ad': 'Sosyal', 'aciklama': ''},
    ],
    'siniflar': [
      {
        'id': 3,
        'ad': '6-A',
        'dersler': 'Fen',
        'ogrenciler': [
          {'id': 10, 'ad': 'Deneme Öğrenci', 'okulNo': '12', 'girilen': 1},
        ],
      },
    ],
  };

  testWidgets('gelişim öğretmen: dönem, sınıf ve öğrenci durumunu gösterir', (t) async {
    await t.pumpWidget(MaterialApp(home: GelisimOgretmenEkrani(api: _api({'/api/gelisim/ogretmen': ogretmen}))));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('1. Dönem'), findsWidgets);
    expect(find.text('6-A'), findsOneWidget);
    expect(find.text('Deneme Öğrenci'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
  });

  testWidgets('gelişim öğrenci: gözlem ve görüşmeleri gösterir', (t) async {
    final rapor = {
      'bugun': '2026-11-02',
      'basliklar': [
        {'id': 1, 'ad': 'Akademik', 'aciklama': ''},
      ],
      'donemler': [
        {
          ...donem,
          'girisler': [
            {'baslikId': 1, 'metin': 'Derse istekli'},
          ],
          'gorusmeler': [
            {
              'id': 4,
              'donemId': 1,
              'tur': 'gorusme',
              'tarih': '2026-10-20',
              'notu': 'Veliyle konuşuldu',
              'yazan': 'Ben',
              'benim': true,
              'duzenlenebilir': true,
            },
          ],
        },
      ],
      'donemsizGorusmeler': <Object>[],
    };
    await t.pumpWidget(
      MaterialApp(
        home: GelisimOgrenciEkrani(
          api: _api({'/api/gelisim/rapor': rapor}),
          ogrenci: {'id': 10, 'ad': 'Deneme Öğrenci', 'okulNo': '12'},
          sinifAd: '6-A',
          donemId: 1,
          aktifBasliklar: [
            {'id': 1, 'ad': 'Akademik', 'aciklama': ''},
          ],
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Derse istekli'), findsOneWidget);
    expect(find.text('Düzenle'), findsOneWidget);
    expect(find.text('Veliyle konuşuldu'), findsOneWidget);
  });
}

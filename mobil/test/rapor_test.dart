import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neademy/cekirdek/api.dart';
import 'package:neademy/ekranlar/rapor.dart';

void main() {
  testWidgets('rapor özeti ve okul süzgeci', (t) async {
    final yollar = <String>[];
    final api = Api(
      istemci: MockClient((istek) async {
        yollar.add(istek.url.path + (istek.url.hasQuery ? '?${istek.url.query}' : ''));
        final govde = {
          'okullar': [
            {'id': 1, 'ad': 'Deneme Okulu'},
          ],
          'okul': null,
          'ozet': {'ogrenci': 120, 'ogretmen': 14, 'sinif': 8},
          'devam': {
            'yuzde': 88,
            'gelmedi': 12,
            'toplam': 100,
            'siniflar': [
              {'ad': '6-A', 'oran': 9, 'gelmedi': 3, 'toplam': 30},
            ],
          },
          'devamsizlar': [
            {'ad': 'Deniz Örnek', 'sinif': '6-A', 'gelmedi': 4},
          ],
          'eksikDersler': {
            'toplam': 5,
            'oran': 10,
            'ogretmenler': [
              {'ad': 'Ayşe Hoca', 'sayi': 5},
            ],
          },
          'odev': {
            'yuzde': 55,
            'siniflar': [
              {'ad': '6-A', 'oran': 55, 'toplam': 10},
            ],
          },
          'kulupler': [
            {'ad': 'Satranç', 'okul': 'Deneme Okulu', 'uye': 8, 'kontenjan': 10},
          ],
        };
        return http.Response.bytes(utf8.encode(jsonEncode(govde)), 200, headers: {'content-type': 'application/json'});
      }),
    );
    t.view.physicalSize = const Size(390, 3000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(home: RaporEkrani(api: api)));
    await t.pumpAndSettle();
    expect(find.text('120'), findsOneWidget);
    expect(find.text('%88'), findsOneWidget);
    expect(find.text('Deniz Örnek · 6-A'), findsOneWidget);
    expect(find.text('Satranç · Deneme Okulu'), findsOneWidget);
    expect(find.text('8/10'), findsOneWidget);

    await t.tap(find.text('Tüm okullar'));
    await t.pumpAndSettle();
    await t.tap(find.text('Deneme Okulu').last);
    await t.pumpAndSettle();
    expect(yollar.last, '/api/rapor/ozet?okul=1');
  });
}

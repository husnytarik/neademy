import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neademy/cekirdek/api.dart';
import 'package:neademy/ekranlar/baskan_toplanti.dart';

Api _api(Map<String, Object> yanitlar, {List<String>? kayit}) => Api(
  istemci: MockClient((istek) async {
    kayit?.add('${istek.method} ${istek.url.path}');
    return http.Response.bytes(utf8.encode(jsonEncode(yanitlar[istek.url.path] ?? {})), 200, headers: {'content-type': 'application/json'});
  }),
);

final _liste = {
  'yonetim': true,
  'okullar': [
    {'id': 1, 'ad': 'Deneme Ortaokulu', 'tur': 'Ortaokul', 'kampus': 'Merkez'},
    {'id': 2, 'ad': 'Deneme Lisesi', 'tur': 'Lise', 'kampus': 'Merkez'},
  ],
  'varsayilan': [1],
  'toplantilar': [
    {
      'id': 1,
      'okullar': [
        {'id': 1, 'ad': 'Deneme Ortaokulu'},
      ],
      'okulIds': [1],
      'okul': 'Deneme Ortaokulu',
      'baslik': 'Eylül toplantısı',
      'tarih': '2026-09-20',
      'saat': '15:00',
      'yer': 'Salon',
      'gundem': 'Plan',
      'karar': 'Kararlar alındı',
      'kararYazan': 'Ceren Husny',
      'kararZamani': 1790000000000,
      'basladi': true,
      'duzenleyebilir': true,
    },
    {
      'id': 2,
      'okullar': [
        {'id': 1, 'ad': 'Deneme Ortaokulu'},
      ],
      'okulIds': [1],
      'okul': 'Deneme Ortaokulu',
      'baslik': 'Kasım toplantısı',
      'tarih': '2099-11-20',
      'saat': '15:00',
      'yer': '',
      'gundem': '',
      'karar': '',
      'basladi': false,
      'duzenleyebilir': true,
    },
  ],
};

void main() {
  void genis(WidgetTester t) {
    t.view.physicalSize = const Size(390, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  testWidgets('başkanlar toplantısı: yaklaşan/yapılan listeler ve kayıt', (t) async {
    genis(t);
    final kayit = <String>[];
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BaskanToplantiEkrani(api: _api({'/api/zumre/baskanlar/liste': _liste}, kayit: kayit)),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Yaklaşan toplantılar'), findsOneWidget);
    expect(find.text('Yapılan toplantılar'), findsOneWidget);
    expect(find.text('Kararı düzenle'), findsOneWidget);
    expect(find.text('Kararlar alındı'), findsOneWidget);

    await t.tap(find.text('+ Toplantı ekle'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Deneme Lisesi'), findsOneWidget);
    await t.tap(find.text('Toplantıyı ekle'));
    await t.pumpAndSettle();
    expect(kayit, contains('POST /api/zumre/baskanlar/kaydet'));
  });
}

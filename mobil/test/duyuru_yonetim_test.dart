import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neademy/cekirdek/api.dart';
import 'package:neademy/ekranlar/duyuru_yonetim.dart';

Api _api(Map<String, Object> yanitlar, {List<String>? kayit}) => Api(
  istemci: MockClient((istek) async {
    kayit?.add('${istek.method} ${istek.url.path} ${istek.body}');
    return http.Response.bytes(utf8.encode(jsonEncode(yanitlar[istek.url.path] ?? {})), 200, headers: {'content-type': 'application/json'});
  }),
);

void main() {
  void genis(WidgetTester t) {
    t.view.physicalSize = const Size(390, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  final yanitlar = <String, Object>{
    '/api/duyuru/liste': {
      'duyurular': [
        {'id': 1, 'baslik': 'Veli toplantısı', 'metin': 'Cuma 18:00', 'tarih': 1762000000000, 'hedef': 'Tüm okullar · Veliler', 'alici': 10, 'okunan': 4},
      ],
    },
    '/api/duyuru/secenek': {
      'okullar': [
        {'id': 1, 'ad': 'Ortaokul'},
      ],
      'roller': {'hepsi': 'Herkes', 'veli': 'Veliler'},
    },
  };

  testWidgets('yönetim duyuruları okunma sayısıyla listeler', (t) async {
    genis(t);
    await t.pumpWidget(MaterialApp(home: DuyuruYonetimEkrani(api: _api(yanitlar))));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Veli toplantısı'), findsOneWidget);
    expect(find.text('Tüm okullar · Veliler · 4/10 okudu'), findsOneWidget);
  });

  testWidgets('duyuru yaz formu yayınlar', (t) async {
    genis(t);
    final kayit = <String>[];
    await t.pumpWidget(
      MaterialApp(
        home: DuyuruYonetimEkrani(api: _api(yanitlar, kayit: kayit)),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('+ Duyuru yaz'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, 'Tatil');
    await t.enterText(find.byType(TextField).last, 'Yarın okul yok');
    await t.tap(find.text('Yayınla'));
    await t.pumpAndSettle();
    expect(kayit.any((k) => k.startsWith('POST /api/duyuru/ekle') && k.contains('Tatil')), isTrue);
    expect(t.takeException(), isNull);
  });
}

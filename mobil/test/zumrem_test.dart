import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neademy/cekirdek/api.dart';
import 'package:neademy/ekranlar/zumrem.dart';

Api _api(Map<String, Object> yanitlar, {List<String>? kayit}) => Api(
  istemci: MockClient((istek) async {
    kayit?.add('${istek.method} ${istek.url.path}');
    return http.Response.bytes(utf8.encode(jsonEncode(yanitlar[istek.url.path] ?? {})), 200, headers: {'content-type': 'application/json'});
  }),
);

Map<String, Object> _yanitlar({required bool baskan}) => {
  '/api/zumre/benim': {
    'baskan': baskan,
    'zumreler': [
      {'id': 4, 'ad': 'Fen Bilimleri', 'ogretmenSayisi': 2},
    ],
  },
  '/api/zumre/detay': {
    'zumre': {'id': 4, 'ad': 'Fen Bilimleri'},
    'baskan': baskan,
    'ogretmenler': [
      {'id': 1, 'ad': 'Ceren Husny', 'telefon': '', 'baskan': baskan, 'ben': true},
      {'id': 2, 'ad': 'Deneme Öğretmen', 'telefon': '5550000000', 'baskan': !baskan, 'ben': false},
    ],
    'toplantilar': [
      {
        'id': 7,
        'baslik': 'Haftalık zümre',
        'tekrar': 'haftalik',
        'baslangic': '2026-11-02',
        'saat': '15:00',
        'yer': 'Öğretmenler odası',
        'gundem': 'Sınav takvimi',
        'siradaki': ['2026-11-09', '2026-11-16'],
        'bekleyen': '2026-11-02',
      },
    ],
    'kararlar': [
      {
        'id': 3,
        'toplantiId': 7,
        'baslik': 'Haftalık zümre',
        'tarih': '2026-10-26',
        'saat': '15:00',
        'yer': '',
        'karar': 'Ortak sınav yapılacak',
        'yazan': 'Ceren Husny',
        'zaman': 1,
      },
    ],
    'yazilar': [
      {'id': 5, 'metin': 'Laboratuvar cuma açık', 'zaman': 1762000000000, 'yazan': 'Ceren Husny', 'baskan': true, 'benim': true},
    ],
    'tekrarlar': {'haftalik': 'Her hafta', 'yok': 'Tek seferlik'},
  },
  '/api/zumre/baskanlar/liste': {
    'toplantilar': [
      {
        'id': 9,
        'baslik': 'Başkanlar kurulu',
        'tarih': '2026-11-04',
        'saat': '14:00',
        'yer': 'Müdür odası',
        'gundem': 'Dönem planı',
        'karar': '',
        'basladi': true,
      },
    ],
  },
};

void main() {
  void genis(WidgetTester t) {
    t.view.physicalSize = const Size(390, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  testWidgets('zümre başkanı: toplantı, karar ve bitir düğmesi görünür', (t) async {
    genis(t);
    await t.pumpWidget(MaterialApp(home: ZumremEkrani(api: _api(_yanitlar(baskan: true)))));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Fen Bilimleri zümresi'), findsOneWidget);
    expect(find.text('+ Toplantı ekle'), findsOneWidget);
    expect(find.text('Haftalık zümre'), findsOneWidget);
    expect(find.text('Ortak sınav yapılacak'), findsOneWidget);
    // Başkanlar toplantısı ayrı sekmede değil, Toplantılar sekmesinde
    expect(find.text('Başkanlar'), findsNothing);
    expect(find.text('Zümre başkanları toplantıları'), findsOneWidget);
    expect(find.text('Başkanlar kurulu'), findsOneWidget);
    expect(find.text('Toplantıyı bitir'), findsNWidgets(2));
    // Düğme dar kalmaz: "Toplantıyı bitir" yazısı tek satırda
    expect(t.getSize(find.text('Toplantıyı bitir').first).height, lessThan(24));
  });

  testWidgets('zümre öğretmeni: düzenleme düğmeleri yok; yazılar ve öğretmenler sekmeleri çalışır', (t) async {
    genis(t);
    await t.pumpWidget(MaterialApp(home: ZumremEkrani(api: _api(_yanitlar(baskan: false)))));
    await t.pumpAndSettle();
    expect(find.text('+ Toplantı ekle'), findsNothing);
    expect(find.text('Toplantıyı bitir'), findsNothing);
    expect(find.text('Başkanlar'), findsNothing);
    expect(find.text('Zümre başkanları toplantıları'), findsNothing);

    await t.tap(find.text('Yazılar'));
    await t.pumpAndSettle();
    expect(find.text('Laboratuvar cuma açık'), findsOneWidget);

    await t.tap(find.text('Öğretmenler'));
    await t.pumpAndSettle();
    expect(find.text('Ceren Husny (siz)'), findsOneWidget);
    expect(find.text('Zümre başkanı'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('toplantıyı bitir: karar yazılıp kaydedilince sunucuya gider', (t) async {
    genis(t);
    final kayit = <String>[];
    await t.pumpWidget(
      MaterialApp(
        home: ZumremEkrani(api: _api(_yanitlar(baskan: true), kayit: kayit)),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Toplantıyı bitir').first);
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'Sınav tarihi belirlendi');
    await t.tap(find.text('Kaydet'));
    await t.pumpAndSettle();
    expect(kayit, contains('POST /api/zumre/karar'));
  });
}

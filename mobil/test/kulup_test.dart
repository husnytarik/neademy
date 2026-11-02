import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neademy/cekirdek/api.dart';
import 'package:neademy/ekranlar/kulup.dart';

Api _api(Map<String, Object> yanitlar) => Api(
  istemci: MockClient((istek) async {
    return http.Response.bytes(utf8.encode(jsonEncode(yanitlar[istek.url.path] ?? {})), 200, headers: {'content-type': 'application/json'});
  }),
);

void main() {
  final kulup = {
    'id': 1,
    'ad': 'Bilim Kulübü',
    'tema': 'Deney ve proje',
    'aciklama': '',
    'kontenjan': 20,
    'gunAd': 'Cuma',
    'dersSaati': 7,
    'aralik': '14:00–14:40',
    'uyeSayisi': 3,
    'ogretmenler': [
      {'ad': 'Ceren Husny'},
    ],
  };

  testWidgets('kulüp öğretmen: plan, üye ve işlenen dersleri listeler', (t) async {
    final yanit = {
      'bugun': '2026-11-02',
      'kulupler': [
        {
          ...kulup,
          'uyeler': [
            {'uyelikId': 9, 'ad': 'Deneme Öğrenci', 'sinif': '6-A'},
          ],
          'planlar': [
            {'tarih': '2026-11-06', 'tur': 'deney', 'baslik': 'Elektrik devresi', 'aciklama': '', 'iptal': false},
          ],
          'calismalar': [
            {'id': 2, 'tarih': '2026-10-30', 'tur': 'proje', 'baslik': 'Maket', 'aciklama': '', 'geldi': 2, 'gelmedi': 1, 'izinli': 0},
          ],
        },
      ],
    };
    await t.pumpWidget(MaterialApp(home: KulupOgretmenEkrani(api: _api({'/api/kulup/kuluplerim': yanit}))));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Bilim Kulübü'), findsOneWidget);
    expect(find.text('Elektrik devresi'), findsOneWidget);
    expect(find.text('Maket'), findsOneWidget);
    expect(find.text('2/3'), findsOneWidget);
  });

  testWidgets('kulüp oturumu: ders başlamışsa yoklama listesi çizilir', (t) async {
    final yanit = {
      'kulup': kulup,
      'tarih': '2026-10-30',
      'basladi': true,
      'uyeler': [
        {'uyelikId': 9, 'ad': 'Deneme Öğrenci', 'sinif': '6-A'},
      ],
      'calisma': null,
      'katilim': <String, Object>{},
    };
    t.view.physicalSize = const Size(390, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        home: KulupOturumEkrani(api: _api({'/api/kulup/oturum': yanit}), kulupId: 1, tarih: '2026-10-30'),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Deneme Öğrenci'), findsOneWidget);
    expect(find.text('Dersi bitir'), findsOneWidget);
    expect(find.text('Dersi iptal et'), findsOneWidget);
  });

  testWidgets('kulüp öğrenci: yerleştirilmemişse tercih listesi görünür', (t) async {
    final yanit = {
      'cocuklar': [
        {'id': 5, 'ad': 'Deneme Öğrenci'},
      ],
      'cocuk': 5,
      'sinif': '6-A',
      'talepSiniri': 3,
      'uye': null,
      'kulupler': [kulup],
      'talepler': <Object>[],
    };
    await t.pumpWidget(MaterialApp(home: KulupOgrenciEkrani(api: _api({'/api/kulup/benim': yanit}))));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Henüz kulüp tercihi yapılmadı'), findsOneWidget);
    await t.tap(find.text('Bilim Kulübü'));
    await t.pumpAndSettle();
    expect(find.text('1. tercih'), findsOneWidget);
    expect(find.text('Tercihleri gönder (1)'), findsOneWidget);
  });
}

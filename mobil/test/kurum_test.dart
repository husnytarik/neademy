import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neademy/cekirdek/api.dart';
import 'package:neademy/ekranlar/kurum.dart';

Api _api(Map<String, Object> yanitlar, {List<String>? kayit}) => Api(
  istemci: MockClient((istek) async {
    kayit?.add('${istek.method} ${istek.url.path}');
    return http.Response.bytes(utf8.encode(jsonEncode(yanitlar[istek.url.path] ?? {})), 200, headers: {'content-type': 'application/json'});
  }),
);

final _kurum = {
  'kurum': {'ad': 'Deneme Eğitim Kurumları', 'kisaAd': 'DEK', 'telefon': '', 'eposta': '', 'web': 'ornek.com', 'adres': '', 'aciklama': '', 'sosyal': {}},
  'logo': null,
  'kurucular': [
    {'userId': 9, 'ad': 'Kurucu Kişi', 'telefon': '', 'foto': null},
  ],
  'kampusler': [
    {
      'id': 1,
      'ad': 'Merkez Kampüsü',
      'adres': 'Ankara',
      'telefon': '',
      'okullar': [
        {
          'id': 3,
          'ad': 'Deneme Ortaokulu',
          'kampusId': 1,
          'tur': 'Ortaokul',
          'kurumKodu': '',
          'telefon': '',
          'eposta': '',
          'adres': '',
          'web': '',
          'aciklama': '',
          'sosyal': {},
          'sinif': 8,
          'ogrenci': 120,
          'ogretmen': 15,
          'veli': 100,
          'yeniKayit': 5,
          'yenileme': 100,
          'nakil': 2,
          'kayitsiz': 13,
          'yoklamaToplam': 200,
          'gelmedi': 10,
          'gec': 2,
          'izinli': 1,
          'yoneticiler': [
            {'id': 1, 'okulId': 3, 'userId': 20, 'gorev': 'mudur', 'ad': 'Müdür Kişi', 'telefon': '5550000000'},
          ],
          'zumreler': [
            {'okulId': 3, 'brans': 'Fen Bilimleri', 'ogretmen': 3, 'baskan': 'Ceren Husny'},
          ],
          'gorevliler': <Object>[],
        },
      ],
    },
  ],
  'adaylar': [
    {'userId': 21, 'ad': 'Aday Kişi', 'rol': 'Öğretmen', 'okul': 'Deneme Ortaokulu'},
  ],
  'turler': ['Anaokulu', 'İlkokul', 'Ortaokul', 'Lise'],
  'gorevler': {'mudur': 'Müdür', 'mudur_yrd': 'Müdür yardımcısı'},
  'sosyalAlanlar': [
    {'kod': 'instagram', 'ad': 'Instagram'},
  ],
  'tanitimAzami': 600,
  'kurumYonetimi': true,
};

void main() {
  void genis(WidgetTester t) {
    t.view.physicalSize = const Size(390, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  testWidgets('kurum: sekmeler, kampüs okulları, okul sayfası ve okul kaydı', (t) async {
    genis(t);
    final kayit = <String>[];
    await t.pumpWidget(
      MaterialApp(
        home: KurumEkrani(api: _api({'/api/yonetim/kurum': _kurum}, kayit: kayit)),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Deneme Eğitim Kurumları'), findsOneWidget);
    expect(find.text('Kurucu Kişi'), findsOneWidget);

    await t.tap(find.text('Merkez'));
    await t.pumpAndSettle();
    expect(find.text('Deneme Ortaokulu'), findsOneWidget);
    expect(find.text('Müdür: Müdür Kişi'), findsOneWidget);

    await t.tap(find.text('Deneme Ortaokulu'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Okul yönetimi'), findsOneWidget);
    expect(find.text('+ Yönetici ekle'), findsOneWidget);
    expect(find.text('Fen Bilimleri'), findsOneWidget);

    await t.tap(find.text('Düzenle'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await t.tap(find.text('Kaydet'));
    await t.pumpAndSettle();
    expect(kayit, contains('POST /api/yonetim/okul-kaydet'));
  });

  testWidgets('kampüsler: salt okunur özet ve okul sayfası', (t) async {
    genis(t);
    await t.pumpWidget(MaterialApp(home: KampuslerEkrani(api: _api({'/api/yonetim/kurum': _kurum}))));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.textContaining('1 kampüs · 1 okul'), findsOneWidget);
    expect(find.text('+ Okul ekle'), findsNothing);
    await t.tap(find.text('Deneme Ortaokulu'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Müdür Kişi'), findsOneWidget);
  });
}

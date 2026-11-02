import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neademy/cekirdek/api.dart';
import 'package:neademy/ekranlar/kurulum.dart';

Api _api(Map<String, Object> yanitlar, {List<String>? kayit}) => Api(
  istemci: MockClient((istek) async {
    kayit?.add('${istek.method} ${istek.url.path}');
    return http.Response.bytes(utf8.encode(jsonEncode(yanitlar[istek.url.path] ?? {})), 200, headers: {'content-type': 'application/json'});
  }),
);

final _kurulum = {
  'kampusler': [],
  'subeler': [
    {'id': 1, 'ad': 'Deneme Okulu', 'kampusId': 1},
  ],
  'kademeler': ['Anasınıfı', 'İlkokul', 'Ortaokul'],
  'dersler': [
    {
      'id': 1,
      'ad': 'Matematik',
      'kademeler': ['İlkokul', 'Ortaokul'],
    },
    {
      'id': 2,
      'ad': 'Sınıf Öğretmenliği',
      'kademeler': ['İlkokul'],
    },
  ],
  'sinifOgretmenligiId': 2,
  'sinifOgretmeniKademeleri': ['İlkokul'],
  'ogretmenler': [
    {
      'uyelikId': 20,
      'bransId': 1,
      'ad': 'Ayşe Hoca',
      'subeId': 1,
      'sube': 'Deneme Okulu',
      'durum': 'aktif',
      'dersIds': [1],
    },
  ],
  'ogrenciler': [
    {
      'uyelikId': 30,
      'ad': 'Deniz Örnek',
      'okulNo': '12',
      'subeId': 1,
      'sube': 'Deneme Okulu',
      'durum': 'aktif',
      'sinifId': 5,
      'veliler': [
        {'ad': 'Veli Örnek', 'telefon': '5550000000'},
      ],
    },
    {'uyelikId': 31, 'ad': 'Sınıfsız Kişi', 'okulNo': '13', 'subeId': 1, 'sube': 'Deneme Okulu', 'durum': 'aktif', 'sinifId': null, 'veliler': []},
  ],
  'siniflar': [
    {'id': 5, 'subeId': 1, 'sube': 'Deneme Okulu', 'kademe': 'Ortaokul', 'ad': '6-A', 'sinifOgretmenUyelikId': 20, 'ogrenciSayisi': 1},
  ],
  'atamalar': [
    {'id': 70, 'sinifId': 5, 'dersId': 1, 'ders': 'Matematik', 'ogretmenUyelikId': null, 'haftalikSaat': 4, 'kullanilan': 0},
  ],
};

Future<void> _ac(WidgetTester t, Api api) async {
  t.view.physicalSize = const Size(390, 2400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(MaterialApp(home: KurulumEkrani(api: api)));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('sınıflar ve sekmeler listelenir', (t) async {
    await _ac(t, _api({'/api/yonetim/kurulum': _kurulum}));
    expect(find.text('6-A'), findsOneWidget);
    expect(find.textContaining('Ayşe Hoca'), findsOneWidget);

    await t.tap(find.text('Dersler'));
    await t.pumpAndSettle();
    expect(find.text('Matematik'), findsOneWidget);
    expect(find.text('Sistem dersi'), findsNothing);

    await t.tap(find.text('Öğretmenler'));
    await t.pumpAndSettle();
    expect(find.text('Ayşe Hoca'), findsOneWidget);

    await t.tap(find.text('Öğrenciler'));
    await t.pumpAndSettle();
    expect(find.text('Deniz Örnek'), findsOneWidget);
    expect(find.textContaining('Sınıfsız'), findsWidgets);
  });

  testWidgets('sınıf sayfasında öğrenci eklenir', (t) async {
    final kayit = <String>[];
    await _ac(t, _api({'/api/yonetim/kurulum': _kurulum}, kayit: kayit));
    await t.tap(find.text('6-A'));
    await t.pumpAndSettle();
    expect(find.text('Matematik'), findsOneWidget);
    expect(find.textContaining('Haftada 4 saat'), findsOneWidget);
    expect(find.text('Deniz Örnek'), findsOneWidget);

    await t.dragUntilVisible(find.text('Sınıfa öğrenci ekle'), find.byType(ListView), const Offset(0, -200));
    await t.tap(find.text('Sınıfa öğrenci ekle'));
    await t.pumpAndSettle();
    await t.tap(find.text('Sınıfsız Kişi').last);
    await t.pumpAndSettle();
    expect(kayit, contains('POST /api/yonetim/ogrenci-sinif'));
  });

  testWidgets('yeni ders en az bir kademe ister', (t) async {
    final kayit = <String>[];
    await _ac(t, _api({'/api/yonetim/kurulum': _kurulum}, kayit: kayit));
    await t.tap(find.text('Dersler'));
    await t.pumpAndSettle();
    await t.tap(find.text('+ Ders ekle'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, 'Fen');
    await t.tap(find.text('İlkokul'));
    await t.tap(find.text('Ortaokul'));
    await t.pump();
    await t.tap(find.text('Dersi ekle'));
    await t.pump();
    expect(find.text('En az bir kademe seçin.'), findsOneWidget);
    expect(kayit.where((x) => x.startsWith('POST')), isEmpty);
  });
}

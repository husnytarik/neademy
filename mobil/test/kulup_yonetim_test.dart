import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neademy/cekirdek/api.dart';
import 'package:neademy/ekranlar/kulup_yonetim.dart';

Api _api(Map<String, Object> yanitlar, {List<String>? kayit}) => Api(
  istemci: MockClient((istek) async {
    kayit?.add('${istek.method} ${istek.url.path}${istek.method == 'POST' ? ' ${istek.body}' : ''}');
    return http.Response.bytes(utf8.encode(jsonEncode(yanitlar[istek.url.path] ?? {})), 200, headers: {'content-type': 'application/json'});
  }),
);

final _yonetim = {
  'kulupler': [
    {
      'id': 1,
      'ad': 'Satranç',
      'tema': 'Strateji',
      'aciklama': 'Haftalık turnuvalar',
      'kontenjan': 10,
      'aktif': true,
      'gun': 5,
      'gunAd': 'Cuma',
      'dersSaati': 7,
      'aralik': '14:00–14:40',
      'seviyeler': ['Ortaokul'],
      'ogretmenler': [
        {'uyelikId': 20, 'ad': 'Ayşe Hoca'},
      ],
      'uyeSayisi': 1,
      'bekleyen': 2,
    },
  ],
  'gunler': [
    {'gun': 4, 'ad': 'Perşembe'},
    {'gun': 5, 'ad': 'Cuma'},
  ],
  'zamanlar': ['08:30–09:10', '09:20–10:00'],
  'duzeyler': ['İlkokul', 'Ortaokul'],
  'ogretmenler': [
    {'uyelikId': 20, 'ad': 'Ayşe Hoca'},
  ],
  'sinifSayisi': {'İlkokul': 2, 'Ortaokul': 3},
  'kulupSaatleri': [
    {'duzey': 'Ortaokul', 'gun': 5, 'gunAd': 'Cuma', 'saat': 7, 'aralik': '14:00–14:40', 'sinif': 3},
  ],
};

final _talepler = {
  'ogrenciler': [
    {
      'uyelikId': 30,
      'ad': 'Deniz Örnek',
      'sinif': '6-A',
      'okulNo': '12',
      'uye': null,
      'talepler': [
        {'id': 100, 'sira': 1, 'kulup': 'Satranç', 'kulupId': 1, 'uyeSayisi': 1, 'kontenjan': 10, 'durum': 'bekliyor'},
      ],
    },
  ],
};

Future<void> _ac(WidgetTester t, Api api) async {
  t.view.physicalSize = const Size(390, 2400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(MaterialApp(home: KulupYonetimEkrani(api: api)));
  await t.pumpAndSettle();
}

void main() {
  final yanit = <String, Object>{
    '/api/kulup/yonetim': _yonetim,
    '/api/kulup/talepler': _talepler,
    '/api/kulup/uyeler': {
      'uyeler': [
        {'uyelikId': 31, 'ad': 'Ece Üye', 'sinif': '7-B'},
      ],
    },
  };

  testWidgets('kulüp listelenir ve ayrıntıda üye çıkarılır', (t) async {
    final kayit = <String>[];
    await _ac(t, _api(yanit, kayit: kayit));
    expect(find.text('Satranç'), findsOneWidget);
    expect(find.textContaining('2 bekleyen talep'), findsOneWidget);

    await t.tap(find.text('Satranç'));
    await t.pumpAndSettle();
    expect(find.textContaining('Ece Üye'), findsOneWidget);
    expect(find.text('Kulübü sil'), findsOneWidget);

    await t.tap(find.text('Çıkar'));
    await t.pumpAndSettle();
    await t.tap(find.text('Çıkar').last);
    await t.pumpAndSettle();
    expect(kayit.any((x) => x.startsWith('POST /api/kulup/cikar') && x.contains('31')), isTrue);
  });

  testWidgets('talep yerleştirilir', (t) async {
    final kayit = <String>[];
    await _ac(t, _api(yanit, kayit: kayit));
    await t.tap(find.text('Talepler'));
    await t.pumpAndSettle();
    expect(find.text('Deniz Örnek'), findsOneWidget);
    await t.tap(find.text('Yerleştir'));
    await t.pumpAndSettle();
    expect(kayit.any((x) => x.startsWith('POST /api/kulup/yerlestir') && x.contains('"kulupId":1')), isTrue);
  });

  testWidgets('kulüp saati ister ve kaldırılır', (t) async {
    final kayit = <String>[];
    await _ac(t, _api(yanit, kayit: kayit));
    await t.tap(find.text('Kulüp saatleri'));
    await t.pumpAndSettle();
    await t.tap(find.text('Kulüp saati ekle'));
    await t.pump();
    expect(find.text('Düzey, gün ve ders saatini seçin.'), findsOneWidget);
    expect(kayit.where((x) => x.startsWith('POST')), isEmpty);

    await t.tap(find.text('Kaldır'));
    await t.pumpAndSettle();
    expect(kayit.any((x) => x.startsWith('POST /api/kulup/saat') && x.contains('"kaldir":true')), isTrue);
  });
}

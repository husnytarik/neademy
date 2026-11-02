import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neademy/cekirdek/api.dart';
import 'package:neademy/ekranlar/kisiler.dart';

Api _api(Map<String, Object> yanitlar, {List<String>? kayit}) => Api(
  istemci: MockClient((istek) async {
    kayit?.add('${istek.method} ${istek.url.path}');
    return http.Response.bytes(utf8.encode(jsonEncode(yanitlar[istek.url.path] ?? {})), 200, headers: {'content-type': 'application/json'});
  }),
);

final _yanit = <String, Object>{
  '/api/yonetim/subeler': {
    'subeler': [
      {'id': 1, 'ad': 'Deneme Okulu', 'kampusId': 1},
    ],
    'kampusler': [
      {'id': 1, 'ad': 'Merkez'},
    ],
  },
  '/api/yonetim/kullanicilar': {
    'kullanicilar': [
      {
        'id': 7,
        'ad': 'Ayşe Yönetici',
        'telefon': '555***01',
        'uyelikler': [
          {'id': 70, 'rol': 'yonetim', 'durum': 'aktif', 'gorev': 'okul', 'subeId': 1, 'sube': 'Deneme Okulu'},
        ],
        'roller': [2],
        'okulGorevleri': [
          {'gorev': 'mudur', 'okul': 'Deneme Okulu'},
        ],
      },
      {
        'id': 8,
        'ad': 'Boş Kişi',
        'uyelikler': [
          {'id': 80, 'rol': 'yonetim', 'durum': 'aktif', 'gorev': 'okul', 'subeId': 1, 'sube': 'Deneme Okulu'},
        ],
        'roller': <Object>[],
        'okulGorevleri': <Object>[],
      },
    ],
  },
  '/api/yonetim/roller': {
    'roller': [
      {
        'id': 2,
        'kod': 'ozel',
        'ad': 'Kütüphane',
        'aciklama': '',
        'sistem': false,
        'yetkiler': ['rapor'],
        'kisi': 1,
        'okulAtar': false,
        'kilitli': false,
      },
    ],
    'katalog': [
      {
        'grup': 'Raporlar',
        'yetkiler': [
          {'kod': 'rapor', 'ad': 'Raporlar', 'aciklama': 'Karne ve raporlar'},
        ],
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

  testWidgets('kişiler: kadro, rol atanmamış uyarısı, kişi düzenleme ve rol seçimi', (t) async {
    genis(t);
    final kayit = <String>[];
    await t.pumpWidget(
      MaterialApp(
        home: KisilerEkrani(api: _api(_yanit, kayit: kayit)),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Ayşe Yönetici'), findsOneWidget);
    expect(find.textContaining('Rol atanmamış'), findsOneWidget);

    await t.tap(find.text('Düzenle'));
    await t.pumpAndSettle();
    await t.tap(find.text('Boş Kişi'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await t.tap(find.widgetWithText(FilterChip, 'Kütüphane'));
    await t.pumpAndSettle();
    expect(kayit, contains('POST /api/yonetim/kullanici-rol'));
  });

  testWidgets('roller sekmesi: yetki sayısı ve rol sayfası', (t) async {
    genis(t);
    await t.pumpWidget(MaterialApp(home: KisilerEkrani(api: _api(_yanit))));
    await t.pumpAndSettle();
    await t.tap(find.text('Roller'));
    await t.pumpAndSettle();
    expect(find.textContaining('1 yetki'), findsOneWidget);
    await t.tap(find.text('Kütüphane'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Raporlar'), findsOneWidget);
  });
}

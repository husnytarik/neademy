import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neademy/cekirdek/api.dart';
import 'package:neademy/cekirdek/foto.dart';
import 'package:neademy/ekranlar/kisiler.dart';

/// [kayit]: "METHOD /yol" satırları; [govdeler]: POST gövdeleri yol → gövde.
Api _api(Map<String, Object> yanitlar, {List<String>? kayit, Map<String, Map<String, dynamic>>? govdeler}) => Api(
  istemci: MockClient((istek) async {
    kayit?.add('${istek.method} ${istek.url.path}');
    if (istek.method == 'POST' && govdeler != null && istek.body.isNotEmpty && istek.headers['content-type']?.contains('json') == true) {
      govdeler[istek.url.path] = jsonDecode(istek.body) as Map<String, dynamic>;
    }
    return http.Response.bytes(utf8.encode(jsonEncode(yanitlar[istek.url.path] ?? {})), 200, headers: {'content-type': 'application/json'});
  }),
);

final _yanit = <String, Object>{
  '/api/yonetim/subeler': {
    'subeler': [
      {'id': 1, 'ad': 'Okul A', 'kampusId': 1},
      {'id': 2, 'ad': 'Okul B', 'kampusId': 1},
    ],
    'kampusler': [
      {'id': 1, 'ad': 'Merkez'},
    ],
  },
  '/api/yonetim/kullanici-secenek': {
    'okullar': [
      {'id': 1, 'ad': 'Okul A'},
      {'id': 2, 'ad': 'Okul B'},
    ],
    'dersler': [
      {'id': 5, 'ad': 'Matematik'},
    ],
    'roller': [
      {'id': 3, 'kod': 'guvenlik', 'ad': 'Güvenlik'},
      {'id': 4, 'kod': 'zumre', 'ad': 'Zümre'},
    ],
    'gorevler': {'mudur': 'Müdür', 'mudur_yrd': 'Müdür yardımcısı'},
  },
  '/api/yonetim/kullanicilar': {
    'kullanicilar': [
      {
        'id': 8,
        'ad': 'Mehmet Güvenlik',
        'uyelikler': [
          {'id': 80, 'rol': 'yonetim', 'durum': 'aktif', 'gorev': 'okul', 'subeId': 1, 'sube': 'Okul A'},
        ],
        'roller': [3],
        'okulGorevleri': <Object>[],
      },
      {
        'id': 9,
        'ad': 'Aylin Atamasız',
        'uyelikler': [
          {'id': 90, 'rol': 'yonetim', 'durum': 'aktif', 'gorev': 'okul', 'subeId': 1, 'sube': 'Okul A'},
        ],
        'roller': <Object>[],
        'okulGorevleri': <Object>[],
      },
    ],
  },
  '/api/yonetim/kullanici-detay': {
    'id': 8,
    'ad': 'Mehmet Güvenlik',
    'kimlik': '11122233344',
    'kimlikTuru': 'T.C. kimlik no',
    'telefon': '555 111 22 33',
    'foto': '',
    'kendisi': false,
    'uyelikler': [
      {'id': 80, 'rol': 'yonetim', 'durum': 'aktif', 'gorev': 'okul', 'subeId': 1, 'sube': 'Okul A'},
    ],
    'roller': [3],
    'okulGorevleri': <Object>[],
    'diger': <Object>[],
    'veliOgrenciler': <Object>[],
    'atamalar': <Object>[],
    'sinifOgretmenligi': <Object>[],
  },
  '/api/yonetim/kullanici-denetim': {
    'gecmis': [
      {'id': 11, 'zaman': '2026-11-14 10:20:00', 'aktor': 'Ayşe Yönetici', 'ozet': 'Okul A okuluna eklendi', 'geriAlinabilir': true},
    ],
  },
  '/api/yonetim/kullanici-yeni': {'id': 8, 'tamam': true},
  '/api/yonetim/roller': {
    'roller': [
      {'id': 2, 'kod': 'ozel', 'ad': 'Kütüphane', 'aciklama': '', 'sistem': false, 'yetkiler': ['rapor'], 'kisi': 1, 'okulAtar': false, 'kilitli': false},
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
    t.view.physicalSize = const Size(390, 3000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  Future<void> goster(WidgetTester t, Api api) async {
    await t.pumpWidget(MaterialApp(home: KisilerEkrani(api: api)));
    await t.pumpAndSettle();
  }

  Future<void> gorunur(WidgetTester t, Finder f) async {
    await t.ensureVisible(f);
    await t.pumpAndSettle();
  }

  testWidgets('kişiler: görev unvanı listelenir, kişi dosyası açılır', (t) async {
    genis(t);
    await goster(t, _api(_yanit));
    expect(t.takeException(), isNull);
    expect(find.text('Mehmet Güvenlik'), findsOneWidget);
    expect(find.textContaining('Güvenlik · Okul A'), findsOneWidget);
    // görevi olmayan çalışan listede belirtilir
    expect(find.textContaining('Görev atanmamış'), findsOneWidget);

    await t.tap(find.text('Mehmet Güvenlik'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Kimlik ve iletişim'), findsOneWidget);
    expect(find.text('Okullar'), findsOneWidget);
    expect(find.text('Geçmiş'), findsOneWidget);
  });

  testWidgets('kişi fotoğrafı seçilip yüklenir', (t) async {
    genis(t);
    final kayit = <String>[];
    galeridenFotoSec = () async => Uint8List.fromList([0xff, 0xd8, 0xff, 1, 2, 3]);
    await goster(t, _api(_yanit, kayit: kayit));
    await t.tap(find.text('Mehmet Güvenlik'));
    await t.pumpAndSettle();
    await t.tap(find.text('Fotoğraf ekle'));
    await t.pumpAndSettle();
    expect(kayit, contains('POST /api/foto'));
  });

  testWidgets('yanlış okul: "Okulunu değiştir" onay özetiyle doğru okula taşır', (t) async {
    genis(t);
    final kayit = <String>[];
    final govde = <String, Map<String, dynamic>>{};
    await goster(t, _api(_yanit, kayit: kayit, govdeler: govde));
    await t.tap(find.text('Mehmet Güvenlik'));
    await t.pumpAndSettle();
    await gorunur(t, find.text('Okulunu değiştir'));
    await t.tap(find.text('Okulunu değiştir'));
    await t.pumpAndSettle();
    // okul seçilmeden Devam kapalı
    expect(t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Devam')).onPressed, isNull);
    await t.tap(find.byType(DropdownButtonFormField<int>));
    await t.pumpAndSettle();
    await t.tap(find.text('Okul B').last);
    await t.pumpAndSettle();
    await t.tap(find.text('Devam'));
    await t.pumpAndSettle();
    expect(find.textContaining('Okul A → Okul B okuluna taşınacak'), findsOneWidget);
    expect(kayit, isNot(contains('POST /api/yonetim/kullanici-okul-tasi')));
    await t.tap(find.text('Taşı'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(kayit, contains('POST /api/yonetim/kullanici-okul-tasi'));
    expect(govde['/api/yonetim/kullanici-okul-tasi'], {'userId': 8, 'kaynakSubeId': 1, 'hedefSubeId': 2});
  });

  testWidgets('geçmişteki işlem "Geri al" ile onaydan sonra döndürülür', (t) async {
    genis(t);
    final kayit = <String>[];
    final govde = <String, Map<String, dynamic>>{};
    await goster(t, _api(_yanit, kayit: kayit, govdeler: govde));
    await t.tap(find.text('Mehmet Güvenlik'));
    await t.pumpAndSettle();
    await gorunur(t, find.text('Okul A okuluna eklendi'));
    await t.tap(find.text('Geri al'));
    await t.pumpAndSettle();
    expect(kayit, isNot(contains('POST /api/yonetim/kullanici-geri-al')));
    await t.tap(find.text('Geri al').last);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(govde['/api/yonetim/kullanici-geri-al'], {'userId': 8, 'denetimId': 11});
  });

  testWidgets('yeni kişi: okul seçmeden eklenmez, onay özeti sonra kişi dosyası açılır', (t) async {
    genis(t);
    final kayit = <String>[];
    final govde = <String, Map<String, dynamic>>{};
    await goster(t, _api(_yanit, kayit: kayit, govdeler: govde));
    await t.tap(find.text('+ Yeni kişi'));
    await t.pumpAndSettle();
    expect(find.text('Yeni kişi'), findsOneWidget);

    await t.enterText(find.widgetWithText(TextField, 'Ad soyad'), 'Hasan Bekçi');
    await t.enterText(find.widgetWithText(TextField, 'T.C. / pasaport no'), '99988877766');
    await gorunur(t, find.text('Kişiyi ekle'));
    // iki okul var: seçim yapılmadan ilerlenemez (sessiz varsayılan yok)
    await t.tap(find.text('Kişiyi ekle'));
    await t.pumpAndSettle();
    expect(find.textContaining('Okul seçin'), findsOneWidget);
    expect(kayit, isNot(contains('POST /api/yonetim/kullanici-yeni')));

    await t.tap(find.widgetWithText(FilterChip, 'Okul B'));
    await t.pumpAndSettle();
    // zümre ek görev olarak sunulmaz
    expect(find.widgetWithText(FilterChip, 'Zümre'), findsNothing);
    await t.tap(find.widgetWithText(FilterChip, 'Güvenlik'));
    await t.pumpAndSettle();
    await gorunur(t, find.text('Kişiyi ekle'));
    await t.tap(find.text('Kişiyi ekle'));
    await t.pumpAndSettle();
    expect(find.textContaining('Okul: Okul B'), findsOneWidget);
    expect(find.textContaining('Görev: Güvenlik'), findsOneWidget);
    expect(kayit, isNot(contains('POST /api/yonetim/kullanici-yeni')));

    await t.tap(find.text('Doğru, ekle'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    final g = govde['/api/yonetim/kullanici-yeni']!;
    expect(g['subeIds'], [2]);
    expect(g['rolIds'], [3]);
    expect(g['ogretmen'], false);
    expect(g['yonetim'], false);
    expect(g['kimlik'], '99988877766');
    // ardından kişi dosyası (yanlışsa düzeltme notuyla) açılır
    expect(find.textContaining('yanlışsa'), findsWidgets);
    expect(find.text('Kimlik ve iletişim'), findsOneWidget);
  });

  testWidgets('roller sekmesi: yetki sayısı ve rol sayfası', (t) async {
    genis(t);
    await goster(t, _api(_yanit));
    await t.tap(find.text('Roller'));
    await t.pumpAndSettle();
    expect(find.textContaining('1 yetki'), findsOneWidget);
    await t.tap(find.text('Kütüphane'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Raporlar'), findsOneWidget);
  });
}

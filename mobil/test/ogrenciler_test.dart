import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neademy/cekirdek/api.dart';
import 'package:neademy/ekranlar/ogrenciler.dart';

Api _api(Map<String, Object> yanitlar, {List<String>? kayit}) => Api(
  istemci: MockClient((istek) async {
    kayit?.add('${istek.method} ${istek.url.path}');
    return http.Response.bytes(utf8.encode(jsonEncode(yanitlar[istek.url.path] ?? {})), 200, headers: {'content-type': 'application/json'});
  }),
);

const _secenek = {
  'yakinlik': ['Anne', 'Baba'],
  'kanGrubu': ['A+', '0+'],
  'ozelTur': {'saglik': 'Sağlık'},
  'kayitTuru': {'yeni': 'Yeni kayıt'},
};
final _subeler = [
  {'id': 1, 'ad': 'Deneme Okulu'},
];
final _siniflar = [
  {'id': 5, 'subeId': 1, 'ad': '6-A', 'kademe': '6'},
];

final _liste = {
  'ogrenciler': [
    {
      'id': 9,
      'ad': 'Deniz Örnek',
      'foto': null,
      'okulNo': '12',
      'subeId': 1,
      'sube': 'Deneme Okulu',
      'durum': 'aktif',
      'sinifId': 5,
      'sinif': '6-A',
      'yemek': 'almayacak',
      'ozelSayisi': 1,
    },
    {
      'id': 10,
      'ad': 'Ali Ayrılmış',
      'okulNo': '13',
      'subeId': 1,
      'sube': 'Deneme Okulu',
      'durum': 'pasif',
      'sinifId': null,
      'sinif': null,
      'yemek': '',
      'ozelSayisi': 0,
    },
  ],
  'subeler': _subeler,
  'siniflar': _siniflar,
};

final _kayit = {
  'ogrenci': {
    'id': 9,
    'userId': 90,
    'ad': 'Deniz Örnek',
    'telefon': '5550000000',
    'kimlik': '100****000',
    'kimlikTuru': 'T.C. kimlik no',
    'okulNo': '12',
    'durum': 'aktif',
    'subeId': 1,
    'sube': 'Deneme Okulu',
    'sinifId': 5,
    'sinif': '6-A',
  },
  'kayit': {
    'dogumTarihi': '2014-05-03',
    'dogumYeri': 'Ankara',
    'cinsiyet': 'erkek',
    'kanGrubu': '0+',
    'oncekiOkul': '',
    'kayitTarihi': '2026-09-01',
    'kayitTuru': 'yeni',
    'yemek': 'almayacak',
  },
  'iletisim': {'email': '', 'il': 'Ankara', 'ilce': '', 'adres': '', 'yakinAd': '', 'yakinYakinlik': '', 'yakinTelefon': ''},
  'aile': [
    {'uyelikId': 30, 'userId': 300, 'ad': 'Zeynep Örnek', 'telefon': '5551110000', 'yakinlik': 'Anne', 'meslek': '', 'email': ''},
  ],
  'ozelDurumlar': [
    {'id': 1, 'tur': 'saglik', 'baslik': 'Fıstık alerjisi', 'aciklama': ''},
  ],
  'duzenleyebilir': true,
  'secenekler': _secenek,
  'subeler': _subeler,
  'siniflar': _siniflar,
};

final _rapor = {
  'ogrenci': {'id': 9, 'ad': 'Deniz Örnek', 'okulNo': '12', 'sube': 'Deneme Okulu', 'sinif': '6-A', 'mentor': '', 'mentorEtiket': 'Sınıf öğretmeni'},
  'devam': {'toplam': 10, 'geldi': 8, 'gelmedi': 2, 'gec': 0, 'izinli': 0},
  'dersler': <Object>[],
  'son': <Object>[],
  'bilgi': <String, Object>{},
  'donemler': <Object>[],
  'odevler': <Object>[],
  'etutler': <Object>[],
  'donemKarsilastirma': <Object>[],
  'bekleyenOdev': {'bekleyen': 2, 'geciken': 0},
};

void main() {
  void genis(WidgetTester t) {
    t.view.physicalSize = const Size(390, 2800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  testWidgets('öğrenci listesi: süzgeç, rozetler ve dosya sayfası', (t) async {
    genis(t);
    final api = _api({
      '/api/ogrenci/liste': _liste,
      '/api/ogrenci/rapor': _rapor,
      '/api/ogrenci/kayit': _kayit,
      '/api/sinav/ogrenci': {'sinavlar': <Object>[]},
      '/api/ogrenci/teslim': {
        'kayitlar': [
          {'zaman': DateTime.utc(2026, 11, 2, 12, 30).millisecondsSinceEpoch, 'kisi': 'Veli Örnek', 'yakinlik': 'Anne', 'guvenlik': 'Güvenlik Görevlisi'},
        ],
      },
    });
    await t.pumpWidget(MaterialApp(home: OgrencilerEkrani(api: api)));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('2 öğrenci'), findsOneWidget);
    expect(find.text('Yemek yok'), findsOneWidget);
    await t.enterText(find.byType(TextField).first, 'deniz');
    await t.pumpAndSettle();
    expect(find.text('1 öğrenci'), findsOneWidget);

    await t.tap(find.text('Deniz Örnek'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Düzenle'), findsOneWidget);
    expect(find.textContaining('2 ders saati devamsızlığı'), findsNothing);
    await t.tap(find.text('Teslim'));
    await t.pumpAndSettle();
    expect(find.text('Veli Örnek'), findsOneWidget);
    expect(find.text('15:30'), findsOneWidget);
    expect(find.textContaining('Güvenlik: Güvenlik Görevlisi'), findsOneWidget);
    await t.tap(find.text('Kayıt'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Fıstık alerjisi'), findsOneWidget);
    expect(find.textContaining('Zeynep Örnek'), findsOneWidget);
  });

  testWidgets('kayıt formu: düzenleme kaydı sunucuya gider', (t) async {
    genis(t);
    final kayit = <String>[];
    await t.pumpWidget(
      MaterialApp(
        home: OgrenciFormu(api: _api({'/api/ogrenci/kayit': _kayit}, kayit: kayit), id: 9),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Kayıt bilgilerini düzenle'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Değişiklikleri kaydet'), 400, scrollable: find.byType(Scrollable).first);
    await t.tap(find.text('Değişiklikleri kaydet'));
    await t.pumpAndSettle();
    expect(kayit, containsAll(['POST /api/ogrenci/kaydet', 'POST /api/ogrenci/veli-guncelle', 'POST /api/ogrenci/ozel-durum-kaydet']));
  });

  testWidgets('yeni öğrenci: kimlik yoksa uyarır', (t) async {
    genis(t);
    final kayit = <String>[];
    await t.pumpWidget(
      MaterialApp(
        home: OgrenciFormu(
          api: _api({
            '/api/ogrenci/kayit': {'secenekler': _secenek, 'subeler': _subeler, 'siniflar': _siniflar},
          }, kayit: kayit),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Yeni öğrenci'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Öğrenciyi kaydet'), 400, scrollable: find.byType(Scrollable).first);
    await t.tap(find.text('Öğrenciyi kaydet'));
    await t.pumpAndSettle();
    expect(find.textContaining('kimlik numarası ve telefon gerekli'), findsOneWidget);
    expect(kayit, isNot(contains('POST /api/ogrenci/kaydet')));
  });
}

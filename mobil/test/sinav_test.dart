import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neademy/cekirdek/api.dart';
import 'package:neademy/ekranlar/sinav.dart';

Api _api(Map<String, Object> yanitlar, {List<String>? kayit}) => Api(
  istemci: MockClient((istek) async {
    kayit?.add('${istek.method} ${istek.url.path}');
    return http.Response.bytes(utf8.encode(jsonEncode(yanitlar[istek.url.path] ?? {})), 200, headers: {'content-type': 'application/json'});
  }),
);

final _liste = {
  'yonetim': true,
  'sinavlar': [
    {
      'id': 1,
      'ad': '1. Dönem 1. Deneme',
      'tarih': '2026-10-20',
      'yanlisKat': 3,
      'yayin': false,
      'tur': 'test',
      'amac': 'deneme',
      'duzey': 6,
      'durum': 'aktif',
      'siniflar': ['6-A', '6-B'],
      'dersler': ['Fen Bilimleri', 'Matematik'],
      'soru': 40,
      'hazirlik': [
        {'ders': 'Fen Bilimleri', 'onay': true, 'soru': 20, 'sik': 20, 'kazanim': 20, 'gerekli': 20, 'tamam': true},
        {'ders': 'Matematik', 'onay': false, 'soru': 20, 'sik': 5, 'kazanim': 0, 'gerekli': 20, 'tamam': false},
      ],
      'kazanimli': 0,
      'okunan': 12,
    },
  ],
};

final _detay = {
  'yonetim': false,
  'sinav': {
    'id': 1,
    'ad': '1. Dönem 1. Deneme',
    'tarih': '2026-10-20',
    'yanlisKat': 3,
    'yayin': false,
    'tur': 'test',
    'amac': 'deneme',
    'duzey': 6,
    'durum': 'aktif',
    'kapsam': [],
    'cevapVar': true,
  },
  'siniflar': [
    {'id': 1, 'name': '6-A'},
  ],
  'dersler': [
    {'id': 11, 'ders': 'Fen Bilimleri', 'soruSayisi': 3, 'onay': false},
  ],
  'ogrenciler': <Object>[],
};

final _hazirlik = {
  'siniflar': ['6-A'],
  'duzey': 6,
  'durum': 'aktif',
  'dersler': [
    {
      'id': 11,
      'ders': 'Fen Bilimleri',
      'soruSayisi': 3,
      'onay': false,
      'onayAd': '',
      'sik': 2,
      'kazanim': 1,
      'gerekli': 3,
      'tamam': false,
      'sorular': [
        {'no': 1, 'sik': 'A', 'iptal': false, 'kazanim': 'Kuvvet ve hareket', 'kim': 'Ceren Husny'},
        {'no': 2, 'sik': 'C', 'iptal': false, 'kazanim': '', 'kim': ''},
        {'no': 3, 'sik': '', 'iptal': false, 'kazanim': '', 'kim': ''},
      ],
    },
  ],
};

final _sonuc = {
  'sinav': {
    'id': 1,
    'ad': '1. Dönem 1. Deneme',
    'tarih': '2026-10-20',
    'yanlisKat': 3,
    'yayin': false,
    'tur': 'test',
    'amac': 'deneme',
    'duzey': 6,
    'kapsam': [],
  },
  'dersler': [
    {'id': 11, 'ders': 'Fen Bilimleri', 'soruSayisi': 3},
  ],
  'ogrenciler': [
    {
      'ogrenciId': 5,
      'ad': 'Deneme Öğrenci',
      'okulNo': '12',
      'sinif': '6-A',
      'ortalama': 82.5,
      'sira': 1,
      'dersler': {
        '11': {'puan': 82.5, 'dogru': 2, 'yanlis': 1, 'bos': 0, 'net': 1.7},
      },
      'siralama': {
        'sinif': {'sira': 1, 'sayi': 2},
        'okul': {'sira': 1, 'sayi': 2},
        'genel': null,
      },
      'degisim': null,
    },
    {'ogrenciId': 6, 'ad': 'Girmeyen Öğrenci', 'okulNo': '13', 'sinif': '6-A', 'ortalama': null, 'sira': null, 'dersler': <String, Object>{}},
  ],
  'giren': 1,
  'beklenen': 2,
  'kisitli': false,
  'analiz': [
    {
      'dersId': 11,
      'ders': 'Fen Bilimleri',
      'giren': 1,
      'sorular': [
        {
          'no': 1,
          'basari': 100,
          'dogru': 1,
          'yanlis': 0,
          'bos': 0,
          'iptal': false,
          'dogruSik': 'A',
          'zorluk': 'Kolay',
          'ayirt': null,
          'dagilim': {'A': 1, 'B': 0, 'C': 0, 'D': 0, 'E': 0, 'bos': 0},
        },
      ],
      'kazanimlar': [
        {
          'kazanim': 'Kuvvet ve hareket',
          'sorular': [1],
          'oran': 100,
          'giren': 1,
          'islenmedi': 0,
          'devamsiz': 0,
        },
      ],
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

  testWidgets('sınav listesi: rozetler, hazırlık özeti ve yönetim düğmesi', (t) async {
    genis(t);
    await t.pumpWidget(MaterialApp(home: SinavEkrani(api: _api({'/api/sinav/liste': _liste}), yonetim: true)));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('+ Yeni sınav'), findsOneWidget);
    expect(find.text('1. Dönem 1. Deneme'), findsOneWidget);
    expect(find.text('Deneme'), findsOneWidget);
    expect(find.textContaining('1/2 ders tamam'), findsOneWidget);
  });

  testWidgets('öğretmen: hazırlık sekmesi derslerin durumunu gösterir, anahtar sayfası kaydeder', (t) async {
    genis(t);
    final kayit = <String>[];
    final api = _api({'/api/sinav/detay': _detay, '/api/sinav/hazirlik': _hazirlik}, kayit: kayit);
    await t.pumpWidget(MaterialApp(home: SinavDetayEkrani(api: api, id: 1, yonetim: false)));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Hazırlık'), findsOneWidget);
    expect(find.text('Eksik'), findsOneWidget);
    expect(find.textContaining('cevap 2/3'), findsOneWidget);

    await t.tap(find.text('Fen Bilimleri'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Hızlı anahtar'), findsOneWidget);
    await t.enterText(find.byType(TextField).first, 'ABC');
    await t.tap(find.text('Uygula'));
    await t.pumpAndSettle();
    await t.tap(find.text('Kaydet'));
    await t.pumpAndSettle();
    expect(kayit, contains('POST /api/sinav/sorular'));
  });

  testWidgets('sonuç sekmesi: ortalama, sıralı öğrenciler ve öğrenci raporu', (t) async {
    genis(t);
    final api = _api({'/api/sinav/detay': _detay, '/api/sinav/hazirlik': _hazirlik, '/api/sinav/sonuc': _sonuc});
    await t.pumpWidget(MaterialApp(home: SinavDetayEkrani(api: api, id: 1, yonetim: false)));
    await t.pumpAndSettle();
    await t.tap(find.text('Sonuç'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.textContaining('1/2 öğrenci girdi'), findsOneWidget);
    expect(find.text('Deneme Öğrenci'), findsOneWidget);
    expect(find.text('Girmeyen Öğrenci'), findsOneWidget);
    await t.tap(find.text('Deneme Öğrenci'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Sınıfta 1/2'), findsOneWidget);

    await t.tapAt(const Offset(10, 10));
    await t.pumpAndSettle();
    await t.tap(find.text('Analiz'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Soru 1'), findsOneWidget);
    expect(find.text('Kolay'), findsOneWidget);
  });

  testWidgets('yazılı sınav: puanlar kaydedilir', (t) async {
    genis(t);
    final kayit = <String>[];
    final detay = {
      'yonetim': false,
      'sinav': {
        'id': 2,
        'ad': 'Fen Yazılısı',
        'tarih': '2026-10-22',
        'yanlisKat': 0,
        'yayin': false,
        'tur': 'yazili',
        'amac': 'deneme',
        'duzey': 6,
        'durum': 'aktif',
        'kapsam': [],
      },
      'siniflar': [
        {'id': 1, 'name': '6-A'},
      ],
      'dersler': [
        {'id': 12, 'ders': 'Fen Bilimleri', 'soruSayisi': 0, 'onay': false},
      ],
      'ogrenciler': [
        {'ogrenciId': 5, 'ad': 'Deneme Öğrenci', 'okulNo': '12', 'sinif': '6-A', 'puan': 70},
      ],
    };
    await t.pumpWidget(
      MaterialApp(
        home: SinavDetayEkrani(api: _api({'/api/sinav/detay': detay}, kayit: kayit), id: 2, yonetim: false),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Puanlar'), findsOneWidget);
    expect(find.text('Deneme Öğrenci'), findsOneWidget);
    await t.tap(find.text('Puanları kaydet'));
    await t.pumpAndSettle();
    expect(kayit, contains('POST /api/sinav/puanlar'));
  });

  testWidgets('cevaplar: optik çıktısı yapıştırılınca okul numarasına göre yazılır', (t) async {
    genis(t);
    final detay = {
      'yonetim': true,
      'sinav': {..._detay['sinav'] as Map<String, Object>},
      'siniflar': [
        {'id': 1, 'name': '6-A'},
      ],
      'dersler': [
        {'id': 11, 'ders': 'Fen Bilimleri', 'soruSayisi': 3, 'onay': true, 'anahtar': 'ABC', 'iptal': <Object>[]},
      ],
      'ogrenciler': [
        {'ogrenciId': 5, 'ad': 'Deneme Öğrenci', 'okulNo': '12', 'sinif': '6-A', 'cevaplar': <String, Object>{}},
      ],
    };
    await t.pumpWidget(MaterialApp(home: SinavDetayEkrani(api: _api({'/api/sinav/detay': detay}), id: 1, yonetim: true)));
    await t.pumpAndSettle();
    await t.tap(find.text('Cevaplar'));
    await t.pumpAndSettle();
    await t.tap(find.text('Optik çıktısını yapıştır'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).last, '012;AB*\n99;ABC');
    await t.tap(find.text('Uygula'));
    await t.pumpAndSettle();
    expect(find.textContaining('1 öğrencinin cevabı yazıldı'), findsOneWidget);
    expect(find.textContaining('"99" numaralı öğrenci'), findsOneWidget);
    await t.tap(find.text('Tamam'));
    await t.pumpAndSettle();
    expect(find.text('AB-'), findsOneWidget);
  });

  testWidgets('sonuç: yönetim öğrenci raporunda soru soru doğru/yanlış ve doğru şık görür', (t) async {
    genis(t);
    final detay = {
      'yonetim': true,
      'sinav': {..._detay['sinav'] as Map<String, Object>},
      'siniflar': [
        {'id': 1, 'name': '6-A'},
      ],
      'dersler': [
        {'id': 11, 'ders': 'Fen Bilimleri', 'soruSayisi': 3, 'onay': true, 'anahtar': 'ABC', 'iptal': <Object>[]},
      ],
      'ogrenciler': [
        {
          'ogrenciId': 5,
          'ad': 'Deneme Öğrenci',
          'okulNo': '12',
          'sinif': '6-A',
          'cevaplar': {'11': 'AD-'},
        },
      ],
    };
    final api = _api({'/api/sinav/detay': detay, '/api/sinav/hazirlik': _hazirlik, '/api/sinav/sonuc': _sonuc});
    await t.pumpWidget(MaterialApp(home: SinavDetayEkrani(api: api, id: 1, yonetim: true)));
    await t.pumpAndSettle();
    await t.tap(find.text('Sonuç'));
    await t.pumpAndSettle();
    await t.tap(find.text('Deneme Öğrenci'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.byType(CevapIzgarasi), findsOneWidget);
    // 2. soru yanlış: işaret D, doğru şık B altında; 1. doğru (A), 3. boş
    expect(find.text('D'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('·'), findsOneWidget);
  });

  testWidgets('sonuç: sınavı hazırlayan öğretmen de öğrenci raporunda soru soru doğru/yanlış ve doğru şık görür', (t) async {
    genis(t);
    final detay = {
      'yonetim': false,
      'sinav': {..._detay['sinav'] as Map<String, Object>},
      'siniflar': [
        {'id': 1, 'name': '6-A'},
      ],
      'dersler': [
        {'id': 11, 'ders': 'Fen Bilimleri', 'soruSayisi': 3, 'onay': true, 'anahtar': 'ABC', 'iptal': <Object>[]},
      ],
      'ogrenciler': <Object>[],
      'cevapKayitlari': [
        {
          'ogrenciId': 5,
          'cevaplar': {'11': 'AD-'},
        },
      ],
    };
    final api = _api({'/api/sinav/detay': detay, '/api/sinav/hazirlik': _hazirlik, '/api/sinav/sonuc': _sonuc});
    await t.pumpWidget(MaterialApp(home: SinavDetayEkrani(api: api, id: 1, yonetim: false)));
    await t.pumpAndSettle();
    await t.tap(find.text('Sonuç'));
    await t.pumpAndSettle();
    await t.tap(find.text('Deneme Öğrenci'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.byType(CevapIzgarasi), findsOneWidget);
    // 2. soru yanlış: işaret D, doğru şık B altında; 1. doğru (A), 3. boş
    expect(find.text('D'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('·'), findsOneWidget);
  });
}

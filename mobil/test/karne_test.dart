import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neademy/cekirdek/api.dart';
import 'package:neademy/ekranlar/karne.dart';

Api _api(Map<String, Object> yanitlar, {List<String>? kayit}) => Api(
  istemci: MockClient((istek) async {
    kayit?.add('${istek.method} ${istek.url.path}?${istek.url.query}');
    return http.Response.bytes(utf8.encode(jsonEncode(yanitlar[istek.url.path] ?? {})), 200, headers: {'content-type': 'application/json'});
  }),
);

final _karne = {
  'rapor': '2026-11-02',
  'okul': {'ad': 'Deneme Okulu'},
  'sinif': {'id': 5, 'ad': '6-A'},
  'donem': {'id': 10, 'ad': '1. Dönem', 'baslangic': '2026-09-14', 'bitis': '2027-01-22'},
  'donemler': [
    {'id': 10, 'ad': '1. Dönem', 'baslangic': '2026-09-14', 'bitis': '2027-01-22'},
    {'id': 11, 'ad': '2. Dönem', 'baslangic': '2027-02-01', 'bitis': '2027-06-18'},
  ],
  'ogrenciler': [
    {
      'ogrenci': {
        'id': 30,
        'ad': 'Deniz Örnek',
        'okulNo': '12',
        'sinif': '6-A',
        'veli': 'Veli Örnek',
        'mentor': 'Ayşe Hoca',
        'mentorEtiket': 'Sınıf öğretmeni',
      },
      'genel': {'ortalama': 82.5, 'denemeOrtalama': 71, 'devamsiz': 2, 'izinli': 1, 'gec': 0, 'dersSaati': 40, 'odevYuzde': 80, 'etut': 1},
      'dersler': [
        {
          'ders': 'Matematik',
          'ogretmen': 'Ayşe Hoca',
          'yazililar': [
            {'ad': '1. Yazılı', 'tarih': '2026-10-20', 'puan': 85},
          ],
          'not': 85,
          'devam': {'toplam': 20, 'gelmedi': 2, 'gec': 0, 'izinli': 1},
        },
      ],
      'sinav': {
        'denemeler': [
          {
            'ad': 'Ekim Denemesi',
            'tarih': '2026-10-25',
            'ortalama': 71,
            'giren': 20,
            'siralama': {
              'sinif': {'sira': 3, 'sayi': 24},
            },
            'degisim': {'fark': 4.5, 'oran': 6},
          },
        ],
        'tekrar': [
          {'ders': 'Matematik', 'kazanim': 'Kesirlerle işlem', 'oran': 35},
        ],
        'katilmadi': <Object>[],
      },
      'odev': {
        'toplam': {'verilen': 10, 'yapildi': 8, 'duzeltme': 0, 'yapilmadi': 1, 'isaretsiz': 1, 'yuzde': 80},
        'dersler': [
          {'ders': 'Matematik', 'verilen': 10, 'yapildi': 8, 'yuzde': 80},
        ],
        'eksik': [
          {'baslik': 'Problemler', 'ders': 'Matematik', 'son': '2026-10-30', 'durum': 'isaretsiz'},
        ],
      },
      'etut': {
        'ozet': {'toplam': 1, 'geldi': 1, 'gelmedi': 0, 'izinli': 0, 'bekliyor': 0},
        'liste': [
          {'konu': 'Kesirler', 'tarih': '2026-10-28', 'saat': '15:00', 'ders': 'Matematik', 'devam': 'geldi'},
        ],
      },
      'gelisim': {
        'gozlemler': [
          {'baslik': 'Akademik süreç', 'ogretmen': 'Ayşe Hoca', 'ders': 'Matematik', 'metin': 'Derse çok katılıyor.'},
        ],
        'gorusmeler': <Object>[],
      },
    },
  ],
};

void main() {
  void genis(WidgetTester t) {
    t.view.physicalSize = const Size(390, 4800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  testWidgets('öğrenci karnesi: özet, dersler, sınav, ödev ve gözlemler', (t) async {
    genis(t);
    final kayit = <String>[];
    await t.pumpWidget(
      MaterialApp(
        home: KarneEkrani(api: _api({'/api/karne': _karne}, kayit: kayit), ogrenciId: 30),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Deniz Örnek'), findsOneWidget);
    expect(find.text('82.5'), findsOneWidget);
    expect(find.text('Not 85'), findsOneWidget);
    expect(find.text('Ekim Denemesi'), findsOneWidget);
    expect(find.text('Sınıfta 3/24'), findsOneWidget);
    expect(find.text('Kesirlerle işlem'), findsOneWidget);
    expect(find.textContaining('8/10 ödev yapıldı'), findsOneWidget);
    expect(find.text('Derse çok katılıyor.'), findsOneWidget);

    await t.tap(find.byType(DropdownButtonFormField<int>));
    await t.pumpAndSettle();
    await t.tap(find.text('2. Dönem').last);
    await t.pumpAndSettle();
    expect(kayit.last, 'GET /api/karne?id=30&donemId=11');
  });

  testWidgets('sınıf karneleri: öğrenciye dokununca karnesi açılır', (t) async {
    genis(t);
    final kayit = <String>[];
    await t.pumpWidget(
      MaterialApp(
        home: SinifKarneEkrani(api: _api({'/api/karne': _karne}, kayit: kayit), sinifId: 5),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('6-A sınıfı'), findsOneWidget);
    expect(find.textContaining('Not 82.5'), findsOneWidget);
    await t.tap(find.text('Deniz Örnek'));
    await t.pumpAndSettle();
    expect(kayit.last, 'GET /api/karne?id=30&donemId=10');
    expect(find.text('Dönem karnesi'), findsOneWidget);
  });
}

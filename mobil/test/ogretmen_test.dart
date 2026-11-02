import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neademy/cekirdek/api.dart';
import 'package:neademy/ekranlar/ders_detay.dart';
import 'package:neademy/ekranlar/derslerim.dart';
import 'package:neademy/ekranlar/odev_takip.dart';
import 'package:neademy/ekranlar/ogrencilerim.dart';
import 'package:neademy/ekranlar/veli_mesaj.dart';

Api _api(Map<String, Object> yanitlar) => Api(
  istemci: MockClient((istek) async {
    final yol = istek.url.path;
    return http.Response.bytes(utf8.encode(jsonEncode(yanitlar[yol] ?? {})), 200, headers: {'content-type': 'application/json'});
  }),
);

Future<void> _ciz(WidgetTester t, Widget ekran) async {
  await t.pumpWidget(MaterialApp(home: ekran));
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
}

void main() {
  final ders = {
    'dersSaati': 2,
    'atamaId': 5,
    'sinifId': 3,
    'sinif': '6-A',
    'ders': 'Matematik',
    'aralik': '09:00–09:40',
    'alindi': false,
    'gelmedi': 0,
    'durum': 'bekliyor',
  };

  testWidgets('derslerim günün derslerini ve etütlerini gösterir', (t) async {
    final api = _api({
      '/api/ders/liste': {
        'tarih': '2026-11-02',
        'bugun': '2026-11-02',
        'hafta_sonu': false,
        'tatil': null,
        'gunluk': [
          ders,
          {...ders, 'dersSaati': 3, 'sinif': '7-B', 'durum': 'tamam', 'alindi': true, 'gelmedi': 2},
          {'dersSaati': 5, 'kulupId': 1, 'sinif': 'Satranç', 'ders': 'Kulüp', 'aralik': '13:00–13:40', 'durum': 'bekliyor'},
        ],
        'atamalar': [],
        'etutler': [
          {'id': 1, 'konu': 'Denklemler', 'saat': '15:30', 'sure': 60, 'yer': 'A-12', 'ders': 'Matematik', 'kisi': 4},
        ],
      },
    });
    await _ciz(t, DerslerimEkrani(api: api));
    expect(find.text('6-A'), findsOneWidget);
    expect(find.text('7-B'), findsOneWidget);
    expect(find.text('Kulüp · Satranç'), findsOneWidget);
    expect(find.textContaining('Denklemler'), findsOneWidget);
    expect(find.text('Tamamlandı · 2 gelmedi'), findsOneWidget);
    expect(find.text('Günlük'), findsOneWidget);
    expect(find.text('Haftalık'), findsOneWidget);
    expect(find.text('Sınıflarım'), findsOneWidget);
  });

  testWidgets('derslerim sınıflarım sekmesi atamaları, haftalık sekme tabloyu gösterir', (t) async {
    final api = _api({
      '/api/ders/liste': {
        'tarih': '2026-11-02',
        'bugun': '2026-11-02',
        'hafta_sonu': false,
        'tatil': null,
        'gunluk': [],
        'etutler': [],
        'atamalar': [
          {'atamaId': 5, 'sinifId': 3, 'sinif': '6-A', 'ders': 'Matematik', 'ogrenciSayisi': 24, 'kisa': 'MA', 'renk': '#1f6feb'},
        ],
      },
      '/api/ders/hafta': {
        'bugun': '2026-11-02',
        'pazartesi': '2026-11-02',
        'zamanlar': ['08:30–09:10', '09:20–10:00'],
        'gunler': [
          for (var i = 0; i < 7; i++)
            {
              'tarih': '2026-11-0${2 + i}',
              'gun': (i + 1) % 7,
              'acik': i < 5,
              'tatil': null,
              'etutler': [],
              'dersler': i == 0
                  ? [
                      {...ders, 'dersSaati': 2, 'durum': 'tamam', 'renk': '#1f6feb', 'kisa': 'MA'},
                    ]
                  : [],
            },
        ],
      },
    });
    await _ciz(t, DerslerimEkrani(api: api));
    await t.tap(find.text('Sınıflarım'));
    await t.pumpAndSettle();
    expect(find.text('Matematik · 24 öğrenci'), findsOneWidget);
    await t.tap(find.text('Haftalık'));
    await t.pumpAndSettle();
    expect(find.text('1 saat ders'), findsOneWidget);
    expect(find.text('6-A ✓'), findsOneWidget);
  });

  testWidgets('ders detayı: öğrenciler, konular ve ödevler sekmeleri', (t) async {
    final api = _api({
      '/api/ders/ogrenciler': {
        'sinif': '6-A',
        'ders': 'Matematik',
        'yoklamaAlindi': false,
        'ogrenciler': [
          {'ogrenciId': 1, 'ad': 'Ali Deneme', 'devamsiz': 0},
        ],
      },
      '/api/ders/konular': {
        'konular': [
          {'id': 1, 'tarih': '2026-10-30', 'baslik': 'Doğal sayılar', 'aciklama': '', 'kazanim': 'MAT.6.1.1 – Doğal sayılarla işlem yapar.'},
        ],
      },
      '/api/ders/odevler': {
        'odevler': [
          {
            'id': 2,
            'baslik': 'Sayfa 40',
            'aciklama': '',
            'kazanim': '',
            'sonTarih': '2026-11-09',
            'gorunur': null,
            'toplam': 24,
            'dogrulandi': 3,
            'yapildi': 0,
            'soru': 0,
          },
        ],
      },
    });
    final atama = {...ders}..remove('dersSaati');
    await _ciz(t, DersDetayEkrani(api: api, ders: atama, tarih: '2026-11-02', bugun: '2026-11-02'));
    expect(find.text('Ali Deneme'), findsOneWidget);
    expect(find.text('Dersi bitir'), findsNothing);
    await t.tap(find.text('Konular'));
    await t.pumpAndSettle();
    expect(find.text('Doğal sayılar'), findsOneWidget);
    expect(find.text('Kazanım: MAT.6.1.1'), findsOneWidget);
    await t.tap(find.text('Ödevler'));
    await t.pumpAndSettle();
    expect(find.text('Sayfa 40'), findsOneWidget);
    expect(find.text('Takip et · 3/24 doğrulandı'), findsOneWidget);
  });

  testWidgets('ders bitir: yoklama listesi ve kazanım alanı çizilir', (t) async {
    final api = _api({
      '/api/yoklama/ogrenciler': {
        'ders': 'Matematik',
        'sinif': '6-A',
        'alindi': false,
        'tamam': false,
        'iptal': false,
        'konu': '',
        'kazanim': '',
        'kazanimKodlari': [],
        'aciklama': '',
        'odev': null,
        'ogrenciler': [
          {'ogrenciId': 1, 'ad': 'Ali Deneme', 'durum': 'geldi'},
          {'ogrenciId': 2, 'ad': 'Veli Deneme', 'durum': 'gelmedi'},
        ],
      },
      '/api/mufredat/kazanimlar': {
        'var': true,
        'uniteli': true,
        'gruplar': [
          {
            'anahtar': 'MAT.6.1',
            'no': 1,
            'ad': '',
            'baslik': '1. Ünite',
            'kazanimlar': [
              {'kod': 'MAT.6.1.1', 'metin': 'Doğal sayılarla işlem yapar.'},
            ],
          },
        ],
      },
    });
    await _ciz(t, DersBitirEkrani(api: api, ders: ders, tarih: '2026-11-02'));
    expect(find.text('Ali Deneme'), findsOneWidget);
    expect(find.text('Veli Deneme'), findsOneWidget);
    expect(find.text('Gelmedi'), findsWidgets);
    expect(find.text('Kazanım seç'), findsWidgets);
    await t.scrollUntilVisible(find.text('Dersi bitir'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Dersi bitir'), findsOneWidget);
  });

  testWidgets('ödev takibi bekleyenleri gösterir', (t) async {
    final api = _api({
      '/api/odev/ogretmen': {
        'bugun': '2026-11-02',
        'durumlar': {},
        'odevler': [
          {
            'id': 1,
            'baslik': 'Sayfa 40',
            'sonTarih': '2026-11-05',
            'ders': 'Matematik',
            'sinif': '6-A',
            'toplam': 20,
            'yapildi': 3,
            'yapilamadi': 1,
            'dogrulandi': 10,
            'duzeltme': 0,
            'soru': 1,
            'bekleyen': 4,
          },
          {
            'id': 2,
            'baslik': 'Sayfa 50',
            'sonTarih': '2026-11-06',
            'ders': 'Matematik',
            'sinif': '6-A',
            'toplam': 20,
            'yapildi': 0,
            'yapilamadi': 0,
            'dogrulandi': 20,
            'duzeltme': 0,
            'soru': 0,
            'bekleyen': 0,
          },
        ],
      },
    });
    await _ciz(t, OdevTakipOgretmenEkrani(api: api));
    expect(find.text('Sayfa 40'), findsOneWidget);
    expect(find.text('Sayfa 50'), findsNothing);
    expect(find.text('3 onay bekliyor'), findsOneWidget);
    expect(find.text('1 soru'), findsOneWidget);
  });

  testWidgets('öğrencilerim sınıfı ve öğrencileri listeler, profil açılır', (t) async {
    final api = _api({
      '/api/ogrencilerim': {
        'siniflar': [
          {
            'id': 3,
            'ad': '6-A',
            'kademe': 'ortaokul',
            'ogrenciler': [
              {'id': 1, 'ad': 'Ali Deneme', 'okulNo': '12', 'toplam': 10, 'geldi': 8, 'gelmedi': 1, 'gec': 1, 'izinli': 0},
            ],
          },
        ],
      },
      '/api/ogrencilerim/profil': {
        'ogrenci': {'id': 1, 'ad': 'Ali Deneme', 'okulNo': '12', 'sinif': '6-A'},
        'veliler': [
          {'ad': 'Veli Deneme', 'telefon': '0500 000 00 00'},
        ],
        'devam': {'toplam': 10, 'geldi': 8, 'gelmedi': 1, 'gec': 1, 'izinli': 0},
        'dersler': [
          {'ders': 'Matematik', 'toplam': 5, 'geldi': 4, 'gelmedi': 1, 'gec': 0, 'izinli': 0},
        ],
        'son': [
          {'tarih': '2026-10-30', 'dersSaati': 2, 'ders': 'Matematik', 'durum': 'gelmedi'},
        ],
      },
      '/api/ogrencilerim/dosya': {
        'bilgi': {'email': '', 'yakinAd': 'Yakın Deneme', 'yakinYakinlik': 'Hala', 'yakinTelefon': '0500 111 11 11'},
        'donemler': [
          {
            'id': 1,
            'ad': '1. Dönem',
            'girisler': [
              {'baslik': 'Sosyal', 'ogretmen': 'Hoca', 'ders': 'Matematik', 'metin': 'Gayretli.'},
            ],
            'gorusmeler': [],
          },
        ],
        'odevler': [
          {'id': 1, 'baslik': 'Sayfa 40', 'son': '2026-11-05', 'ders': 'Matematik', 'durum': 'verildi'},
        ],
        'kulup': {'ad': 'Satranç', 'geldi': 3, 'toplam': 4},
        'etutler': [],
      },
    });
    await _ciz(t, OgrencilerimEkrani(api: api));
    expect(find.text('Ali Deneme'), findsOneWidget);
    expect(find.text('%90'), findsOneWidget);
    await t.tap(find.text('Ali Deneme'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Veli · Veli Deneme'), findsOneWidget);
    expect(find.text('Gelişim · 1. Dönem'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Satranç'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Satranç'), findsOneWidget);
  });

  testWidgets('veli bilgilendirme gönderilen mesajları gösterir', (t) async {
    final api = _api({
      '/api/duyuru/liste': {
        'duyurular': [],
        'mesajlar': [
          {'id': 1, 'baslik': 'Gezi', 'metin': 'Cuma gezi var.', 'tarih': '2026-11-01', 'hedef': '6-A velileri', 'okunan': 3},
        ],
      },
      '/api/duyuru/secenek': {
        'siniflar': [
          {'id': 3, 'ad': '6-A'},
        ],
        'ogrenciler': [
          {'id': 1, 'ad': 'Ali Deneme', 'sinifId': 3},
        ],
      },
    });
    await _ciz(t, VeliBilgilendirmeEkrani(api: api));
    expect(find.text('Gezi'), findsOneWidget);
    expect(find.text('3 okudu'), findsOneWidget);
    await t.tap(find.text('Yeni mesaj'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Gönder'), findsOneWidget);
  });
}

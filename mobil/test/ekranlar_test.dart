import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neademy/cekirdek/api.dart';
import 'package:neademy/ekranlar/devamsizlik.dart';
import 'package:neademy/ekranlar/etut.dart';
import 'package:neademy/ekranlar/teslim.dart';
import 'package:neademy/ekranlar/duyurular.dart';
import 'package:neademy/ekranlar/notlarim.dart';
import 'package:neademy/ekranlar/odevler.dart';
import 'package:neademy/ekranlar/ogrencim.dart';
import 'package:neademy/ekranlar/program.dart';

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
  testWidgets('devamsızlık çizilir', (t) async {
    final api = _api({
      '/api/yoklama/devam': {
        'cocuklar': [
          {
            'ad': 'Ayşe Deneme',
            'say': {'geldi': 8, 'gelmedi': 1, 'gec': 1, 'izinli': 0},
            'toplam': 10,
            'kayitlar': [
              {'tarih': '2026-10-26', 'dersSaati': 1, 'ders': 'Matematik', 'durum': 'gelmedi'},
              {'tarih': '2026-10-27', 'dersSaati': 2, 'ders': 'Fizik', 'durum': 'geldi'},
            ],
          },
        ],
      },
    });
    await _ciz(t, DevamsizlikEkrani(api: api, baslik: 'Devamsızlık'));
    expect(find.text('Ayşe Deneme'), findsWidgets);
  });

  testWidgets('duyurular çizilir', (t) async {
    final api = _api({
      '/api/duyuru/liste': {
        'duyurular': [
          {'id': 1, 'baslik': 'Veli toplantısı', 'metin': 'Cuma 17:00', 'tarih': 1793000000000, 'yazan': 'Müdür', 'yeni': true, 'hedef': 'Herkes'},
        ],
        'mesajlar': [
          {'id': 2, 'baslik': 'Ödev hk.', 'metin': 'Merhaba', 'tarih': 1793000000000, 'yazan': 'Öğretmen', 'yeni': false, 'hedef': 'Veli'},
        ],
      },
    });
    await _ciz(t, DuyurularEkrani(api: api));
    expect(find.text('Veli toplantısı'), findsOneWidget);
    await t.tap(find.textContaining('Mesajlar'));
    await t.pumpAndSettle();
    expect(find.text('Ödev hk.'), findsOneWidget);
  });

  testWidgets('ödevler çizilir', (t) async {
    final api = _api({
      '/api/ders/odevlerim': {
        'bugun': '2026-11-02',
        'durumlar': {
          'verildi': {'ad': 'Verildi', 'aciklama': ''},
          'dogrulandi': {'ad': 'Doğrulandı', 'aciklama': ''},
        },
        'ogrenciler': [
          {
            'id': 1,
            'ad': 'Ayşe Deneme',
            'odevler': [
              {
                'id': 1,
                'baslik': 'Problemler',
                'aciklama': 'Sayfa 12',
                'kazanim': 'M.9.1',
                'sonTarih': '2026-11-04',
                'ders': 'Matematik',
                'ogretmen': 'A. Hoca',
                'durum': 'verildi',
                'dosya': 0,
                'yeniMesaj': 0,
              },
              {
                'id': 2,
                'baslik': 'Deney raporu',
                'aciklama': '',
                'kazanim': '',
                'sonTarih': '2026-10-30',
                'ders': 'Fizik',
                'ogretmen': 'B. Hoca',
                'durum': 'dogrulandi',
                'dosya': 1,
                'yeniMesaj': 1,
              },
            ],
          },
        ],
      },
    });
    await _ciz(t, OdevlerEkrani(api: api));
    expect(find.text('Problemler'), findsOneWidget);
    expect(find.text('Sayfa 12'), findsOneWidget);
  });

  testWidgets('ders programı çizilir', (t) async {
    final api = _api({
      '/api/ders/program': {
        'bugun': '2026-11-02',
        'pazartesi': '2026-11-02',
        'cocuklar': [
          {'id': 1, 'ad': 'Ayşe Deneme'},
          {'id': 2, 'ad': 'Ali Deneme'},
        ],
        'cocuk': 1,
        'sinif': '9-A',
        'gunler': [
          for (var i = 0; i < 5; i++)
            {
              'tarih': '2026-11-0${2 + i}',
              'gun': i,
              'acik': true,
              'tatil': null,
              'dersler': [
                {
                  'dersSaati': 1,
                  'ders': 'Matematik',
                  'ogretmen': 'A. Hoca',
                  'aralik': '08:30-09:10',
                  'iptal': i == 1,
                  'islendi': i == 0,
                  'konu': 'Fonksiyonlar',
                  'devam': i == 0 ? 'gec' : '',
                  'odevler': [],
                  'renk': '#2E9E5B',
                },
              ],
              'etutler': i == 2
                  ? [
                      {
                        'id': 1,
                        'konu': 'Soru çözümü',
                        'saat': '15:00',
                        'sure': 40,
                        'yer': 'A1',
                        'ders': 'Fizik',
                        'ogretmen': 'B. Hoca',
                        'yanit': 'bekliyor',
                        'devam': '',
                      },
                    ]
                  : [],
            },
        ],
      },
    });
    await _ciz(t, ProgramEkrani(api: api));
    expect(find.text('Matematik'), findsWidgets);
    expect(find.text('Etüt'), findsOneWidget);
  });

  testWidgets('sınav sonuçları çizilir', (t) async {
    Map<String, dynamic> sinav(String ad, num ort) => {
      'ad': ad,
      'tarih': '2026-10-20',
      'yanlisKat': 4,
      'ortalama': ort,
      'sira': 3,
      'giren': 28,
      'yazili': false,
      'kapsam': ['Fonksiyonlar'],
      'siralama': {
        'sinif': {'sira': 3, 'sayi': 28},
        'okul': {'sira': 20, 'sayi': 200},
        'genel': {'sira': 900, 'sayi': 5000},
      },
      'dersler': [
        {
          'ders': 'Matematik',
          'soruSayisi': 20,
          'dogru': 14,
          'yanlis': 4,
          'bos': 2,
          'net': 13,
          'puan': 65,
          'kazanimlar': [
            {
              'kazanim': 'Fonksiyon tanımı',
              'durum': 'Edinildi',
              'sorular': [1, 2],
              'dogru': 2,
              'toplam': 2,
            },
            {
              'kazanim': 'Bileşke fonksiyon',
              'durum': 'Eksik',
              'sorular': [3, 4],
              'dogru': 0,
              'toplam': 2,
            },
          ],
        },
      ],
    };
    final api = _api({
      '/api/sinav/notlarim': {
        'ogrenciler': [
          {
            'ad': 'Ayşe Deneme',
            'sinavlar': [sinav('1. Dönem 1. Deneme Sınavı', 72), sinav('Ekim Sınavı', 38)],
          },
          {'ad': 'Ali Deneme', 'sinavlar': []},
        ],
      },
    });
    await _ciz(t, NotlarimEkrani(api: api));
    expect(find.text('1. Dönem 1. Deneme Sınavı'), findsOneWidget);
    expect(find.textContaining('28 öğrenci içinde 3. sıra'), findsWidgets);
  });

  testWidgets('öğrencim çizilir', (t) async {
    final api = _api({
      '/api/ogrencim': {
        'ogrenciler': [
          {
            'id': 1,
            'ad': 'Ayşe Deneme',
            'okulNo': '123',
            'okul': 'Pilot Lise',
            'sinif': '9-A',
            'rehber': {'ad': 'C. Hoca', 'telefon': '', 'etiket': 'Sınıf öğretmeni'},
            'ogretmenler': [
              {'ders': 'Matematik', 'ad': 'A. Hoca'},
            ],
            'veliler': [
              {'ad': 'Veli Deneme', 'telefon': '5551112233'},
            ],
            'devam': {'toplam': 10, 'gelmedi': 1, 'gec': 1, 'izinli': 0, 'yuzde': 90},
            'odev': {'yapilacak': 2, 'onayda': 1, 'geciken': 0},
            'kulup': 'Satranç',
          },
        ],
      },
    });
    await _ciz(t, OgrencimEkrani(api: api));
    expect(find.text('Ayşe Deneme'), findsOneWidget);
    expect(find.text('%90'), findsOneWidget);
  });

  testWidgets('etüt (veli ve öğretmen) çizilir', (t) async {
    final gelecek = '${DateTime.now().year + 1}-03-10';
    final api = _api({
      '/api/etut/liste': {
        'cocuklar': [
          {'ogrenciId': 1, 'ad': 'Ayşe Deneme'},
        ],
        'etutler': [
          {
            'id': 1,
            'ders': 'Fizik',
            'konu': 'Kuvvet',
            'tarih': gelecek,
            'saat': '15:30',
            'sureDk': 40,
            'yer': 'A1',
            'not': '',
            'durum': 'planli',
            'ogretmen': 'B. Hoca',
            'ogrenciId': 1,
            'ogrenci': 'Ayşe Deneme',
            'yanit': 'bekliyor',
            'devam': '',
          },
          {
            'id': 2,
            'ders': 'Kimya',
            'konu': 'Mol',
            'tarih': '2020-01-10',
            'saat': '14:00',
            'sureDk': 40,
            'yer': '',
            'not': '',
            'durum': 'planli',
            'ogretmen': 'C. Hoca',
            'ogrenciId': 1,
            'ogrenci': 'Ayşe Deneme',
            'yanit': 'gelecek',
            'devam': 'geldi',
          },
        ],
      },
    });
    await _ciz(t, EtutEkrani(api: api, rol: 'veli'));
    expect(find.text('Gelecek'), findsOneWidget);
    expect(find.text('Gelmeyecek'), findsOneWidget);

    final ogretmen = _api({
      '/api/etut/liste': {
        'etutler': [
          {
            'id': 1,
            'ders': 'Fizik',
            'konu': 'Kuvvet',
            'tarih': gelecek,
            'saat': '15:30',
            'sureDk': 40,
            'yer': 'A1',
            'not': '',
            'durum': 'planli',
            'ogretmen': 'B. Hoca',
            'katilimcilar': [
              {'ogrenciId': 1, 'ad': 'Ayşe Deneme', 'yanit': 'gelecek', 'devam': ''},
            ],
          },
        ],
      },
    });
    await _ciz(t, EtutEkrani(api: ogretmen, rol: 'ogretmen'));
    expect(find.text('Etüt aç'), findsOneWidget);
    expect(find.text('1 gelecek'), findsOneWidget);
  });

  testWidgets('teslim yetkileri çizilir', (t) async {
    final api = _api({
      '/api/teslim/liste': {
        'ogrenciler': [
          {
            'id': 1,
            'ad': 'Ayşe Deneme',
            'sinif': '9-A',
            'kisiler': [
              {'id': 5, 'ad': 'Servis Şoförü', 'yakinlik': 'Servis', 'telefon': '5551112233', 'baglanti': 'abc'},
            ],
          },
        ],
      },
    });
    await _ciz(t, TeslimYetkileriEkrani(api: api));
    expect(find.text('Servis Şoförü'), findsOneWidget);
    expect(find.text('Özel bağlantı açık'), findsOneWidget);
    expect(find.text('Kişi ekle'), findsOneWidget);
  });

  testWidgets('teslim kodu QR olarak çizilir', (t) async {
    final api = _api({
      '/api/teslim/kod': {
        'kod': 'ABC234',
        'omur': 45,
        'kisi': {'ad': 'Veli Deneme', 'yakinlik': 'Veli'},
        'ogrenciler': [
          {'ad': 'Ayşe Deneme', 'sinif': '9-A', 'okul': 'Pilot Lise'},
        ],
      },
      '/api/teslim/durum': {'talep': null},
    });
    await t.pumpWidget(MaterialApp(home: TeslimKoduEkrani(api: api)));
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('ABC 234'), findsOneWidget);
    expect(find.text('Ayşe Deneme'), findsOneWidget);
    await t.pumpWidget(const SizedBox()); // zamanlayıcıları kapat
    expect(t.takeException(), isNull);
  });
}

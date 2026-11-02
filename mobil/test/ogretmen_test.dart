import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neademy/cekirdek/api.dart';
import 'package:neademy/ekranlar/derslerim.dart';

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
    'dersSaati': 2, 'atamaId': 5, 'sinifId': 3, 'sinif': '6-A', 'ders': 'Matematik', 'aralik': '09:00–09:40',
    'alindi': false, 'gelmedi': 0, 'durum': 'bekliyor',
  };

  testWidgets('derslerim günün derslerini ve etütlerini gösterir', (t) async {
    final api = _api({
      '/api/ders/liste': {
        'tarih': '2026-11-02', 'bugun': '2026-11-02', 'hafta_sonu': false, 'tatil': null,
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
    expect(find.text('6-A · Matematik'), findsOneWidget);
    expect(find.text('7-B · Matematik'), findsOneWidget);
    expect(find.text('Satranç'), findsOneWidget);
    expect(find.text('Denklemler'), findsOneWidget);
    expect(find.text('İşlendi'), findsOneWidget);
  });

  testWidgets('ders bitir: yoklama listesi ve kazanım alanı çizilir', (t) async {
    final api = _api({
      '/api/yoklama/ogrenciler': {
        'ders': 'Matematik', 'sinif': '6-A', 'alindi': false, 'tamam': false, 'iptal': false, 'konu': '', 'kazanim': '',
        'kazanimKodlari': [], 'aciklama': '', 'odev': null,
        'ogrenciler': [
          {'ogrenciId': 1, 'ad': 'Ali Deneme', 'durum': 'geldi'},
          {'ogrenciId': 2, 'ad': 'Veli Deneme', 'durum': 'gelmedi'},
        ],
      },
      '/api/mufredat/kazanimlar': {
        'var': true, 'uniteli': true,
        'gruplar': [
          {'anahtar': 'MAT.6.1', 'no': 1, 'ad': '', 'baslik': '1. Ünite', 'kazanimlar': [{'kod': 'MAT.6.1.1', 'metin': 'Doğal sayılarla işlem yapar.'}]},
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
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neademy/cekirdek/api.dart';
import 'package:neademy/ekranlar/ders_programi_yonetim.dart';

Api _api(Map<String, Object> yanitlar, List<String> kayit, List<Map<String, dynamic>> govdeler) => Api(
  istemci: MockClient((istek) async {
    kayit.add('${istek.method} ${istek.url.path}');
    if (istek.method == 'POST') govdeler.add(jsonDecode(istek.body) as Map<String, dynamic>);
    return http.Response.bytes(utf8.encode(jsonEncode(yanitlar[istek.url.path] ?? {})), 200, headers: {'content-type': 'application/json'});
  }),
);

final _yanitlar = <String, Object>{
  '/api/yonetim/sinif-yapisi': {
    'okul': {
      'gunler': [
        {'no': 1, 'ad': 'Pazartesi', 'acik': true},
        {'no': 2, 'ad': 'Salı', 'acik': true},
        {'no': 6, 'ad': 'Cumartesi', 'acik': false},
      ],
      'saatler': [
        {'bas': '08:30', 'bit': '09:10'},
        {'bas': '09:20', 'bit': '10:00'},
      ],
    },
    'siniflar': [
      {'id': 5, 'subeId': 1, 'sube': 'Deneme Okulu', 'kademe': 'Ortaokul', 'ad': '6-A'},
    ],
    'ogretmenler': [
      {'uyelikId': 20, 'userId': 200, 'ad': 'Ayşe Hoca', 'subeId': 1, 'sube': 'Deneme Okulu'},
    ],
  },
  '/api/yonetim/atamalar': {
    'atamalar': [
      {
        'id': 70,
        'dersId': 1,
        'ders': 'Matematik',
        'ogretmenUyelikId': 20,
        'ogretmen': 'Ayşe Hoca',
        'ogretmenUserId': 200,
        'haftalikSaat': 4,
        'kullanilan': 1,
        'kisa': 'MAT',
        'renk': '#2563eb',
      },
    ],
  },
  '/api/yonetim/program': {
    'hucreler': [
      {'gun': 1, 'saat': 1, 'atamaId': 70, 'ders': 'Matematik', 'ogretmen': 'Ayşe Hoca', 'kisa': 'MAT', 'renk': '#2563eb'},
    ],
  },
  '/api/yonetim/ogretmen-programi': {
    'hucreler': [
      {'gun': 2, 'saat': 2, 'sinif': '7-B', 'ders': 'Matematik', 'renk': '#2563eb'},
    ],
  },
  '/api/yonetim/ogretmen-durum': {'kapali': [], 'azami': 20, 'gorevler': []},
  '/api/yonetim/gorevler': {
    'gorevler': [
      {
        'id': 1,
        'userId': 200,
        'ogretmen': 'Ayşe Hoca',
        'tur': 'nobet',
        'ad': 'Bahçe nöbeti',
        'yer': 'Bahçe',
        'tekrar': 'haftalik',
        'gun': 1,
        'tarih': null,
        'saatler': [1],
        'bas': '08:00',
        'bit': '08:30',
      },
    ],
  },
};

Future<void> _ac(WidgetTester t, Api api) async {
  t.view.physicalSize = const Size(390, 2400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(MaterialApp(home: DersProgramiYonetimEkrani(api: api)));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('sınıf programı: dolu hücre görünür, fırça seçilir, program temizlenir', (t) async {
    final kayit = <String>[];
    final govdeler = <Map<String, dynamic>>[];
    await _ac(t, _api(_yanitlar, kayit, govdeler));
    expect(find.text('MAT'), findsOneWidget);

    await t.tap(find.textContaining('Matematik · Hoca'));
    await t.pumpAndSettle();
    // 2. gün 1. saat boş: ikinci sütunun ilk satırı
    final bos = find.byType(InkWell).evaluate().toList();
    expect(bos, isNotEmpty);
    await t.tap(find.text('Programı temizle'));
    await t.pumpAndSettle();
    expect(find.textContaining('silinsin mi'), findsOneWidget);
    await t.tap(find.text('Temizle'));
    await t.pumpAndSettle();
    expect(kayit, contains('POST /api/yonetim/program-temizle'));
    expect(govdeler.last['sinifId'], 5);
  });

  testWidgets('öğretmen programı: müsait olmadığı saat işaretlenip kaydedilir', (t) async {
    final kayit = <String>[];
    final govdeler = <Map<String, dynamic>>[];
    await _ac(t, _api(_yanitlar, kayit, govdeler));
    await t.tap(find.text('Öğretmen'));
    await t.pumpAndSettle();
    await t.tap(find.text('Öğretmen seçin'));
    await t.pumpAndSettle();
    await t.tap(find.text('Ayşe Hoca').last);
    await t.pumpAndSettle();
    expect(find.text('7-B'), findsOneWidget);

    await t.tap(find.text('Müsaitliği düzenle'));
    await t.pumpAndSettle();
    await t.tap(find.text('Kaydet'));
    await t.pumpAndSettle();
    expect(kayit, contains('POST /api/yonetim/ogretmen-musait'));
    expect(govdeler.last['userId'], 200);
    expect(govdeler.last['azami'], '20');
  });

  testWidgets('nöbet ve görevler listelenir, silme onaydan sonra gider', (t) async {
    final kayit = <String>[];
    final govdeler = <Map<String, dynamic>>[];
    await _ac(t, _api(_yanitlar, kayit, govdeler));
    await t.tap(find.text('Nöbet / görev'));
    await t.pumpAndSettle();
    expect(find.text('Bahçe nöbeti · Bahçe'), findsOneWidget);
    expect(find.textContaining('Her Pazartesi'), findsOneWidget);

    await t.tap(find.text('Düzenle'));
    await t.pumpAndSettle();
    await t.tap(find.byIcon(Icons.delete_outline));
    await t.pumpAndSettle();
    await t.tap(find.text('Sil').last);
    await t.pumpAndSettle();
    expect(kayit, contains('POST /api/yonetim/gorev-sil'));
    expect(govdeler.last['id'], 1);
  });
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neademy/cekirdek/api.dart';
import 'package:neademy/ekranlar/gelisim_yonetim.dart';

Api _api(Map<String, Object> yanitlar, {List<String>? kayit}) => Api(
  istemci: MockClient((istek) async {
    kayit?.add('${istek.method} ${istek.url.path}${istek.method == 'POST' ? ' ${istek.body}' : ''}');
    return http.Response.bytes(utf8.encode(jsonEncode(yanitlar[istek.url.path] ?? {})), 200, headers: {'content-type': 'application/json'});
  }),
);

final _ayar = {
  'bugun': '2026-11-02',
  'basliklar': [
    {'id': 1, 'ad': 'Akademik süreç', 'aciklama': 'Derse katılım', 'sira': 1, 'aktif': true, 'girisSayisi': 3},
    {'id': 2, 'ad': 'Sosyal gelişim', 'aciklama': '', 'sira': 2, 'aktif': false, 'girisSayisi': 0},
  ],
  'donemler': [
    {'id': 10, 'ad': 'Kasım gözlemi', 'baslangic': '2026-11-01', 'bitis': '2026-11-15', 'toplantiTarihi': '2026-11-20', 'durum': 'acik'},
    {'id': 11, 'ad': 'Ekim gözlemi', 'baslangic': '2026-10-01', 'bitis': '2026-10-15', 'toplantiTarihi': '', 'durum': 'kapandi'},
  ],
};

Future<void> _ac(WidgetTester t, Api api) async {
  t.view.physicalSize = const Size(390, 2400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(MaterialApp(home: GelisimYonetimEkrani(api: api)));
  await t.pumpAndSettle();
}

void main() {
  final yanit = <String, Object>{
    '/api/gelisim/ayar': _ayar,
    '/api/gelisim/siniflar': {
      'siniflar': [
        {
          'id': 5,
          'ad': '6-A',
          'ogrenciler': [
            {'id': 30, 'ad': 'Deniz Örnek', 'okulNo': '12'},
          ],
        },
      ],
      'donemler': _ayar['donemler'],
    },
    '/api/gelisim/rapor': {
      'ogrenci': {'id': 30, 'ad': 'Deniz Örnek', 'okulNo': '12', 'sinif': '6-A'},
      'basliklar': [
        {'id': 1, 'ad': 'Akademik süreç', 'aciklama': ''},
      ],
      'donemler': [
        {
          'id': 10,
          'ad': 'Kasım gözlemi',
          'baslangic': '2026-11-01',
          'bitis': '2026-11-15',
          'toplantiTarihi': '',
          'durum': 'acik',
          'girisler': [
            {'baslikId': 1, 'ogretmenId': 20, 'ogretmen': 'Ayşe Hoca', 'ders': 'Matematik', 'metin': 'Derse çok katılıyor.'},
          ],
          'gorusmeler': [],
        },
      ],
      'donemsizGorusmeler': [],
      'bugun': '2026-11-02',
    },
    '/api/gelisim/takip': {
      'donem': _ayar['donemler'],
      'baslikSayisi': 1,
      'ogretmenler': [
        {'id': 20, 'ad': 'Ayşe Hoca', 'dersler': 'Matematik', 'ogrenciSayisi': 4, 'tamam': 4, 'kismi': 0},
      ],
    },
  };

  testWidgets('öğrenci raporu açılır', (t) async {
    await _ac(t, _api(yanit));
    await t.tap(find.text('Sınıf'));
    await t.pumpAndSettle();
    await t.tap(find.text('6-A').last);
    await t.pumpAndSettle();
    await t.tap(find.text('Öğrenci'));
    await t.pumpAndSettle();
    await t.tap(find.textContaining('Deniz Örnek').last);
    await t.pumpAndSettle();
    await t.tap(find.text('Raporu aç'));
    await t.pumpAndSettle();
    expect(find.text('Derse çok katılıyor.'), findsOneWidget);
    expect(find.text('Ayşe Hoca · Matematik'), findsOneWidget);
  });

  testWidgets('dönem takibi ve yeniden açma', (t) async {
    final kayit = <String>[];
    await _ac(t, _api(yanit, kayit: kayit));
    await t.tap(find.text('Dönemler'));
    await t.pumpAndSettle();
    expect(find.text('Kasım gözlemi'), findsOneWidget);
    await t.tap(find.text('Ekim gözlemi'));
    await t.pumpAndSettle();
    expect(find.textContaining('1/1 tamam'), findsOneWidget);
    await t.tap(find.text('Yeniden aç (7 gün)'));
    await t.pumpAndSettle();
    await t.tap(find.text('Aç'));
    await t.pumpAndSettle();
    expect(kayit.any((x) => x.startsWith('POST /api/gelisim/donem-kaydet') && x.contains('"bitis":"2026-11-09"')), isTrue);
  });

  testWidgets('başlık taşınır ve pasif başlık işaretlenir', (t) async {
    final kayit = <String>[];
    await _ac(t, _api(yanit, kayit: kayit));
    await t.tap(find.text('Başlıklar'));
    await t.pumpAndSettle();
    expect(find.text('Pasif'), findsOneWidget);
    await t.tap(find.byTooltip('Aşağı taşı').first);
    await t.pumpAndSettle();
    expect(kayit.any((x) => x.startsWith('POST /api/gelisim/baslik-sira') && x.contains('asagi')), isTrue);
  });
}

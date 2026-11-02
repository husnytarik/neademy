import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neademy/cekirdek/api.dart';
import 'package:neademy/cekirdek/foto.dart';
import 'package:neademy/ekranlar/odev_detay.dart';

Api _api(Map<String, Object> yanitlar, {List<String>? kayit}) => Api(
  istemci: MockClient((istek) async {
    kayit?.add(
      '${istek.method} ${istek.url.path}${istek.url.query.isEmpty ? '' : '?${istek.url.query}'}${istek.method == 'POST' && (istek.headers['Content-Type'] ?? '').startsWith('application/json') ? ' ${istek.body}' : ''}',
    );
    return http.Response.bytes(utf8.encode(jsonEncode(yanitlar[istek.url.path] ?? {})), 200, headers: {'content-type': 'application/json'});
  }),
);

Map<String, Object> _detay(String rol, String kod) => {
  'rol': rol,
  'bugun': '2026-11-02',
  'durumlar': {
    'verildi': {'ad': 'Verildi', 'aciklama': 'Henüz işaretlenmedi'},
    'yapildi': {'ad': 'Yapıldı', 'aciklama': 'Öğretmen onayı bekleniyor'},
    'yapilamadi': {'ad': 'Yapılamadı', 'aciklama': ''},
    'dogrulandi': {'ad': 'Doğrulandı', 'aciklama': 'Öğretmen kontrol etti'},
  },
  'odev': {
    'id': 7,
    'baslik': 'Problemler',
    'aciklama': 'Sayfa 12',
    'kazanim': 'M.9.1',
    'sonTarih': '2026-11-04',
    'ders': 'Matematik',
    'sinif': '9-A',
    'ogretmen': 'A. Hoca',
  },
  'ogrenci': {'id': 3, 'ad': 'Ayşe Deneme'},
  'durum': {'kod': kod, 'ogrenciNotu': '', 'ogretmenNotu': ''},
  'dosyalar': <Object>[],
  'mesajlar': [
    {'id': 1, 'yazan': 'A. Hoca', 'yazanRol': 'ogretmen', 'metin': 'Önce örnekleri çöz.', 'zaman': 1793000000000, 'yeni': false, 'dosyalar': <Object>[]},
  ],
};

void main() {
  void genis(WidgetTester t) {
    t.view.physicalSize = const Size(390, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  testWidgets('öğrenci: yaptım diyebilir ve geri alabilir', (t) async {
    genis(t);
    final kayit = <String>[];
    await t.pumpWidget(
      MaterialApp(
        home: OdevDetayEkrani(api: _api({'/api/odev/detay': _detay('ogrenci', 'verildi'), '/api/odev/isaretle': {}}, kayit: kayit), odevId: 7),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Problemler'), findsOneWidget);
    expect(find.text('Sayfa 12'), findsOneWidget);
    expect(find.text('Önce örnekleri çöz.'), findsOneWidget);
    expect(find.text('Geri al'), findsNothing);
    await t.tap(find.text('Yaptım'));
    await t.pumpAndSettle();
    expect(kayit.any((x) => x.startsWith('POST /api/odev/isaretle') && x.contains('"durum":"yapildi"') && x.contains('"odevId":7')), isTrue);
  });

  testWidgets('öğrenci: teslim fotoğrafı yüklenir, soru fotoğrafla gönderilir', (t) async {
    genis(t);
    final kayit = <String>[];
    galeridenFotoSec = () async => Uint8List.fromList([0xff, 0xd8, 0xff, 1, 2, 3]);
    final api = _api({
      '/api/odev/detay': _detay('ogrenci', 'yapildi'),
      '/api/odev/dosya-yukle': {'id': 55},
      '/api/odev/mesaj-gonder': {},
    }, kayit: kayit);
    await t.pumpWidget(MaterialApp(home: OdevDetayEkrani(api: api, odevId: 7)));
    await t.pumpAndSettle();
    expect(find.text('Geri al'), findsOneWidget);

    await t.tap(find.text('Fotoğraf ekle'));
    await t.pumpAndSettle();
    expect(kayit, contains('POST /api/odev/dosya-yukle?odevId=7&amac=teslim'));

    await t.tap(find.text('Fotoğraf'));
    await t.pumpAndSettle();
    expect(kayit, contains('POST /api/odev/dosya-yukle?odevId=7&amac=soru'));

    await t.enterText(find.widgetWithText(TextField, 'Sorunuzu yazın').first, 'Üçüncü soruyu anlamadım');
    await t.tap(find.text('Soruyu gönder'));
    await t.pumpAndSettle();
    expect(kayit.any((x) => x.startsWith('POST /api/odev/mesaj-gonder') && x.contains('"dosyaIds":[55]') && x.contains('Üçüncü soruyu anlamadım')), isTrue);
  });

  testWidgets('doğrulanmış ödev ve veli: salt okunur', (t) async {
    genis(t);
    await t.pumpWidget(MaterialApp(home: OdevDetayEkrani(api: _api({'/api/odev/detay': _detay('ogrenci', 'dogrulandi')}), odevId: 7)));
    await t.pumpAndSettle();
    expect(find.textContaining('artık değiştirilemez'), findsOneWidget);
    expect(find.text('Yaptım'), findsNothing);
    expect(find.text('Fotoğraf ekle'), findsNothing);

    await t.pumpWidget(
      MaterialApp(
        home: OdevDetayEkrani(key: UniqueKey(), api: _api({'/api/odev/detay': _detay('veli', 'verildi')}), odevId: 7, ogrenciId: 3),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Ayşe Deneme · 9-A'), findsOneWidget);
    expect(find.text('Yaptım'), findsNothing);
    expect(find.text('Soruyu gönder'), findsNothing);
  });
}

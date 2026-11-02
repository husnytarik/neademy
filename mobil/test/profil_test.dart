import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neademy/cekirdek/api.dart';
import 'package:neademy/ekranlar/profil.dart';

Api _api(Map<String, Object> yanitlar, {List<String>? kayit, List<Object?>? govdeler}) => Api(
  istemci: MockClient((istek) async {
    kayit?.add('${istek.method} ${istek.url.path}');
    if (istek.method == 'POST') govdeler?.add(jsonDecode(utf8.decode(istek.bodyBytes)));
    return http.Response.bytes(utf8.encode(jsonEncode(yanitlar[istek.url.path] ?? {'tamam': true})), 200, headers: {'content-type': 'application/json'});
  }),
);

final _bilgi = {
  'hesap': [
    {'ad': 'Ad soyad', 'deger': 'Deniz Örnek'},
    {'ad': 'Giriş telefonu', 'deger': '5550000000'},
  ],
  'okul': {
    'baslik': 'Okul bilgilerim',
    'satirlar': [
      {'ad': 'Sınıf', 'deger': '6-A'},
    ],
  },
  'yakinlar': ['Eş', 'Anne', 'Baba', 'Diğer'],
  'adDegistir': false,
  'duzenle': {
    'email': 'deniz@ornek.com',
    'telefon2': '5321234567',
    'il': 'Ankara',
    'ilce': '',
    'adres': '',
    'yakinAd': 'Ayşe Örnek',
    'yakinYakinlik': 'Teyze',
    'yakinTelefon': '5329876543',
  },
};

final _cihazlar = {
  'cihazlar': [
    {'anahtar': 'aaaaaaaaaaaa', 'cihaz': 'iPhone 15', 'sonKullanim': DateTime(2026, 11, 2, 15, 30).millisecondsSinceEpoch, 'buCihaz': true},
    {'anahtar': 'bbbbbbbbbbbb', 'cihaz': 'Eski telefon', 'sonKullanim': DateTime(2026, 10, 1, 9, 5).millisecondsSinceEpoch, 'buCihaz': false},
  ],
};

void main() {
  void genis(WidgetTester t) {
    t.view.physicalSize = const Size(390, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  testWidgets('profil: bilgiler, düzenleme kaydı ve cihaz kapatma', (t) async {
    genis(t);
    final kayit = <String>[];
    final govdeler = <Object?>[];
    final api = _api({'/api/profil/bilgi': _bilgi, '/api/mobil/cihazlar': _cihazlar}, kayit: kayit, govdeler: govdeler);
    await t.pumpWidget(MaterialApp(home: ProfilEkrani(api: api)));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Deniz Örnek'), findsOneWidget);
    expect(find.text('6-A'), findsOneWidget);
    expect(find.text('deniz@ornek.com'), findsOneWidget);
    expect(find.text('Bağlı cihazlar'), findsOneWidget);
    expect(find.text('Bu cihaz · Son kullanım 2 Kas 15:30'), findsOneWidget);

    await t.tap(find.text('Profili düzenle'));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextField, 'İl'), 'İzmir');
    await t.tap(find.text('Kaydet'));
    await t.pumpAndSettle();
    expect(kayit, contains('POST /api/profil/kaydet'));
    final gonderilen = govdeler.first as Map<String, dynamic>;
    expect(gonderilen['il'], 'İzmir');
    expect(gonderilen['yakinYakinlik'], 'Teyze'); // listede olmayan yakınlık "Diğer" ile korunur

    await t.tap(find.text('Kapat'));
    await t.pumpAndSettle();
    await t.tap(find.text('Oturumu kapat'));
    await t.pumpAndSettle();
    expect(kayit, contains('POST /api/mobil/cihaz-kapat'));
    expect((govdeler.last as Map)['anahtar'], 'bbbbbbbbbbbb');
  });

  testWidgets('profil: kurum yöneticisi adını değiştirebilir', (t) async {
    genis(t);
    final govdeler = <Object?>[];
    final api = _api({
      '/api/profil/bilgi': {..._bilgi, 'adDegistir': true},
      '/api/profil/ad': {'tamam': true, 'ad': 'Deniz Yeni'},
    }, govdeler: govdeler);
    await t.pumpWidget(MaterialApp(home: ProfilEkrani(api: api)));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextField, 'Ad soyad'), 'Deniz Yeni');
    await t.tap(find.text('Adı kaydet'));
    await t.pumpAndSettle();
    expect((govdeler.first as Map)['ad'], 'Deniz Yeni');
  });
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neademy/cekirdek/api.dart';
import 'package:neademy/cekirdek/oturum.dart';
import 'package:neademy/ekranlar/hizli_giris.dart';

http.Response _json(Object o, [int kod = 200]) => http.Response.bytes(utf8.encode(jsonEncode(o)), kod, headers: {'content-type': 'application/json'});

Oturum _kur({required bool acik, List<String>? kayit, Map<String, dynamic>? govde}) => Oturum(
  api: Api(
    istemci: MockClient((r) async {
      kayit?.add('${r.method} ${r.url.path}');
      switch (r.url.path) {
        case '/api/hizli/liste':
          if (!acik || r.url.queryParameters['k'] != 'anahtar') return _json({'hata': 'yok'}, 404);
          return _json({
            'gruplar': [
              {
                'ad': 'Öğretmenler',
                'kisiler': [
                  {'id': '7', 'etiket': 'Ceren Hoca', 'alt': 'Fen Bilimleri'},
                ],
              },
              {'ad': 'Boş grup', 'kisiler': <Object>[]},
            ],
          });
        case '/api/hizli/giris':
          govde?.addAll(jsonDecode(r.body) as Map<String, dynamic>);
          return _json({'tamam': true, 'token': 'a' * 64});
        case '/api/ben':
          return _json({'ad': 'Ceren Hoca', 'rol': 'ogretmen', 'sube': '', 'unvan': 'Fen', 'coklu': false, 'kurum': {'ad': 'Okul'}});
      }
      return _json({'hata': 'yok'}, 404);
    }),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('anahtar doğruysa kişi listesi gelir, dokununca oturum açılır', (t) async {
    final kayit = <String>[];
    final govde = <String, dynamic>{};
    final oturum = _kur(acik: true, kayit: kayit, govde: govde);
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(c).push(MaterialPageRoute(builder: (_) => HizliGirisEkrani(oturum: oturum))),
              child: const Text('ac'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('ac'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'anahtar');
    await t.tap(find.text('Listeyi getir'));
    await t.pumpAndSettle();
    expect(find.text('Öğretmenler'), findsOneWidget);
    expect(find.text('Ceren Hoca'), findsOneWidget);
    expect(find.text('Boş grup'), findsNothing);

    await t.tap(find.text('Ceren Hoca'));
    await t.pumpAndSettle();
    expect([govde['k'], govde['id'], govde['mobil']], ['anahtar', '7', true]);
    expect(oturum.durum, Durum.giris);
    expect(oturum.api.jeton, 'a' * 64);
    expect(oturum.ben?.ad, 'Ceren Hoca');
    // ekran kapanmış olmalı
    expect(find.text('Hızlı giriş'), findsNothing);
  });

  testWidgets('özellik kapalıysa (404) hata gösterilir, giriş yapılmaz', (t) async {
    final oturum = _kur(acik: false);
    await t.pumpWidget(MaterialApp(home: HizliGirisEkrani(oturum: oturum)));
    await t.enterText(find.byType(TextField), 'anahtar');
    await t.tap(find.text('Listeyi getir'));
    await t.pumpAndSettle();
    expect(find.textContaining('Liste alınamadı'), findsOneWidget);
    expect(oturum.api.jeton, isNull);
  });
}

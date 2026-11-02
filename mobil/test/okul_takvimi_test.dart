import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neademy/cekirdek/api.dart';
import 'package:neademy/ekranlar/okul_takvimi.dart';

void main() {
  testWidgets('takvim görüntülenir, günü kapatıp kaydedince sunucuya gider', (t) async {
    final govdeler = <Map<String, dynamic>>[];
    final api = Api(
      istemci: MockClient((istek) async {
        if (istek.method == 'POST') govdeler.add(jsonDecode(istek.body) as Map<String, dynamic>);
        final govde = istek.url.path == '/api/okul/ayar'
            ? {
                'gunler': [
                  {'no': 1, 'ad': 'Pazartesi', 'acik': true},
                  {'no': 2, 'ad': 'Salı', 'acik': true},
                  {'no': 6, 'ad': 'Cumartesi', 'acik': false},
                ],
                'saatler': [
                  {'bas': '08:30', 'bit': '09:10'},
                  {'bas': '09:20', 'bit': '10:00'},
                ],
              }
            : {};
        return http.Response.bytes(utf8.encode(jsonEncode(govde)), 200, headers: {'content-type': 'application/json'});
      }),
    );
    t.view.physicalSize = const Size(390, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(home: OkulTakvimiEkrani(api: api)));
    await t.pumpAndSettle();
    expect(find.text('08:30 – 09:10'), findsOneWidget);
    expect(find.text('Cmt'), findsOneWidget);

    await t.tap(find.text('Düzenle'));
    await t.pumpAndSettle();
    await t.tap(find.text('Sal'));
    await t.pump();
    await t.tap(find.text('+ Ders saati ekle'));
    await t.pump();
    await t.tap(find.text('Kaydet'));
    await t.pumpAndSettle();

    expect(govdeler, hasLength(1));
    expect(govdeler.single['gunler'], [1]);
    expect((govdeler.single['saatler'] as List), hasLength(3));
    expect((govdeler.single['saatler'] as List).last, {'bas': '10:10', 'bit': '10:50'});
  });
}

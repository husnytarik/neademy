import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neademy/cekirdek/oturum.dart';
import 'package:neademy/cekirdek/tema.dart';
import 'package:neademy/ekranlar/giris.dart';

void main() {
  for (final p in [Brightness.light, Brightness.dark]) {
    testWidgets('giriş ekranı çizilir ($p)', (t) async {
      await t.pumpWidget(MaterialApp(theme: temaOlustur(p), home: GirisEkrani(oturum: Oturum())));
      expect(find.text('Giriş yap'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
    });
  }
}

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neademy/cekirdek/api.dart';
import 'package:neademy/cekirdek/biyometri.dart';
import 'package:neademy/cekirdek/oturum.dart';

class SahteBiyometri extends Biyometri {
  SahteBiyometri({this.var_ = true, this.sonuc = true});
  final bool var_;
  bool sonuc;
  @override
  Future<bool> kullanilabilir() async => var_;
  @override
  Future<bool> dogrula(String sebep) async => sonuc;
}

http.Response _json(Object o, [int kod = 200]) =>
    http.Response(jsonEncode(o), kod, headers: {'content-type': 'application/json; charset=utf-8'});

Oturum _kur({String enDusuk = '1.0.0', SahteBiyometri? bio, List<String>? cagrilar, Map<String, Object?> ayarEk = const {}}) {
  final istemci = MockClient((r) async {
    cagrilar?.add('${r.method} ${r.url.path} ${r.headers['Authorization'] ?? ''}');
    switch (r.url.path) {
      case '/api/mobil/ayar':
        return _json({'enDusukSurum': enDusuk, ...ayarEk});
      case '/api/ben':
        return _json({'ad': 'Ceren Husny', 'rol': 'ogretmen', 'sube': '', 'unvan': 'Fen', 'coklu': false, 'kurum': {'ad': 'Okul'}});
      case '/api/cikis':
        return _json({'tamam': true});
    }
    return _json({'hata': 'yok'}, 404);
  });
  return Oturum(api: Api(istemci: istemci), biyometri: bio ?? SahteBiyometri());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('sunucu bakım metni verirse bakım durumu, duyuru ve kapalı modüller okunur', () async {
    final o = _kur(ayarEk: {'bakim': 'Kısa bakım.'});
    await o.baslat();
    expect(o.durum, Durum.bakim);
    expect(o.ayar.bakim, 'Kısa bakım.');

    FlutterSecureStorage.setMockInitialValues({'oturum_jetonu': 'f' * 64});
    final p = _kur(ayarEk: {
      'duyuru': {'id': 'x1', 'baslik': 'Merhaba', 'metin': 'Yeni özellik geldi.'},
      'kapaliModuller': ['takvimim'],
    });
    await p.baslat();
    expect(p.durum, Durum.giris);
    expect(p.ayar.duyuru!.metin, 'Yeni özellik geldi.');
    expect(p.ayar.kapaliModuller, {'takvimim'});
  });

  test('jeton yoksa çıkış durumu', () async {
    final o = _kur();
    await o.baslat();
    expect(o.durum, Durum.cikis);
  });

  test('eski sürüm güncelleme ekranına düşer', () async {
    final o = _kur(enDusuk: '9.0.0');
    await o.baslat();
    expect(o.durum, Durum.guncellemeGerek);
  });

  test('jeton varsa panel, Bearer başlığı gider', () async {
    FlutterSecureStorage.setMockInitialValues({'oturum_jetonu': 'a' * 64});
    final cagrilar = <String>[];
    final o = _kur(cagrilar: cagrilar);
    await o.baslat();
    expect(o.durum, Durum.giris);
    expect(o.ben!.ad, 'Ceren Husny');
    expect(cagrilar.any((c) => c.contains('/api/ben Bearer ${'a' * 64}')), isTrue);
  });

  test('biyometrik kilit açıksa açılışta kilitli, doğrulayınca panel', () async {
    FlutterSecureStorage.setMockInitialValues({'oturum_jetonu': 'b' * 64, 'biyometrik_kilit': '1'});
    final bio = SahteBiyometri(sonuc: false);
    final o = _kur(bio: bio);
    await o.baslat();
    expect(o.durum, Durum.kilitli);
    expect(await o.kilidiAc(), isFalse);
    expect(o.durum, Durum.kilitli);
    bio.sonuc = true;
    expect(await o.kilidiAc(), isTrue);
    expect(o.durum, Durum.giris);
  });

  test('biyometri cihazda yoksa kayıtlı kilit yok sayılır', () async {
    FlutterSecureStorage.setMockInitialValues({'oturum_jetonu': 'c' * 64, 'biyometrik_kilit': '1'});
    final o = _kur(bio: SahteBiyometri(var_: false));
    await o.baslat();
    expect(o.durum, Durum.giris);
  });

  test('arka plandan dönüşte kilitle yalnız kilit açıkken çalışır', () async {
    FlutterSecureStorage.setMockInitialValues({'oturum_jetonu': 'd' * 64});
    final o = _kur();
    await o.baslat();
    o.kilitle();
    expect(o.durum, Durum.giris);
    await o.kilidiAyarla(true);
    o.kilitle();
    expect(o.durum, Durum.kilitli);
  });

  test('çıkışta jeton ve kilit ayarı silinir', () async {
    FlutterSecureStorage.setMockInitialValues({'oturum_jetonu': 'e' * 64, 'biyometrik_kilit': '1'});
    final o = _kur();
    await o.baslat();
    await o.kilidiAc();
    await o.cikisYap();
    expect(o.durum, Durum.cikis);
    const depo = FlutterSecureStorage();
    expect(await depo.read(key: 'oturum_jetonu'), isNull);
    expect(await depo.read(key: 'biyometrik_kilit'), isNull);
  });
}

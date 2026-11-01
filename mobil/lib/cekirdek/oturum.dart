import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api.dart';
import 'biyometri.dart';

enum Durum {
  /// Açılışta jeton/sürüm kontrolü sürüyor.
  aciliyor,

  /// Giriş yapılmamış.
  cikis,

  /// Giriş yapıldı, birden çok profil var; seçim bekleniyor.
  profilSecimi,

  /// Giriş yapıldı, panel gösterilir.
  giris,

  /// Uygulama sürümü sunucunun kabul ettiğinden eski.
  guncellemeGerek,

  /// Giriş var ama uygulama biyometrik doğrulamayla kilitli.
  kilitli,

  /// Sunucu bakım modunda (mobil-ayar.json içindeki "bakim" metni dolu).
  bakim,

  /// Açılışta sunucuya ulaşılamadı (jeton korunur, yeniden denenir).
  baglantiYok,
}

/// Sunucudan yönetilen ayarlar (/api/mobil/ayar): mağaza güncellemesi olmadan değişir.
class MobilAyar {
  const MobilAyar({this.enDusukSurum, this.bakim, this.duyuru, this.kapaliModuller = const {}});

  factory MobilAyar.json(dynamic j) {
    if (j is! Map) return const MobilAyar();
    final d = j['duyuru'];
    return MobilAyar(
      enDusukSurum: j['enDusukSurum'] as String?,
      bakim: j['bakim'] as String?,
      duyuru: d is Map && d['metin'] is String ? Duyuru(id: d['id'] as String? ?? 'd', baslik: d['baslik'] as String?, metin: d['metin'] as String) : null,
      kapaliModuller: {for (final m in (j['kapaliModuller'] as List? ?? const [])) m.toString()},
    );
  }

  final String? enDusukSurum;
  final String? bakim;
  final Duyuru? duyuru;
  final Set<String> kapaliModuller;
}

class Duyuru {
  const Duyuru({required this.id, required this.baslik, required this.metin});

  final String id;
  final String? baslik;
  final String metin;
}

class Profil {
  Profil({required this.id, required this.rol, required this.sube, required this.unvan});

  factory Profil.json(Map<String, dynamic> j) => Profil(
        id: j['id'] as int,
        rol: j['rol'] as String? ?? '',
        sube: j['sube'] as String? ?? '',
        unvan: j['unvan'] as String? ?? '',
      );

  final int id;
  final String rol;
  final String sube;
  final String unvan;
}

/// Oturum kayıtlı kişi: ad, rol, kurum ve yetkiler (/api/ben).
class Ben {
  Ben({required this.ad, required this.rol, required this.sube, required this.unvan, required this.coklu, required this.kurum});

  factory Ben.json(Map<String, dynamic> j) => Ben(
        ad: j['ad'] as String? ?? '',
        rol: j['rol'] as String? ?? '',
        sube: j['sube'] as String? ?? '',
        unvan: j['unvan'] as String? ?? '',
        coklu: j['coklu'] == true,
        kurum: (j['kurum'] is Map ? (j['kurum']['ad'] as String? ?? '') : ''),
      );

  final String ad;
  final String rol;
  final String sube;
  final String unvan;
  final bool coklu;
  final String kurum;
}

/// Uygulamanın oturum durumu: jeton güvenli depoda (iOS Keychain / Android Keystore) tutulur.
class Oturum extends ChangeNotifier {
  Oturum({Api? api, FlutterSecureStorage? depo, Biyometri? biyometri})
      : api = api ?? Api(),
        _depo = depo ?? const FlutterSecureStorage(),
        biyometri = biyometri ?? Biyometri() {
    this.api.oturumDustu = _oturumDustu;
  }

  static const _jetonAnahtari = 'oturum_jetonu';
  static const _kilitAnahtari = 'biyometrik_kilit';

  final Api api;
  final Biyometri biyometri;
  final FlutterSecureStorage _depo;

  Durum durum = Durum.aciliyor;
  Ben? ben;
  List<Profil> profiller = const [];
  MobilAyar ayar = const MobilAyar();
  String? get enDusukSurum => ayar.enDusukSurum;

  /// Kullanıcı biyometrik açılışı etkinleştirdi mi (cihazda saklanır).
  bool kilitAcik = false;

  Future<void> baslat() async {
    durum = Durum.aciliyor;
    notifyListeners();
    try {
      // Sürüm kapısı: eski istemciler sunucudan kapatılabilir
      ayar = MobilAyar.json(await api.get('/api/mobil/ayar'));
      if (enDusukSurum != null && surumKarsilastir(Api.surum, enDusukSurum!) < 0) {
        durum = Durum.guncellemeGerek;
        notifyListeners();
        return;
      }
      if (ayar.bakim != null) {
        durum = Durum.bakim;
        notifyListeners();
        return;
      }
      final jeton = await _depo.read(key: _jetonAnahtari);
      if (jeton == null) return _cikisDurumu();
      api.jeton = jeton;
      await _benYukle();
      kilitAcik = await _depo.read(key: _kilitAnahtari) == '1' && await biyometri.kullanilabilir();
      durum = kilitAcik ? Durum.kilitli : Durum.giris;
    } on ApiHata catch (e) {
      if (e.baglantiYok) {
        durum = Durum.baglantiYok;
      } else {
        await _jetonuSil();
        durum = Durum.cikis;
      }
    }
    notifyListeners();
  }

  /// Panel yenilenirken ayarlar da tazelenir (duyuru, kapalı modüller, bakım).
  Future<void> ayariYenile() async {
    try {
      ayar = MobilAyar.json(await api.get('/api/mobil/ayar'));
      notifyListeners();
    } on ApiHata {
      // Eski ayarlarla devam
    }
  }

  Future<void> _benYukle() async {
    final j = await api.get('/api/ben');
    ben = Ben.json(j as Map<String, dynamic>);
  }

  Future<void> _cikisDurumu() async {
    api.jeton = null;
    ben = null;
    durum = Durum.cikis;
    notifyListeners();
  }

  /// Kimlik + telefon ile giriş. Birden çok profil varsa [Durum.profilSecimi]'ne geçer.
  Future<void> girisYap(String kimlik, String telefon) async {
    final yanit = await api.post('/api/giris/dogrula', {
      'kimlik': kimlik.trim(),
      'telefon': telefon.trim(),
      'mobil': true,
      'cihaz': _cihazAdi(),
    });
    final jeton = (yanit as Map)['token'] as String;
    api.jeton = jeton;
    await _depo.write(key: _jetonAnahtari, value: jeton);
    if (yanit['coklu'] == true) {
      await profilleriYukle();
      durum = Durum.profilSecimi;
    } else {
      await _benYukle();
      durum = Durum.giris;
    }
    notifyListeners();
  }

  /// Kilit ekranından: doğrulama başarılıysa panele geçer.
  Future<bool> kilidiAc() async {
    if (durum != Durum.kilitli) return true;
    final tamam = await biyometri.dogrula('Uygulamayı açmak için doğrulayın');
    if (tamam) {
      durum = Durum.giris;
      notifyListeners();
    }
    return tamam;
  }

  /// Uygulama uzun süre arka planda kaldıysa yeniden kilitler.
  void kilitle() {
    if (kilitAcik && durum == Durum.giris) {
      durum = Durum.kilitli;
      notifyListeners();
    }
  }

  /// Menüden açıp kapatma; açarken bir kez doğrulatır.
  Future<void> kilidiAyarla(bool ac) async {
    if (ac && !(await biyometri.dogrula('Biyometrik açılışı etkinleştirmek için doğrulayın'))) return;
    kilitAcik = ac;
    await _depo.write(key: _kilitAnahtari, value: ac ? '1' : '0');
    notifyListeners();
  }

  Future<void> profilleriYukle() async {
    final j = await api.get('/api/profiller') as Map<String, dynamic>;
    profiller = [for (final p in (j['profiller'] as List)) Profil.json(p as Map<String, dynamic>)];
  }

  Future<void> profilSec(int id) async {
    await api.post('/api/profil/sec', {'id': id});
    await _benYukle();
    durum = Durum.giris;
    notifyListeners();
  }

  /// Panelden profil değiştirmek için seçim ekranını açar.
  Future<void> profilDegistir() async {
    await profilleriYukle();
    durum = Durum.profilSecimi;
    notifyListeners();
  }

  Future<void> cikisYap() async {
    try {
      await api.post('/api/cikis');
    } on ApiHata {
      // Sunucuya ulaşılamasa da bu cihazdan çıkılır; jeton sunucuda süresi dolunca kapanır
    }
    await _jetonuSil();
    await _cikisDurumu();
  }

  void _oturumDustu() {
    if (durum == Durum.giris || durum == Durum.profilSecimi) {
      _jetonuSil().then((_) => _cikisDurumu());
    }
  }

  Future<void> _jetonuSil() async {
    api.jeton = null;
    kilitAcik = false;
    try {
      await _depo.delete(key: _jetonAnahtari);
      await _depo.delete(key: _kilitAnahtari);
    } catch (_) {}
  }

  String _cihazAdi() => switch (defaultTargetPlatform) {
        TargetPlatform.iOS => 'iPhone',
        TargetPlatform.android => 'Android telefon',
        _ => 'Bilgisayar',
      };
}

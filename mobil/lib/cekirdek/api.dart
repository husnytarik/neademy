import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Sunucudan dönen ya da bağlantıdan doğan hata. [mesaj] kullanıcıya gösterilebilir.
class ApiHata implements Exception {
  ApiHata(this.kod, this.mesaj);

  /// HTTP durum kodu; 0 = sunucuya ulaşılamadı.
  final int kod;
  final String mesaj;

  bool get baglantiYok => kod == 0;
  bool get oturumYok => kod == 401;

  @override
  String toString() => mesaj;
}

/// Sunucu ile tek konuşma noktası: jetonu ekler, hataları tek biçime çevirir.
class Api {
  Api({http.Client? istemci}) : _istemci = istemci ?? http.Client();

  /// Sunucu adresi. Geliştirmede: --dart-define=API=http://localhost:3000
  static const taban = String.fromEnvironment('API', defaultValue: 'https://app.neademy.com');

  /// Uygulama sürümü; sunucudaki "en düşük sürüm" ile karşılaştırılır.
  static const surum = '1.0.0';

  final http.Client _istemci;
  String? jeton;

  /// Kimlik doğrulanmış bir istek 401 dönerse (oturum bitti/iptal edildi) çağrılır.
  void Function()? oturumDustu;

  Map<String, String> get _basliklar => {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
        'X-Istemci-Surum': surum,
        if (jeton != null) 'Authorization': 'Bearer $jeton',
      };

  Future<dynamic> get(String yol) => _gonder(() => _istemci.get(Uri.parse('$taban$yol'), headers: _basliklar));

  Future<dynamic> post(String yol, [Map<String, dynamic>? govde]) =>
      _gonder(() => _istemci.post(Uri.parse('$taban$yol'), headers: _basliklar, body: jsonEncode(govde ?? {})));

  Future<dynamic> _gonder(Future<http.Response> Function() istek) async {
    final http.Response r;
    try {
      r = await istek().timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw ApiHata(0, 'Sunucu yanıt vermedi. Biraz sonra tekrar deneyin.');
    } catch (_) {
      throw ApiHata(0, 'Sunucuya ulaşılamadı. İnternet bağlantınızı kontrol edin.');
    }
    dynamic veri;
    try {
      veri = r.body.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {
      veri = null;
    }
    if (r.statusCode >= 200 && r.statusCode < 300) return veri;
    final mesaj = (veri is Map && veri['hata'] is String) ? veri['hata'] as String : 'Beklenmeyen bir hata oluştu (${r.statusCode}).';
    if (r.statusCode == 401 && jeton != null) oturumDustu?.call();
    throw ApiHata(r.statusCode, mesaj);
  }
}

/// "1.2.3" biçimli iki sürümü karşılaştırır: a < b ise negatif.
int surumKarsilastir(String a, String b) {
  final x = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  final y = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  for (var i = 0; i < 3; i++) {
    final fark = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (fark != 0) return fark;
  }
  return 0;
}

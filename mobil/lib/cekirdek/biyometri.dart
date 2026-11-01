import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Face ID / parmak izi ile yerel doğrulama. Jeton cihazda kalır; bu yalnızca uygulamayı açar.
class Biyometri {
  Biyometri([LocalAuthentication? la]) : _la = la ?? LocalAuthentication();

  final LocalAuthentication _la;

  /// Web'de ve biyometrisi kayıtlı olmayan cihazlarda false.
  Future<bool> kullanilabilir() async {
    if (kIsWeb) return false;
    try {
      return await _la.isDeviceSupported() && (await _la.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> dogrula(String sebep) async {
    try {
      return await _la.authenticate(
        localizedReason: sebep,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}

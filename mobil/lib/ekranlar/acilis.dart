import 'package:flutter/material.dart';

import '../cekirdek/tema.dart';

/// Açılış / bağlantı yok / güncelleme gerekli ekranı.
class AcilisEkrani extends StatelessWidget {
  const AcilisEkrani({super.key, this.hata, this.yenidenDene});

  final String? hata;
  final VoidCallback? yenidenDene;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('neademy', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: context.yazi, letterSpacing: -.5)),
                const SizedBox(height: 24),
                if (hata == null)
                  const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5))
                else ...[
                  Text(hata!, textAlign: TextAlign.center, style: TextStyle(color: context.soluk, fontSize: 15, height: 1.4)),
                  if (yenidenDene != null) ...[
                    const SizedBox(height: 20),
                    SizedBox(width: 200, child: FilledButton(onPressed: yenidenDene, child: const Text('Tekrar dene'))),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

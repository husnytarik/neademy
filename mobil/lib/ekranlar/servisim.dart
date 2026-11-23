import 'package:flutter/material.dart';

import '../bilesenler/ortak.dart';
import '../cekirdek/api.dart';

/// Veli ve öğrenci: çocuğun/kendi servis aracı, şoför, durak ve saatleri.
class ServisimEkrani extends StatelessWidget {
  const ServisimEkrani({super.key, required this.api});

  final Api api;

  @override
  Widget build(BuildContext context) => VeriSayfasi(
    baslik: 'Servis',
    getir: () => api.get('/api/servis/benim'),
    cizim: (context, raw) {
      final liste = (raw as Map<String, dynamic>).l('ogrenciler');
      if (liste.isEmpty) return const [BosNot('Bağlı öğrenci bulunamadı.')];
      return [for (final o in liste) ServisKarti(o)];
    },
  );
}

/// Bir öğrencinin servis bilgisi; [ServisimEkrani] ve öğrenci dosyası kullanır.
class ServisKarti extends StatelessWidget {
  const ServisKarti(this.ogrenci, {super.key});

  /// {ad, sinif, servis: {...}|null}
  final Map<String, dynamic> ogrenci;

  @override
  Widget build(BuildContext context) {
    final s = ogrenci['servis'] as Map<String, dynamic>?;
    final sinif = ogrenci.s('sinif');
    final satirlar = <(String, String)>[];
    if (s != null) {
      final durak = s['durak'] as Map<String, dynamic>?;
      final yon = s.s('yon');
      satirlar.addAll([
        ('Servis', s.s('servis') + (s['aktif'] == false ? ' (şu an hizmet dışı)' : '')),
        ('Plaka', s.s('plaka')),
        ('Şoför', [s.s('soforAd'), s.s('soforTel')].where((x) => x.isNotEmpty).join(' · ')),
        ('Hostes', [s.s('hostesAd'), s.s('hostesTel')].where((x) => x.isNotEmpty).join(' · ')),
        ('Kullanım', s.s('yonAd')),
        if (durak != null) ('Durak', durak.s('ad')),
        if (durak != null && yon != 'aksam') ('Sabah saati', durak.s('sabahSaat')),
        if (durak != null && yon != 'sabah') ('Akşam saati', durak.s('aksamSaat')),
        ('Not', s.s('notu')),
      ]);
    }
    return KartKutu(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${ogrenci.s('ad')}${sinif.isEmpty ? '' : ' · $sinif'}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (s == null)
            const Text('Bu öğrenci için kayıtlı bir servis yok.')
          else
            for (final (a, v) in satirlar)
              if (v.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text.rich(TextSpan(children: [TextSpan(text: '$a: ', style: const TextStyle(fontWeight: FontWeight.w600)), TextSpan(text: v)])),
                ),
        ],
      ),
    );
  }
}

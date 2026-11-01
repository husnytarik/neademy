import 'package:flutter/material.dart';

import '../cekirdek/api.dart';
import '../cekirdek/oturum.dart';
import '../cekirdek/tema.dart';

const _rolAdi = {'yonetim': 'Yönetim', 'ogretmen': 'Öğretmen', 'veli': 'Veli', 'ogrenci': 'Öğrenci'};

/// Birden çok profili olan hesap için "Hangi profille devam edelim?".
class ProfilSecEkrani extends StatefulWidget {
  const ProfilSecEkrani({super.key, required this.oturum});

  final Oturum oturum;

  @override
  State<ProfilSecEkrani> createState() => _ProfilSecEkraniState();
}

class _ProfilSecEkraniState extends State<ProfilSecEkrani> {
  int? _seciliId;
  String? _hata;

  Future<void> _sec(Profil p) async {
    setState(() {
      _seciliId = p.id;
      _hata = null;
    });
    try {
      await widget.oturum.profilSec(p.id);
    } on ApiHata catch (e) {
      if (mounted) setState(() => _hata = e.mesaj);
    } finally {
      if (mounted) setState(() => _seciliId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profiller = widget.oturum.profiller;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Profil seçin'),
        actions: [
          TextButton(onPressed: widget.oturum.cikisYap, child: const Text('Çıkış')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text('Hangi profille devam edelim?', style: TextStyle(color: context.soluk, fontSize: 15)),
          const SizedBox(height: 16),
          for (final p in profiller)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: context.kart,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: context.ince)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _seciliId == null ? () => _sec(p) : null,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_rolAdi[p.rol] ?? p.rol, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(
                                [p.unvan, p.sube].where((e) => e.isNotEmpty).join(' · '),
                                style: TextStyle(color: context.soluk, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        if (_seciliId == p.id)
                          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2))
                        else
                          Icon(Icons.chevron_right, color: context.soluk),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_hata != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_hata!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
    );
  }
}

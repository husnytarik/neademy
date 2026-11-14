import 'package:flutter/material.dart';

import '../bilesenler/ortak.dart';
import '../cekirdek/oturum.dart';
import '../cekirdek/tema.dart';

/// Kapasite / deneme amaçlı tek dokunuşla giriş (web: hizli-giris). Giriş ekranında "neademy" yazısına
/// uzun basarak açılır. Sunucuda HIZLI_GIRIS_ANAHTAR tanımlı değilse uçlar 404 verir ve burada hata görünür.
class HizliGirisEkrani extends StatefulWidget {
  const HizliGirisEkrani({super.key, required this.oturum});

  final Oturum oturum;

  @override
  State<HizliGirisEkrani> createState() => _HizliGirisEkraniState();
}

class _HizliGirisEkraniState extends State<HizliGirisEkrani> {
  final _anahtar = TextEditingController();
  List<Map<String, dynamic>>? _gruplar;
  String _mesaj = '';
  bool _mesgul = false;

  @override
  void dispose() {
    _anahtar.dispose();
    super.dispose();
  }

  Future<void> _listele() async {
    final k = _anahtar.text.trim();
    if (k.isEmpty) return;
    setState(() {
      _mesgul = true;
      _mesaj = '';
    });
    try {
      final r = await widget.oturum.api.get('/api/hizli/liste?k=${Uri.encodeQueryComponent(k)}') as Map<String, dynamic>;
      if (mounted) setState(() => _gruplar = [for (final g in r.l('gruplar')) if (g.l('kisiler').isNotEmpty) g]);
    } catch (_) {
      if (mounted) setState(() => _mesaj = 'Liste alınamadı: anahtar yanlış ya da özellik kapalı.');
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  Future<void> _gir(String id) async {
    setState(() {
      _mesgul = true;
      _mesaj = 'Giriş yapılıyor…';
    });
    try {
      await widget.oturum.hizliGiris(_anahtar.text.trim(), id);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _mesgul = false;
          _mesaj = 'Giriş yapılamadı.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Hızlı giriş')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        if (_gruplar == null) ...[
          Text('Deneme anahtarını girin; kişi listesi açılır.', style: TextStyle(color: context.soluk)),
          const SizedBox(height: 10),
          TextField(
            controller: _anahtar,
            obscureText: true,
            autocorrect: false,
            onSubmitted: (_) => _listele(),
            decoration: const InputDecoration(labelText: 'Anahtar'),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _mesgul ? null : _listele, child: const Text('Listeyi getir')),
        ] else
          for (final g in _gruplar!) ...[
            Baslik(g.s('ad')),
            for (final k in g.l('kisiler'))
              KartKutu(
                onTap: _mesgul ? null : () => _gir(k.s('id')),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(k.s('etiket'), style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
                    if (k.s('alt').isNotEmpty) Text(k.s('alt'), style: TextStyle(color: context.soluk, fontSize: 12.5)),
                  ],
                ),
              ),
          ],
        if (_mesaj.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_mesaj, style: TextStyle(color: _mesaj.startsWith('Giriş yapılıyor') ? context.soluk : Theme.of(context).colorScheme.error)),
          ),
      ],
    ),
  );
}

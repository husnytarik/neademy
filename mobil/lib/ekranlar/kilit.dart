import 'package:flutter/material.dart';

import '../cekirdek/oturum.dart';
import '../cekirdek/tema.dart';

/// Biyometrik açılış: açılınca doğrulama kendiliğinden istenir, olmazsa düğmeyle tekrarlanır.
class KilitEkrani extends StatefulWidget {
  const KilitEkrani({super.key, required this.oturum});

  final Oturum oturum;

  @override
  State<KilitEkrani> createState() => _KilitEkraniState();
}

class _KilitEkraniState extends State<KilitEkrani> {
  bool _sorgu = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ac());
  }

  Future<void> _ac() async {
    if (_sorgu) return;
    setState(() => _sorgu = true);
    await widget.oturum.kilidiAc();
    if (mounted) setState(() => _sorgu = false);
  }

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
                const SizedBox(height: 8),
                Text(widget.oturum.ben?.ad ?? '', style: TextStyle(color: context.soluk, fontSize: 15)),
                const SizedBox(height: 28),
                Icon(Icons.lock_outline, size: 40, color: context.soluk),
                const SizedBox(height: 24),
                SizedBox(
                  width: 220,
                  child: FilledButton(onPressed: _sorgu ? null : _ac, child: const Text('Kilidi aç')),
                ),
                const SizedBox(height: 10),
                TextButton(onPressed: widget.oturum.cikisYap, child: Text('Çıkış yap', style: TextStyle(color: context.soluk))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

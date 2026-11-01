import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../cekirdek/api.dart';
import '../cekirdek/oturum.dart';
import '../cekirdek/tema.dart';

/// T.C./pasaport no + telefon ile giriş (web ile aynı kural, kod yok).
class GirisEkrani extends StatefulWidget {
  const GirisEkrani({super.key, required this.oturum});

  final Oturum oturum;

  @override
  State<GirisEkrani> createState() => _GirisEkraniState();
}

class _GirisEkraniState extends State<GirisEkrani> {
  final _kimlik = TextEditingController();
  final _telefon = TextEditingController();
  bool _yukleniyor = false;
  String? _hata;

  @override
  void dispose() {
    _kimlik.dispose();
    _telefon.dispose();
    super.dispose();
  }

  Future<void> _gonder() async {
    final kimlik = _kimlik.text.trim();
    final telefon = _telefon.text.trim();
    if (kimlik.isEmpty || telefon.isEmpty) {
      setState(() => _hata = 'Kimlik numarası ve telefon numarasını girin.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      await widget.oturum.girisYap(kimlik, telefon);
    } on ApiHata catch (e) {
      if (mounted) setState(() => _hata = e.mesaj);
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('neademy', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -.6, color: context.yazi)),
                    const SizedBox(height: 4),
                    Text('Okul yönetim platformu', style: TextStyle(color: context.soluk, fontSize: 15)),
                    const SizedBox(height: 36),
                    _Etiket('T.C. kimlik no veya pasaport no', context),
                    TextField(
                      controller: _kimlik,
                      maxLength: 20,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.username],
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]'))],
                      decoration: const InputDecoration(counterText: ''),
                    ),
                    const SizedBox(height: 16),
                    _Etiket('Telefon numarası', context),
                    TextField(
                      controller: _telefon,
                      maxLength: 20,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      onSubmitted: (_) => _gonder(),
                      decoration: const InputDecoration(counterText: '', hintText: '5XX XXX XX XX'),
                    ),
                    if (_hata != null) ...[
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        child: Text(_hata!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 14.5)),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _yukleniyor ? null : _gonder,
                      child: _yukleniyor
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                          : const Text('Giriş yap'),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Hesabınız okulunuz tarafından açılır.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.soluk, fontSize: 13.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Etiket extends StatelessWidget {
  const _Etiket(this.metin, this.context);

  final String metin;
  final BuildContext context;

  @override
  Widget build(BuildContext _) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(metin, style: TextStyle(color: context.soluk, fontSize: 13.5, fontWeight: FontWeight.w500)),
      );
}

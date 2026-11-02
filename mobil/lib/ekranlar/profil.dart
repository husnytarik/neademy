import 'package:flutter/material.dart';

import '../bilesenler/ortak.dart';
import '../cekirdek/api.dart';
import '../cekirdek/tema.dart';

String _telYaz(String t) {
  final d = t.replaceAll(RegExp(r'\D'), '');
  return d.length == 10 ? '${d.substring(0, 3)} ${d.substring(3, 6)} ${d.substring(6, 8)} ${d.substring(8)}' : t;
}

/// "1762000000000" -> "2 Kas 15:30" (yerel saat)
String _sonKullanim(int ms) {
  if (ms <= 0) return '';
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  const aylar = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
  final saat = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  return '${d.day} ${aylar[d.month - 1]} $saat';
}

/// Kişinin kendi bilgileri (web profil sayfası) ve bağlı mobil cihazları.
class ProfilEkrani extends StatefulWidget {
  const ProfilEkrani({super.key, required this.api});

  final Api api;

  @override
  State<ProfilEkrani> createState() => _ProfilEkraniState();
}

class _ProfilEkraniState extends State<ProfilEkrani> {
  Map<String, dynamic>? _bilgi;
  List<Map<String, dynamic>> _cihazlar = const [];
  String? _hata;
  bool _duzenle = false;
  bool _kaydediyor = false;

  final _ad = TextEditingController();
  final _alan = <String, TextEditingController>{
    for (final k in ['email', 'telefon2', 'il', 'ilce', 'adres', 'yakinAd', 'yakinDiger', 'yakinTelefon']) k: TextEditingController(),
  };
  String _yakinlik = '';

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    _ad.dispose();
    for (final c in _alan.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _yukle() async {
    try {
      final b = await widget.api.get('/api/profil/bilgi') as Map<String, dynamic>;
      List<Map<String, dynamic>> cihazlar = const [];
      try {
        cihazlar = ((await widget.api.get('/api/mobil/cihazlar') as Map<String, dynamic>)['cihazlar'] as List? ?? const []).cast<Map<String, dynamic>>();
      } on ApiHata {
        // cihaz listesi alınamasa da profil gösterilir
      }
      if (!mounted) return;
      setState(() {
        _bilgi = b;
        _cihazlar = cihazlar;
        _hata = null;
        _alanlariDoldur();
      });
    } on ApiHata catch (e) {
      if (mounted) setState(() => _hata = e.mesaj);
    }
  }

  void _alanlariDoldur() {
    final d = _bilgi!.m('duzenle');
    final yakinlar = _bilgi!['yakinlar'] as List? ?? const [];
    for (final k in ['email', 'il', 'ilce', 'adres', 'yakinAd']) {
      _alan[k]!.text = d.s(k);
    }
    for (final k in ['telefon2', 'yakinTelefon']) {
      _alan[k]!.text = _telYaz(d.s(k));
    }
    final hesapAd = _bilgi!.l('hesap').where((x) => x.s('ad') == 'Ad soyad');
    if (hesapAd.isNotEmpty) _ad.text = hesapAd.first.s('deger');
    final y = d.s('yakinYakinlik');
    if (y.isEmpty || yakinlar.contains(y)) {
      _yakinlik = y;
      _alan['yakinDiger']!.text = '';
    } else {
      _yakinlik = 'Diğer';
      _alan['yakinDiger']!.text = y;
    }
  }

  Future<void> _kaydet() async {
    setState(() => _kaydediyor = true);
    try {
      final yakinlik = _yakinlik == 'Diğer' ? (_alan['yakinDiger']!.text.trim().isEmpty ? 'Diğer' : _alan['yakinDiger']!.text.trim()) : _yakinlik;
      await widget.api.post('/api/profil/kaydet', {
        'email': _alan['email']!.text,
        'telefon2': _alan['telefon2']!.text,
        'il': _alan['il']!.text,
        'ilce': _alan['ilce']!.text,
        'adres': _alan['adres']!.text,
        'yakinAd': _alan['yakinAd']!.text,
        'yakinYakinlik': yakinlik,
        'yakinTelefon': _alan['yakinTelefon']!.text,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Bilgileriniz kaydedildi')));
      setState(() => _duzenle = false);
      await _yukle();
    } catch (e) {
      if (mounted) hataGoster(context, e);
    } finally {
      if (mounted) setState(() => _kaydediyor = false);
    }
  }

  Future<void> _adKaydet() async {
    setState(() => _kaydediyor = true);
    try {
      final r = await widget.api.post('/api/profil/ad', {'ad': _ad.text}) as Map<String, dynamic>;
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Adınız güncellendi')));
      _ad.text = r.s('ad');
      await _yukle();
    } catch (e) {
      if (mounted) hataGoster(context, e);
    } finally {
      if (mounted) setState(() => _kaydediyor = false);
    }
  }

  Future<void> _cihazKapat(Map<String, dynamic> c) async {
    if (!await onayIste(context, '"${c.s('cihaz')}" cihazındaki oturum kapatılsın mı?', evet: 'Oturumu kapat')) return;
    try {
      await widget.api.post('/api/mobil/cihaz-kapat', {'anahtar': c.s('anahtar')});
      await _yukle();
    } catch (e) {
      if (mounted) hataGoster(context, e);
    }
  }

  Widget _satirlar(BuildContext context, List<Map<String, dynamic>> satirlar) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final s in satirlar)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Wrap(
              spacing: 10,
              children: [
                Text(s.s('ad'), style: TextStyle(color: context.soluk, fontSize: 13)),
                Text(s.s('deger'), style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _kutu(TextEditingController c, String etiket, {TextInputType? tur, int satir = 1, int? en, String? ipucu}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        keyboardType: tur,
        minLines: satir,
        maxLines: satir,
        maxLength: en,
        decoration: InputDecoration(labelText: etiket, hintText: ipucu, counterText: ''),
      ),
    );
  }

  List<Widget> _form(BuildContext context, List yakinlar) {
    return [
      const Baslik('İletişim'),
      _kutu(_alan['email']!, 'E-posta', tur: TextInputType.emailAddress, en: 120, ipucu: 'ad@ornek.com'),
      _kutu(_alan['telefon2']!, 'İkinci telefon', tur: TextInputType.phone, en: 20, ipucu: '532 123 45 67'),
      const Baslik('Adres'),
      _kutu(_alan['il']!, 'İl', en: 40),
      _kutu(_alan['ilce']!, 'İlçe', en: 40),
      _kutu(_alan['adres']!, 'Açık adres', satir: 3, en: 250, ipucu: 'Mahalle, cadde/sokak, bina ve daire no'),
      const Baslik('Acil durumda aranacak yakın'),
      Text('Okul size ulaşamazsa bu kişiyi arar.', style: TextStyle(color: context.soluk, fontSize: 13)),
      const SizedBox(height: 8),
      _kutu(_alan['yakinAd']!, 'Ad soyad', en: 80),
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: DropdownButtonFormField<String>(
          initialValue: _yakinlik,
          decoration: const InputDecoration(labelText: 'Yakınlık'),
          items: [
            const DropdownMenuItem(value: '', child: Text('Seçiniz')),
            for (final y in yakinlar) DropdownMenuItem(value: '$y', child: Text('$y')),
          ],
          onChanged: (v) => setState(() => _yakinlik = v ?? ''),
        ),
      ),
      if (_yakinlik == 'Diğer') _kutu(_alan['yakinDiger']!, 'Yakınlık derecesini yazın', en: 30, ipucu: 'Örn. Kardeş, Dede'),
      _kutu(_alan['yakinTelefon']!, 'Telefon', tur: TextInputType.phone, en: 20, ipucu: '532 123 45 67'),
      const SizedBox(height: 4),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _kaydediyor
                  ? null
                  : () => setState(() {
                      _alanlariDoldur();
                      _duzenle = false;
                    }),
              child: const Text('Vazgeç'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(onPressed: _kaydediyor ? null : _kaydet, child: const Text('Kaydet')),
          ),
        ],
      ),
    ];
  }

  List<Widget> _goruntule(BuildContext context) {
    final d = _bilgi!.m('duzenle');
    final yakin = [d.s('yakinAd'), d.s('yakinYakinlik'), _telYaz(d.s('yakinTelefon'))].where((x) => x.isNotEmpty).join(' · ');
    final adres = [d.s('adres'), d.s('ilce'), d.s('il')].where((x) => x.isNotEmpty).join(', ');
    final satirlar = <Map<String, dynamic>>[
      {'ad': 'E-posta', 'deger': d.s('email')},
      {'ad': 'İkinci telefon', 'deger': _telYaz(d.s('telefon2'))},
      {'ad': 'Adres', 'deger': adres},
      {'ad': 'Acil durumda aranacak', 'deger': yakin},
    ].where((s) => s.s('deger').isNotEmpty).toList();
    return [
      const Baslik('İletişim ve adres'),
      if (satirlar.isEmpty) const BosNot('Henüz iletişim bilgisi girilmemiş.') else _satirlar(context, satirlar),
      const SizedBox(height: 10),
      OutlinedButton(onPressed: () => setState(() => _duzenle = true), child: const Text('Profili düzenle')),
    ];
  }

  Widget _cihazSatiri(BuildContext context, Map<String, dynamic> c) {
    final son = _sonKullanim(c.n('sonKullanim'));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: KartKutu(
        child: Row(
          children: [
            Icon(Icons.smartphone, color: context.soluk),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.s('cihaz').isEmpty ? 'Cihaz' : c.s('cihaz'), style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    [if (c['buCihaz'] == true) 'Bu cihaz', if (son.isNotEmpty) 'Son kullanım $son'].join(' · '),
                    style: TextStyle(color: context.soluk, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (c['buCihaz'] != true) TextButton(onPressed: () => _cihazKapat(c), child: const Text('Kapat')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = _bilgi;
    return Scaffold(
      appBar: AppBar(title: const Text('Profilim')),
      body: b == null
          ? Center(
              child: _hata == null
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_hata!, textAlign: TextAlign.center),
                          TextButton(onPressed: _yukle, child: const Text('Tekrar dene')),
                        ],
                      ),
                    ),
            )
          : RefreshIndicator(
              onRefresh: _yukle,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const Baslik('Hesap bilgileri'),
                  _satirlar(context, b.l('hesap')),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      b['adDegistir'] == true
                          ? 'Kimlik ve giriş telefonu değiştirilemez.'
                          : 'Ad, kimlik ve giriş telefonu okul yönetimi tarafından güncellenir.',
                      style: TextStyle(color: context.soluk, fontSize: 12),
                    ),
                  ),
                  if (b['adDegistir'] == true) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _ad,
                      maxLength: 80,
                      decoration: InputDecoration(
                        labelText: 'Ad soyad',
                        counterText: '',
                        suffixIcon: TextButton(onPressed: _kaydediyor ? null : _adKaydet, child: const Text('Adı kaydet')),
                      ),
                    ),
                  ],
                  if (b.m('okul').l('satirlar').isNotEmpty) ...[Baslik(b.m('okul').s('baslik')), _satirlar(context, b.m('okul').l('satirlar'))],
                  ...(_duzenle ? _form(context, b['yakinlar'] as List? ?? const []) : _goruntule(context)),
                  if (_cihazlar.isNotEmpty) ...[const Baslik('Bağlı cihazlar'), for (final c in _cihazlar) _cihazSatiri(context, c)],
                ],
              ),
            ),
    );
  }
}

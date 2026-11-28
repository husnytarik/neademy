import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../bilesenler/ortak.dart';
import '../cekirdek/api.dart';
import '../cekirdek/tema.dart';

/// "Okulumuz": kurum ve okulun tanıtım sayfası. Öğrenci, veli, öğretmen ve yönetim okur;
/// içeriği Okul kurulumunda yönetim girer.
class OkulumuzEkrani extends StatelessWidget {
  const OkulumuzEkrani({super.key, required this.api});

  final Api api;

  @override
  Widget build(BuildContext context) => VeriSayfasi(
    baslik: 'Okulumuz',
    getir: () => api.get('/api/okulum'),
    cizim: (context, raw) {
      final v = raw as Map<String, dynamic>;
      final k = v.m('kurum');
      final okullar = v.l('okullar');
      return [
        _Ust(api: api, ad: k.s('ad'), alt: k.s('kisaAd'), logo: v.s('logo').isEmpty ? null : '/api/kurum-logo?v=${v.s('logo')}'),
        if (k.s('aciklama').isNotEmpty) ...[
          const Baslik('Biz kimiz'),
          Text(k.s('aciklama'), style: const TextStyle(height: 1.5, fontSize: 15)),
        ],
        ..._baglantilar(context, v, k),
        if (okullar.length == 1) ...[const _Ayrac(), _OkulBolumu(api: api, v: v, okul: okullar.first)],
        if (okullar.length > 1) ...[
          const Baslik('Okullarımız', ust: 24),
          for (final o in okullar)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Logo(api: api, ad: o.s('ad'), yol: _okulLogo(o)),
              title: Text(o.s('ad'), style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text([o.s('tur'), o.s('kampus')].where((e) => e.isNotEmpty).join(' · ')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: Text(o.s('ad'))),
                    body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [_OkulBolumu(api: api, v: v, okul: o)]),
                  ),
                ),
              ),
            ),
        ],
      ];
    },
  );
}

String? _okulLogo(Map<String, dynamic> o) => o.s('logo').isEmpty ? null : '/api/okul-logo?id=${o.n('id')}&v=${o.s('logo')}';

/// Web, sosyal medya, telefon, e-posta ve adres satırları: dokununca açılır.
List<Widget> _baglantilar(BuildContext context, Map<String, dynamic> v, Map<String, dynamic> x) {
  final sosyal = ((x['sosyal'] as Map?) ?? const {}).cast<String, dynamic>();
  final alanlar = v.l('sosyalAlanlar');
  final site = RegExp(r'^https?://(www\.)?');
  final izle = <Widget>[
    if (x.s('web').isNotEmpty)
      _Satir(Icons.language, 'Web sitesi', x.s('web').replaceFirst(site, ''), x.s('web').startsWith('http') ? x.s('web') : 'https://${x.s('web')}'),
    for (final a in alanlar)
      if ('${sosyal[a.s('kod')] ?? ''}'.isNotEmpty)
        _Satir(_sosyalSimge(a.s('kod')), a.s('ad'), '${sosyal[a.s('kod')]}'.replaceFirst(site, ''), '${sosyal[a.s('kod')]}'),
  ];
  final iletisim = <Widget>[
    if (x.s('telefon').isNotEmpty) _Satir(Icons.phone_outlined, 'Telefon', x.s('telefon'), 'tel:${x.s('telefon').replaceAll(' ', '')}'),
    if (x.s('eposta').isNotEmpty) _Satir(Icons.mail_outline, 'E-posta', x.s('eposta'), 'mailto:${x.s('eposta')}'),
    if (x.s('adres').isNotEmpty) _Satir(Icons.place_outlined, 'Adres', x.s('adres'), 'https://maps.google.com/?q=${Uri.encodeComponent(x.s('adres'))}'),
  ];
  return [
    if (izle.isNotEmpty) ...[const Baslik('Bizi takip edin'), ...izle],
    if (iletisim.isNotEmpty) ...[const Baslik('İletişim'), ...iletisim],
  ];
}

IconData _sosyalSimge(String kod) => switch (kod) {
  'instagram' => Icons.photo_camera_outlined,
  'facebook' => Icons.thumb_up_alt_outlined,
  'youtube' => Icons.play_circle_outline,
  'tiktok' => Icons.music_note_outlined,
  'linkedin' => Icons.work_outline,
  _ => Icons.alternate_email,
};

class _Satir extends StatelessWidget {
  const _Satir(this.simge, this.ad, this.deger, this.adres);

  final IconData simge;
  final String ad, deger, adres;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    dense: true,
    leading: Icon(simge, color: context.ana),
    title: Text(ad, style: TextStyle(color: context.soluk, fontSize: 12.5)),
    subtitle: Text(deger, style: const TextStyle(fontSize: 15)),
    trailing: Icon(Icons.open_in_new, size: 18, color: context.soluk),
    onTap: () async {
      final mesaj = ScaffoldMessenger.of(context);
      var ok = false;
      try {
        ok = await launchUrl(Uri.parse(adres), mode: LaunchMode.externalApplication);
      } catch (_) {}
      if (!ok) mesaj.showSnackBar(const SnackBar(content: Text('Bağlantı açılamadı')));
    },
  );
}

class _Ayrac extends StatelessWidget {
  const _Ayrac();

  @override
  Widget build(BuildContext context) => const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider());
}

class _Ust extends StatelessWidget {
  const _Ust({required this.api, required this.ad, required this.alt, required this.logo});

  final Api api;
  final String ad, alt;
  final String? logo;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      children: [
        Logo(api: api, ad: ad, yol: logo, boyut: 64),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ad, style: serif.copyWith(fontSize: 24, fontWeight: FontWeight.w600)),
              if (alt.isNotEmpty) Text(alt, style: TextStyle(color: context.soluk)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _OkulBolumu extends StatelessWidget {
  const _OkulBolumu({required this.api, required this.v, required this.okul});

  final Api api;
  final Map<String, dynamic> v;
  final Map<String, dynamic> okul;

  @override
  Widget build(BuildContext context) {
    final gorevler = ((v['gorevler'] as Map?) ?? const {}).cast<String, dynamic>();
    final yon = okul.l('yoneticiler');
    final sirali = [...yon.where((y) => y.s('gorev') == 'mudur'), ...yon.where((y) => y.s('gorev') != 'mudur')];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Ust(api: api, ad: okul.s('ad'), alt: [okul.s('tur'), okul.s('kampus')].where((e) => e.isNotEmpty).join(' · '), logo: _okulLogo(okul)),
        const SizedBox(height: 6),
        Text('${okul.n('ogrenci')} öğrenci · ${okul.n('ogretmen')} öğretmen', style: TextStyle(color: context.soluk)),
        if (okul.s('aciklama').isNotEmpty) ...[
          const Baslik('Okulumuz hakkında'),
          Text(okul.s('aciklama'), style: const TextStyle(height: 1.5, fontSize: 15)),
        ],
        if (sirali.isNotEmpty) ...[
          const Baslik('Okul yönetimi'),
          for (final y in sirali)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Logo(api: api, ad: y.s('ad'), boyut: 38),
              title: Text(y.s('ad')),
              subtitle: Text('${gorevler[y.s('gorev')] ?? y.s('gorev')}'),
            ),
        ],
        ..._baglantilar(context, v, okul),
      ],
    );
  }
}

/// Logo ya da baş harf rozeti.
class Logo extends StatelessWidget {
  const Logo({super.key, required this.api, required this.ad, this.yol, this.boyut = 44});

  final Api api;
  final String ad;
  final String? yol;
  final double boyut;

  @override
  Widget build(BuildContext context) {
    final harf = Text(
      ad.trim().isEmpty ? '?' : ad.trim().characters.first.toUpperCase(),
      style: serif.copyWith(fontSize: boyut * .43, fontWeight: FontWeight.w600, color: context.ana),
    );
    return Container(
      width: boyut,
      height: boyut,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: context.ana.withValues(alpha: .14), shape: BoxShape.circle),
      alignment: Alignment.center,
      child: yol == null
          ? harf
          : Image.network('${Api.taban}$yol', headers: api.kimlik, width: boyut, height: boyut, fit: BoxFit.contain, errorBuilder: (_, _, _) => harf),
    );
  }
}

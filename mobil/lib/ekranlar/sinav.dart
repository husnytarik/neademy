import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../bilesenler/ortak.dart';
import '../cekirdek/api.dart';
import '../cekirdek/optik.dart';
import '../cekirdek/takvim_model.dart';
import '../cekirdek/tema.dart';

const _siklar = 'ABCDE';

Color _puanRenk(num p) => p < 40
    ? const Color(0xFFD64545)
    : p < 70
    ? const Color(0xFFE0A100)
    : const Color(0xFF2E9E5B);

String _tarihGor(String t) => t.length >= 10 ? t.split('-').reversed.join('.') : t;

String _sayi(num? n) => n == null ? '–' : n.toStringAsFixed(n % 1 == 0 ? 0 : 1);

String _bugun() => tarihYaz(DateTime.now());

String _turAd(Map<String, dynamic> s) => s.s('tur') == 'yazili' ? 'Yazılı' : (s.s('amac') == 'acilis' ? 'Açılış' : 'Deneme');

/// Sunucudan veri çeken ve bir parça (sekme içeriği) çizen küçük yükleyici.
class _Yuklu extends StatefulWidget {
  const _Yuklu({super.key, required this.getir, required this.cizim});

  final Future<dynamic> Function() getir;
  final Widget Function(BuildContext context, dynamic veri, Future<void> Function() yenile) cizim;

  @override
  State<_Yuklu> createState() => _YukluState();
}

class _YukluState extends State<_Yuklu> {
  dynamic _veri;
  String? _hata;
  bool _yukleniyor = true;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final v = await widget.getir();
      if (mounted) {
        setState(() {
          _veri = v;
          _hata = null;
        });
      }
    } on ApiHata catch (e) {
      if (mounted && !e.oturumYok) setState(() => _hata = e.mesaj);
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_veri != null) return widget.cizim(context, _veri, _yukle);
    if (_yukleniyor) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text(
            _hata ?? 'Veri alınamadı.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.soluk),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              setState(() => _yukleniyor = true);
              _yukle();
            },
            child: const Text('Tekrar dene'),
          ),
        ],
      ),
    );
  }
}

/// Küçük renkli etiket (Deneme, Taslak, Yayında…).
Widget _etiket(String metin, Color renk) => Cip(metin, renk: renk);

// ─────────────────────────── Liste ───────────────────────────

/// Öğretmen (not-girisi) ve yönetim (sinav-yonetim): sınav listesi.
class SinavEkrani extends StatefulWidget {
  const SinavEkrani({super.key, required this.api, required this.yonetim});

  final Api api;
  final bool yonetim;

  @override
  State<SinavEkrani> createState() => _SinavEkraniState();
}

class _SinavEkraniState extends State<SinavEkrani> {
  int _yenile = 0;

  Future<void> _ac(Map<String, dynamic> s) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SinavDetayEkrani(api: widget.api, id: s.n('id'), yonetim: widget.yonetim),
      ),
    );
    if (mounted) setState(() => _yenile++);
  }

  Future<void> _yeni() async {
    final id = await Navigator.of(context).push<int>(MaterialPageRoute(builder: (_) => _YeniSinavFormu(api: widget.api)));
    if (id == null || !mounted) return;
    setState(() => _yenile++);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SinavDetayEkrani(api: widget.api, id: id, yonetim: true),
      ),
    );
    if (mounted) setState(() => _yenile++);
  }

  @override
  Widget build(BuildContext context) => VeriSayfasi(
    key: ValueKey(_yenile),
    baslik: 'Sınavlar',
    getir: () => widget.api.get('/api/sinav/liste'),
    cizim: (context, veri) {
      final liste = (veri as Map<String, dynamic>).l('sinavlar');
      return [
        if (widget.yonetim) EkleDugmesi('+ Yeni sınav', onPressed: _yeni),
        if (liste.isEmpty)
          BosNot(widget.yonetim ? 'Henüz sınav oluşturulmadı.' : 'Dersinize ait etkin sınav yok. Yönetim sınavı etkinleştirdiğinde burada görünür.'),
        const SizedBox(height: 4),
        for (final s in liste) _SinavKarti(s: s, yonetim: widget.yonetim, onTap: () => _ac(s)),
      ];
    },
  );
}

class _SinavKarti extends StatelessWidget {
  const _SinavKarti({required this.s, required this.yonetim, required this.onTap});

  final Map<String, dynamic> s;
  final bool yonetim;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final yazili = s.s('tur') == 'yazili';
    final hazirlik = s.l('hazirlik');
    final hazir = hazirlik.where((h) => h['tamam'] == true).length;
    final onayli = hazirlik.where((h) => h['onay'] == true).length;
    final dersler = [for (final d in (s['dersler'] as List? ?? const [])) d.toString()];
    final siniflar = [for (final d in (s['siniflar'] as List? ?? const [])) d.toString()];
    return KartKutu(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(s.s('ad'), style: serif.copyWith(fontSize: 17, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Text(_tarihGor(s.s('tarih')), style: TextStyle(color: context.soluk, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _etiket(_turAd(s), context.ana),
              if (s.n('duzey') > 0) _etiket('${s.n('duzey')}. sınıf', context.soluk),
              if (yonetim && s.s('durum') != 'aktif') _etiket('Taslak', const Color(0xFFB45309)),
              if (s['yayin'] == true) _etiket('Yayında', const Color(0xFF2E9E5B)),
            ],
          ),
          if (dersler.isNotEmpty) ...[const SizedBox(height: 8), Text(dersler.join(' · '), style: TextStyle(color: context.soluk, fontSize: 13, height: 1.3))],
          if (siniflar.isNotEmpty) Text(siniflar.join(', '), style: TextStyle(color: context.soluk, fontSize: 12.5)),
          const SizedBox(height: 8),
          if (yazili)
            Text('${s.n('okunan')} öğrenci puanı girildi', style: TextStyle(color: context.soluk, fontSize: 12.5))
          else ...[
            if (hazirlik.isNotEmpty)
              Text(
                'Hazırlık: $hazir/${hazirlik.length} ders tamam · $onayli onaylı · ${s.n('soru')} soru',
                style: TextStyle(color: hazir == hazirlik.length ? const Color(0xFF2E9E5B) : context.soluk, fontSize: 12.5),
              ),
            if (s.n('okunan') > 0) Text('${s.n('okunan')} öğrencinin cevabı girildi', style: TextStyle(color: context.soluk, fontSize: 12.5)),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────── Detay ───────────────────────────

class SinavDetayEkrani extends StatefulWidget {
  const SinavDetayEkrani({super.key, required this.api, required this.id, required this.yonetim});

  final Api api;
  final int id;
  final bool yonetim;

  @override
  State<SinavDetayEkrani> createState() => _SinavDetayEkraniState();
}

class _SinavDetayEkraniState extends State<SinavDetayEkrani> {
  Map<String, dynamic>? _detay;
  String? _hata;
  String _sekme = '';
  int _v = 0;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final j = await widget.api.get('/api/sinav/detay?id=${widget.id}') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _detay = j;
        _hata = null;
        _v++;
        if (_sekme.isEmpty) _sekme = j.m('sinav').s('tur') == 'yazili' ? 'puan' : 'hazirlik';
      });
    } on ApiHata catch (e) {
      if (mounted && !e.oturumYok) setState(() => _hata = e.mesaj);
    }
  }

  List<(String, String)> _sekmeler(bool yazili) => yazili
      ? [('puan', 'Puanlar'), ('sonuc', 'Sonuç'), ('kazanim', 'Kazanım'), if (widget.yonetim) ('ayar', 'Ayarlar')]
      : [
          ('hazirlik', 'Hazırlık'),
          ('sonuc', 'Sonuç'),
          ('analiz', 'Analiz'),
          if (widget.yonetim) ('cevap', 'Cevaplar'),
          if (widget.yonetim) ('ayar', 'Ayarlar'),
        ];

  Widget _icerik(Map<String, dynamic> d) {
    final sinav = d.m('sinav');
    final key = ValueKey('$_sekme$_v');
    switch (_sekme) {
      case 'hazirlik':
        return _HazirlikSekmesi(key: key, api: widget.api, sinavId: widget.id, yonetim: widget.yonetim);
      case 'sonuc':
        return _SonucSekmesi(key: key, api: widget.api, sinavId: widget.id, detay: d);
      case 'analiz':
        return _AnalizSekmesi(key: key, api: widget.api, sinavId: widget.id);
      case 'puan':
        return _PuanSekmesi(key: key, api: widget.api, sinavId: widget.id, ogrenciler: d.l('ogrenciler'));
      case 'kazanim':
        return _YaziliKazanimSekmesi(
          key: key,
          api: widget.api,
          sinavId: widget.id,
          kapsam: [for (final k in (sinav['kapsam'] as List? ?? const [])) k.toString()],
        );
      case 'cevap':
        return _CevapSekmesi(key: key, api: widget.api, sinavId: widget.id, detay: d);
      case 'ayar':
        return _AyarSekmesi(key: key, api: widget.api, detay: d, degisti: _yukle, silindi: () => Navigator.of(context).pop());
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final d = _detay;
    final sinav = d?.m('sinav') ?? const <String, dynamic>{};
    final yazili = sinav.s('tur') == 'yazili';
    final siniflar = [for (final c in (d?.l('siniflar') ?? const <Map<String, dynamic>>[])) (c['name'] ?? c['ad'] ?? '').toString()];
    return Scaffold(
      appBar: AppBar(title: Text(sinav.s('ad').isEmpty ? 'Sınav' : sinav.s('ad'))),
      body: d == null
          ? Center(
              child: _hata == null
                  ? const CircularProgressIndicator(strokeWidth: 2.5)
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _hata!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: context.soluk),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(onPressed: _yukle, child: const Text('Tekrar dene')),
                        ],
                      ),
                    ),
            )
          : RefreshIndicator(
              onRefresh: _yukle,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  KartKutu(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _etiket(_turAd(sinav), context.ana),
                            if (sinav.n('duzey') > 0) _etiket('${sinav.n('duzey')}. sınıf', context.soluk),
                            if (sinav.s('durum') != 'aktif') _etiket('Taslak', const Color(0xFFB45309)),
                            if (sinav['yayin'] == true) _etiket('Yayında', const Color(0xFF2E9E5B)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          [
                            _tarihGor(sinav.s('tarih')),
                            if (siniflar.isNotEmpty) siniflar.join(', '),
                            if (!yazili && sinav.n('yanlisKat') > 0) 'Yanlış katsayısı ${sinav.n('yanlisKat')}',
                          ].join(' · '),
                          style: TextStyle(color: context.soluk, fontSize: 13.5, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                  Sekmeler(secenekler: _sekmeler(yazili), secili: _sekme, degisti: (v) => setState(() => _sekme = v)),
                  const SizedBox(height: 12),
                  _icerik(d),
                ],
              ),
            ),
    );
  }
}

// ─────────────────────────── Hazırlık ───────────────────────────

class _HazirlikSekmesi extends StatefulWidget {
  const _HazirlikSekmesi({super.key, required this.api, required this.sinavId, required this.yonetim});

  final Api api;
  final int sinavId;
  final bool yonetim;

  @override
  State<_HazirlikSekmesi> createState() => _HazirlikSekmesiState();
}

class _HazirlikSekmesiState extends State<_HazirlikSekmesi> {
  int _yenile = 0;

  @override
  Widget build(BuildContext context) => _Yuklu(
    key: ValueKey(_yenile),
    getir: () => widget.api.get('/api/sinav/hazirlik?id=${widget.sinavId}'),
    cizim: (context, veri, _) {
      final dersler = (veri as Map<String, dynamic>).l('dersler');
      if (dersler.isEmpty) return const BosNot('Bu sınavda dersiniz yok.');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Her ders için cevap anahtarını ve soruların kazanımlarını girin, sonra onaylayın. Cevaplar girildiğinde sonuçlar buna göre hesaplanır.',
            style: TextStyle(color: context.soluk, fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 10),
          for (final d in dersler)
            KartKutu(
              onTap: () async {
                final tamam = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => _DersHazirlikEkrani(api: widget.api, sinavId: widget.sinavId, ders: d, yonetim: widget.yonetim),
                  ),
                );
                if (tamam == true && mounted) setState(() => _yenile++);
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(d.s('ders'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                      if (d['onay'] == true)
                        _etiket('Onaylı', const Color(0xFF2E9E5B))
                      else if (d['tamam'] == true)
                        _etiket('Onay bekliyor', const Color(0xFFB45309))
                      else
                        _etiket('Eksik', const Color(0xFFC62828)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${d.n('soruSayisi')} soru · cevap ${d.n('sik')}/${d.n('soruSayisi')} · kazanım ${d.n('kazanim')}/${d.n('gerekli')}',
                    style: TextStyle(color: context.soluk, fontSize: 13),
                  ),
                  if (d['onay'] == true && d.s('onayAd').isNotEmpty)
                    Text('Onaylayan: ${d.s('onayAd')}', style: TextStyle(color: context.soluk, fontSize: 12.5)),
                ],
              ),
            ),
        ],
      );
    },
  );
}

/// Bir dersin soru soru cevap anahtarı, iptal ve kazanım girişi.
class _DersHazirlikEkrani extends StatefulWidget {
  const _DersHazirlikEkrani({required this.api, required this.sinavId, required this.ders, required this.yonetim});

  final Api api;
  final int sinavId;
  final Map<String, dynamic> ders;
  final bool yonetim;

  @override
  State<_DersHazirlikEkrani> createState() => _DersHazirlikEkraniState();
}

class _DersHazirlikEkraniState extends State<_DersHazirlikEkrani> {
  late final List<String> _sik;
  late final List<bool> _iptal;
  late final List<TextEditingController> _kazanim;
  final _hizli = TextEditingController();
  bool _onay = false;
  bool _mesgul = false;
  bool _degisti = false;

  @override
  void initState() {
    super.initState();
    final sorular = widget.ders.l('sorular');
    _sik = [for (final q in sorular) q.s('sik')];
    _iptal = [for (final q in sorular) q['iptal'] == true];
    _kazanim = [for (final q in sorular) TextEditingController(text: q.s('kazanim'))];
    _onay = widget.ders['onay'] == true;
  }

  @override
  void dispose() {
    _hizli.dispose();
    for (final c in _kazanim) {
      c.dispose();
    }
    super.dispose();
  }

  void _hizliUygula() {
    final metin = _hizli.text.toUpperCase();
    setState(() {
      for (var i = 0; i < metin.length && i < _sik.length; i++) {
        final ch = metin[i];
        if (_siklar.contains(ch)) _sik[i] = ch;
      }
      _degisti = true;
    });
    FocusScope.of(context).unfocus();
  }

  Future<bool> _kaydet() async {
    setState(() => _mesgul = true);
    try {
      await widget.api.post('/api/sinav/sorular', {
        'id': widget.sinavId,
        'dersId': widget.ders.n('id'),
        'sorular': [
          for (var i = 0; i < _sik.length; i++) {'no': i + 1, 'sik': _sik[i], 'iptal': _iptal[i], 'kazanim': _kazanim[i].text},
        ],
      });
      // Öğretmen düzenleyince onay düşer; yönetim düzenleyince korunur.
      if (!widget.yonetim) _onay = false;
      _degisti = false;
      return true;
    } catch (e) {
      if (mounted) hataGoster(context, e);
      return false;
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  Future<void> _kaydetVeKapat() async {
    if (await _kaydet() && mounted) Navigator.pop(context, true);
  }

  Future<void> _onayla(bool onay) async {
    if (onay && _degisti && !await _kaydet()) return;
    setState(() => _mesgul = true);
    try {
      await widget.api.post('/api/sinav/onay', {'id': widget.sinavId, 'dersId': widget.ders.n('id'), 'onay': onay});
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _mesgul = false);
        hataGoster(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dolu = _sik.where((s) => s.isNotEmpty).length;
    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(title: Text('${widget.ders.s('ders')} · anahtar')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            KartKutu(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hızlı anahtar',
                    style: TextStyle(color: context.soluk, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _hizli,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[A-Ea-e?-]'))],
                          decoration: InputDecoration(
                            hintText: 'ABCDEABCDE…',
                            isDense: true,
                            helperText: 'Soru sırasıyla cevapları yazın ($dolu/${_sik.length})',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(onPressed: _hizliUygula, child: const Text('Uygula')),
                    ],
                  ),
                ],
              ),
            ),
            for (var i = 0; i < _sik.length; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: context.kart,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.ince),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 32,
                          child: Text('${i + 1}.', style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        for (final s in _siklar.split(''))
                          Padding(
                            padding: const EdgeInsets.only(right: 5),
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _sik[i] = _sik[i] == s ? '' : s;
                                _degisti = true;
                              }),
                              child: Container(
                                width: 30,
                                height: 30,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: _sik[i] == s ? context.ana : context.icZemin, borderRadius: BorderRadius.circular(10)),
                                child: Text(
                                  s,
                                  style: TextStyle(fontWeight: FontWeight.w700, color: _sik[i] == s ? Colors.white : context.yazi),
                                ),
                              ),
                            ),
                          ),
                        const Spacer(),
                        Text('İptal', style: TextStyle(color: context.soluk, fontSize: 12.5)),
                        Switch(
                          value: _iptal[i],
                          onChanged: (v) => setState(() {
                            _iptal[i] = v;
                            _degisti = true;
                          }),
                        ),
                      ],
                    ),
                    if (!_iptal[i])
                      TextField(
                        controller: _kazanim[i],
                        onChanged: (_) => _degisti = true,
                        minLines: 1,
                        maxLines: 3,
                        maxLength: 300,
                        decoration: const InputDecoration(hintText: 'Kazanım', isDense: true, counterText: ''),
                      ),
                    if (widget.ders.l('sorular')[i].s('kim').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('Giren: ${widget.ders.l('sorular')[i].s('kim')}', style: TextStyle(color: context.soluk, fontSize: 11.5)),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _mesgul ? null : _kaydetVeKapat,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: Text(_mesgul ? 'Kaydediliyor…' : 'Kaydet'),
            ),
            const SizedBox(height: 10),
            if (_onay)
              OutlinedButton(
                onPressed: _mesgul ? null : () => _onayla(false),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                child: const Text('Onayı kaldır'),
              )
            else
              OutlinedButton(
                onPressed: _mesgul ? null : () => _onayla(true),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                child: const Text('Kaydet ve onayla'),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Sonuç ───────────────────────────

class _SonucSekmesi extends StatelessWidget {
  const _SonucSekmesi({super.key, required this.api, required this.sinavId, this.detay});

  final Api api;
  final int sinavId;

  /// Sınav ayrıntısı: öğrenci cevapları ve cevap anahtarı (soru soru inceleme için; yönetimde hepsi, öğretmende kendi dersi).
  final Map<String, dynamic>? detay;

  @override
  Widget build(BuildContext context) => _Yuklu(
    getir: () => api.get('/api/sinav/sonuc?id=$sinavId'),
    cizim: (context, veri, _) {
      final j = veri as Map<String, dynamic>;
      final ogrenciler = j.l('ogrenciler');
      final dersler = j.l('dersler');
      final girenler = [
        for (final g in ogrenciler)
          if (g['ortalama'] is num) g,
      ];
      if (girenler.isEmpty) return const BosNot('Henüz sonuç yok. Cevaplar ya da puanlar girildiğinde burada görünür.');
      final ort = girenler.fold<double>(0, (t, g) => t + (g['ortalama'] as num)) / girenler.length;
      final dagilim = [
        ('0–39', girenler.where((g) => (g['ortalama'] as num) < 40).length, const Color(0xFFD64545)),
        ('40–69', girenler.where((g) => (g['ortalama'] as num) >= 40 && (g['ortalama'] as num) < 70).length, const Color(0xFFE0A100)),
        ('70–100', girenler.where((g) => (g['ortalama'] as num) >= 70).length, const Color(0xFF2E9E5B)),
      ];
      final sirali = [...ogrenciler]
        ..sort((a, b) {
          final x = a['ortalama'] is num ? a['ortalama'] as num : -1;
          final y = b['ortalama'] is num ? b['ortalama'] as num : -1;
          return y.compareTo(x);
        });
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KartKutu(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _sayi(ort),
                      style: serif.copyWith(fontSize: 38, fontWeight: FontWeight.w600, color: _puanRenk(ort)),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('ortalama · ${j.n('giren')}/${j.n('beklenen')} öğrenci girdi', style: TextStyle(color: context.soluk, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
                if (j['kisitli'] == true)
                  Text('Yalnızca ders verdiğiniz sınıflar ve dersiniz gösteriliyor.', style: TextStyle(color: context.soluk, fontSize: 12.5)),
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: [for (final (ad, n, renk) in dagilim) _etiket('$ad: $n', renk)]),
                if (dersler.length > 1) ...[
                  const SizedBox(height: 14),
                  for (final d in dersler) _DersOrtalamasi(d.s('ders'), _dersOrtalama(girenler, d.s('id'))),
                ],
              ],
            ),
          ),
          const Baslik('Öğrenciler'),
          for (final g in sirali)
            KartKutu(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              onTap: g['ortalama'] is num ? () => _ogrenciRaporu(context, g, dersler, j.m('sinav'), detay) : null,
              child: Row(
                children: [
                  SizedBox(
                    width: 30,
                    child: Text(
                      g['sira'] != null ? '${g.n('sira')}.' : '–',
                      style: TextStyle(color: context.soluk, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(g.s('ad'), style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text('${g.s('sinif')}${g.s('okulNo').isEmpty ? '' : ' · ${g.s('okulNo')}'}', style: TextStyle(color: context.soluk, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  if (g['ortalama'] is num)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: _puanRenk(g['ortalama'] as num).withValues(alpha: .14), borderRadius: BorderRadius.circular(10)),
                      child: Text(
                        _sayi(g['ortalama'] as num),
                        style: TextStyle(fontWeight: FontWeight.w700, color: _puanRenk(g['ortalama'] as num)),
                      ),
                    )
                  else
                    Text('Girmedi', style: TextStyle(color: context.soluk, fontSize: 12.5)),
                ],
              ),
            ),
        ],
      );
    },
  );

  /// Öğrencinin bu dersteki soru soru cevapları (yalnız yönetim; web'deki "Cevaplar" sekmesi gibi).
  static List<Widget> _soruSoru(BuildContext c, String dersId, int ogrenciId, Map<String, dynamic>? detay) {
    if (detay == null) return const [];
    final x = detay.l('dersler').where((e) => '${e.n('id')}' == dersId).firstOrNull;
    // Yönetimde öğrenci satırında, öğretmende ayrı listede (yalnız kendi ders ve sınıfları)
    final og = [
      ...detay.l('ogrenciler'),
      ...detay.l('cevapKayitlari'),
    ].where((e) => e.n('ogrenciId') == ogrenciId && e.m('cevaplar').s(dersId).isNotEmpty).firstOrNull;
    final cevap = og?.m('cevaplar').s(dersId) ?? '';
    if (x == null || cevap.isEmpty) return const [];
    return [
      CevapIzgarasi(
        soruSayisi: x.n('soruSayisi'),
        anahtar: x.s('anahtar'),
        cevap: cevap,
        iptal: [for (final i in (x['iptal'] as List? ?? const [])) (i as num).toInt()],
      ),
      const SizedBox(height: 16),
    ];
  }

  static double? _dersOrtalama(List<Map<String, dynamic>> girenler, String dersId) {
    final p = <num>[
      for (final g in girenler)
        if (g.m('dersler').m(dersId)['puan'] is num) g.m('dersler').m(dersId)['puan'] as num,
    ];
    return p.isEmpty ? null : p.fold<double>(0, (t, x) => t + x) / p.length;
  }

  static void _ogrenciRaporu(
    BuildContext context,
    Map<String, dynamic> g,
    List<Map<String, dynamic>> dersler,
    Map<String, dynamic> sinav,
    Map<String, dynamic>? detay,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .7,
        maxChildSize: .95,
        builder: (c, sc) => ListView(
          controller: sc,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            Text(g.s('ad'), style: serif.copyWith(fontSize: 21, fontWeight: FontWeight.w600)),
            Text('${g.s('sinif')} · ${sinav.s('ad')}', style: TextStyle(color: c.soluk, fontSize: 13)),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _sayi(g['ortalama'] as num),
                  style: serif.copyWith(fontSize: 40, fontWeight: FontWeight.w600, color: _puanRenk(g['ortalama'] as num)),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Text(g['sira'] != null ? 'ortalama · ${g.n('sira')}. sıra' : 'ortalama', style: TextStyle(color: c.soluk)),
                  ),
                ),
              ],
            ),
            if (g.m('siralama').isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final (ad, k) in [('Sınıfta', 'sinif'), ('Okulda', 'okul'), ('Genelde', 'genel')])
                    if (g.m('siralama').m(k).isNotEmpty) _etiket('$ad ${g.m('siralama').m(k).n('sira')}/${g.m('siralama').m(k).n('sayi')}', c.ana),
                ],
              ),
            if (g.m('degisim').isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '${g.m('degisim').s('ad')} sınavına göre ${(g.m('degisim')['fark'] as num? ?? 0) >= 0 ? '+' : ''}${_sayi(g.m('degisim')['fark'] as num?)} puan',
                style: TextStyle(
                  color: (g.m('degisim')['fark'] as num? ?? 0) >= 0 ? const Color(0xFF2E9E5B) : const Color(0xFFD64545),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (detay != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('Soru soru: yeşil doğru, kırmızı yanlış (altında doğru şık), gri boş.', style: TextStyle(color: c.soluk, fontSize: 12.5)),
              ),
            for (final d in dersler)
              if (g.m('dersler').m(d.s('id')).isNotEmpty) ...[
                _RaporDers(d.s('ders'), g.m('dersler').m(d.s('id'))),
                ..._soruSoru(c, d.s('id'), g.n('ogrenciId'), detay),
              ],
          ],
        ),
      ),
    );
  }
}

/// Soru soru işaret: yeşil doğru, kırmızı yanlış (altında doğru şık), gri boş, çizgili iptal (doğru sayılır).
class CevapIzgarasi extends StatelessWidget {
  const CevapIzgarasi({super.key, required this.soruSayisi, required this.anahtar, required this.cevap, this.iptal = const []});

  final int soruSayisi;
  final String anahtar;
  final String cevap;
  final List<int> iptal;

  @override
  Widget build(BuildContext context) {
    const yesil = Color(0xFF2E9E5B);
    const kirmizi = Color(0xFFD64545);
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: [
        for (var i = 0; i < soruSayisi; i++)
          Builder(
            builder: (context) {
              final h = i < cevap.length && cevap[i] != '-' && cevap[i] != ' ' && cevap[i] != '*' ? cevap[i].toUpperCase() : '-';
              final dogru = i < anahtar.length ? anahtar[i] : '?';
              final ipt = iptal.contains(i + 1);
              final renk = ipt
                  ? context.soluk
                  : h == '-'
                  ? context.soluk
                  : h == dogru
                  ? yesil
                  : kirmizi;
              final yanlis = !ipt && h != '-' && h != dogru;
              return Container(
                width: 40,
                height: 50,
                decoration: BoxDecoration(
                  color: renk.withValues(alpha: ipt || h == '-' ? .10 : .14),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: renk.withValues(alpha: .45)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${i + 1}', style: TextStyle(fontSize: 9.5, color: context.soluk, height: 1.1)),
                    Text(
                      h == '-' ? '·' : h,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: renk, height: 1.15),
                    ),
                    SizedBox(
                      height: 12,
                      child: yanlis
                          ? Text(
                              dogru,
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: yesil, height: 1.1),
                            )
                          : null,
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

class _DersOrtalamasi extends StatelessWidget {
  const _DersOrtalamasi(this.ad, this.ort);

  final String ad;
  final double? ort;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(ad, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            ),
            Text(_sayi(ort), style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: ((ort ?? 0).clamp(0, 100)) / 100, minHeight: 6, color: _puanRenk(ort ?? 0), backgroundColor: context.ince),
        ),
      ],
    ),
  );
}

class _RaporDers extends StatelessWidget {
  const _RaporDers(this.ad, this.d);

  final String ad;
  final Map<String, dynamic> d;

  @override
  Widget build(BuildContext context) {
    final puan = d['puan'] as num?;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DersOrtalamasi(ad, puan?.toDouble()),
          if (d['net'] != null)
            Text(
              '${d.n('dogru')} doğru · ${d.n('yanlis')} yanlış · ${d.n('bos')} boş · net ${d['net']}',
              style: TextStyle(color: context.soluk, fontSize: 12.5),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Madde analizi ───────────────────────────

class _AnalizSekmesi extends StatelessWidget {
  const _AnalizSekmesi({super.key, required this.api, required this.sinavId});

  final Api api;
  final int sinavId;

  static Color _zorlukRenk(String z) => switch (z) {
    'Kolay' => const Color(0xFF2E9E5B),
    'Zor' => const Color(0xFFD64545),
    _ => const Color(0xFFE0A100),
  };

  @override
  Widget build(BuildContext context) => _Yuklu(
    getir: () => api.get('/api/sinav/sonuc?id=$sinavId'),
    cizim: (context, veri, _) {
      final analiz = (veri as Map<String, dynamic>).l('analiz');
      if (analiz.isEmpty || analiz.every((a) => a.n('giren') == 0)) return const BosNot('Madde analizi için öğrenci cevapları girilmeli.');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final a in analiz) ...[
            Baslik('${a.s('ders')} · ${a.n('giren')} öğrenci', ust: 6),
            for (final q in a.l('sorular'))
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.kart,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.ince),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Soru ${q.n('no')}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        if (q['iptal'] == true)
                          _etiket('İptal', context.soluk)
                        else ...[
                          Text('Doğru: ${q.s('dogruSik')}', style: TextStyle(color: context.soluk, fontSize: 12.5)),
                          const Spacer(),
                          if (q.s('zorluk').isNotEmpty) _etiket(q.s('zorluk'), _zorlukRenk(q.s('zorluk'))),
                        ],
                      ],
                    ),
                    if (q['iptal'] != true) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ((q['basari'] as num? ?? 0).clamp(0, 100)) / 100,
                          minHeight: 6,
                          color: _puanRenk(q['basari'] as num? ?? 0),
                          backgroundColor: context.ince,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Başarı %${_sayi(q['basari'] as num?)} · ${q.n('dogru')} doğru · ${q.n('yanlis')} yanlış · ${q.n('bos')} boş'
                        '${q['ayirt'] != null ? ' · ayırt edicilik ${q['ayirt']}' : ''}',
                        style: TextStyle(color: context.soluk, fontSize: 12.5, height: 1.35),
                      ),
                      Text(
                        [
                          for (final s in [..._siklar.split(''), 'bos']) '${s == 'bos' ? 'Boş' : s}: ${q.m('dagilim').n(s)}',
                        ].join('   '),
                        style: TextStyle(color: context.soluk, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            if (a.l('kazanimlar').isNotEmpty) ...[
              Text(
                'Kazanım başarısı (düşükten yükseğe)',
                style: TextStyle(color: context.soluk, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              for (final k in a.l('kazanimlar'))
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(color: context.icZemin, borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Text(k.s('kazanim'), style: const TextStyle(fontSize: 13.5, height: 1.3))),
                          const SizedBox(width: 8),
                          _etiket('%${_sayi(k['oran'] as num?)}', _puanRenk(k['oran'] as num? ?? 0)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Soru ${[for (final x in (k['sorular'] as List? ?? const [])) x].join(', ')} · ${k.n('giren')} öğrenci'
                        '${k.n('islenmedi') > 0 ? ' · ${k.n('islenmedi')} öğrenciye işlenmemiş' : ''}',
                        style: TextStyle(color: context.soluk, fontSize: 12),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ],
      );
    },
  );
}

// ─────────────────────────── Yazılı: puanlar ve kazanımlar ───────────────────────────

class _PuanSekmesi extends StatefulWidget {
  const _PuanSekmesi({super.key, required this.api, required this.sinavId, required this.ogrenciler});

  final Api api;
  final int sinavId;
  final List<Map<String, dynamic>> ogrenciler;

  @override
  State<_PuanSekmesi> createState() => _PuanSekmesiState();
}

class _PuanSekmesiState extends State<_PuanSekmesi> {
  late final Map<int, TextEditingController> _puan = {
    for (final o in widget.ogrenciler) o.n('ogrenciId'): TextEditingController(text: o['puan'] is num ? _sayi(o['puan'] as num) : ''),
  };
  bool _mesgul = false;

  @override
  void dispose() {
    for (final c in _puan.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _kaydet() async {
    setState(() => _mesgul = true);
    try {
      await widget.api.post('/api/sinav/puanlar', {
        'id': widget.sinavId,
        'kayitlar': [
          for (final e in _puan.entries) {'ogrenciId': e.key, 'puan': e.value.text},
        ],
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Puanlar kaydedildi.')));
    } catch (e) {
      if (mounted) hataGoster(context, e);
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ogrenciler.isEmpty) return const BosNot('Bu sınavda puan girebileceğiniz öğrenci yok.');
    final girilen = _puan.values.where((c) => c.text.trim().isNotEmpty).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Puanlar 0–100 arasında girilir; boş bırakılan öğrenci sınava girmedi sayılır. ($girilen/${_puan.length})',
          style: TextStyle(color: context.soluk, fontSize: 13, height: 1.35),
        ),
        const SizedBox(height: 10),
        for (final o in widget.ogrenciler)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
              decoration: BoxDecoration(
                color: context.kart,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.ince),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(o.s('ad'), style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text('${o.s('sinif')}${o.s('okulNo').isEmpty ? '' : ' · ${o.s('okulNo')}'}', style: TextStyle(color: context.soluk, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 84,
                    child: TextField(
                      controller: _puan[o.n('ogrenciId')],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      onChanged: (_) => setState(() {}),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                      decoration: const InputDecoration(hintText: '–', isDense: true),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _mesgul ? null : _kaydet,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          child: Text(_mesgul ? 'Kaydediliyor…' : 'Puanları kaydet'),
        ),
      ],
    );
  }
}

class _YaziliKazanimSekmesi extends StatefulWidget {
  const _YaziliKazanimSekmesi({super.key, required this.api, required this.sinavId, required this.kapsam});

  final Api api;
  final int sinavId;
  final List<String> kapsam;

  @override
  State<_YaziliKazanimSekmesi> createState() => _YaziliKazanimSekmesiState();
}

class _YaziliKazanimSekmesiState extends State<_YaziliKazanimSekmesi> {
  late final List<TextEditingController> _liste = [for (final k in widget.kapsam) TextEditingController(text: k)];
  bool _mesgul = false;

  @override
  void dispose() {
    for (final c in _liste) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _kaydet() async {
    setState(() => _mesgul = true);
    try {
      await widget.api.post('/api/sinav/yazili-kazanim', {
        'id': widget.sinavId,
        'kazanimlar': [
          for (final c in _liste)
            if (c.text.trim().isNotEmpty) c.text.trim(),
        ],
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kazanımlar kaydedildi.')));
    } catch (e) {
      if (mounted) hataGoster(context, e);
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Yazılı sınavın bütününün ölçtüğü kazanımlar (isteğe bağlı, en çok 30).', style: TextStyle(color: context.soluk, fontSize: 13, height: 1.35)),
      const SizedBox(height: 10),
      for (final (i, c) in _liste.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: c,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 300,
                  decoration: InputDecoration(hintText: 'Kazanım ${i + 1}', isDense: true, counterText: ''),
                ),
              ),
              IconButton(
                tooltip: 'Kaldır',
                icon: Icon(Icons.close, size: 20, color: context.soluk),
                onPressed: () => setState(() => _liste.removeAt(i).dispose()),
              ),
            ],
          ),
        ),
      if (_liste.length < 30)
        TextButton.icon(
          onPressed: () => setState(() => _liste.add(TextEditingController())),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Kazanım ekle'),
        ),
      const SizedBox(height: 8),
      FilledButton(
        onPressed: _mesgul ? null : _kaydet,
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
        child: Text(_mesgul ? 'Kaydediliyor…' : 'Kaydet'),
      ),
    ],
  );
}

// ─────────────────────────── Yönetim: cevaplar ───────────────────────────

class _CevapSekmesi extends StatefulWidget {
  const _CevapSekmesi({super.key, required this.api, required this.sinavId, required this.detay});

  final Api api;
  final int sinavId;
  final Map<String, dynamic> detay;

  @override
  State<_CevapSekmesi> createState() => _CevapSekmesiState();
}

class _CevapSekmesiState extends State<_CevapSekmesi> {
  late final List<Map<String, dynamic>> _dersler = widget.detay.l('dersler');
  late final List<Map<String, dynamic>> _ogrenciler = widget.detay.l('ogrenciler');
  final Map<String, TextEditingController> _c = {};
  late int _dersId = _dersler.isEmpty ? 0 : _dersler.first.n('id');
  bool _mesgul = false;

  TextEditingController _ctrl(Map<String, dynamic> o, int dersId) =>
      _c.putIfAbsent('${o.n('ogrenciId')}:$dersId', () => TextEditingController(text: o.m('cevaplar').s('$dersId')));

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _kaydet() async {
    final kayit = <Map<String, dynamic>>[];
    for (final e in _c.entries) {
      final p = e.key.split(':');
      kayit.add({'ogrenciId': int.parse(p[0]), 'dersId': int.parse(p[1]), 'cevaplar': e.value.text});
    }
    setState(() => _mesgul = true);
    try {
      await widget.api.post('/api/sinav/cevaplar', {'id': widget.sinavId, 'kayitlar': kayit});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cevaplar kaydedildi.')));
    } catch (e) {
      if (mounted) hataGoster(context, e);
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  Future<void> _optik() async {
    final ham = await showDialog<_OptikGirdi>(context: context, builder: (_) => const _OptikDialog());
    if (ham == null || !mounted) {
      return;
    }
    final kayitlar = optikCoz(ham.metin, csv: ham.csv, noUzunluk: ham.noUzunluk, soruSayilari: [for (final d in _dersler) d.n('soruSayisi')]);
    final harita = {for (final o in _ogrenciler) noSade(o.s('okulNo')): o};
    var uygulanan = 0;
    final sorunlar = <String>[];
    for (final k in kayitlar) {
      final o = harita[k.no];
      if (o == null) {
        sorunlar.add('Satır ${k.satir}: "${k.no}" numaralı öğrenci bu sınavda yok');
        continue;
      }
      for (var j = 0; j < _dersler.length; j++) {
        if (_dersler[j].s('anahtar').contains('?')) {
          continue;
        }
        _ctrl(o, _dersler[j].n('id')).text = cevapTemizle(j < k.cevap.length ? k.cevap[j] : '');
      }
      uygulanan++;
      if (k.uyari.isNotEmpty) {
        sorunlar.add('Satır ${k.satir} (${o.s('ad')}): ${k.uyari}');
      }
    }
    setState(() {});
    final girmeyen = harita.keys.where((no) => !kayitlar.any((k) => k.no == no)).length;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Optik çıktısı'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$uygulanan öğrencinin cevabı yazıldı; dosyada olmayan öğrenci: $girmeyen. Kontrol edip "Cevapları kaydet"e basın.'),
              if (sorunlar.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('${sorunlar.length} uyarı:', style: const TextStyle(fontWeight: FontWeight.w700)),
                for (final u in sorunlar.take(30)) Text('• $u', style: const TextStyle(fontSize: 12.5)),
                if (sorunlar.length > 30) Text('… ve ${sorunlar.length - 30} uyarı daha', style: const TextStyle(fontSize: 12.5)),
              ],
            ],
          ),
        ),
        actions: [
          DiyalogEylemleri(
            children: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Tamam'))],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_dersler.isEmpty) return const BosNot('Sınavda ders yok.');
    final ders = _dersler.firstWhere((d) => d.n('id') == _dersId);
    final anahtar = ders.s('anahtar');
    final bekliyor = anahtar.contains('?') || anahtar.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_dersler.length > 1) ...[
          SuzgecCipleri(
            secenekler: [for (final d in _dersler) ('${d.n('id')}', d.s('ders'))],
            secili: '$_dersId',
            degisti: (v) => setState(() => _dersId = int.parse(v)),
          ),
          const SizedBox(height: 10),
        ],
        Text(
          bekliyor
              ? '${ders.s('ders')}: cevap anahtarı henüz tamamlanmadı. Önce Hazırlık sekmesinden anahtarı girin.'
              : '${ders.s('ders')} · ${ders.n('soruSayisi')} soru. Öğrencinin cevaplarını soru sırasıyla yazın (A–E, boş için -).',
          style: TextStyle(color: bekliyor ? const Color(0xFFB45309) : context.soluk, fontSize: 13, height: 1.35),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _optik,
          icon: const Icon(Icons.content_paste_go_outlined),
          label: const Text('Optik çıktısını yapıştır'),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
        ),
        const SizedBox(height: 10),
        for (final o in _ogrenciler)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              decoration: BoxDecoration(
                color: context.kart,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.ince),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${o.s('ad')} · ${o.s('sinif')}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextField(
                    controller: _ctrl(o, _dersId),
                    enabled: !bekliyor,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[A-Ea-e?-]'))],
                    maxLength: ders.n('soruSayisi'),
                    style: const TextStyle(letterSpacing: 1.5, fontFeatures: [FontFeature.tabularFigures()]),
                    decoration: const InputDecoration(hintText: 'ABCDE…', isDense: true),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _mesgul || bekliyor ? null : _kaydet,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          child: Text(_mesgul ? 'Kaydediliyor…' : 'Cevapları kaydet'),
        ),
      ],
    );
  }
}

class _OptikGirdi {
  const _OptikGirdi(this.metin, this.csv, this.noUzunluk);

  final String metin;
  final bool csv;
  final int noUzunluk;
}

class _OptikDialog extends StatefulWidget {
  const _OptikDialog();

  @override
  State<_OptikDialog> createState() => _OptikDialogState();
}

class _OptikDialogState extends State<_OptikDialog> {
  final _metin = TextEditingController();
  final _uzunluk = TextEditingController(text: '10');
  bool _csv = true;

  @override
  void dispose() {
    _metin.dispose();
    _uzunluk.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Optik çıktısı'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Her satır bir öğrencidir; okul numarasıyla eşleştirilir. Boş soru "-", "*" ya da boşluk olabilir.',
            style: TextStyle(color: context.soluk, fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 10),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('CSV')),
              ButtonSegment(value: false, label: Text('Sabit genişlik')),
            ],
            selected: {_csv},
            onSelectionChanged: (v) => setState(() => _csv = v.first),
          ),
          if (!_csv) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _uzunluk,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Okul no karakter sayısı', isDense: true),
            ),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: _metin,
            maxLines: 8,
            minLines: 4,
            autocorrect: false,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
            decoration: InputDecoration(hintText: _csv ? '12;ABCDE…;ABCD…' : '12        ABCDEABCDE', isDense: true),
          ),
        ],
      ),
    ),
    actions: [
      DiyalogEylemleri(
        children: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () => Navigator.pop(context, _OptikGirdi(_metin.text, _csv, (int.tryParse(_uzunluk.text) ?? 10).clamp(1, 20))),
            child: const Text('Uygula'),
          ),
        ],
      ),
    ],
  );
}

// ─────────────────────────── Yönetim: ayarlar ───────────────────────────

class _AyarSekmesi extends StatefulWidget {
  const _AyarSekmesi({super.key, required this.api, required this.detay, required this.degisti, required this.silindi});

  final Api api;
  final Map<String, dynamic> detay;
  final Future<void> Function() degisti;
  final VoidCallback silindi;

  @override
  State<_AyarSekmesi> createState() => _AyarSekmesiState();
}

class _AyarSekmesiState extends State<_AyarSekmesi> {
  bool _mesgul = false;

  Map<String, dynamic> get _sinav => widget.detay.m('sinav');

  Future<void> _istek(String yol, Map<String, dynamic> govde) async {
    setState(() => _mesgul = true);
    try {
      await widget.api.post(yol, govde);
      await widget.degisti();
    } catch (e) {
      if (mounted) hataGoster(context, e);
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  Future<void> _duzenle() async {
    final tamam = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _SinavDuzenle(api: widget.api, detay: widget.detay),
      ),
    );
    if (tamam == true) await widget.degisti();
  }

  Future<void> _sil() async {
    if (!await onayIste(context, '"${_sinav.s('ad')}" ve tüm cevap/puan kayıtları silinsin mi? Bu geri alınamaz.', evet: 'Sil')) return;
    setState(() => _mesgul = true);
    try {
      await widget.api.post('/api/sinav/sil', {'id': _sinav.n('id')});
      widget.silindi();
    } catch (e) {
      if (mounted) {
        setState(() => _mesgul = false);
        hataGoster(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final aktif = _sinav.s('durum') == 'aktif';
    final yayin = _sinav['yayin'] == true;
    final acilis = _sinav.s('amac') == 'acilis' && _sinav.s('tur') != 'yazili';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KartKutu(
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Öğretmenlere açık'),
                subtitle: Text(
                  aktif ? 'Etkin: dersi veren öğretmenler anahtar ve puan girebilir.' : 'Taslak: yalnızca yönetim görür.',
                  style: TextStyle(color: context.soluk, fontSize: 12.5),
                ),
                value: aktif,
                onChanged: _mesgul ? null : (v) => _istek('/api/sinav/aktif', {'id': _sinav.n('id'), 'aktif': v}),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Sonuçları yayınla'),
                subtitle: Text(
                  acilis ? 'Açılış sınavı sonuçları öğrenci ve velilere açılmaz.' : 'Yayınlanınca öğrenci ve veli sonucu görür.',
                  style: TextStyle(color: context.soluk, fontSize: 12.5),
                ),
                value: yayin,
                onChanged: _mesgul || acilis ? null : (v) => _istek('/api/sinav/yayin', {'id': _sinav.n('id'), 'yayin': v}),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        OutlinedButton(
          onPressed: _mesgul ? null : _duzenle,
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          child: const Text('Ad, tarih ve soru sayılarını düzenle'),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _mesgul ? null : _sil,
          child: Text('Sınavı sil', style: TextStyle(color: Colors.red.shade600)),
        ),
      ],
    );
  }
}

class _SinavDuzenle extends StatefulWidget {
  const _SinavDuzenle({required this.api, required this.detay});

  final Api api;
  final Map<String, dynamic> detay;

  @override
  State<_SinavDuzenle> createState() => _SinavDuzenleState();
}

class _SinavDuzenleState extends State<_SinavDuzenle> {
  late final _ad = TextEditingController(text: widget.detay.m('sinav').s('ad'));
  late String _tarih = widget.detay.m('sinav').s('tarih');
  late int _kat = widget.detay.m('sinav').n('yanlisKat');
  late final List<Map<String, dynamic>> _dersler = widget.detay.l('dersler');
  late final Map<int, TextEditingController> _soru = {for (final d in _dersler) d.n('id'): TextEditingController(text: '${d.n('soruSayisi')}')};
  bool _mesgul = false;

  bool get _yazili => widget.detay.m('sinav').s('tur') == 'yazili';

  @override
  void dispose() {
    _ad.dispose();
    for (final c in _soru.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _tarihSec() async {
    final s = await showDatePicker(context: context, initialDate: tarihCoz(_tarih), firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (s != null) setState(() => _tarih = tarihYaz(s));
  }

  Future<void> _kaydet() async {
    setState(() => _mesgul = true);
    try {
      await widget.api.post('/api/sinav/guncelle', {
        'id': widget.detay.m('sinav').n('id'),
        'ad': _ad.text,
        'tarih': _tarih,
        'yanlisKat': _kat,
        'dersler': [
          for (final d in _dersler) {'id': d.n('id'), 'soruSayisi': _soru[d.n('id')]!.text},
        ],
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _mesgul = false);
        hataGoster(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Sınavı düzenle')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        TextField(
          controller: _ad,
          maxLength: 80,
          decoration: const InputDecoration(labelText: 'Sınav adı'),
        ),
        const SizedBox(height: 4),
        OutlinedButton(
          onPressed: _tarihSec,
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), alignment: Alignment.centerLeft),
          child: Text('Tarih: ${_tarihGor(_tarih)}'),
        ),
        if (!_yazili) ...[
          const SizedBox(height: 14),
          DropdownButtonFormField<int>(
            initialValue: _kat,
            decoration: const InputDecoration(labelText: 'Yanlış katsayısı'),
            items: const [
              DropdownMenuItem(value: 0, child: Text('Yok')),
              DropdownMenuItem(value: 2, child: Text('2 yanlış 1 doğruyu götürür')),
              DropdownMenuItem(value: 3, child: Text('3 yanlış 1 doğruyu götürür')),
              DropdownMenuItem(value: 4, child: Text('4 yanlış 1 doğruyu götürür')),
            ],
            onChanged: (v) => setState(() => _kat = v ?? 0),
          ),
        ],
        const SizedBox(height: 14),
        for (final d in _dersler)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(
              controller: _soru[d.n('id')],
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: '${d.s('ders')} soru sayısı', helperText: 'Cevap girildikten sonra değiştirilemez'),
            ),
          ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _mesgul ? null : _kaydet,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          child: Text(_mesgul ? 'Kaydediliyor…' : 'Kaydet'),
        ),
      ],
    ),
  );
}

// ─────────────────────────── Yönetim: yeni sınav ───────────────────────────

class _YeniSinavFormu extends StatefulWidget {
  const _YeniSinavFormu({required this.api});

  final Api api;

  @override
  State<_YeniSinavFormu> createState() => _YeniSinavFormuState();
}

class _YeniSinavFormuState extends State<_YeniSinavFormu> {
  final _ad = TextEditingController();
  final _yaziliSoru = TextEditingController();
  final Map<String, TextEditingController> _soru = {};
  List<Map<String, dynamic>>? _duzeyler;
  String? _hata;
  String _tarih = _bugun();
  String _tur = 'test';
  String _amac = 'deneme';
  int? _duzey;
  int _kat = 0;
  String? _yaziliDers;
  bool _mesgul = false;

  @override
  void initState() {
    super.initState();
    widget.api
        .get('/api/sinav/secenekler')
        .then((j) {
          if (mounted) setState(() => _duzeyler = (j as Map<String, dynamic>).l('duzeyler'));
        })
        .catchError((Object e) {
          if (mounted) setState(() => _hata = e is ApiHata ? e.mesaj : 'Seçenekler alınamadı');
        });
  }

  @override
  void dispose() {
    _ad.dispose();
    _yaziliSoru.dispose();
    for (final c in _soru.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _dersler {
    final d = (_duzeyler ?? const []).where((x) => x.n('duzey') == _duzey);
    return d.isEmpty ? const [] : [for (final x in (d.first['dersler'] as List? ?? const [])) x.toString()];
  }

  Future<void> _tarihSec() async {
    final s = await showDatePicker(context: context, initialDate: tarihCoz(_tarih), firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (s != null) setState(() => _tarih = tarihYaz(s));
  }

  Future<void> _olustur() async {
    final govde = <String, dynamic>{'ad': _ad.text, 'tarih': _tarih, 'duzey': _duzey, 'tur': _tur};
    if (_tur == 'yazili') {
      govde['ders'] = _yaziliDers ?? '';
      govde['soruSayisi'] = _yaziliSoru.text;
      govde['yanlisKat'] = 0;
    } else {
      govde['amac'] = _amac;
      govde['yanlisKat'] = _kat;
      govde['dersler'] = [
        for (final e in _soru.entries)
          if (e.value.text.trim().isNotEmpty && _dersler.contains(e.key)) {'ders': e.key, 'soruSayisi': e.value.text},
      ];
    }
    setState(() => _mesgul = true);
    try {
      final j = await widget.api.post('/api/sinav/olustur', govde) as Map<String, dynamic>;
      if (mounted) Navigator.pop(context, j.n('id'));
    } catch (e) {
      if (mounted) {
        setState(() => _mesgul = false);
        hataGoster(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final duzeyler = _duzeyler;
    return Scaffold(
      appBar: AppBar(title: const Text('Yeni sınav')),
      body: duzeyler == null
          ? Center(
              child: _hata == null ? const CircularProgressIndicator(strokeWidth: 2.5) : Text(_hata!, style: TextStyle(color: context.soluk)),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Sekmeler(secenekler: const [('test', 'Test (deneme/açılış)'), ('yazili', 'Yazılı')], secili: _tur, degisti: (v) => setState(() => _tur = v)),
                const SizedBox(height: 14),
                TextField(
                  controller: _ad,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'Sınav adı'),
                ),
                const SizedBox(height: 4),
                OutlinedButton(
                  onPressed: _tarihSec,
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), alignment: Alignment.centerLeft),
                  child: Text('Tarih: ${_tarihGor(_tarih)}'),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  initialValue: _duzey,
                  decoration: const InputDecoration(labelText: 'Sınıf düzeyi'),
                  items: [
                    for (final d in duzeyler)
                      DropdownMenuItem(value: d.n('duzey'), child: Text('${d.n('duzey')}. sınıf (${(d['siniflar'] as List? ?? const []).join(', ')})')),
                  ],
                  onChanged: (v) => setState(() {
                    _duzey = v;
                    _yaziliDers = null;
                  }),
                ),
                const SizedBox(height: 14),
                if (_tur == 'yazili') ...[
                  DropdownButtonFormField<String>(
                    initialValue: _dersler.contains(_yaziliDers) ? _yaziliDers : null,
                    decoration: const InputDecoration(labelText: 'Ders'),
                    items: [for (final d in _dersler) DropdownMenuItem(value: d, child: Text(d))],
                    onChanged: (v) => setState(() => _yaziliDers = v),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _yaziliSoru,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Soru sayısı (isteğe bağlı)'),
                  ),
                ] else ...[
                  Sekmeler(secenekler: const [('deneme', 'Deneme'), ('acilis', 'Açılış')], secili: _amac, degisti: (v) => setState(() => _amac = v)),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    initialValue: _kat,
                    decoration: const InputDecoration(labelText: 'Yanlış katsayısı'),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Yok')),
                      DropdownMenuItem(value: 2, child: Text('2 yanlış 1 doğruyu götürür')),
                      DropdownMenuItem(value: 3, child: Text('3 yanlış 1 doğruyu götürür')),
                      DropdownMenuItem(value: 4, child: Text('4 yanlış 1 doğruyu götürür')),
                    ],
                    onChanged: (v) => setState(() => _kat = v ?? 0),
                  ),
                  const Baslik('Dersler ve soru sayıları'),
                  if (_duzey == null)
                    Text('Önce sınıf düzeyini seçin.', style: TextStyle(color: context.soluk))
                  else
                    for (final d in _dersler)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TextField(
                          controller: _soru.putIfAbsent(d, TextEditingController.new),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: InputDecoration(labelText: d, hintText: 'Soru sayısı (boşsa sınavda yok)'),
                        ),
                      ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _mesgul ? null : _olustur,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  child: Text(_mesgul ? 'Oluşturuluyor…' : 'Sınavı oluştur'),
                ),
              ],
            ),
    );
  }
}

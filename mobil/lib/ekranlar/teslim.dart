import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../bilesenler/ortak.dart';
import '../cekirdek/api.dart';
import '../cekirdek/tema.dart';

const _yesil = Color(0xFF2E9E5B);
const _kirmizi = Color(0xFFD64545);

String _saat(num ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms.toInt());
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

String _gunSaat(num ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms.toInt());
  return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} ${_saat(ms)}';
}

// ---------------------------------------------------------------------------
// Veli: güvenliğe gösterilecek QR kod
// ---------------------------------------------------------------------------

/// Kod 45 sn geçerli; ekran 40 sn'de yeniler. Güvenlik okutunca onay isteği buraya düşer.
class TeslimKoduEkrani extends StatefulWidget {
  const TeslimKoduEkrani({super.key, required this.api});

  final Api api;

  @override
  State<TeslimKoduEkrani> createState() => _TeslimKoduEkraniState();
}

class _TeslimKoduEkraniState extends State<TeslimKoduEkrani> with WidgetsBindingObserver {
  static const _yenileMs = 40000;

  Map<String, dynamic>? _kod;
  String? _hata;
  Map<String, dynamic>? _talep; // onay bekleyen istek
  ({String metin, bool tamam, DateTime bitis})? _sonuc;
  final _goruldu = <int>{};
  DateTime _kodZamani = DateTime.now();
  bool _kodIsteniyor = false;
  bool _kararVeriliyor = false;
  Timer? _saatTimer;
  Timer? _sorguTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _kodAl();
    _sorgula();
    _saatTimer = Timer.periodic(const Duration(milliseconds: 500), (_) => _tik());
    _sorguTimer = Timer.periodic(const Duration(seconds: 2), (_) => _sorgula());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saatTimer?.cancel();
    _sorguTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState durum) {
    if (durum == AppLifecycleState.resumed && _qrAcik && _gecen > _yenileMs) _kodAl();
  }

  bool get _qrAcik => _hata == null && _talep == null && _sonuc == null;
  int get _gecen => DateTime.now().difference(_kodZamani).inMilliseconds;

  void _tik() {
    if (!mounted) return;
    final s = _sonuc;
    if (s != null && DateTime.now().isAfter(s.bitis)) {
      setState(() => _sonuc = null);
      _kodAl();
      return;
    }
    if (_qrAcik && _gecen >= _yenileMs) _kodAl();
    if (_qrAcik) setState(() {});
  }

  Future<void> _kodAl() async {
    if (_kodIsteniyor) return;
    _kodIsteniyor = true;
    try {
      final r = await widget.api.get('/api/teslim/kod') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _kod = r;
        _hata = null;
        _kodZamani = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      if (_kod == null) setState(() => _hata = e is ApiHata ? e.mesaj : 'Kod alınamadı.');
    } finally {
      _kodIsteniyor = false;
    }
  }

  void _sonucGoster(String metin, bool tamam) =>
      setState(() => _sonuc = (metin: metin, tamam: tamam, bitis: DateTime.now().add(const Duration(seconds: 5))));

  Future<void> _sorgula() async {
    if (!mounted || _hata != null) return;
    try {
      final r = (await widget.api.get('/api/teslim/durum') as Map<String, dynamic>).m('talep');
      if (!mounted) return;
      if (r.isEmpty || _goruldu.contains(r.n('id'))) {
        // Onay paneli açıkken istek düştüyse (süre doldu, güvenlik iptal etti) QR'a dön
        if (_talep != null && _sonuc == null) {
          setState(() => _talep = null);
          _kodAl();
        }
        return;
      }
      final adlar = r.l('ogrenciler').map((o) => o.s('ad')).join(', ');
      if (r.s('durum') == 'bekliyor') {
        setState(() => _talep = r);
      } else {
        _goruldu.add(r.n('id'));
        setState(() => _talep = null);
        if (r.s('durum') == 'onaylandi') {
          _sonucGoster('$adlar teslim edildi.', true);
        } else if (r.s('durum') == 'reddedildi') {
          _sonucGoster('Teslim reddedildi.', false);
        } else if (r.s('durum') == 'doldu') {
          _sonucGoster('İstek zaman aşımına uğradı.', false);
        }
      }
    } catch (_) {/* bir sonraki turda yeniden denenir */}
  }

  Future<void> _karar(bool onay) async {
    final id = _talep!.n('id');
    setState(() => _kararVeriliyor = true);
    try {
      await widget.api.post('/api/teslim/karar', {'talepId': id, 'onay': onay});
      _goruldu.add(id);
      if (!mounted) return;
      setState(() => _talep = null);
      _sonucGoster(onay ? 'Teslim onaylandı. Öğrenci size teslim edilecek.' : 'Teslimi reddettiniz.', onay);
    } catch (e) {
      if (mounted) hataGoster(context, e);
      _sorgula();
    } finally {
      if (mounted) setState(() => _kararVeriliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Teslim kodu')),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [_icerik(context)]),
        ),
      );

  Widget _icerik(BuildContext context) {
    if (_hata != null) {
      return Column(children: [
        const SizedBox(height: 40),
        BosNot(_hata!),
        Center(
          child: FilledButton(
            onPressed: () {
              setState(() => _hata = null);
              _kodAl();
            },
            child: const Text('Tekrar dene'),
          ),
        ),
      ]);
    }
    final s = _sonuc;
    if (s != null) return _sonucPaneli(context, s.metin, s.tamam);
    final t = _talep;
    if (t != null) return _kararPaneli(context, t);
    final kod = _kod;
    if (kod == null) return const Padding(padding: EdgeInsets.only(top: 80), child: Center(child: CircularProgressIndicator()));
    final kodMetin = kod.s('kod');
    final kisi = kod.m('kisi');
    final kalan = (1 - _gecen / _yenileMs).clamp(0.0, 1.0);
    return Column(children: [
      KartKutu(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Text(kisi.s('ad'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          if (kisi.s('yakinlik').isNotEmpty && kisi.s('yakinlik') != 'Veli') Text(kisi.s('yakinlik'), style: TextStyle(color: context.soluk)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.ince)),
            child: QrImageView(data: kodMetin, size: 220, backgroundColor: Colors.white, eyeStyle: const QrEyeStyle(color: Colors.black, eyeShape: QrEyeShape.square)),
          ),
          const SizedBox(height: 14),
          Text(
            kodMetin.length > 3 ? '${kodMetin.substring(0, 3)} ${kodMetin.substring(3)}' : kodMetin,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: 5, fontFeatures: [FontFeature.tabularFigures()]),
          ),
          const SizedBox(height: 12),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: kalan, minHeight: 5, backgroundColor: context.ince)),
          const SizedBox(height: 10),
          Text('Bu kodu kapıdaki güvenliğe okutun. Kod kısa sürede yenilenir.', textAlign: TextAlign.center, style: TextStyle(color: context.soluk, fontSize: 13.5)),
        ]),
      ),
      const Baslik('Teslim alınabilecek öğrenciler', ust: 8),
      for (final o in kod.l('ogrenciler'))
        KartKutu(
          child: Row(children: [
            Expanded(child: Text(o.s('ad'), style: const TextStyle(fontWeight: FontWeight.w600))),
            Text([o.s('sinif'), o.s('okul')].where((e) => e.isNotEmpty).join(' · '), style: TextStyle(color: context.soluk, fontSize: 13)),
          ]),
        ),
    ]);
  }

  Widget _kararPaneli(BuildContext context, Map<String, dynamic> t) => Column(children: [
        const SizedBox(height: 12),
        const Icon(Icons.how_to_reg_outlined, size: 54),
        const SizedBox(height: 10),
        const Text('Teslim onayı', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Güvenlik aşağıdaki öğrencileri teslim etmek istiyor.', textAlign: TextAlign.center, style: TextStyle(color: context.soluk)),
        const SizedBox(height: 16),
        for (final o in t.l('ogrenciler'))
          KartKutu(child: Text([o.s('ad'), o.s('sinif')].where((e) => e.isNotEmpty).join(' · '), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16))),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _kararVeriliyor ? null : () => _karar(true),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: _yesil),
            child: const Text('Onayla'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _kararVeriliyor ? null : () => _karar(false),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), foregroundColor: _kirmizi),
            child: const Text('Reddet'),
          ),
        ),
      ]);

  Widget _sonucPaneli(BuildContext context, String metin, bool tamam) => Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(children: [
          Icon(tamam ? Icons.check_circle_outline : Icons.cancel_outlined, size: 72, color: tamam ? _yesil : _kirmizi),
          const SizedBox(height: 14),
          Text(metin, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.3)),
        ]),
      );
}

// ---------------------------------------------------------------------------
// Veli: teslim alabilecek kişiler
// ---------------------------------------------------------------------------

class TeslimYetkileriEkrani extends StatefulWidget {
  const TeslimYetkileriEkrani({super.key, required this.api});

  final Api api;

  @override
  State<TeslimYetkileriEkrani> createState() => _TeslimYetkileriEkraniState();
}

class _TeslimYetkileriEkraniState extends State<TeslimYetkileriEkrani> {
  int _surum = 0;

  void _yenile() => setState(() => _surum++);

  Future<void> _islem(Future<dynamic> Function() is_, {String? basari}) async {
    try {
      await is_();
      if (basari != null && mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(basari)));
      }
      _yenile();
    } catch (e) {
      if (mounted) hataGoster(context, e);
    }
  }

  Future<void> _ekle(Map<String, dynamic> ogr) async {
    final ad = TextEditingController(), yakinlik = TextEditingController(), telefon = TextEditingController();
    final tamam = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(c).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${ogr.s('ad')} için kişi ekle', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          TextField(controller: ad, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Ad soyad')),
          const SizedBox(height: 10),
          TextField(controller: yakinlik, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Yakınlık (anne, amca, servis şoförü…)')),
          const SizedBox(height: 10),
          TextField(controller: telefon, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telefon')),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Ekle')),
        ]),
      ),
    );
    if (tamam != true) return;
    await _islem(() => widget.api.post('/api/teslim/ekle', {'ogrenciId': ogr.n('id'), 'ad': ad.text, 'yakinlik': yakinlik.text, 'telefon': telefon.text}));
  }

  Future<void> _gecmis(Map<String, dynamic> ogr) async {
    try {
      final r = await widget.api.get('/api/teslim/gecmis?ogrenciId=${ogr.n('id')}') as Map<String, dynamic>;
      if (!mounted) return;
      final kayitlar = r.l('kayitlar');
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (c) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: .6,
          maxChildSize: .9,
          builder: (c, k) => ListView(controller: k, padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
            Text('${ogr.s('ad')} · teslim kayıtları', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            if (kayitlar.isEmpty) const BosNot('Henüz teslim kaydı yok.'),
            for (final x in kayitlar)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(x.s('kisi') + (x.s('yakinlik') == 'Veli' || x.s('yakinlik').isEmpty ? '' : ' (${x.s('yakinlik')})')),
                subtitle: Text(x.s('guvenlik').isEmpty ? '' : 'Teslim eden: ${x.s('guvenlik')}'),
                trailing: Text(_gunSaat(x['zaman'] as num), style: TextStyle(color: c.soluk, fontSize: 12.5)),
              ),
          ]),
        ),
      );
    } catch (e) {
      if (mounted) hataGoster(context, e);
    }
  }

  Future<void> _sil(Map<String, dynamic> k) async {
    if (!await onayIste(context, '${k.s('ad')} teslim alabilecekler arasından çıkarılsın mı?', evet: 'Çıkar')) return;
    await _islem(() => widget.api.post('/api/teslim/sil', {'id': k.n('id')}));
  }

  Future<void> _baglanti(Map<String, dynamic> k) async {
    if (k.s('baglanti').isNotEmpty) {
      final secim = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (c) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(leading: const Icon(Icons.copy_outlined), title: const Text('Bağlantıyı kopyala'), onTap: () => Navigator.pop(c, 'kopyala')),
            ListTile(leading: const Icon(Icons.link_off_outlined), title: const Text('Bağlantıyı iptal et'), onTap: () => Navigator.pop(c, 'iptal')),
          ]),
        ),
      );
      if (secim == 'kopyala') {
        await Clipboard.setData(ClipboardData(text: '${Api.taban}/t/${k.s('baglanti')}'));
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bağlantı kopyalandı.')));
      } else if (secim == 'iptal') {
        await _islem(() => widget.api.post('/api/teslim/baglanti', {'id': k.n('id'), 'islem': 'iptal'}), basari: 'Bağlantı iptal edildi.');
      }
      return;
    }
    try {
      final r = await widget.api.post('/api/teslim/baglanti', {'id': k.n('id'), 'islem': 'olustur'}) as Map<String, dynamic>;
      await Clipboard.setData(ClipboardData(text: '${Api.taban}/t/${r.s('kod')}'));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Özel bağlantı oluşturuldu ve kopyalandı. Kişiye mesajla gönderin.')));
      }
      _yenile();
    } catch (e) {
      if (mounted) hataGoster(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => VeriSayfasi(
        key: ValueKey(_surum),
        baslik: 'Teslim yetkileri',
        getir: () => widget.api.get('/api/teslim/liste'),
        cizim: (context, veri) {
          final ogrenciler = (veri as Map<String, dynamic>).l('ogrenciler');
          if (ogrenciler.isEmpty) return const [BosNot('Bağlı öğrenci bulunamadı.')];
          return [
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Çocuğunuzu sizden başka kimler teslim alabilir? Eklediğiniz kişi, özel bağlantı ile hesap açmadan QR kod alabilir.',
                  style: TextStyle(color: context.soluk, height: 1.35)),
            ),
            for (final o in ogrenciler) ...[
              Baslik('${o.s('ad')}${o.s('sinif').isEmpty ? '' : ' · ${o.s('sinif')}'}'),
              if (o.l('kisiler').isEmpty) const BosNot('Ek yetkili kişi yok; yalnızca veliler teslim alabilir.'),
              for (final k in o.l('kisiler'))
                KartKutu(
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(k.s('ad'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5)),
                        Text([k.s('yakinlik'), k.s('telefon')].where((e) => e.isNotEmpty).join(' · '), style: TextStyle(color: context.soluk, fontSize: 13.5)),
                        if (k.s('baglanti').isNotEmpty) ...[const SizedBox(height: 6), const Cip('Özel bağlantı açık')],
                      ]),
                    ),
                    IconButton(tooltip: 'Özel bağlantı', onPressed: () => _baglanti(k), icon: Icon(k.s('baglanti').isEmpty ? Icons.link : Icons.link_outlined)),
                    IconButton(tooltip: 'Çıkar', onPressed: () => _sil(k), icon: const Icon(Icons.delete_outline)),
                  ]),
                ),
              Wrap(spacing: 8, children: [
                OutlinedButton.icon(style: kompakt, onPressed: () => _ekle(o), icon: const Icon(Icons.person_add_alt_outlined), label: const Text('Kişi ekle')),
                TextButton.icon(onPressed: () => _gecmis(o), icon: const Icon(Icons.history), label: const Text('Teslim kayıtları')),
              ]),
            ],
          ];
        },
      );
}

// ---------------------------------------------------------------------------
// Güvenlik: kapıda QR okutup öğrenciyi teslim et
// ---------------------------------------------------------------------------

class TeslimKapiEkrani extends StatefulWidget {
  const TeslimKapiEkrani({super.key, required this.api});

  final Api api;

  @override
  State<TeslimKapiEkrani> createState() => _TeslimKapiEkraniState();
}

enum _Asama { tara, secim, bekle, sonuc }

class _TeslimKapiEkraniState extends State<TeslimKapiEkrani> {
  _Asama _asama = _Asama.tara;
  final _kodGir = TextEditingController();
  MobileScannerController? _kamera;
  bool _mesgul = false;
  String _sonHataKod = '';
  DateTime _sonHataZaman = DateTime.fromMillisecondsSinceEpoch(0);
  String? _mesaj;

  int? _talepId;
  Map<String, dynamic> _kisi = {};
  List<Map<String, dynamic>> _ogrenciler = [];
  final _secili = <int>{};
  List<Map<String, dynamic>> _secilenler = [];
  String _sonucDurum = '';
  List<Map<String, dynamic>> _bugun = [];
  Timer? _sorgu;
  Timer? _donus;

  @override
  void initState() {
    super.initState();
    _kamera = MobileScannerController(formats: const [BarcodeFormat.qrCode], facing: CameraFacing.back, detectionSpeed: DetectionSpeed.noDuplicates);
    _bugunYukle();
  }

  @override
  void dispose() {
    _sorgu?.cancel();
    _donus?.cancel();
    _kamera?.dispose();
    _kodGir.dispose();
    super.dispose();
  }

  Future<void> _bugunYukle() async {
    try {
      final r = await widget.api.get('/api/teslim/kapi/bugun') as Map<String, dynamic>;
      if (mounted) setState(() => _bugun = r.l('kayitlar'));
    } catch (_) {/* liste yardımcı bilgidir */}
  }

  void _oku(String kod) async {
    if (_mesgul || kod.trim().isEmpty) return;
    if (kod == _sonHataKod && DateTime.now().difference(_sonHataZaman).inSeconds < 8) return;
    _mesgul = true;
    setState(() => _mesaj = null);
    try {
      final r = await widget.api.post('/api/teslim/kapi/oku', {'kod': kod}) as Map<String, dynamic>;
      if (!mounted) return;
      _talepId = r.n('talepId');
      _kisi = r.m('kisi');
      _ogrenciler = r.l('ogrenciler');
      _secili
        ..clear()
        ..addAll(_ogrenciler.map((o) => o.n('id')));
      _kamera?.stop();
      setState(() => _asama = _Asama.secim);
    } catch (e) {
      _sonHataKod = kod;
      _sonHataZaman = DateTime.now();
      if (mounted) setState(() => _mesaj = e is ApiHata ? e.mesaj : 'Kod okunamadı.');
      // Aynı hatalı kodu art arda göndermemek için kısa bekleme
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      _mesgul = false;
      return;
    }
    _mesgul = true; // seçim/bekleme sürerken yeni okuma yok
  }

  void _basaDon() {
    _sorgu?.cancel();
    _donus?.cancel();
    _talepId = null;
    _kodGir.clear();
    _mesgul = false;
    _kamera?.start();
    if (mounted) {
      setState(() {
        _asama = _Asama.tara;
        _mesaj = null;
      });
    }
    _bugunYukle();
  }

  Future<void> _gonder() async {
    if (_secili.isEmpty) {
      setState(() => _mesaj = 'En az bir öğrenci seçin.');
      return;
    }
    try {
      await widget.api.post('/api/teslim/kapi/gonder', {'talepId': _talepId, 'ogrenciIds': _secili.toList()});
    } catch (e) {
      if (mounted) hataGoster(context, e);
      _basaDon();
      return;
    }
    _secilenler = [for (final o in _ogrenciler) if (_secili.contains(o.n('id'))) o];
    setState(() {
      _asama = _Asama.bekle;
      _mesaj = null;
    });
    _sorgu = Timer.periodic(const Duration(milliseconds: 1500), (_) async {
      try {
        final d = await widget.api.get('/api/teslim/kapi/durum?id=$_talepId') as Map<String, dynamic>;
        if (d.s('durum') != 'bekliyor') _sonucGoster(d.s('durum'));
      } catch (_) {}
    });
  }

  Future<void> _vazgec() async {
    try {
      await widget.api.post('/api/teslim/kapi/iptal', {'talepId': _talepId});
    } catch (_) {}
    _basaDon();
  }

  Future<void> _beklemeIptal() async {
    try {
      await widget.api.post('/api/teslim/kapi/iptal', {'talepId': _talepId});
    } catch (_) {}
    _sonucGoster('iptal');
  }

  void _sonucGoster(String durum) {
    _sorgu?.cancel();
    if (!mounted) return;
    setState(() {
      _sonucDurum = durum;
      _asama = _Asama.sonuc;
    });
    _donus = Timer(const Duration(seconds: 5), _basaDon);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Teslim kapısı')),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
            switch (_asama) {
              _Asama.tara => _tara(context),
              _Asama.secim => _secim(context),
              _Asama.bekle => _bekle(context),
              _Asama.sonuc => _sonuc(context),
            },
          ]),
        ),
      );

  Widget _tara(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 1,
            child: MobileScanner(
              controller: _kamera,
              onDetect: (c) {
                final v = c.barcodes.isEmpty ? null : c.barcodes.first.rawValue;
                if (v != null) _oku(v);
              },
              errorBuilder: (context, hata) => Container(
                color: context.icZemin,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(24),
                child: Text('Kamera açılamadı. Ayarlardan kamera iznini verin ya da kodu elle girin.', textAlign: TextAlign.center, style: TextStyle(color: context.soluk)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text("Velinin ekranındaki QR kodu çerçeveye alın.", style: TextStyle(color: context.soluk, fontSize: 13.5)),
        if (_mesaj != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_mesaj!, style: const TextStyle(color: _kirmizi, fontWeight: FontWeight.w600))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _kodGir,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Kodu elle gir', isDense: true),
              onSubmitted: _oku,
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(style: kompakt, onPressed: () => _oku(_kodGir.text), child: const Text('Tamam')),
        ]),
        const Baslik('Bugünkü teslimler', ust: 22),
        if (_bugun.isEmpty) const BosNot('Henüz teslim yapılmadı.'),
        for (final k in _bugun)
          KartKutu(
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(k.s('ogrenci'), style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('${k.s('sinif').isEmpty ? '' : '${k.s('sinif')} · '}${k.s('kisi')}${k.s('yakinlik') == 'Veli' || k.s('yakinlik').isEmpty ? '' : ' (${k.s('yakinlik')})'}',
                      style: TextStyle(color: context.soluk, fontSize: 13.5)),
                ]),
              ),
              Text(_saat(k['zaman'] as num), style: TextStyle(color: context.soluk)),
            ]),
          ),
      ]);

  Widget _secim(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_kisi.s('ad'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        Text(_kisi.s('yakinlik'), style: TextStyle(color: context.soluk)),
        const Baslik('Teslim edilecek öğrenciler', ust: 16),
        for (final o in _ogrenciler)
          KartKutu(
            padding: EdgeInsets.zero,
            child: CheckboxListTile(
              value: _secili.contains(o.n('id')),
              onChanged: (v) => setState(() => v == true ? _secili.add(o.n('id')) : _secili.remove(o.n('id'))),
              title: Text(o.s('ad'), style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text([o.s('sinif'), o.s('okul')].where((e) => e.isNotEmpty).join(' · ')),
              controlAffinity: ListTileControlAffinity.trailing,
            ),
          ),
        if (_mesaj != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_mesaj!, style: const TextStyle(color: _kirmizi, fontWeight: FontWeight.w600))),
        const SizedBox(height: 8),
        FilledButton(onPressed: _gonder, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)), child: const Text('Veliye onaya gönder')),
        const SizedBox(height: 10),
        OutlinedButton(onPressed: _vazgec, style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)), child: const Text('Vazgeç')),
      ]);

  Widget _bekle(BuildContext context) => Column(children: [
        const SizedBox(height: 30),
        const SizedBox(width: 44, height: 44, child: CircularProgressIndicator()),
        const SizedBox(height: 18),
        const Text('Veli onayı bekleniyor…', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        for (final o in _secilenler) Text([o.s('ad'), o.s('sinif')].where((e) => e.isNotEmpty).join(' · '), style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 26),
        OutlinedButton(onPressed: _beklemeIptal, child: const Text('İptal et')),
      ]);

  Widget _sonuc(BuildContext context) {
    final tamam = _sonucDurum == 'onaylandi';
    final metin = tamam
        ? 'Teslim edildi'
        : _sonucDurum == 'doldu'
            ? 'Veli zamanında onaylamadı'
            : _sonucDurum == 'iptal'
                ? 'İptal edildi'
                : 'Veli onaylamadı';
    return Padding(
      padding: const EdgeInsets.only(top: 50),
      child: Column(children: [
        Icon(tamam ? Icons.check_circle_outline : Icons.cancel_outlined, size: 80, color: tamam ? _yesil : _kirmizi),
        const SizedBox(height: 14),
        Text(metin, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        for (final o in _secilenler) Text(o.s('ad'), style: const TextStyle(fontSize: 16)),
      ]),
    );
  }
}

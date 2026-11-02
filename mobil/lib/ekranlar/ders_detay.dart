import 'package:flutter/material.dart';

import '../bilesenler/kazanim_secici.dart';
import '../bilesenler/ortak.dart';
import '../cekirdek/api.dart';
import '../cekirdek/takvim_model.dart';
import '../cekirdek/tema.dart';
import 'ders_bitir.dart';

/// Dersin ders saati geldi mi? Gelecek gün ya da henüz başlamamış ders bitirilemez (web: dersBasladi).
bool dersBasladi(String tarih, String bugun, String aralik) {
  if (tarih != bugun) return tarih.compareTo(bugun) < 0;
  final su = DateTime.now().toUtc().add(const Duration(hours: 3));
  final simdi = '${su.hour.toString().padLeft(2, '0')}:${su.minute.toString().padLeft(2, '0')}';
  return (aralik.length >= 5 ? aralik.substring(0, 5) : aralik).compareTo(simdi) <= 0;
}

/// Çok kazanımlı kayıtlar satır satır saklanır; listede tek satıra indirilir.
String _kazanimYaz(String k) {
  if (k.isEmpty) return '';
  return '${k.contains('\n') ? 'Kazanımlar' : 'Kazanım'}: ${k.split('\n').map((x) => x.split(' – ').first).join(', ')}';
}

/// Bir ders (ya da sınıf ataması) için sekmeli detay: Dersi bitir · Öğrenciler · Konular · Ödevler.
/// [ders] içinde `dersSaati` yoksa sınıf listesinden açılmıştır; o zaman "Dersi bitir" sekmesi yoktur.
class DersDetayEkrani extends StatefulWidget {
  const DersDetayEkrani({super.key, required this.api, required this.ders, required this.tarih, required this.bugun});

  final Api api;
  final Map<String, dynamic> ders;
  final String tarih;
  final String bugun;

  @override
  State<DersDetayEkrani> createState() => _DersDetayEkraniState();
}

class _DersDetayEkraniState extends State<DersDetayEkrani> {
  late String _sekme;
  bool get _programdan => widget.ders['dersSaati'] != null;
  bool get _bitirVar => _programdan && dersBasladi(widget.tarih, widget.bugun, widget.ders.s('aralik'));

  @override
  void initState() {
    super.initState();
    _sekme = _bitirVar ? 'bitir' : 'ogrenciler';
  }

  void _bitti() => Navigator.pop(context, true);

  @override
  Widget build(BuildContext context) {
    final d = widget.ders;
    final alt = _programdan ? '${uzunTarih(widget.tarih)} · ${d.n('dersSaati')}. ders · ${d.s('aralik')}' : 'Öğrenciler, konular ve ödevler';
    final sekmeler = [if (_bitirVar) ('bitir', 'Dersi bitir'), ('ogrenciler', 'Öğrenciler'), ('konular', 'Konular'), ('odevler', 'Ödevler')];
    final api = widget.api;
    return Scaffold(
      appBar: AppBar(title: Text('${d.s('sinif')} · ${d.s('ders')}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    DersRozeti(d.s('kisa'), rengiCoz(d.s('renk')) ?? context.ana, boyut: 34),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(alt, style: TextStyle(color: context.soluk, fontSize: 13.5)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Sekmeler(secenekler: sekmeler, secili: _sekme, degisti: (v) => setState(() => _sekme = v)),
              ],
            ),
          ),
          Expanded(
            child: switch (_sekme) {
              'bitir' => DersBitirGovde(api: api, ders: d, tarih: widget.tarih, bitti: _bitti),
              'ogrenciler' => _OgrencilerSekmesi(key: ValueKey('o'), api: api, ders: d, tarih: widget.tarih),
              'konular' => _KonularSekmesi(key: ValueKey('k'), api: api, ders: d, tarih: widget.tarih, bugun: widget.bugun),
              _ => _OdevlerSekmesi(key: const ValueKey('d'), api: api, ders: d, tarih: widget.tarih, bugun: widget.bugun),
            },
          ),
        ],
      ),
    );
  }
}

/// Yükleme/hata durumunu yöneten sekme gövdesi.
class _SekmeGovdesi extends StatefulWidget {
  const _SekmeGovdesi({super.key, required this.getir, required this.cizim});

  final Future<dynamic> Function() getir;
  final List<Widget> Function(BuildContext context, Map<String, dynamic> veri, Future<void> Function() yenile) cizim;

  @override
  State<_SekmeGovdesi> createState() => _SekmeGovdesiState();
}

class _SekmeGovdesiState extends State<_SekmeGovdesi> {
  Map<String, dynamic>? _veri;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final v = await widget.getir() as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _veri = v;
          _hata = null;
        });
      }
    } on ApiHata catch (e) {
      if (mounted && !e.oturumYok) setState(() => _hata = e.mesaj);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = _veri;
    if (v == null) {
      return _hata == null
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_hata!, style: TextStyle(color: context.soluk)),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _yukle, child: const Text('Tekrar dene')),
                ],
              ),
            );
    }
    return RefreshIndicator(
      onRefresh: _yukle,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: widget.cizim(context, v, _yukle),
      ),
    );
  }
}

const _isaret = {
  'geldi': ('✓', 'Geldi', Color(0xFF2E9E5B)),
  'gec': ('G', 'Geç geldi', Color(0xFFE0A100)),
  'gelmedi': ('✗', 'Gelmedi', Color(0xFFD64545)),
  'izinli': ('İ', 'İzinli', Color(0xFF8A867D)),
};

class _OgrencilerSekmesi extends StatelessWidget {
  const _OgrencilerSekmesi({super.key, required this.api, required this.ders, required this.tarih});

  final Api api;
  final Map<String, dynamic> ders;
  final String tarih;

  @override
  Widget build(BuildContext context) {
    final gunluk = ders['dersSaati'] != null;
    final q = 'atamaId=${ders.n('atamaId')}${gunluk ? '&tarih=$tarih&dersSaati=${ders.n('dersSaati')}' : ''}';
    return _SekmeGovdesi(
      getir: () => api.get('/api/ders/ogrenciler?$q'),
      cizim: (context, j, _) {
        final ogr = j.l('ogrenciler');
        final alindi = j['yoklamaAlindi'] == true;
        int say(String d) => ogr.where((o) => o.s('durum') == d).length;
        final ozet =
            '${ogr.length} öğrenci${!gunluk
                ? ''
                : alindi
                ? ' · ${say('geldi') + say('gec')} geldi · ${say('gelmedi')} gelmedi · ${say('izinli')} izinli'
                : ' · bu ders için yoklama henüz alınmadı'}';
        return [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(ozet, style: TextStyle(color: context.soluk, fontSize: 13.5)),
          ),
          if (ogr.isEmpty) const BosNot('Bu sınıfta aktif öğrenci yok.'),
          for (var i = 0; i < ogr.length; i++)
            KartKutu(
              alt: 8,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(color: context.soluk, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(child: Text(ogr[i].s('ad'), style: const TextStyle(fontSize: 15.5))),
                  if (gunluk && alindi) _YoklamaIsareti(ogr[i].s('durum')),
                ],
              ),
            ),
          if (gunluk && alindi)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('✓ geldi · G geç · ✗ gelmedi · İ izinli', style: TextStyle(color: context.soluk, fontSize: 12.5)),
            ),
        ];
      },
    );
  }
}

class _YoklamaIsareti extends StatelessWidget {
  const _YoklamaIsareti(this.durum);

  final String durum;

  @override
  Widget build(BuildContext context) {
    final (harf, ad, renk) = _isaret[durum] ?? ('–', 'Kayıt yok', context.soluk);
    return Tooltip(
      message: ad,
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: renk.withValues(alpha: .15), shape: BoxShape.circle),
        child: Text(
          harf,
          style: TextStyle(color: renk, fontWeight: FontWeight.w800, fontSize: 14),
        ),
      ),
    );
  }
}

/// Liste başlığı + "Ekle" düğmesi.
class _EkleBasligi extends StatelessWidget {
  const _EkleBasligi(this.baslik, this.dugme, this.ac);

  final String baslik;
  final String dugme;
  final VoidCallback ac;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Expanded(
          child: Text(baslik, style: serif.copyWith(fontSize: 18, fontWeight: FontWeight.w600)),
        ),
        FilledButton.tonalIcon(onPressed: ac, icon: const Icon(Icons.add, size: 18), label: Text(dugme)),
      ],
    ),
  );
}

class _KayitKarti extends StatelessWidget {
  const _KayitKarti({required this.baslik, required this.alt, required this.aciklama, required this.sil, this.takip, this.onTakip});

  final String baslik;
  final String alt;
  final String aciklama;
  final VoidCallback sil;
  final String? takip;
  final VoidCallback? onTakip;

  @override
  Widget build(BuildContext context) => KartKutu(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(baslik, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, height: 1.25)),
            ),
            const SizedBox(width: 8),
            Text(alt, style: TextStyle(color: context.soluk, fontSize: 12.5)),
          ],
        ),
        if (aciklama.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(aciklama, style: TextStyle(color: context.soluk, fontSize: 13.5, height: 1.35)),
          ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (takip != null) TextButton(onPressed: onTakip, child: Text(takip!)),
            const Spacer(),
            TextButton(
              onPressed: sil,
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFD64545)),
              child: const Text('Sil'),
            ),
          ],
        ),
      ],
    ),
  );
}

Future<bool> _sil(BuildContext context, Api api, String yol, int id, String baslik) async {
  if (!await onayIste(context, '"$baslik" silinsin mi?', evet: 'Sil')) return false;
  try {
    await api.post(yol, {'id': id});
    return true;
  } catch (e) {
    if (context.mounted) hataGoster(context, e);
    return false;
  }
}

class _KonularSekmesi extends StatefulWidget {
  const _KonularSekmesi({super.key, required this.api, required this.ders, required this.tarih, required this.bugun});

  final Api api;
  final Map<String, dynamic> ders;
  final String tarih;
  final String bugun;

  @override
  State<_KonularSekmesi> createState() => _KonularSekmesiState();
}

class _KonularSekmesiState extends State<_KonularSekmesi> {
  int _surum = 0;

  Future<void> _ekle() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EkleSayfasi(
          api: widget.api,
          ders: widget.ders,
          konu: true,
          bugun: widget.bugun,
          varsayilanTarih: widget.tarih.compareTo(widget.bugun) > 0 ? widget.bugun : widget.tarih,
        ),
      ),
    );
    if (ok == true && mounted) setState(() => _surum++);
  }

  @override
  Widget build(BuildContext context) => _SekmeGovdesi(
    key: ValueKey(_surum),
    getir: () => widget.api.get('/api/ders/konular?atamaId=${widget.ders.n('atamaId')}'),
    cizim: (context, j, _) {
      final konular = j.l('konular');
      return [
        _EkleBasligi('İşlenen konular', 'Konu ekle', _ekle),
        if (konular.isEmpty) const BosNot('Henüz konu girilmemiş.'),
        for (final x in konular)
          _KayitKarti(
            baslik: x.s('baslik'),
            alt: kisaTarih(x.s('tarih')),
            aciklama: [x.s('aciklama'), _kazanimYaz(x.s('kazanim'))].where((e) => e.isNotEmpty).join(' · '),
            sil: () async {
              if (await _sil(context, widget.api, '/api/ders/konu-sil', x.n('id'), x.s('baslik')) && mounted) setState(() => _surum++);
            },
          ),
      ];
    },
  );
}

class _OdevlerSekmesi extends StatefulWidget {
  const _OdevlerSekmesi({super.key, required this.api, required this.ders, required this.tarih, required this.bugun});

  final Api api;
  final Map<String, dynamic> ders;
  final String tarih;
  final String bugun;

  @override
  State<_OdevlerSekmesi> createState() => _OdevlerSekmesiState();
}

class _OdevlerSekmesiState extends State<_OdevlerSekmesi> {
  int _surum = 0;

  Future<void> _ekle() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EkleSayfasi(api: widget.api, ders: widget.ders, konu: false, bugun: widget.bugun, varsayilanTarih: gunKaydir(widget.bugun, 7)),
      ),
    );
    if (ok == true && mounted) setState(() => _surum++);
  }

  @override
  Widget build(BuildContext context) => _SekmeGovdesi(
    key: ValueKey(_surum),
    getir: () => widget.api.get('/api/ders/odevler?atamaId=${widget.ders.n('atamaId')}'),
    cizim: (context, j, _) {
      final odevler = j.l('odevler');
      return [
        _EkleBasligi('Verilen ödevler', 'Ödev ver', _ekle),
        if (odevler.isEmpty) const BosNot('Henüz ödev verilmemiş.'),
        for (final x in odevler)
          _KayitKarti(
            baslik: x.s('baslik'),
            alt: 'Son: ${kisaTarih(x.s('sonTarih'))}',
            aciklama: [
              if (x.s('gorunur').isNotEmpty && x.s('gorunur').compareTo(widget.bugun) > 0) 'Planlı: ${kisaTarih(x.s('gorunur'))} tarihinde öğrencilere görünür',
              x.s('aciklama'),
              _kazanimYaz(x.s('kazanim')),
            ].where((e) => e.isNotEmpty).join(' · '),
            takip: x.s('gorunur').isNotEmpty && x.s('gorunur').compareTo(widget.bugun) > 0
                ? null
                : (x.n('yapildi') > 0 || x.n('soru') > 0)
                ? 'Takip et · ${x.n('yapildi')} onay bekliyor${x.n('soru') > 0 ? ', ${x.n('soru')} soru' : ''}'
                : 'Takip et · ${x.n('dogrulandi')}/${x.n('toplam')} doğrulandı',
            onTakip: () => ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(const SnackBar(content: Text('Ödev takibi için panelden "Ödev takip" bölümünü açın.'))),
            sil: () async {
              if (await _sil(context, widget.api, '/api/ders/odev-sil', x.n('id'), x.s('baslik')) && mounted) setState(() => _surum++);
            },
          ),
      ];
    },
  );
}

/// Konu ya da ödev ekleme formu (web: ekleForm).
class EkleSayfasi extends StatefulWidget {
  const EkleSayfasi({super.key, required this.api, required this.ders, required this.konu, required this.bugun, required this.varsayilanTarih});

  final Api api;
  final Map<String, dynamic> ders;
  final bool konu;
  final String bugun;
  final String varsayilanTarih;

  @override
  State<EkleSayfasi> createState() => _EkleSayfasiState();
}

class _EkleSayfasiState extends State<EkleSayfasi> {
  final _baslik = TextEditingController();
  final _aciklama = TextEditingController();
  late final KazanimSecimi _kazanim = KazanimSecimi(tek: !widget.konu);
  late String _tarih = widget.varsayilanTarih;
  late String _yayin = widget.bugun;
  bool _gonderiliyor = false;

  @override
  void initState() {
    super.initState();
    _kazanim.yukle(widget.api, sinifId: widget.ders.n('sinifId'), ders: widget.ders.s('ders'));
  }

  @override
  void dispose() {
    _baslik.dispose();
    _aciklama.dispose();
    _kazanim.dispose();
    super.dispose();
  }

  Future<void> _tarihSec(bool yayin) async {
    final bugun = tarihCoz(widget.bugun);
    final su = tarihCoz(yayin ? _yayin : _tarih);
    final ilk = widget.konu ? DateTime(2024) : DateTime(bugun.year, bugun.month, bugun.day);
    final son = widget.konu
        ? DateTime(bugun.year, bugun.month, bugun.day)
        : yayin
        ? DateTime(tarihCoz(_tarih).year, tarihCoz(_tarih).month, tarihCoz(_tarih).day)
        : DateTime(2030);
    final d = await showDatePicker(context: context, initialDate: DateTime(su.year, su.month, su.day), firstDate: ilk, lastDate: son);
    if (d == null) return;
    final t = tarihYaz(DateTime.utc(d.year, d.month, d.day));
    setState(() {
      if (yayin) {
        _yayin = t;
      } else {
        _tarih = t;
        if (_yayin.compareTo(t) > 0) _yayin = t;
      }
    });
  }

  Future<void> _kaydet() async {
    setState(() => _gonderiliyor = true);
    try {
      await widget.api.post(widget.konu ? '/api/ders/konu-ekle' : '/api/ders/odev-ekle', {
        'atamaId': widget.ders.n('atamaId'),
        'baslik': _baslik.text,
        'tarih': _tarih,
        'aciklama': _aciklama.text,
        'kazanimlar': widget.konu ? _kazanim.kodlar : <String>[],
        'kazanimKod': widget.konu ? '' : (_kazanim.kodlar.firstOrNull ?? ''),
        'gorunur': widget.konu ? '' : _yayin,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kaydedildi.')));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _gonderiliyor = false);
        hataGoster(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.konu ? 'Konu ekle' : 'Ödev ver')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text(widget.konu ? 'Ünite ve kazanımlar' : 'Ödevin kazanımı (isteğe bağlı)', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        KazanimAlani(secim: _kazanim),
        ListenableBuilder(
          listenable: _kazanim,
          builder: (_, _) => (!widget.konu || (_kazanim.yuklendi && !_kazanim.var_))
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: _baslik,
                    maxLength: 120,
                    decoration: const InputDecoration(labelText: 'Başlık'),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _aciklama,
          maxLength: 500,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Açıklama (isteğe bağlı)'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _tarihSec(false),
          icon: const Icon(Icons.event, size: 20),
          label: Text('${widget.konu ? 'İşlendiği tarih' : 'Son teslim'}: ${uzunTarih(_tarih)}'),
        ),
        if (!widget.konu) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _tarihSec(true),
            icon: const Icon(Icons.visibility_outlined, size: 20),
            label: Text('Öğrenci ve veliler görsün: ${uzunTarih(_yayin)}'),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Bugünü bırakırsanız hemen görünür; ileri bir tarih seçerseniz o güne kadar gizli kalır.',
              style: TextStyle(color: context.soluk, fontSize: 12.5),
            ),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _gonderiliyor ? null : _kaydet,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: Text(_gonderiliyor ? 'Kaydediliyor…' : 'Kaydet'),
        ),
      ],
    ),
  );
}

import 'package:flutter/material.dart';

import '../bilesenler/ortak.dart';
import '../cekirdek/api.dart';
import '../cekirdek/takvim_model.dart';
import '../cekirdek/tema.dart';

const _kanGruplari = ['A Rh+', 'A Rh-', 'B Rh+', 'B Rh-', 'AB Rh+', 'AB Rh-', '0 Rh+', '0 Rh-'];
const _sonuclar = {'sinifa': 'Sınıfa döndü', 'eve': 'Eve gönderildi', 'hastane': 'Hastaneye sevk', 'ilac': 'İlaç / müdahale sonrası dinlendi'};
const _kirmizi = Color(0xFFD64545);

/// Öğrenci sağlık kartı. [rol]: 'yonetim' | 'ogretmen' | 'veli' | 'ogrenci'.
/// Yönetim: liste + revir; öğretmen: uyarılı öğrencilerim; veli/öğrenci: kendi çocuğu / kendisi.
class SaglikEkrani extends StatefulWidget {
  const SaglikEkrani({super.key, required this.api, required this.rol});

  final Api api;
  final String rol;

  @override
  State<SaglikEkrani> createState() => _SaglikEkraniState();
}

class _SaglikEkraniState extends State<SaglikEkrani> {
  String _sekme = 'liste';
  String _filtre = 'tum';
  final _ara = TextEditingController();
  String _aranan = '';

  Widget _satir(Map<String, dynamic> o) {
    final uyarilar = [for (final x in (o['uyarilar'] as List? ?? const [])) '$x'];
    return KartKutu(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SaglikKartiEkrani(api: widget.api, ogrenciId: o.n('id')))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.s('ad'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5)),
                Text([o.s('sinif'), if (o.s('kanGrubu').isNotEmpty) o.s('kanGrubu')].where((x) => x.isNotEmpty).join(' · '), style: TextStyle(color: context.soluk, fontSize: 13)),
                if (uyarilar.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Wrap(spacing: 6, children: [for (final u in uyarilar) Cip(u, renk: _kirmizi)])),
              ],
            ),
          ),
          if (widget.rol == 'yonetim' && o['kartVar'] != true) const Cip('Kart yok'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.rol) {
      case 'veli' || 'ogrenci':
        return VeriSayfasi(
          baslik: widget.rol == 'veli' ? 'Sağlık kartı' : 'Sağlık kartım',
          getir: () => widget.api.get('/api/saglik/baglam'),
          cizim: (context, raw) {
            final liste = (raw as Map<String, dynamic>).l('ogrenciler');
            if (liste.isEmpty) return const [BosNot('Bağlı öğrenci bulunamadı.')];
            return [
              for (final o in liste)
                KartKutu(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SaglikKartiEkrani(api: widget.api, ogrenciId: o.n('id')))),
                  child: Row(children: [Expanded(child: Text('${o.s('ad')}${o.s('sinif').isEmpty ? '' : ' · ${o.s('sinif')}'}', style: const TextStyle(fontWeight: FontWeight.w600))), const Icon(Icons.chevron_right)]),
                ),
            ];
          },
        );
      case 'ogretmen':
        return VeriSayfasi(
          baslik: 'Sağlık uyarıları',
          getir: () => widget.api.get('/api/saglik/liste'),
          cizim: (context, raw) {
            final liste = (raw as Map<String, dynamic>).l('ogrenciler');
            return [
              const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Öğrencilerimden alerji, kronik hastalık, ilaç ya da özel gereksinimi olanlar.')),
              if (liste.isEmpty) const BosNot('Uyarı bulunan öğrenci yok.'),
              for (final o in liste) _satir(o),
            ];
          },
        );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Sağlık kartı ve revir')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Sekmeler(secenekler: const [('liste', 'Öğrenciler'), ('revir', 'Revir kayıtları')], secili: _sekme, degisti: (x) => setState(() => _sekme = x)),
          ),
          Expanded(child: _sekme == 'liste' ? _liste() : _Revir(api: widget.api)),
        ],
      ),
    );
  }

  Widget _liste() => VeriSayfasiGovde(
    key: ValueKey('$_filtre$_aranan'),
    getir: () => widget.api.get('/api/saglik/liste?filtre=$_filtre&ara=${Uri.encodeQueryComponent(_aranan)}'),
    cizim: (context, raw) {
      final v = raw as Map<String, dynamic>;
      final t = v.m('toplam');
      final liste = v.l('ogrenciler');
      return [
        TextField(
          controller: _ara,
          textInputAction: TextInputAction.search,
          onSubmitted: (x) => setState(() => _aranan = x.trim()),
          decoration: InputDecoration(labelText: 'Öğrenci ara', suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: () => setState(() => _aranan = _ara.text.trim()))),
        ),
        const SizedBox(height: 8),
        SuzgecCipleri(
          secenekler: [('tum', 'Tümü ${t.n('ogrenci')}'), ('uyari', 'Uyarılı ${t.n('uyarili')}'), ('eksik', 'Kartsız ${t.n('kartsiz')}'), ('veli', 'Veli girdi')],
          secili: _filtre,
          degisti: (x) => setState(() => _filtre = x),
        ),
        const SizedBox(height: 8),
        if (liste.isEmpty) const BosNot('Öğrenci bulunamadı.'),
        for (final o in liste) _satir(o),
      ];
    },
  );
}

/// [VeriSayfasi]'nın Scaffold'suz hali (sekme içeriği için).
class VeriSayfasiGovde extends StatefulWidget {
  const VeriSayfasiGovde({super.key, required this.getir, required this.cizim});

  final Future<dynamic> Function() getir;
  final List<Widget> Function(BuildContext context, dynamic veri) cizim;

  @override
  State<VeriSayfasiGovde> createState() => _VeriSayfasiGovdeState();
}

class _VeriSayfasiGovdeState extends State<VeriSayfasiGovde> {
  dynamic _veri;
  String? _hata;

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
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_veri == null) {
      return _hata == null
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
          : Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_hata!), const SizedBox(height: 12), OutlinedButton(onPressed: _yukle, child: const Text('Tekrar dene'))]),
            );
    }
    return RefreshIndicator(
      onRefresh: _yukle,
      child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: widget.cizim(context, _veri)),
    );
  }
}

class _Revir extends StatelessWidget {
  const _Revir({required this.api});

  final Api api;

  @override
  Widget build(BuildContext context) => VeriSayfasiGovde(
    getir: () => api.get('/api/saglik/olaylar?gun=30'),
    cizim: (context, raw) {
      final liste = (raw as Map<String, dynamic>).l('olaylar');
      return [
        const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Son 30 günün revir kayıtları.')),
        if (liste.isEmpty) const BosNot('Kayıt yok.'),
        for (final e in liste)
          KartKutu(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SaglikKartiEkrani(api: api, ogrenciId: e.n('ogrenciId')))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${e.s('ogrenci')}${e.s('sinif').isEmpty ? '' : ' · ${e.s('sinif')}'}', style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('${e.s('tarih')} ${e.s('saat')} · ${e.s('sonucAd')}', style: TextStyle(color: context.soluk, fontSize: 13)),
                Text(e.s('sikayet')),
              ],
            ),
          ),
      ];
    },
  );
}

// ---------------- Öğrencinin sağlık kartı ----------------
class SaglikKartiEkrani extends StatefulWidget {
  const SaglikKartiEkrani({super.key, required this.api, required this.ogrenciId});

  final Api api;
  final int ogrenciId;

  @override
  State<SaglikKartiEkrani> createState() => _SaglikKartiEkraniState();
}

const _metinAlanlari = <(String, String, int)>[
  ('alerji', 'Alerji (ilaç, besin, böcek...)', 2),
  ('kronik', 'Kronik hastalık', 2),
  ('ilac', 'Sürekli kullandığı ilaç', 2),
  ('ozelGereksinim', 'Özel gereksinim', 2),
  ('diyet', 'Özel beslenme', 2),
  ('gecmis', 'Geçirdiği ameliyat / önemli hastalıklar', 3),
  ('hekim', 'Aile hekimi / doktor', 1),
  ('hastane', 'Tercih edilen hastane', 1),
  ('acilNot', 'Acil durum notu', 3),
];

class _SaglikKartiEkraniState extends State<SaglikKartiEkrani> {
  Map<String, dynamic>? _v;
  String? _hata;
  final _c = {for (final a in _metinAlanlari) a.$1: TextEditingController()};
  String _kan = '';
  bool _gozluk = false, _mesgul = false;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final v = await widget.api.get('/api/saglik/ogrenci?id=${widget.ogrenciId}') as Map<String, dynamic>;
      if (!mounted) return;
      final k = v.m('kart');
      setState(() {
        _v = v;
        _hata = null;
        _kan = k.s('kanGrubu');
        _gozluk = k['gozluk'] == true;
        for (final a in _metinAlanlari) {
          _c[a.$1]!.text = k.s(a.$1);
        }
      });
    } on ApiHata catch (e) {
      if (mounted && !e.oturumYok) setState(() => _hata = e.mesaj);
    }
  }

  void _bildir(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  Future<void> _islem(Future<dynamic> Function() is_, {String? basari, bool yenile = true}) async {
    try {
      await is_();
      if (!mounted) return;
      if (basari != null) _bildir(basari);
      if (yenile) await _yukle();
    } catch (e) {
      if (mounted) hataGoster(context, e);
    }
  }

  Future<void> _kaydet() async {
    setState(() => _mesgul = true);
    await _islem(() => widget.api.post('/api/saglik/kart', {'ogrenciId': widget.ogrenciId, 'kanGrubu': _kan, 'gozluk': _gozluk, for (final a in _metinAlanlari) a.$1: _c[a.$1]!.text}), basari: 'Sağlık kartı kaydedildi');
    if (mounted) setState(() => _mesgul = false);
  }

  Future<void> _olcumEkle() async {
    final boy = TextEditingController(), kilo = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Boy-kilo ölçümü'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: boy, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Boy (cm)')),
            const SizedBox(height: 10),
            TextField(controller: kilo, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Kilo (kg)')),
          ],
        ),
        actions: [DiyalogEylemleri(children: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Kaydet'))])],
      ),
    );
    if (ok == true) await _islem(() => widget.api.post('/api/saglik/olcum', {'ogrenciId': widget.ogrenciId, 'boy': boy.text, 'kilo': kilo.text}), basari: 'Ölçüm eklendi');
  }

  Future<void> _olayEkle() async {
    final sikayet = TextEditingController(), mudahale = TextEditingController();
    var sonuc = 'sinifa';
    var haber = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Revir kaydı'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: sikayet, maxLines: 2, decoration: const InputDecoration(labelText: 'Şikâyet')),
                const SizedBox(height: 10),
                TextField(controller: mudahale, maxLines: 2, decoration: const InputDecoration(labelText: 'Müdahale')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: sonuc,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Sonuç'),
                  items: [for (final e in _sonuclar.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                  onChanged: (x) => set(() => sonuc = x ?? sonuc),
                ),
                CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('Veli bilgilendirildi'), value: haber, onChanged: (x) => set(() => haber = x == true)),
              ],
            ),
          ),
          actions: [DiyalogEylemleri(children: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Kaydet'))])],
        ),
      ),
    );
    if (ok == true) {
      await _islem(() => widget.api.post('/api/saglik/olay', {'ogrenciId': widget.ogrenciId, 'sikayet': sikayet.text, 'mudahale': mudahale.text, 'sonuc': sonuc, 'veliHaber': haber}), basari: 'Revir kaydı eklendi');
    }
  }

  Widget _uyariGorunumu(Map<String, dynamic> k) {
    const adlar = {'alerji': 'Alerji', 'kronik': 'Kronik hastalık', 'ilac': 'İlaç', 'ozelGereksinim': 'Özel gereksinim', 'diyet': 'Özel beslenme', 'acilNot': 'Acil durum notu'};
    final dolu = [for (final e in adlar.entries) if (k.s(e.key).isNotEmpty) e];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (k.s('kanGrubu').isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('Kan grubu: ${k.s('kanGrubu')}')),
        if (dolu.isEmpty) const BosNot('Kayıtlı uyarı yok.'),
        for (final e in dolu) KartKutu(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(e.value, style: const TextStyle(fontWeight: FontWeight.w700, color: _kirmizi)), const SizedBox(height: 2), Text(k.s(e.key))])),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = _v;
    if (v == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sağlık kartı')),
        body: Center(child: _hata == null ? const CircularProgressIndicator(strokeWidth: 2.5) : Padding(padding: const EdgeInsets.all(24), child: Text(_hata!))),
      );
    }
    final og = v.m('ogrenci');
    final duzenle = v['duzenle'] == true;
    final olcumler = v.l('olcumler'), olaylar = v.l('olaylar');
    final yonetim = v['olcumDuzenle'] == true;
    final veli = v.s('gorunum') == 'veli';
    return Scaffold(
      appBar: AppBar(title: Text(og.s('ad'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Text([og.s('sinif'), og.s('okul')].where((x) => x.isNotEmpty).join(' · '), style: TextStyle(color: context.soluk)),
          if (v.s('gorunum') == 'uyari') ...[const Baslik('Sağlık uyarıları'), _uyariGorunumu(v.m('kart'))] else ...[
            const Baslik('Sağlık bilgileri'),
            if (veli) const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Bu bilgileri güncel tutarak okulun acil durumlarda doğru davranmasına yardım edersiniz.')),
            DropdownButtonFormField<String>(
              initialValue: _kanGruplari.contains(_kan) ? _kan : '',
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Kan grubu'),
              items: [const DropdownMenuItem(value: '', child: Text('Bilinmiyor')), for (final g in _kanGruplari) DropdownMenuItem(value: g, child: Text(g))],
              onChanged: duzenle ? (x) => setState(() => _kan = x ?? '') : null,
            ),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Gözlük / lens kullanıyor'), value: _gozluk, onChanged: duzenle ? (x) => setState(() => _gozluk = x) : null),
            for (final a in _metinAlanlari)
              Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: _c[a.$1], enabled: duzenle, maxLines: a.$3, decoration: InputDecoration(labelText: a.$2))),
            if (duzenle) FilledButton(onPressed: _mesgul ? null : _kaydet, child: Text(_mesgul ? 'Kaydediliyor…' : 'Kartı kaydet')),
            Row(children: [const Expanded(child: Baslik('Boy ve kilo')), if (yonetim) TextButton(onPressed: _olcumEkle, child: const Text('+ Ölçüm'))]),
            if (olcumler.isEmpty) const BosNot('Ölçüm kaydı yok.'),
            for (final o in olcumler)
              KartKutu(
                child: Row(
                  children: [
                    Expanded(child: Text('${o.s('tarih')}  ·  ${o['boy'] ?? '-'} cm  ·  ${o['kilo'] ?? '-'} kg${o['bki'] == null ? '' : '  ·  BKİ ${o['bki']}'}')),
                    if (yonetim)
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          if (await onayIste(context, 'Ölçüm silinsin mi?', evet: 'Sil')) await _islem(() => widget.api.post('/api/saglik/olcum-sil', {'id': o.n('id')}));
                        },
                      ),
                  ],
                ),
              ),
            if (v['olaylar'] != null) ...[
              Row(children: [const Expanded(child: Baslik('Revir kayıtları')), if (yonetim) TextButton(onPressed: _olayEkle, child: const Text('+ Kayıt'))]),
              if (olaylar.isEmpty) const BosNot('Revir kaydı yok.'),
              for (final e in olaylar)
                KartKutu(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${tarihYaz(tarihCoz(e.s('tarih')))} ${e.s('saat')} · ${e.s('sonucAd')}', style: TextStyle(color: context.soluk, fontSize: 13)),
                            Text(e.s('sikayet'), style: const TextStyle(fontWeight: FontWeight.w600)),
                            if (e.s('mudahale').isNotEmpty) Text(e.s('mudahale')),
                            if (e['veliHaber'] == true) Text('Veli bilgilendirildi', style: TextStyle(color: context.soluk, fontSize: 12.5)),
                          ],
                        ),
                      ),
                      if (yonetim)
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            if (await onayIste(context, 'Kayıt silinsin mi?', evet: 'Sil')) await _islem(() => widget.api.post('/api/saglik/olay-sil', {'id': e.n('id')}));
                          },
                        ),
                    ],
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

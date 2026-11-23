import 'package:flutter/material.dart';

import '../bilesenler/ortak.dart';
import '../cekirdek/api.dart';
import '../cekirdek/tema.dart';
import 'saglik.dart' show VeriSayfasiGovde;

const _turler = {'ogrenci': 'Öğrenciyle', 'veli': 'Veliyle', 'ogretmen': 'Öğretmenle', 'diger': 'Diğer'};
const _durumlar = {'taslak': 'Taslak', 'acik': 'Açık', 'kapali': 'Kapalı'};

String _gun(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Rehberlik: görüşme kayıtları, takipler, test ve anket sonuçları.
/// (Test/anket oluşturma ve düzenleme şimdilik web panelindedir.)
class RehberlikEkrani extends StatefulWidget {
  const RehberlikEkrani({super.key, required this.api});

  final Api api;

  @override
  State<RehberlikEkrani> createState() => _RehberlikEkraniState();
}

class _RehberlikEkraniState extends State<RehberlikEkrani> {
  String _sekme = 'gorusme';
  int _yenile = 0;
  final _ara = TextEditingController();
  String _aranan = '';

  Future<void> _gorusmeAc([Map<String, dynamic>? g]) async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => _GorusmeFormu(api: widget.api, duzenle: g)));
    if (ok == true && mounted) setState(() => _yenile++);
  }

  Future<void> _detay(Map<String, dynamic> g) async {
    final degisti = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (c) => _GorusmeDetay(api: widget.api, g: g),
    );
    if (degisti == true && mounted) setState(() => _yenile++);
    if (degisti == null) return;
  }

  Widget _gorusmeKarti(Map<String, dynamic> g) => KartKutu(
    onTap: () => _detay(g),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(g.s('ogrenci'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5))),
            if (g['gizli'] == true) const Icon(Icons.lock_outline, size: 16),
          ],
        ),
        Text([g.s('sinif'), g.s('tarih'), g.s('turAd')].where((x) => x.isNotEmpty).join(' · '), style: TextStyle(color: context.soluk, fontSize: 13)),
        Text(g.s('konu')),
        if (g.s('takipTarihi').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Cip(g['takipTamam'] == true ? 'Takip tamam' : 'Takip: ${g.s('takipTarihi')}')),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Rehberlik')),
    floatingActionButton: _sekme == 'gorusme' ? FloatingActionButton.extended(onPressed: () => _gorusmeAc(), icon: const Icon(Icons.add), label: const Text('Görüşme')) : null,
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Sekmeler(secenekler: const [('gorusme', 'Görüşmeler'), ('takip', 'Takipler'), ('form', 'Test / anket')], secili: _sekme, degisti: (x) => setState(() => _sekme = x)),
        ),
        Expanded(
          child: switch (_sekme) {
            'takip' => VeriSayfasiGovde(
              key: ValueKey('t$_yenile'),
              getir: () => widget.api.get('/api/rehberlik/baglam'),
              cizim: (context, raw) {
                final v = raw as Map<String, dynamic>;
                final liste = v.l('takipler');
                return [
                  Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Son 30 günde ${v.m('ozet').n('gorusme30')} görüşme · ${v.m('ozet').n('acikFormlar')} açık form.')),
                  const Baslik('Yaklaşan ve geciken takipler'),
                  if (liste.isEmpty) const BosNot('Bekleyen takip yok.'),
                  for (final g in liste) _gorusmeKarti(g),
                ];
              },
            ),
            'form' => _Formlar(key: ValueKey('f$_yenile'), api: widget.api),
            _ => VeriSayfasiGovde(
              key: ValueKey('g$_yenile$_aranan'),
              getir: () => widget.api.get('/api/rehberlik/gorusmeler?ara=${Uri.encodeQueryComponent(_aranan)}'),
              cizim: (context, raw) {
                final liste = (raw as Map<String, dynamic>).l('gorusmeler');
                return [
                  TextField(
                    controller: _ara,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (x) => setState(() => _aranan = x.trim()),
                    decoration: InputDecoration(labelText: 'Öğrenci veya konu ara', suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: () => setState(() => _aranan = _ara.text.trim()))),
                  ),
                  const SizedBox(height: 8),
                  if (liste.isEmpty) const BosNot('Görüşme kaydı yok.'),
                  for (final g in liste) _gorusmeKarti(g),
                  const SizedBox(height: 60),
                ];
              },
            ),
          },
        ),
      ],
    ),
  );
}

class _GorusmeDetay extends StatelessWidget {
  const _GorusmeDetay({required this.api, required this.g});

  final Api api;
  final Map<String, dynamic> g;

  @override
  Widget build(BuildContext context) {
    final benim = g['benim'] == true;
    Future<void> islem(Future<dynamic> Function() f) async {
      try {
        await f();
        if (context.mounted) Navigator.pop(context, true);
      } catch (e) {
        if (context.mounted) hataGoster(context, e);
      }
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(g.s('ogrenci'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text([g.s('sinif'), g.s('tarih'), g.s('saat'), g.s('turAd'), 'Yazan: ${g.s('yazan')}'].where((x) => x.isNotEmpty).join(' · '), style: TextStyle(color: context.soluk, fontSize: 13)),
            const SizedBox(height: 10),
            Text(g.s('konu'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            if (g.s('ozet').isNotEmpty) ...[const SizedBox(height: 8), const Text('Görüşme özeti', style: TextStyle(fontWeight: FontWeight.w600)), Text(g.s('ozet'))],
            if (g.s('yapilan').isNotEmpty) ...[const SizedBox(height: 8), const Text('Yapılan / yönlendirme', style: TextStyle(fontWeight: FontWeight.w600)), Text(g.s('yapilan'))],
            if (g['gizli'] == true) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Gizli görüşme: yalnızca yazan görebilir.')),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              children: [
                if (g.s('takipTarihi').isNotEmpty)
                  OutlinedButton(
                    onPressed: () => islem(() => api.post('/api/rehberlik/gorusme-takip', {'id': g.n('id'), 'tamam': g['takipTamam'] != true})),
                    child: Text(g['takipTamam'] == true ? 'Takibi aç' : 'Takip tamam (${g.s('takipTarihi')})'),
                  ),
                if (benim)
                  OutlinedButton(
                    onPressed: () async {
                      Navigator.pop(context, false);
                      final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => _GorusmeFormu(api: api, duzenle: g)));
                      if (ok == true && context.mounted) {}
                    },
                    child: const Text('Düzenle'),
                  ),
                if (benim)
                  TextButton(
                    onPressed: () async {
                      if (await onayIste(context, 'Görüşme kaydı silinsin mi?', evet: 'Sil')) await islem(() => api.post('/api/rehberlik/gorusme-sil', {'id': g.n('id')}));
                    },
                    child: const Text('Sil'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GorusmeFormu extends StatefulWidget {
  const _GorusmeFormu({required this.api, this.duzenle});

  final Api api;
  final Map<String, dynamic>? duzenle;

  @override
  State<_GorusmeFormu> createState() => _GorusmeFormuState();
}

class _GorusmeFormuState extends State<_GorusmeFormu> {
  final _konu = TextEditingController(), _ozet = TextEditingController(), _yapilan = TextEditingController(), _ara = TextEditingController();
  String _tarih = _gun(DateTime.now()), _takip = '', _tur = 'ogrenci';
  bool _gizli = false, _mesgul = false;
  int? _ogrenciId;
  String _ogrenciAd = '';
  List<Map<String, dynamic>> _sonuc = [];

  @override
  void initState() {
    super.initState();
    final g = widget.duzenle;
    if (g != null) {
      _konu.text = g.s('konu');
      _ozet.text = g.s('ozet');
      _yapilan.text = g.s('yapilan');
      _tarih = g.s('tarih');
      _takip = g.s('takipTarihi');
      _tur = g.s('tur').isEmpty ? 'ogrenci' : g.s('tur');
      _gizli = g['gizli'] == true;
      _ogrenciId = g.n('ogrenciId');
      _ogrenciAd = g.s('ogrenci');
    }
  }

  Future<void> _ogrenciBul() async {
    if (_ara.text.trim().length < 2) return;
    try {
      final v = await widget.api.get('/api/rehberlik/ogrenciler?ara=${Uri.encodeQueryComponent(_ara.text.trim())}') as Map<String, dynamic>;
      if (mounted) setState(() => _sonuc = v.l('ogrenciler'));
    } catch (e) {
      if (mounted) hataGoster(context, e);
    }
  }

  Future<void> _gunSec(String simdiki, void Function(String) sec, {bool gelecek = false}) async {
    final bugun = DateTime.now();
    final ilk = DateTime.tryParse(simdiki) ?? bugun;
    final d = await showDatePicker(context: context, initialDate: ilk, firstDate: DateTime(bugun.year - 2), lastDate: gelecek ? DateTime(bugun.year + 1, 12, 31) : bugun);
    if (d != null) setState(() => sec(_gun(d)));
  }

  Future<void> _kaydet() async {
    if (_ogrenciId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Öğrenci seçin')));
      return;
    }
    setState(() => _mesgul = true);
    try {
      await widget.api.post('/api/rehberlik/gorusme', {
        if (widget.duzenle != null) 'id': widget.duzenle!.n('id'),
        'ogrenciId': _ogrenciId,
        'tarih': _tarih,
        'tur': _tur,
        'konu': _konu.text,
        'ozet': _ozet.text,
        'yapilan': _yapilan.text,
        'takipTarihi': _takip,
        'gizli': _gizli,
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
    appBar: AppBar(title: Text(widget.duzenle == null ? 'Yeni görüşme' : 'Görüşmeyi düzenle')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        if (widget.duzenle == null) ...[
          if (_ogrenciId != null) ListTile(contentPadding: EdgeInsets.zero, title: Text(_ogrenciAd), subtitle: const Text('Seçili öğrenci'), trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _ogrenciId = null))),
          if (_ogrenciId == null) ...[
            TextField(
              controller: _ara,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _ogrenciBul(),
              decoration: InputDecoration(labelText: 'Öğrenci ara (ad)', suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _ogrenciBul)),
            ),
            for (final o in _sonuc)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(o.s('ad')),
                subtitle: Text([o.s('sinif'), o.s('okul')].where((x) => x.isNotEmpty).join(' · ')),
                onTap: () => setState(() {
                  _ogrenciId = o.n('id');
                  _ogrenciAd = o.s('ad');
                  _sonuc = [];
                }),
              ),
          ],
        ] else
          Text(_ogrenciAd, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: OutlinedButton(onPressed: () => _gunSec(_tarih, (x) => _tarih = x), child: Text('Tarih: $_tarih'))),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _turler.containsKey(_tur) ? _tur : 'ogrenci',
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Görüşülen'),
                items: [for (final e in _turler.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                onChanged: (x) => setState(() => _tur = x ?? _tur),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(controller: _konu, decoration: const InputDecoration(labelText: 'Konu')),
        const SizedBox(height: 12),
        TextField(controller: _ozet, maxLines: 4, decoration: const InputDecoration(labelText: 'Görüşme özeti')),
        const SizedBox(height: 12),
        TextField(controller: _yapilan, maxLines: 3, decoration: const InputDecoration(labelText: 'Yapılan / yönlendirme')),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: OutlinedButton(onPressed: () => _gunSec(_takip.isEmpty ? _tarih : _takip, (x) => _takip = x, gelecek: true), child: Text(_takip.isEmpty ? 'Takip tarihi ekle' : 'Takip: $_takip'))),
            if (_takip.isNotEmpty) IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _takip = '')),
          ],
        ),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Gizli görüşme (yalnızca ben görürüm)'), value: _gizli, onChanged: (x) => setState(() => _gizli = x)),
        const SizedBox(height: 8),
        FilledButton(onPressed: _mesgul ? null : _kaydet, child: Text(_mesgul ? 'Kaydediliyor…' : 'Kaydet')),
      ],
    ),
  );
}

// ---------------- Test / anket ----------------
class _Formlar extends StatefulWidget {
  const _Formlar({super.key, required this.api});

  final Api api;

  @override
  State<_Formlar> createState() => _FormlarState();
}

class _FormlarState extends State<_Formlar> {
  int _yenile = 0;

  @override
  Widget build(BuildContext context) => VeriSayfasiGovde(
    key: ValueKey(_yenile),
    getir: () => widget.api.get('/api/rehberlik/formlar'),
    cizim: (context, raw) {
      final liste = (raw as Map<String, dynamic>).l('formlar');
      return [
        const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Test ve anketleri web panelinden oluşturabilirsiniz; burada durumunu ve sonuçlarını izlersiniz.')),
        if (liste.isEmpty) const BosNot('Henüz test ya da anket yok.'),
        for (final f in liste)
          KartKutu(
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => _FormSonuc(api: widget.api, form: f)));
              if (mounted) setState(() => _yenile++);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [Expanded(child: Text(f.s('ad'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5))), Cip(_durumlar[f.s('durum')] ?? f.s('durum'))]),
                Text('${f.s('tur') == 'test' ? 'Test' : 'Anket'} · ${f.s('okul')} · ${f.n('soruSayisi')} soru · ${f.n('cevapSayisi')} cevap${f['anonim'] == true ? ' · anonim' : ''}', style: TextStyle(color: context.soluk, fontSize: 13)),
              ],
            ),
          ),
      ];
    },
  );
}

class _FormSonuc extends StatefulWidget {
  const _FormSonuc({required this.api, required this.form});

  final Api api;
  final Map<String, dynamic> form;

  @override
  State<_FormSonuc> createState() => _FormSonucState();
}

class _FormSonucState extends State<_FormSonuc> {
  int _yenile = 0;
  String _durum = '';

  Future<void> _durumDegistir(String d) async {
    try {
      await widget.api.post('/api/rehberlik/form-durum', {'id': widget.form.n('id'), 'durum': d});
      if (mounted) {
        setState(() {
          _durum = d;
          _yenile++;
        });
      }
    } catch (e) {
      if (mounted) hataGoster(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final aktif = _durum.isEmpty ? widget.form.s('durum') : _durum;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.form.s('ad')),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Durum',
            onSelected: _durumDegistir,
            itemBuilder: (_) => [for (final e in _durumlar.entries) if (e.key != aktif) PopupMenuItem(value: e.key, child: Text('${e.value} yap'))],
          ),
        ],
      ),
      body: VeriSayfasiGovde(
        key: ValueKey(_yenile),
        getir: () => widget.api.get('/api/rehberlik/form-sonuc?id=${widget.form.n('id')}'),
        cizim: (context, raw) {
          final v = raw as Map<String, dynamic>;
          final kisiler = v['kisiler'] as List?;
          final yd = v.l('yorumDagilimi');
          return [
            Text('Durum: ${_durumlar[aktif] ?? aktif}'),
            Text('Katılım: ${v.n('katilanOgrenci')} / ${v.n('beklenen')} · Cevap sayısı: ${v.n('cevapSayisi')}'),
            if (v['ortalamaPuan'] != null) Text('Ortalama puan: ${v['ortalamaPuan']}${v['enYuksek'] == null ? '' : ' / ${v['enYuksek']}'}'),
            if (yd.isNotEmpty) ...[const Baslik('Sonuç dağılımı'), for (final y in yd) Text('${y.s('baslik')}: ${y.n('sayi')} kişi')],
            const Baslik('Sorular'),
            for (final (i, q) in v.l('sorularSonuc').indexed)
              KartKutu(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${i + 1}. ${q.s('metin')}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (q['ortalama'] != null) Text('Ortalama: ${q['ortalama']}', style: TextStyle(color: context.soluk)),
                    if (q.s('tip') == 'metin') ...[for (final y in (q['yanitlar'] as List? ?? const [])) Padding(padding: const EdgeInsets.only(top: 4), child: Text('• $y'))] else for (final d in q.l('dagilim')) Text('${d.s('etiket')}: ${d.n('sayi')}'),
                  ],
                ),
              ),
            if (kisiler != null) ...[
              const Baslik('Cevaplayanlar'),
              if (kisiler.isEmpty) const BosNot('Henüz cevap yok.'),
              for (final k in kisiler.cast<Map<String, dynamic>>()) Text('${k.s('ad')}${k.s('sinif').isEmpty ? '' : ' (${k.s('sinif')})'}${k['puan'] == null ? '' : ' · ${k['puan']} puan'}${k.s('yorum').isEmpty ? '' : ' · ${k.s('yorum')}'}'),
            ] else
              const Padding(padding: EdgeInsets.only(top: 12), child: Text('Bu anket anonimdir; kişi adı gösterilmez.')),
          ];
        },
      ),
    );
  }
}

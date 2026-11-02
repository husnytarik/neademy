import 'package:flutter/material.dart';

import '../bilesenler/ortak.dart';
import '../cekirdek/api.dart';
import '../cekirdek/takvim_model.dart';
import '../cekirdek/tema.dart';

const _turler = <String, String>{
  'diger': 'Genel',
  'deney': 'Deney',
  'proje': 'Proje',
  'sunum': 'Sunum',
  'gezi': 'Gezi',
  'calisma': 'Çalışma',
  'prova': 'Prova',
  'konser': 'Konser',
  'gosteri': 'Gösteri',
  'turnuva': 'Turnuva',
};

/// Kulübün temasına göre sunulan çalışma türleri ve örnek konu (web: kulupTurleri).
(List<String>, String) _turSecenekleri(Map<String, dynamic> kulup, String? mevcut) {
  final metin = '${kulup.s('tema')} ${kulup.s('ad')}'.toLowerCase();
  List<String> kodlar = ['calisma', 'proje', 'sunum', 'gezi'];
  var ornek = 'Örn. Bu haftaki çalışma';
  if (RegExp('sanat|müzik|koro|enstrüman|resim').hasMatch(metin)) {
    kodlar = ['calisma', 'prova', 'konser', 'gezi'];
    ornek = 'Örn. Yıl sonu konseri repertuvarı';
  } else if (RegExp('sahne|drama|tiyatro|dil').hasMatch(metin)) {
    kodlar = ['calisma', 'prova', 'gosteri', 'gezi'];
    ornek = 'Örn. İkinci perde provası';
  } else if (RegExp('strateji|satranç|zeka|spor|futbol|basketbol|voleybol').hasMatch(metin)) {
    kodlar = ['calisma', 'turnuva', 'gezi'];
    ornek = 'Örn. Açılış stratejileri';
  } else if (RegExp('bilim|teknoloji|fen|robot|kodlama|deney').hasMatch(metin)) {
    kodlar = ['deney', 'proje', 'sunum', 'gezi'];
    ornek = 'Örn. Basit elektrik devresi';
  }
  final liste = ['diger', ...kodlar];
  if (mevcut != null && mevcut.isNotEmpty && !liste.contains(mevcut)) liste.add(mevcut);
  return (liste, ornek);
}

String _turAd(String kod) => _turler[kod] ?? 'Genel';

/// Öğretmen: danışmanı olduğu kulüpler; üyeler, sonraki haftaların planı ve işlenen dersler.
class KulupOgretmenEkrani extends StatefulWidget {
  const KulupOgretmenEkrani({super.key, required this.api});

  final Api api;

  @override
  State<KulupOgretmenEkrani> createState() => _KulupOgretmenEkraniState();
}

class _KulupOgretmenEkraniState extends State<KulupOgretmenEkrani> {
  int _yenile = 0;

  Future<void> _ac(int kulupId, String tarih) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KulupOturumEkrani(api: widget.api, kulupId: kulupId, tarih: tarih),
      ),
    );
    if (mounted) setState(() => _yenile++);
  }

  @override
  Widget build(BuildContext context) => VeriSayfasi(
    key: ValueKey(_yenile),
    baslik: 'Kulüplerim',
    getir: () => widget.api.get('/api/kulup/kuluplerim'),
    cizim: (context, veri) {
      final v = veri as Map<String, dynamic>;
      final kulupler = v.l('kulupler');
      final bugun = v.s('bugun');
      if (kulupler.isEmpty) return [const BosNot('Danışmanı olduğunuz bir kulüp yok.')];
      return [
        for (final k in kulupler)
          KartKutu(
            alt: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(k.s('ad'), style: serif.copyWith(fontSize: 19, fontWeight: FontWeight.w600)),
                if (k.s('tema').isNotEmpty) Text(k.s('tema'), style: TextStyle(color: context.soluk, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  '${k.s('gunAd')} · ${k.n('dersSaati')}. ders ${k.s('aralik')}',
                  style: TextStyle(color: context.ana, fontWeight: FontWeight.w600, fontSize: 13),
                ),
                if (k.l('ogretmenler').where((o) => o.s('ad').isNotEmpty).length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('Danışmanlar: ${k.l('ogretmenler').map((o) => o.s('ad')).join(', ')}', style: TextStyle(color: context.soluk, fontSize: 12.5)),
                  ),
                const Baslik('Sonraki haftalar', ust: 14),
                Text(
                  'Her haftanın etkinliğini önceden yazın; öğrenciler kulüp sayfasında görür. Yoklama ders saatinde alınır.',
                  style: TextStyle(color: context.soluk, fontSize: 12.5),
                ),
                const SizedBox(height: 8),
                for (final p in k.l('planlar'))
                  InkWell(
                    onTap: () => _ac(k.n('id'), p.s('tarih')),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: context.ince)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${uzunTarih(p.s('tarih'))}${p.s('tarih') == bugun ? ' · bugün' : ''}',
                                  style: TextStyle(color: context.soluk, fontSize: 12),
                                ),
                                Text(
                                  p['iptal'] == true ? 'Ders iptal edildi' : (p.s('baslik').isEmpty ? 'Etkinlik yazılmadı' : p.s('baslik')),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: p.s('baslik').isEmpty && p['iptal'] != true ? context.soluk : context.yazi,
                                  ),
                                ),
                                if (p.s('aciklama').isNotEmpty && p['iptal'] != true)
                                  Text(p.s('aciklama'), style: TextStyle(color: context.soluk, fontSize: 12.5)),
                              ],
                            ),
                          ),
                          Cip(
                            p['iptal'] == true ? 'İptal' : (p.s('baslik').isEmpty ? 'Yaz' : _turAd(p.s('tur'))),
                            renk: p['iptal'] == true ? Colors.red.shade600 : (p.s('baslik').isEmpty ? context.ana : Colors.green.shade700),
                          ),
                          Icon(Icons.chevron_right, color: context.soluk),
                        ],
                      ),
                    ),
                  ),
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(bottom: 6),
                    title: Text('Üyeler (${k.l('uyeler').length})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                    children: [
                      if (k.l('uyeler').isEmpty)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Henüz kulübe yerleştirilen öğrenci yok.', style: TextStyle(color: context.soluk)),
                        ),
                      for (final u in k.l('uyeler'))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(child: Text(u.s('ad'))),
                              Text(u.s('sinif'), style: TextStyle(color: context.soluk, fontSize: 12.5)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const Baslik('İşlenen dersler', ust: 6),
                if (k.l('calismalar').isEmpty) Text('Henüz işlenmiş ders yok.', style: TextStyle(color: context.soluk)),
                for (final w in k.l('calismalar'))
                  InkWell(
                    onTap: () => _ac(k.n('id'), w.s('tarih')),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: context.ince)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(w.s('baslik'), style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text('${kisaTarih(w.s('tarih'))} · ${_turAd(w.s('tur'))}', style: TextStyle(color: context.soluk, fontSize: 12.5)),
                              ],
                            ),
                          ),
                          Text(
                            '${w.n('geldi')}/${w.n('geldi') + w.n('gelmedi') + w.n('izinli')}',
                            style: TextStyle(color: context.soluk, fontWeight: FontWeight.w700),
                          ),
                          Icon(Icons.chevron_right, color: context.soluk),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ];
    },
  );
}

/// Bir kulüp dersi: konu (önceden yazılabilir), ders saati gelince yoklama; dersi bitirme ve iptal.
class KulupOturumEkrani extends StatefulWidget {
  const KulupOturumEkrani({super.key, required this.api, required this.kulupId, required this.tarih});

  final Api api;
  final int kulupId;
  final String tarih;

  @override
  State<KulupOturumEkrani> createState() => _KulupOturumEkraniState();
}

class _KulupOturumEkraniState extends State<KulupOturumEkrani> {
  Map<String, dynamic>? _veri;
  String? _hata;
  final _konu = TextEditingController();
  final _aciklama = TextEditingController();
  String _tur = 'diger';
  final _durum = <int, String>{};
  bool _gonderiliyor = false;
  String? _konuHata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    _konu.dispose();
    _aciklama.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    try {
      final j = await widget.api.get('/api/kulup/oturum?kulupId=${widget.kulupId}&tarih=${widget.tarih}') as Map<String, dynamic>;
      if (!mounted) return;
      final c = j['calisma'] as Map<String, dynamic>?;
      final katilim = (j['katilim'] as Map?)?.cast<String, dynamic>() ?? const {};
      setState(() {
        _veri = j;
        _tur = c?.s('tur').isNotEmpty == true ? c!.s('tur') : 'diger';
        _konu.text = c?.s('baslik') ?? '';
        _aciklama.text = c?.s('aciklama') ?? '';
        _durum
          ..clear()
          ..addEntries([for (final u in j.l('uyeler')) MapEntry(u.n('uyelikId'), '${katilim['${u.n('uyelikId')}'] ?? 'geldi'}')]);
      });
    } on ApiHata catch (e) {
      if (mounted && !e.oturumYok) setState(() => _hata = e.mesaj);
    }
  }

  Future<void> _kaydet(bool basladi) async {
    setState(() {
      _gonderiliyor = true;
      _konuHata = null;
    });
    try {
      final r =
          await widget.api.post('/api/kulup/oturum-kaydet', {
                'kulupId': widget.kulupId,
                'tarih': widget.tarih,
                'tur': _tur,
                'baslik': _konu.text,
                'aciklama': _aciklama.text,
                'bitir': basladi,
                'katilim': {for (final e in _durum.entries) '${e.key}': e.value},
              })
              as Map<String, dynamic>?;
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(basladi ? 'Ders tamamlandı: ${r?['gelmedi'] ?? 0} gelmedi, ${r?['izinli'] ?? 0} izinli.' : 'Plan kaydedildi.')));
      Navigator.pop(context, true);
    } on ApiHata catch (e) {
      if (!mounted) return;
      setState(() {
        _gonderiliyor = false;
        _konuHata = e.mesaj;
      });
    }
  }

  Future<void> _iptal(bool geriAl) async {
    if (!geriAl && !await onayIste(context, 'Bu ders iptal edilsin mi? Girilen yoklama silinir.', evet: 'İptal et')) return;
    try {
      await widget.api.post('/api/kulup/oturum-iptal', {'kulupId': widget.kulupId, 'tarih': widget.tarih, 'geriAl': geriAl});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(geriAl ? 'İptal kaldırıldı.' : 'Ders iptal edildi.')));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) hataGoster(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = _veri;
    if (v == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kulüp dersi')),
        body: Center(
          child: _hata == null ? const CircularProgressIndicator(strokeWidth: 2.5) : Text(_hata!, style: TextStyle(color: context.soluk)),
        ),
      );
    }
    final kulup = v['kulup'] as Map<String, dynamic>;
    final c = v['calisma'] as Map<String, dynamic>?;
    final basladi = v['basladi'] == true;
    final uyeler = v.l('uyeler');
    final iptal = c?['iptal'] == true;
    final tamam = c?['tamam'] == true;
    final (turler, ornek) = _turSecenekleri(kulup, c?.s('tur'));
    final say = {'geldi': 0, 'gelmedi': 0, 'izinli': 0};
    for (final u in uyeler) {
      say[_durum[u.n('uyelikId')] ?? 'geldi'] = (say[_durum[u.n('uyelikId')] ?? 'geldi'] ?? 0) + 1;
    }
    return Scaffold(
      appBar: AppBar(title: Text(kulup.s('ad'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text('${uzunTarih(widget.tarih)} · ${kulup.n('dersSaati')}. ders ${kulup.s('aralik')}', style: TextStyle(color: context.soluk)),
          const SizedBox(height: 12),
          KartKutu(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Yoklama', style: serif.copyWith(fontSize: 18, fontWeight: FontWeight.w600)),
                    ),
                    Cip(
                      iptal ? 'İptal edilmiş' : (tamam ? 'Tamamlandı' : (basladi ? 'Yeni kayıt' : 'Planlanıyor')),
                      renk: iptal ? Colors.red.shade600 : (tamam ? Colors.green.shade700 : null),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (!basladi)
                  Text(
                    'Yoklama ders saati başladıktan sonra alınır (${kulup.s('aralik').split('–').first}). Şimdilik konuyu önceden yazabilirsiniz.',
                    style: TextStyle(color: context.soluk),
                  )
                else if (uyeler.isEmpty)
                  Text('Kulüpte öğrenci yok.', style: TextStyle(color: context.soluk))
                else ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Cip('${say['geldi']} geldi', renk: Colors.green.shade700),
                      Cip('${say['gelmedi']} gelmedi', renk: Colors.red.shade600),
                      Cip('${say['izinli']} izinli'),
                      TextButton(onPressed: () => setState(() => _durum.updateAll((_, _) => 'geldi')), child: const Text('Hepsi geldi')),
                    ],
                  ),
                  for (final u in uyeler)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(u.s('ad'), style: const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                          for (final (kod, ad, renk) in [
                            ('geldi', 'Geldi', Colors.green.shade700),
                            ('gelmedi', 'Gelmedi', Colors.red.shade600),
                            ('izinli', 'İzinli', Colors.blueGrey),
                          ])
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: ChoiceChip(
                                label: Text(ad, style: TextStyle(fontSize: 12.5, color: _durum[u.n('uyelikId')] == kod ? Colors.white : context.yazi)),
                                selected: _durum[u.n('uyelikId')] == kod,
                                selectedColor: renk,
                                showCheckmark: false,
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                onSelected: (_) => setState(() => _durum[u.n('uyelikId')] = kod),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
          KartKutu(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('İşlenen konu', style: serif.copyWith(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: turler.contains(_tur) ? _tur : 'diger',
                  decoration: const InputDecoration(labelText: 'Tür'),
                  items: [for (final t in turler) DropdownMenuItem(value: t, child: Text(_turAd(t)))],
                  onChanged: (s) => setState(() => _tur = s ?? 'diger'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _konu,
                  maxLength: 100,
                  decoration: InputDecoration(labelText: 'Konu', hintText: ornek, errorText: _konuHata),
                  onChanged: (_) => _konuHata == null ? null : setState(() => _konuHata = null),
                ),
                TextField(
                  controller: _aciklama,
                  maxLength: 1000,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Açıklama (isteğe bağlı)', alignLabelWithHint: true),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          FilledButton(
            onPressed: _gonderiliyor ? null : () => _kaydet(basladi),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: Text(basladi ? (tamam ? 'Değişiklikleri kaydet' : 'Dersi bitir') : 'Planı kaydet'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => _iptal(iptal),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46), foregroundColor: iptal ? null : Colors.red.shade600),
            child: Text(iptal ? 'İptali kaldır' : 'Dersi iptal et'),
          ),
        ],
      ),
    );
  }
}

/// Öğrenci / veli: yerleştirildiği kulüp ya da kulüp tercihleri (en çok 3, sıra = tercih sırası).
class KulupOgrenciEkrani extends StatefulWidget {
  const KulupOgrenciEkrani({super.key, required this.api});

  final Api api;

  @override
  State<KulupOgrenciEkrani> createState() => _KulupOgrenciEkraniState();
}

class _KulupOgrenciEkraniState extends State<KulupOgrenciEkrani> {
  int? _cocuk;
  int _yenile = 0;

  @override
  Widget build(BuildContext context) => VeriSayfasi(
    key: ValueKey('$_yenile-$_cocuk'),
    baslik: 'Kulüp',
    getir: () => widget.api.get('/api/kulup/benim${_cocuk == null ? '' : '?cocuk=$_cocuk'}'),
    cizim: (context, veri) {
      final v = veri as Map<String, dynamic>;
      final cocuklar = v.l('cocuklar');
      return [
        if (cocuklar.length > 1) ...[
          const SizedBox(height: 4),
          SuzgecCipleri(
            secenekler: [for (final c in cocuklar) ('${c.n('id')}', c.s('ad'))],
            secili: '${v['cocuk']}',
            degisti: (s) => setState(() => _cocuk = int.parse(s)),
          ),
          const SizedBox(height: 10),
        ],
        if (v['cocuk'] == null)
          const BosNot('Bağlı öğrenci bulunamadı.')
        else if (v.s('sinif').isEmpty)
          const BosNot('Öğrenci bir sınıfa kayıtlı değil.')
        else if (v['uye'] != null)
          ..._kulubum(context, v['uye'] as Map<String, dynamic>)
        else
          _Tercihler(key: ValueKey('${v['cocuk']}-$_yenile'), api: widget.api, veri: v, kaydedildi: () => setState(() => _yenile++)),
      ];
    },
  );

  List<Widget> _kulubum(BuildContext context, Map<String, dynamic> k) => [
    KartKutu(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(k.s('ad'), style: serif.copyWith(fontSize: 20, fontWeight: FontWeight.w600)),
              ),
              Cip('Kulübüm', renk: Colors.green.shade700),
            ],
          ),
          if (k.s('tema').isNotEmpty) Text(k.s('tema'), style: TextStyle(color: context.soluk, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            '${k.s('gunAd')} · ${k.n('dersSaati')}. ders ${k.s('aralik')}',
            style: TextStyle(color: context.ana, fontWeight: FontWeight.w600, fontSize: 13),
          ),
          Text('Danışman: ${k.l('ogretmenler').map((o) => o.s('ad')).join(', ')}', style: TextStyle(color: context.soluk, fontSize: 12.5)),
          if (k.s('aciklama').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(k.s('aciklama'), style: const TextStyle(height: 1.35)),
            ),
        ],
      ),
    ),
    const Baslik('Sonraki etkinlikler'),
    if (k.l('planlar').isEmpty) const BosNot('Yaklaşan ders günü yok.'),
    for (final p in k.l('planlar'))
      KartKutu(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              p.s('baslik').isEmpty ? 'Henüz belirlenmedi' : p.s('baslik'),
              style: TextStyle(fontWeight: FontWeight.w600, color: p.s('baslik').isEmpty ? context.soluk : context.yazi),
            ),
            Text(
              p.s('baslik').isEmpty ? uzunTarih(p.s('tarih')) : '${uzunTarih(p.s('tarih'))} · ${_turAd(p.s('tur'))}',
              style: TextStyle(color: context.soluk, fontSize: 12.5),
            ),
            if (p.s('aciklama').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(p.s('aciklama'), style: const TextStyle(height: 1.3)),
              ),
          ],
        ),
      ),
    const Baslik('Geçmiş çalışmalar'),
    if (k.l('calismalar').isEmpty) const BosNot('Henüz çalışma girilmedi.'),
    for (final w in k.l('calismalar'))
      KartKutu(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(w.s('baslik'), style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('${kisaTarih(w.s('tarih'))} · ${_turAd(w.s('tur'))}', style: TextStyle(color: context.soluk, fontSize: 12.5)),
                  if (w.s('aciklama').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(w.s('aciklama'), style: const TextStyle(height: 1.3)),
                    ),
                ],
              ),
            ),
            if (w.s('devam').isNotEmpty)
              Cip(
                const {'geldi': 'Geldi', 'gelmedi': 'Gelmedi', 'izinli': 'İzinli'}[w.s('devam')] ?? '',
                renk: w.s('devam') == 'gelmedi' ? Colors.red.shade600 : null,
              ),
          ],
        ),
      ),
  ];
}

class _Tercihler extends StatefulWidget {
  const _Tercihler({super.key, required this.api, required this.veri, required this.kaydedildi});

  final Api api;
  final Map<String, dynamic> veri;
  final VoidCallback kaydedildi;

  @override
  State<_Tercihler> createState() => _TercihlerState();
}

class _TercihlerState extends State<_Tercihler> {
  late final List<int> _secili = [for (final t in widget.veri.l('talepler')) t.n('kulupId')];
  late final String _ilk = _secili.join(',');
  bool _gonderiliyor = false;

  Future<void> _gonder() async {
    setState(() => _gonderiliyor = true);
    try {
      await widget.api.post('/api/kulup/talep', {'cocuk': widget.veri['cocuk'], 'kulupler': _secili});
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_secili.isEmpty ? 'Talepleriniz kaldırıldı' : 'Talebiniz alındı; okul yerleştirdiğinde bu sayfada görünür')));
      widget.kaydedildi();
    } catch (e) {
      if (mounted) {
        setState(() => _gonderiliyor = false);
        hataGoster(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.veri;
    final talepler = v.l('talepler');
    final kulupler = v.l('kulupler');
    final sinir = v.n('talepSiniri') == 0 ? 3 : v.n('talepSiniri');
    final durumAd = const {'bekliyor': 'Değerlendiriliyor', 'kabul': 'Yerleştirildi', 'red': 'Yerleşilemedi'};
    final degisti = _secili.join(',') != _ilk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KartKutu(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Cip(talepler.isEmpty ? 'Tercih yapılmadı' : 'Tercih gönderildi', renk: talepler.isEmpty ? context.ana : Colors.green.shade700),
              const SizedBox(height: 8),
              Text(
                talepler.isEmpty ? 'Henüz kulüp tercihi yapılmadı' : 'Tercihleriniz okula iletildi',
                style: serif.copyWith(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                talepler.isEmpty
                    ? 'Aşağıdan en çok $sinir kulüp seçin. Seçme sırası tercih sırasıdır: önce seçtiğiniz kulüp 1. tercihtir.'
                    : 'Okul yerleştirmeyi yaptığında kulübünüz bu sayfada görünür. O zamana kadar tercihlerinizi değiştirebilirsiniz.',
                style: TextStyle(color: context.soluk, fontSize: 13),
              ),
              for (final t in talepler)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Text(
                        '${t.n('sira')}',
                        style: TextStyle(color: context.ana, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(t.s('kulup'), style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      Cip(
                        durumAd[t.s('durum')] ?? '',
                        renk: t.s('durum') == 'kabul' ? Colors.green.shade700 : (t.s('durum') == 'red' ? Colors.red.shade600 : null),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (kulupler.isEmpty)
          BosNot('${v.s('sinif')} sınıfı için açık kulüp yok.')
        else ...[
          const Baslik('Kulüpler'),
          Text(
            'Bir kulübe dokunarak seçin, tekrar dokunarak seçimi kaldırın. Dolu görünen kulüpler de seçilebilir.',
            style: TextStyle(color: context.soluk, fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          for (final k in kulupler)
            Builder(
              builder: (context) {
                final sira = _secili.indexOf(k.n('id')) + 1;
                final dolu = k.n('uyeSayisi') >= k.n('kontenjan');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: sira > 0 ? context.ana.withValues(alpha: .08) : context.kart,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: sira > 0 ? context.ana : context.ince, width: sira > 0 ? 1.5 : 1),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => setState(() {
                        if (sira > 0) {
                          _secili.remove(k.n('id'));
                        } else if (_secili.length >= sinir) {
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(SnackBar(content: Text('En fazla $sinir kulüp seçebilirsiniz')));
                        } else {
                          _secili.add(k.n('id'));
                        }
                      }),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(k.s('ad'), style: serif.copyWith(fontSize: 17, fontWeight: FontWeight.w600)),
                                ),
                                sira > 0
                                    ? Cip('$sira. tercih', renk: Colors.green.shade700)
                                    : Cip(dolu ? 'Dolu' : 'Seç', renk: dolu ? Colors.red.shade600 : null),
                              ],
                            ),
                            if (k.s('tema').isNotEmpty) Text(k.s('tema'), style: TextStyle(color: context.soluk, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text(
                              '${k.s('gunAd')} · ${k.n('dersSaati')}. ders ${k.s('aralik')}',
                              style: TextStyle(color: context.ana, fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            if (k.s('aciklama').isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(k.s('aciklama'), style: const TextStyle(height: 1.3)),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Danışman: ${k.l('ogretmenler').map((o) => o.s('ad')).join(', ')} · ${k.n('uyeSayisi')}/${k.n('kontenjan')} kişi',
                                style: TextStyle(color: context.soluk, fontSize: 12.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 6),
          FilledButton(
            onPressed: degisti && !_gonderiliyor ? _gonder : null,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: Text(
              degisti
                  ? (_secili.isEmpty ? 'Tercihleri kaldır' : 'Tercihleri gönder (${_secili.length})')
                  : (talepler.isEmpty ? 'Kulüp seçin' : 'Tercihler gönderildi'),
            ),
          ),
        ],
      ],
    );
  }
}

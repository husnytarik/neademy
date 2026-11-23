import 'package:flutter/material.dart';

import '../bilesenler/ortak.dart';
import '../cekirdek/api.dart';
import '../cekirdek/tema.dart';

const _likert = ['Hiç katılmıyorum', 'Katılmıyorum', 'Kararsızım', 'Katılıyorum', 'Tamamen katılıyorum'];

/// Öğrenci ve veli: kendisine açılan test/anketler, cevaplama ve test sonucu.
class AnketlerEkrani extends StatefulWidget {
  const AnketlerEkrani({super.key, required this.api});

  final Api api;

  @override
  State<AnketlerEkrani> createState() => _AnketlerEkraniState();
}

class _AnketlerEkraniState extends State<AnketlerEkrani> {
  int _yenile = 0;

  Future<void> _ac(Map<String, dynamic> f) async {
    final degisti = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => _FormCevapla(api: widget.api, form: f)));
    if (degisti == true && mounted) setState(() => _yenile++);
  }

  @override
  Widget build(BuildContext context) => VeriSayfasi(
    key: ValueKey(_yenile),
    baslik: 'Test ve anketler',
    getir: () => widget.api.get('/api/rehberlik/benim'),
    cizim: (context, raw) {
      final liste = (raw as Map<String, dynamic>).l('formlar');
      if (liste.isEmpty) return const [BosNot('Size açılmış test ya da anket yok.')];
      return [
        for (final f in liste)
          KartKutu(
            onTap: f['cevaplandi'] == true && f['sonuc'] == null ? null : () => _ac(f),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(f.s('ad'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5))),
                    Cip(f['cevaplandi'] == true ? 'Cevaplandı' : 'Bekliyor'),
                  ],
                ),
                Text([if (f.s('tur') == 'test') 'Test' else 'Anket', if (f.s('ogrenciAd').isNotEmpty) f.s('ogrenciAd'), if (f.s('sonTarih').isNotEmpty) 'Son: ${f.s('sonTarih')}'].join(' · '), style: TextStyle(color: context.soluk, fontSize: 13)),
                if (f.s('aciklama').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(f.s('aciklama'))),
                if (f['sonuc'] is Map) _Sonuc(f.m('sonuc')),
              ],
            ),
          ),
      ];
    },
  );
}

class _Sonuc extends StatelessWidget {
  const _Sonuc(this.s);

  final Map<String, dynamic> s;

  @override
  Widget build(BuildContext context) {
    final yorum = s.m('yorum');
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Puan: ${s['puan']}${s['enYuksek'] == null ? '' : ' / ${s['enYuksek']}'}', style: const TextStyle(fontWeight: FontWeight.w700)),
          if (yorum.s('baslik').isNotEmpty) Text(yorum.s('baslik'), style: const TextStyle(fontWeight: FontWeight.w600)),
          if (yorum.s('aciklama').isNotEmpty) Text(yorum.s('aciklama')),
        ],
      ),
    );
  }
}

class _FormCevapla extends StatefulWidget {
  const _FormCevapla({required this.api, required this.form});

  final Api api;
  final Map<String, dynamic> form;

  @override
  State<_FormCevapla> createState() => _FormCevaplaState();
}

class _FormCevaplaState extends State<_FormCevapla> {
  Map<String, dynamic>? _v;
  String? _hata;
  List<Object?> _cevap = [];
  final _metinler = <int, TextEditingController>{};
  Map<String, dynamic>? _sonuc;
  bool _mesgul = false, _degisti = false;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final v = await widget.api.get('/api/rehberlik/form-cevap?id=${widget.form.n('formId')}&ogrenci=${widget.form.n('ogrenciId')}') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _v = v;
        _cevap = List<Object?>.filled(v.l('sorular').length, null);
      });
    } on ApiHata catch (e) {
      if (mounted && !e.oturumYok) setState(() => _hata = e.mesaj);
    }
  }

  List<String> _secenekler(Map<String, dynamic> q) {
    switch (q.s('tip')) {
      case 'likert':
        return _likert;
      case 'evet-hayir' || 'evethayir':
        return const ['Evet', 'Hayır'];
    }
    return [for (final x in (q['secenekler'] as List? ?? const [])) x is Map ? '${x['metin']}' : '$x'];
  }

  Future<void> _gonder() async {
    final sorular = _v!.l('sorular');
    final cevaplar = <Object?>[];
    for (var i = 0; i < sorular.length; i++) {
      final tip = sorular[i].s('tip');
      if (tip == 'metin') {
        final t = _metinler[i]?.text.trim() ?? '';
        cevaplar.add(t.isEmpty ? null : t);
      } else {
        final x = _cevap[i];
        if (x == null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${i + 1}. soruyu cevaplayın')));
          return;
        }
        cevaplar.add(tip == 'likert' ? (x as int) + 1 : x);
      }
    }
    setState(() => _mesgul = true);
    try {
      final r = await widget.api.post('/api/rehberlik/cevap', {'formId': widget.form.n('formId'), 'ogrenciId': widget.form.n('ogrenciId'), 'cevaplar': cevaplar}) as Map<String, dynamic>;
      if (!mounted) return;
      _degisti = true;
      if (r['sonuc'] is Map) {
        setState(() {
          _sonuc = r.m('sonuc');
          _mesgul = false;
        });
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _mesgul = false);
        hataGoster(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = _v;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (geri, _) {
        if (!geri) Navigator.pop(context, _degisti);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(widget.form.s('ad'))),
        body: v == null
            ? Center(child: _hata == null ? const CircularProgressIndicator(strokeWidth: 2.5) : Padding(padding: const EdgeInsets.all(24), child: Text(_hata!)))
            : _sonuc != null
            ? ListView(padding: const EdgeInsets.all(16), children: [const Baslik('Teşekkürler, cevaplarınız alındı'), KartKutu(child: _Sonuc(_sonuc!))])
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  if (v.m('form').s('aciklama').isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(v.m('form').s('aciklama'))),
                  if (v.m('form')['anonim'] == true) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Bu anket anonimdir; adınız görünmez.', style: TextStyle(color: context.soluk))),
                  for (var i = 0; i < v.l('sorular').length; i++) _soru(i, v.l('sorular')[i]),
                  const SizedBox(height: 8),
                  FilledButton(onPressed: _mesgul ? null : _gonder, child: Text(_mesgul ? 'Gönderiliyor…' : 'Gönder')),
                ],
              ),
      ),
    );
  }

  Widget _soru(int i, Map<String, dynamic> q) {
    final tip = q.s('tip');
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: KartKutu(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${i + 1}. ${q.s('metin')}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            if (tip == 'metin')
              TextField(controller: _metinler.putIfAbsent(i, TextEditingController.new), maxLines: 3, decoration: const InputDecoration(hintText: 'Yanıtınız (isteğe bağlı)'))
            else
              RadioGroup<int>(
                groupValue: _cevap[i] as int?,
                onChanged: (x) => setState(() => _cevap[i] = x),
                child: Column(children: [for (final (j, s) in _secenekler(q).indexed) RadioListTile<int>(dense: true, contentPadding: EdgeInsets.zero, title: Text(s), value: j)]),
              ),
          ],
        ),
      ),
    );
  }
}

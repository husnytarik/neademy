import 'package:flutter/material.dart';

import '../bilesenler/ortak.dart';
import '../cekirdek/api.dart';
import '../cekirdek/takvim_model.dart';
import '../cekirdek/tema.dart';

/// Okuldan gelen duyurular; öğrenci ve velide öğretmen mesajları ayrı sekmede.
class DuyurularEkrani extends StatefulWidget {
  const DuyurularEkrani({super.key, required this.api});

  final Api api;

  @override
  State<DuyurularEkrani> createState() => _DuyurularEkraniState();
}

class _DuyurularEkraniState extends State<DuyurularEkrani> {
  String _sekme = 'duyuru';

  @override
  Widget build(BuildContext context) => VeriSayfasi(
        baslik: 'Duyurular',
        getir: () => widget.api.get('/api/duyuru/liste'),
        cizim: (context, veri) {
          final v = veri as Map<String, dynamic>;
          final duyurular = v.l('duyurular');
          final mesajlar = v.l('mesajlar');
          final sekme = mesajlar.isEmpty ? 'duyuru' : _sekme;
          final liste = sekme == 'duyuru' ? duyurular : mesajlar;
          return [
            if (mesajlar.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SuzgecCipleri(
                  secenekler: [('duyuru', 'Duyurular · ${duyurular.length}'), ('mesaj', 'Mesajlar · ${mesajlar.length}')],
                  secili: sekme,
                  degisti: (k) => setState(() => _sekme = k),
                ),
              ),
            if (liste.isEmpty) BosNot(sekme == 'duyuru' ? 'Duyuru yok.' : 'Öğretmenlerden gelen mesaj yok.'),
            for (final x in liste) _Ileti(x),
          ];
        },
      );
}

String _gunAy(num ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms.toInt());
  return '${d.day} ${ayAdlari[d.month - 1].substring(0, 3)}';
}

class _Ileti extends StatefulWidget {
  const _Ileti(this.x);

  final Map<String, dynamic> x;

  @override
  State<_Ileti> createState() => _IletiState();
}

class _IletiState extends State<_Ileti> {
  bool _acik = false;

  @override
  Widget build(BuildContext context) {
    final x = widget.x;
    final alt = [x.s('hedef'), x.s('yazan')].where((e) => e.isNotEmpty).join(' · ');
    return KartKutu(
      onTap: () => setState(() => _acik = !_acik),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(x.s('baslik'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
          const SizedBox(width: 8),
          if (x['yeni'] == true) ...[const Cip('Yeni', renk: Color(0xFFA4161A)), const SizedBox(width: 8)],
          if (x['tarih'] is num) Text(_gunAy(x['tarih'] as num), style: TextStyle(color: context.soluk, fontSize: 13)),
        ]),
        const SizedBox(height: 6),
        Text(x.s('metin'), maxLines: _acik ? null : 3, overflow: _acik ? null : TextOverflow.ellipsis, style: const TextStyle(height: 1.4)),
        if (alt.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(alt, style: TextStyle(color: context.soluk, fontSize: 12.5)),
        ],
      ]),
    );
  }
}

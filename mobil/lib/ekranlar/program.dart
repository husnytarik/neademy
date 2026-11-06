import 'package:flutter/material.dart';

import '../bilesenler/ortak.dart';
import '../cekirdek/api.dart';
import '../cekirdek/takvim_model.dart';
import '../cekirdek/tema.dart';

const _devam = {'geldi': 'Geldi', 'gelmedi': 'Gelmedi', 'gec': 'Geç kaldı', 'izinli': 'İzinli'};
const _yanit = {'bekliyor': 'Yanıt bekleniyor', 'gelecek': 'Geleceğiz', 'gelmeyecek': 'Gelmeyecek'};
const _kirmizi = Color(0xFFD64545);
const _yesil = Color(0xFF2E9E5B);

/// Öğrenci ve veli: haftalık ders çizelgesi, işlenen konular ve ödevler.
class ProgramEkrani extends StatefulWidget {
  const ProgramEkrani({super.key, required this.api});

  final Api api;

  @override
  State<ProgramEkrani> createState() => _ProgramEkraniState();
}

class _ProgramEkraniState extends State<ProgramEkrani> {
  String? _tarih; // haftadan herhangi bir gün; boşsa sunucunun "bugün"ü
  int? _cocuk;
  String _mod = 'gun'; // web gibi: günlük / haftalık

  @override
  Widget build(BuildContext context) => VeriSayfasi(
    key: ValueKey('$_tarih|$_cocuk'),
    baslik: 'Ders programı',
    getir: () => widget.api.get('/api/ders/program?${[if (_tarih != null) 'tarih=$_tarih', if (_cocuk != null) 'cocuk=$_cocuk'].join('&')}'),
    cizim: (context, veri) {
      final v = veri as Map<String, dynamic>;
      final cocuklar = v.l('cocuklar');
      if (cocuklar.isEmpty) return const [BosNot('Bağlı öğrenci bulunamadı.')];
      final bugun = v.s('bugun');
      final pazartesi = v.s('pazartesi');
      final gunler = v.l('gunler');
      final bu = gunler.any((g) => g.s('tarih') == bugun);
      final toplam = gunler.fold<int>(0, (t, g) => t + g.l('dersler').where((d) => d['iptal'] != true).length);
      return [
        if (cocuklar.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: DropdownButtonFormField<int>(
              initialValue: v.n('cocuk'),
              decoration: const InputDecoration(isDense: true),
              items: [for (final c in cocuklar) DropdownMenuItem(value: c.n('id'), child: Text(c.s('ad')))],
              onChanged: (id) => setState(() => _cocuk = id),
            ),
          ),
        Sekmeler(secenekler: const [('gun', 'Günlük'), ('hafta', 'Haftalık')], secili: _mod, degisti: (m) => setState(() => _mod = m)),
        const SizedBox(height: 12),
        if (_mod == 'gun') ...[
          _GunSecici(
            metin: uzunTarih(_tarih ?? bugun),
            bugunMu: (_tarih ?? bugun) == bugun,
            onceki: () => setState(() => _tarih = gunKaydir(_tarih ?? bugun, -1)),
            sonraki: () => setState(() => _tarih = gunKaydir(_tarih ?? bugun, 1)),
            bugun: () => setState(() => _tarih = null),
          ),
          const SizedBox(height: 10),
          for (final g in gunler)
            if (g.s('tarih') == (_tarih ?? bugun)) _Gun(g, bugun: bugun, baslikGoster: false),
        ] else ...[
          Row(
            children: [
              IconButton(onPressed: () => setState(() => _tarih = gunKaydir(pazartesi, -7)), icon: const Icon(Icons.chevron_left)),
              Expanded(
                child: Column(
                  children: [
                    Text('${kisaTarih(pazartesi)} – ${kisaTarih(gunler.last.s('tarih'))}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    Text('$toplam saat ders${v.s('sinif').isEmpty ? '' : ' · ${v.s('sinif')}'}', style: TextStyle(color: context.soluk, fontSize: 13)),
                  ],
                ),
              ),
              IconButton(onPressed: () => setState(() => _tarih = gunKaydir(pazartesi, 7)), icon: const Icon(Icons.chevron_right)),
            ],
          ),
          if (!bu)
            Align(
              alignment: Alignment.center,
              child: TextButton(onPressed: () => setState(() => _tarih = null), child: const Text('Bu haftaya dön')),
            ),
          const SizedBox(height: 6),
          for (final g in gunler)
            if (g['acik'] == true || g['tatil'] != null || g.l('dersler').isNotEmpty || g.l('etutler').isNotEmpty) _Gun(g, bugun: bugun),
        ],
      ];
    },
  );
}

class _Gun extends StatelessWidget {
  const _Gun(this.g, {required this.bugun, this.baslikGoster = true});

  final Map<String, dynamic> g;
  final String bugun;
  final bool baslikGoster;

  @override
  Widget build(BuildContext context) {
    final t = tarihCoz(g.s('tarih'));
    final bugunMu = g.s('tarih') == bugun;
    final dersler = g.l('dersler');
    final etutler = g.l('etutler');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (baslikGoster)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
            child: Row(
              children: [
                Text(
                  '${gunAdlari[t.weekday - 1]} ${t.day} ${ayAdlari[t.month - 1].substring(0, 3)}',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: bugunMu ? context.ana : null),
                ),
                if (bugunMu) ...[const SizedBox(width: 8), Cip('Bugün', renk: context.ana)],
              ],
            ),
          ),
        if (dersler.isEmpty && etutler.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(g['tatil'] != null ? '${g.s('tatil')} · okul tatil' : 'Bu günde ders yok.', style: TextStyle(color: context.soluk)),
          ),
        for (final d in dersler) _DersSatiri(d),
        for (final e in etutler) _EtutSatiri(e),
      ],
    );
  }
}

class _DersSatiri extends StatelessWidget {
  const _DersSatiri(this.d);

  final Map<String, dynamic> d;

  @override
  Widget build(BuildContext context) {
    final iptal = d['iptal'] == true;
    final renk = rengiCoz(d['renk'] as String?) ?? context.ana;
    // Kutu dolu kalır: doygunluğu düşük, açık pastel zemin + aynı tonda koyu yazı
    final kutu = pastelZemin(renk);
    final yazi = pastelYazi(renk);
    final odevler = d.l('odevler');
    final devam = d.s('devam');
    final saat = d.s('aralik').split(RegExp(r'[–-]')).first;
    return KartKutu(
      alt: 8,
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 66,
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(color: kutu, borderRadius: BorderRadius.circular(9)),
            child: Column(
              children: [
                Text(
                  '${d.n('dersSaati')}.',
                  style: serif.copyWith(color: yazi, fontSize: 17, fontWeight: FontWeight.w700, height: 1.1),
                ),
                Text(
                  saat,
                  style: TextStyle(color: yazi, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.s('ders'),
                  style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600, decoration: iptal ? TextDecoration.lineThrough : null),
                ),
                if (d.s('ogretmen').isNotEmpty) Text(d.s('ogretmen'), style: TextStyle(color: context.soluk, fontSize: 13.5)),
                if (d.s('konu').isNotEmpty) ...[const SizedBox(height: 6), Text('Konu: ${d.s('konu')}', style: const TextStyle(fontSize: 13.5, height: 1.3))],
                for (final o in odevler)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Ödev: ${o.s('baslik')} (son ${kisaTarih(o.s('sonTarih'))})', style: TextStyle(color: context.soluk, fontSize: 13.5)),
                  ),
                if (iptal || d['islendi'] == true || (!iptal && devam.isNotEmpty)) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (iptal) const Cip('İptal', renk: _kirmizi) else if (d['islendi'] == true) const Cip('İşlendi', renk: _yesil),
                      if (!iptal && devam.isNotEmpty) Cip(_devam[devam] ?? devam, renk: devam == 'gelmedi' ? _kirmizi : null),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EtutSatiri extends StatelessWidget {
  const _EtutSatiri(this.e);

  final Map<String, dynamic> e;

  @override
  Widget build(BuildContext context) {
    final renk = rengiCoz(e['renk'] as String?) ?? const Color(0xFF059669);
    final devam = e.s('devam');
    final yanit = e.s('yanit');
    return KartKutu(
      alt: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Cip('Etüt', renk: renk),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${e.s('saat')} · ${e.n('sure')} dk${e.s('yer').isEmpty ? '' : ' · ${e.s('yer')}'}',
                  style: TextStyle(color: context.soluk, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(e.s('ders').isEmpty ? e.s('konu') : '${e.s('ders')} · ${e.s('konu')}', style: const TextStyle(fontWeight: FontWeight.w600)),
          if (e.s('ogretmen').isNotEmpty) Text(e.s('ogretmen'), style: TextStyle(color: context.soluk, fontSize: 13.5)),
          const SizedBox(height: 6),
          Text(
            devam.isNotEmpty ? 'Devam: ${_devam[devam] ?? devam}' : 'Veli yanıtı: ${_yanit[yanit] ?? yanit}',
            style: TextStyle(color: context.soluk, fontSize: 13.5),
          ),
        ],
      ),
    );
  }
}

/// Günlük görünümde gün seçici: ok kutuları, ortada tarih ve "Bugün" (web: .gun-secici).
class _GunSecici extends StatelessWidget {
  const _GunSecici({required this.metin, required this.bugunMu, required this.onceki, required this.sonraki, required this.bugun});

  final String metin;
  final bool bugunMu;
  final VoidCallback onceki;
  final VoidCallback sonraki;
  final VoidCallback bugun;

  @override
  Widget build(BuildContext context) {
    Widget ok(IconData i, VoidCallback f) => InkWell(
      onTap: f,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: context.kart,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.ince),
        ),
        child: Icon(i, size: 22),
      ),
    );
    return Row(
      children: [
        ok(Icons.arrow_back, onceki),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 46,
            padding: const EdgeInsets.only(left: 14, right: 6),
            decoration: BoxDecoration(
              color: context.kart,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.ince),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    metin,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                if (!bugunMu)
                  TextButton(
                    onPressed: bugun,
                    style: TextButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 12)),
                    child: const Text('Bugün'),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        ok(Icons.arrow_forward, sonraki),
      ],
    );
  }
}

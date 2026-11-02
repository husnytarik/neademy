import 'package:flutter/material.dart';

import '../cekirdek/api.dart';
import '../cekirdek/tema.dart';
import 'ortak.dart';

/// Seçilen kazanım kodlarını tutar; MEB listesi yoksa [var_] false kalır (konu serbest yazılır).
class KazanimSecimi extends ChangeNotifier {
  KazanimSecimi({List<String> secili = const [], this.tek = false}) : kodlar = [...secili];

  final bool tek;
  final List<String> kodlar;
  bool yuklendi = false;
  bool var_ = false;
  List<Map<String, dynamic>> gruplar = [];

  String metin(String kod) {
    for (final g in gruplar) {
      for (final k in g.l('kazanimlar')) {
        if (k.s('kod') == kod) return k.s('metin');
      }
    }
    return '';
  }

  Future<void> yukle(Api api, {required int sinifId, required String ders}) async {
    try {
      final j = await api.get('/api/mufredat/kazanimlar?sinifId=$sinifId&ders=${Uri.encodeQueryComponent(ders)}') as Map<String, dynamic>;
      var_ = j['var'] == true;
      gruplar = j.l('gruplar');
    } on ApiHata {
      var_ = false;
    }
    yuklendi = true;
    notifyListeners();
  }

  void degistir(String kod) {
    if (kodlar.contains(kod)) {
      kodlar.remove(kod);
    } else {
      if (tek) kodlar.clear();
      kodlar.add(kod);
    }
    notifyListeners();
  }
}

/// Seçilen kazanımları çip olarak gösterir; "Kazanım seç" ile ünite/kazanım listesi açılır.
class KazanimAlani extends StatelessWidget {
  const KazanimAlani({super.key, required this.secim});

  final KazanimSecimi secim;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: secim,
        builder: (context, _) {
          if (!secim.yuklendi) {
            return const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: LinearProgressIndicator(minHeight: 2));
          }
          if (!secim.var_) return const SizedBox.shrink();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (secim.kodlar.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final kod in secim.kodlar)
                    InputChip(
                      label: Text(kod, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      onDeleted: () => secim.degistir(kod),
                      visualDensity: VisualDensity.compact,
                      side: BorderSide(color: context.ince),
                    ),
                ]),
              ),
            OutlinedButton.icon(
              onPressed: () => _ac(context),
              icon: const Icon(Icons.checklist, size: 20),
              label: Text(secim.kodlar.isEmpty ? 'Kazanım seç' : 'Kazanımları değiştir'),
            ),
          ]);
        },
      );

  void _ac(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _KazanimListesi(secim: secim),
      );
}

class _KazanimListesi extends StatefulWidget {
  const _KazanimListesi({required this.secim});

  final KazanimSecimi secim;

  @override
  State<_KazanimListesi> createState() => _KazanimListesiState();
}

class _KazanimListesiState extends State<_KazanimListesi> {
  late String _acik;

  @override
  void initState() {
    super.initState();
    final g = widget.secim.gruplar;
    final ilk = g.where((x) => x.l('kazanimlar').any((k) => widget.secim.kodlar.contains(k.s('kod')))).firstOrNull ?? g.firstOrNull;
    _acik = ilk?.s('anahtar') ?? '';
  }

  String _ad(Map<String, dynamic> g) {
    final ipucu = g.s('ad').isNotEmpty ? g.s('ad') : (g.l('kazanimlar').firstOrNull?.s('metin').replaceAll(RegExp(r'-\s+'), '') ?? '');
    final kisa = ipucu.length > 38 ? '${ipucu.substring(0, 38)}…' : ipucu;
    return [g.s('baslik'), kisa].where((e) => e.isNotEmpty).join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final secim = widget.secim;
    final grup = secim.gruplar.where((g) => g.s('anahtar') == _acik).firstOrNull;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .85,
      maxChildSize: .95,
      builder: (context, kaydirma) => ListenableBuilder(
        listenable: secim,
        builder: (context, _) => Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: DropdownButtonFormField<String>(
              initialValue: _acik.isEmpty ? null : _acik,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Ünite'),
              items: [
                for (final g in secim.gruplar)
                  DropdownMenuItem(value: g.s('anahtar'), child: Text(_ad(g), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => _acik = v ?? _acik),
            ),
          ),
          Expanded(
            child: ListView(controller: kaydirma, padding: const EdgeInsets.fromLTRB(8, 0, 8, 12), children: [
              for (final k in grup?.l('kazanimlar') ?? const <Map<String, dynamic>>[])
                CheckboxListTile(
                  value: secim.kodlar.contains(k.s('kod')),
                  onChanged: (_) => secim.degistir(k.s('kod')),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(k.s('kod'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: Text(k.s('metin'), style: const TextStyle(height: 1.3)),
                ),
            ]),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: Text(secim.kodlar.isEmpty ? 'Kapat' : 'Tamam · ${secim.kodlar.length} seçili'),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

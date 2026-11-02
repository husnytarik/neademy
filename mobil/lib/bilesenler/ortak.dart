import 'package:flutter/material.dart';

import '../cekirdek/api.dart';
import '../cekirdek/tema.dart';

/// Sunucudan tek istekle veri çeken, yükleme/hata/yenileme durumlarını yöneten sayfa iskeleti.
/// [getir] değişince sayfayı yeniden yüklemek için çağıran taraf `key` verir.
class VeriSayfasi extends StatefulWidget {
  const VeriSayfasi({super.key, required this.baslik, required this.getir, required this.cizim});

  final String baslik;
  final Future<dynamic> Function() getir;

  /// Listeye girecek parçaları üretir.
  final List<Widget> Function(BuildContext context, dynamic veri) cizim;

  @override
  State<VeriSayfasi> createState() => _VeriSayfasiState();
}

class _VeriSayfasiState extends State<VeriSayfasi> {
  dynamic _veri;
  String? _hata;
  bool _yukleniyor = true;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    if (_veri == null) setState(() => _yukleniyor = true);
    try {
      final v = await widget.getir();
      if (!mounted) return;
      setState(() {
        _veri = v;
        _hata = null;
      });
    } on ApiHata catch (e) {
      if (mounted && !e.oturumYok) setState(() => _hata = e.mesaj);
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget govde;
    if (_veri != null) {
      govde = RefreshIndicator(
        onRefresh: _yukle,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: widget.cizim(context, _veri),
        ),
      );
    } else if (_yukleniyor) {
      govde = const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    } else {
      govde = Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_hata ?? 'Veri alınamadı.', textAlign: TextAlign.center, style: TextStyle(color: context.soluk)),
              const SizedBox(height: 14),
              OutlinedButton(onPressed: _yukle, style: OutlinedButton.styleFrom(minimumSize: const Size(140, 46)), child: const Text('Tekrar dene')),
            ],
          ),
        ),
      );
    }
    return Scaffold(appBar: AppBar(title: Text(widget.baslik)), body: govde);
  }
}

/// Liste boşken gösterilen sade not.
class BosNot extends StatelessWidget {
  const BosNot(this.metin, {super.key});

  final String metin;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 8),
        child: Center(child: Text(metin, textAlign: TextAlign.center, style: TextStyle(color: context.soluk, fontSize: 15))),
      );
}

/// Bölüm başlığı (öğrenci adı, "Kayıtlar" vb.).
class Baslik extends StatelessWidget {
  const Baslik(this.metin, {super.key, this.ust = 18});

  final String metin;
  final double ust;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(2, ust, 2, 8),
        child: Text(metin, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -.2)),
      );
}

/// Küçük etiket (durum, süre vb.).
class Cip extends StatelessWidget {
  const Cip(this.metin, {super.key, this.renk});

  final String metin;
  final Color? renk;

  @override
  Widget build(BuildContext context) {
    final r = renk ?? context.soluk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: r.withValues(alpha: .13), borderRadius: BorderRadius.circular(20)),
      child: Text(metin, style: TextStyle(color: r, fontSize: 12.5, fontWeight: FontWeight.w600)),
    );
  }
}

/// Yumuşak kenarlı kart; [onTap] verilirse dokunulabilir.
class KartKutu extends StatelessWidget {
  const KartKutu({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(14), this.alt = 10});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final double alt;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: alt),
        child: Material(
          color: context.kart,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: context.ince)),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      );
}

/// Yatay kaydırılan seçim çipleri (süzgeç).
class SuzgecCipleri extends StatelessWidget {
  const SuzgecCipleri({super.key, required this.secenekler, required this.secili, required this.degisti});

  /// (değer, görünen ad)
  final List<(String, String)> secenekler;
  final String secili;
  final ValueChanged<String> degisti;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: secenekler.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final (deger, ad) = secenekler[i];
            return ChoiceChip(
              label: Text(ad),
              selected: secili == deger,
              onSelected: (_) => degisti(deger),
              showCheckmark: false,
              side: BorderSide(color: context.ince),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            );
          },
        ),
      );
}

/// Sunucudan gelen JSON alanlarını güvenle okumak için kısayollar.
extension JsonOkuma on Map<String, dynamic> {
  String s(String k) => this[k]?.toString() ?? '';
  int n(String k) => (this[k] as num?)?.toInt() ?? 0;
  List<Map<String, dynamic>> l(String k) => [for (final x in (this[k] as List? ?? const [])) x as Map<String, dynamic>];
  Map<String, dynamic> m(String k) => (this[k] as Map<String, dynamic>?) ?? const {};
}

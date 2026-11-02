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
              Text(
                _hata ?? 'Veri alınamadı.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.soluk),
              ),
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: _yukle,
                style: OutlinedButton.styleFrom(minimumSize: const Size(140, 46)),
                child: const Text('Tekrar dene'),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.baslik)),
      body: govde,
    );
  }
}

/// Liste boşken gösterilen sade not.
class BosNot extends StatelessWidget {
  const BosNot(this.metin, {super.key});

  final String metin;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 8),
    child: Center(
      child: Text(
        metin,
        textAlign: TextAlign.center,
        style: TextStyle(color: context.soluk, fontSize: 15),
      ),
    ),
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
    child: Text(metin, style: serif.copyWith(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -.2)),
  );
}

/// Web'deki hap biçimli sekmeler (.sekmeler): yumuşak zemin üzerinde seçili olan beyaz kabarır.
class Sekmeler extends StatelessWidget {
  const Sekmeler({super.key, required this.secenekler, required this.secili, required this.degisti});

  /// (değer, görünen ad)
  final List<(String, String)> secenekler;
  final String secili;
  final ValueChanged<String> degisti;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(color: context.icZemin, borderRadius: BorderRadius.circular(16)),
    child: Row(
      children: [
        for (final (deger, ad) in secenekler)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => degisti(deger),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: secili == deger ? context.kart : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: secili == deger ? [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 6, offset: const Offset(0, 1))] : null,
                ),
                child: Text(
                  ad,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: secili == deger ? FontWeight.w700 : FontWeight.w500,
                    color: secili == deger ? context.yazi : context.soluk,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// Ders kısaltması rozeti (web: dersChip): dersin sabit renginde yuvarlak köşeli kutu.
/// Koyu temada koyu ders renkleri okunmaz; yazıda kullanılacak rengi açar.
Color okunur(BuildContext context, Color r) => Theme.of(context).brightness == Brightness.dark ? Color.lerp(r, Colors.white, .55)! : r;

class DersRozeti extends StatelessWidget {
  const DersRozeti(this.kisa, this.renk, {super.key, this.boyut = 40});

  final String kisa;
  final Color renk;
  final double boyut;

  @override
  Widget build(BuildContext context) => Container(
    width: boyut,
    height: boyut,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: renk.withValues(alpha: .15), borderRadius: BorderRadius.circular(boyut * .32)),
    child: Text(
      kisa.isEmpty ? '•' : kisa,
      maxLines: 1,
      style: TextStyle(color: okunur(context, renk), fontWeight: FontWeight.w800, fontSize: boyut * .36),
    ),
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
      child: Text(
        metin,
        style: TextStyle(color: r, fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
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
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: .22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
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

/// Hatayı kullanıcıya kısa bir uyarı olarak gösterir.
void hataGoster(BuildContext context, Object hata) {
  if (!context.mounted) return;
  final metin = hata is ApiHata ? hata.mesaj : 'Bir sorun oluştu. Tekrar deneyin.';
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(metin)));
}

/// Onay penceresi; "Evet" seçilirse true döner.
Future<bool> onayIste(BuildContext context, String soru, {String evet = 'Evet'}) async {
  final s = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      content: Text(soru),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(evet)),
      ],
    ),
  );
  return s ?? false;
}

/// "Deniz Örnek" -> "DÖ" (web: bas); boşsa "?".
String basHarfler(String ad) {
  final p = ad.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty).take(2).map((x) => x.characters.first);
  final b = p.join().toUpperCase();
  return b.isEmpty ? '?' : b;
}

/// Kişi küçük resmi: fotoğraf varsa o, yoksa ad baş harfleri (web: .avatar).
class KisiAvatari extends StatelessWidget {
  const KisiAvatari({super.key, required this.ad, this.foto = '', this.api, this.yaricap = 20});

  final String ad;
  final String foto;
  final Api? api;
  final double yaricap;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: yaricap,
    backgroundColor: context.ana.withValues(alpha: .14),
    foregroundImage: foto.isEmpty || api == null ? null : NetworkImage('${Api.taban}$foto', headers: api!.kimlik),
    child: Text(
      basHarfler(ad),
      style: TextStyle(color: context.ana, fontWeight: FontWeight.w700, fontSize: yaricap * .7),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../bilesenler/ortak.dart';
import 'api.dart';

/// Yazdırılacak raporun bir bölümü: başlık + (özet satırları | tablo | düz metin).
/// Web'deki "Yazdır" çıktılarıyla aynı yapı: kurum adı ve tarih üstte, bölümler sırayla.
class RaporBolumu {
  const RaporBolumu({this.baslik, this.ozet = const [], this.sutunlar = const [], this.satirlar = const [], this.metin, this.bos});

  final String? baslik;

  /// Etiket / değer çiftleri (ör. "Öğrenci sayısı" – "480").
  final List<(String, String)> ozet;

  /// Tablo başlıkları ve satırları; [satirlar] boşsa [bos] metni yazılır.
  final List<String> sutunlar;
  final List<List<String>> satirlar;
  final String? metin;
  final String? bos;
}

String bugunMetni() {
  final n = DateTime.now();
  return '${n.day.toString().padLeft(2, '0')}.${n.month.toString().padLeft(2, '0')}.${n.year}';
}

/// Raporu PDF'e çevirip sistemin yazdır / PDF olarak kaydet / paylaş penceresini açar.
/// Telefonda yazıcı seçilebilir ya da "PDF olarak kaydet / paylaş" kullanılır.
Future<void> raporYazdir(
  BuildContext context,
  Api api, {
  String? kurum,
  required String baslik,
  String alt = '',
  required List<RaporBolumu> bolumler,
}) async {
  try {
    final bayt = await _pdfUret(kurum: kurum ?? await _kurumAdi(api), baslik: baslik, alt: alt, bolumler: bolumler);
    final dosya = baslik.toLowerCase().replaceAll(RegExp(r'[^a-z0-9ığüşöçİĞÜŞÖÇ]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
    await Printing.layoutPdf(onLayout: (_) async => bayt, name: dosya.isEmpty ? 'rapor' : dosya);
  } catch (e) {
    if (context.mounted) hataGoster(context, e);
  }
}

String? _kurumOnbellek;

/// Raporun üst satırında yazan kurum adı (oturumdaki kişinin kurumu).
Future<String> _kurumAdi(Api api) async {
  if (_kurumOnbellek != null) return _kurumOnbellek!;
  try {
    final j = await api.get('/api/ben');
    final k = j is Map && j['kurum'] is Map ? (j['kurum']['ad'] as String? ?? '') : '';
    return _kurumOnbellek = k.isEmpty ? 'neademy' : k;
  } on ApiHata {
    return 'neademy';
  }
}

Future<Uint8List> _pdfUret({
  required String kurum,
  required String baslik,
  required String alt,
  required List<RaporBolumu> bolumler,
}) async {
  final normal = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
  final kalin = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
  final doc = pw.Document(
    title: baslik,
    theme: pw.ThemeData.withFont(base: normal, bold: kalin, italic: normal, boldItalic: kalin),
  );
  const koyu = PdfColor.fromInt(0xFF1C1B19);
  const soluk = PdfColor.fromInt(0xFF6B675F);
  const cizgi = PdfColor.fromInt(0xFFD9D4C8);
  const zemin = PdfColor.fromInt(0xFFF1EEE6);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 40),
      header: (c) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 6),
        margin: const pw.EdgeInsets.only(bottom: 14),
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: cizgi, width: .8))),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(child: pw.Text(kurum, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: koyu))),
            pw.Text(bugunMetni(), style: const pw.TextStyle(fontSize: 10, color: soluk)),
          ],
        ),
      ),
      footer: (c) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Sayfa ${c.pageNumber} / ${c.pagesCount}', style: const pw.TextStyle(fontSize: 9, color: soluk)),
      ),
      build: (c) => [
        pw.Text(baslik, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20, color: koyu)),
        if (alt.isNotEmpty) pw.Padding(padding: const pw.EdgeInsets.only(top: 3), child: pw.Text(alt, style: const pw.TextStyle(fontSize: 11, color: soluk))),
        pw.SizedBox(height: 10),
        for (final b in bolumler) ...[
          if (b.baslik != null && b.baslik!.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 12, bottom: 6),
              child: pw.Text(b.baslik!, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: koyu)),
            ),
          if (b.metin != null && b.metin!.isNotEmpty) pw.Text(b.metin!, style: const pw.TextStyle(fontSize: 11, lineSpacing: 2)),
          if (b.ozet.isNotEmpty)
            pw.Table(
              columnWidths: {0: const pw.FlexColumnWidth(2), 1: const pw.FlexColumnWidth(3)},
              border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: cizgi, width: .5), bottom: pw.BorderSide(color: cizgi, width: .5)),
              children: [
                for (final (e, d) in b.ozet)
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4), child: pw.Text(e, style: const pw.TextStyle(fontSize: 10.5, color: soluk))),
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4), child: pw.Text(d, style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold))),
                    ],
                  ),
              ],
            ),
          if (b.sutunlar.isNotEmpty && b.satirlar.isNotEmpty)
            pw.TableHelper.fromTextArray(
              headers: b.sutunlar,
              data: b.satirlar,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: koyu),
              cellStyle: const pw.TextStyle(fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: zemin),
              border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: cizgi, width: .5), bottom: pw.BorderSide(color: cizgi, width: .5)),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              cellAlignment: pw.Alignment.centerLeft,
              headerAlignment: pw.Alignment.centerLeft,
            ),
          if (b.sutunlar.isNotEmpty && b.satirlar.isEmpty && b.bos != null)
            pw.Text(b.bos!, style: const pw.TextStyle(fontSize: 10.5, color: soluk)),
        ],
      ],
    ),
  );
  return doc.save();
}

/// Uygulama çubuğundaki yazıcı simgesi.
class YazdirDugmesi extends StatelessWidget {
  const YazdirDugmesi({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Yazdır',
    onPressed: onPressed,
    icon: const Icon(Icons.print_outlined),
  );
}

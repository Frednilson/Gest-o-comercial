import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/constants/app_constants.dart';
import '../core/utils/formatters.dart';
import '../models/configuracao.dart';
import '../models/relatorio.dart';
import '../models/venda.dart';

/// Geração de recibos e relatórios em PDF.
class PdfService {
  static pw.MemoryImage? _logo(Configuracao c) {
    final path = c.logotipo;
    if (path == null || path.isEmpty) return null;
    final f = File(path);
    if (!f.existsSync()) return null;
    try {
      return pw.MemoryImage(f.readAsBytesSync());
    } catch (_) {
      return null;
    }
  }

  static pw.Widget _linha(String a, String b, {bool bold = false, double size = 9}) {
    final style = pw.TextStyle(fontSize: size, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: pw.Text(a, style: style)),
          pw.SizedBox(width: 6),
          pw.Text(b, style: style),
        ],
      ),
    );
  }

  /// Recibo em formato de talão (80 mm).
  static Future<Uint8List> recibo(Venda v, Configuracao c) async {
    final doc = pw.Document(title: 'Recibo ${v.numeroVenda}', author: c.nomeEstabelecimento);
    final logo = _logo(c);
    const mm = PdfPageFormat.mm;
    final formato = PdfPageFormat(80 * mm, 220 * mm, marginAll: 5 * mm);

    pw.Widget centro(String t, {double size = 9, bool bold = false}) => pw.Center(
          child: pw.Text(t,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: size, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        );

    doc.addPage(pw.MultiPage(
      pageFormat: formato,
      build: (ctx) => [
        if (logo != null) pw.Center(child: pw.Image(logo, height: 42)),
        if (logo != null) pw.SizedBox(height: 4),
        centro(c.nomeEstabelecimento, size: 13, bold: true),
        if ((c.endereco ?? '').isNotEmpty) centro(c.endereco!),
        if ((c.telefone ?? '').isNotEmpty) centro('Tel: ${c.telefone}'),
        pw.Divider(thickness: 0.6),
        centro('RECIBO DE VENDA', size: 10, bold: true),
        pw.SizedBox(height: 3),
        _linha('Nº da venda', v.numeroVenda),
        _linha('Data', Fmt.dateTime(v.dataVenda)),
        if (v.clienteNome != null) _linha('Cliente', v.clienteNome!),
        if (v.cancelada) _linha('Estado', 'CANCELADA', bold: true),
        pw.Divider(thickness: 0.6),
        for (final i in v.itens) ...[
          pw.Text(i.nomeProduto, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          _linha('${i.quantidade} x ${Fmt.number(i.precoUnitario)}', Fmt.number(i.subtotal)),
          pw.SizedBox(height: 2),
        ],
        pw.Divider(thickness: 0.6),
        _linha('Subtotal', Fmt.money(v.subtotal)),
        if (v.desconto > 0) _linha('Desconto', '- ${Fmt.money(v.desconto)}'),
        _linha('TOTAL', Fmt.money(v.total), bold: true, size: 11),
        pw.SizedBox(height: 3),
        _linha('Método de pagamento', v.metodoResumo),
        for (final pg in v.pagamentos) _linha('  ${AppConstants.paymentLabel(pg.metodo)}', Fmt.money(pg.valor)),
        _linha('Total pago', Fmt.money(v.total - v.valorEmFalta + 0)),
        if (v.troco > 0) _linha('Troco', Fmt.money(v.troco)),
        if (v.valorEmFalta > 0) _linha('Em falta', Fmt.money(v.valorEmFalta), bold: true),
        pw.Divider(thickness: 0.6),
        if ((c.rodapeRecibo ?? '').isNotEmpty) centro(c.rodapeRecibo!),
      ],
    ));
    return doc.save();
  }

  /// Relatório genérico em A4.
  static Future<Uint8List> relatorio(ReportData r, Configuracao c) async {
    final doc = pw.Document(title: r.titulo, author: c.nomeEstabelecimento);
    final logo = _logo(c);
    final azul = PdfColor.fromInt(0xFF2563EB);

    final alinhamentos = <int, pw.Alignment>{
      for (final i in r.colunasNumericas) i: pw.Alignment.centerRight,
    };

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
      ),
      build: (ctx) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (logo != null) pw.Image(logo, height: 40),
            if (logo != null) pw.SizedBox(width: 10),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(c.nomeEstabelecimento,
                      style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
                  if ((c.endereco ?? '').isNotEmpty)
                    pw.Text(c.endereco!, style: const pw.TextStyle(fontSize: 9)),
                  if ((c.telefone ?? '').isNotEmpty)
                    pw.Text('Tel: ${c.telefone}', style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Text(r.titulo, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: azul)),
        pw.Text('Período: ${r.periodo}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.Text('Emitido em ${Fmt.dateTime(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.SizedBox(height: 10),
        if (r.resumo.isNotEmpty)
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFEFF6FF),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              children: [
                for (final e in r.resumo.entries) _linha(e.key, e.value, bold: true, size: 10),
              ],
            ),
          ),
        pw.SizedBox(height: 12),
        if (r.linhas.isEmpty)
          pw.Text('Sem registos no período seleccionado.', style: const pw.TextStyle(fontSize: 11))
        else
          pw.TableHelper.fromTextArray(
            headers: r.colunas,
            data: r.linhas,
            headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: azul),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignments: alinhamentos,
            headerAlignments: alinhamentos,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            oddRowDecoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFF8FAFC)),
            border: pw.TableBorder(
              bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
              horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
            ),
          ),
      ],
    ));
    return doc.save();
  }

  /// Guarda o PDF na pasta da aplicação e devolve o caminho.
  static Future<String> guardar(Uint8List bytes, String nomeFicheiro) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'pdfs'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File(p.join(dir.path, nomeFicheiro));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}

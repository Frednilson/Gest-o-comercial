import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/app_exception.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../models/venda.dart';
import '../../../providers/config_provider.dart';
import '../../../services/pdf_service.dart';
import '../../../services/venda_service.dart';

/// Recibo em PDF: pré-visualização, guardar, partilhar e imprimir.
class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key, required this.vendaId});

  final int vendaId;

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  late final Future<({Venda venda, Uint8List bytes})?> _future = _gerar();

  Future<({Venda venda, Uint8List bytes})?> _gerar() async {
    final config = context.read<ConfigProvider>().config;
    final venda = await VendaService().porId(widget.vendaId);
    if (venda == null) return null;
    final bytes = await PdfService.recibo(venda, config);
    return (venda: venda, bytes: bytes);
  }

  Future<String> _guardarFicheiro(Venda v, Uint8List bytes) =>
      PdfService.guardar(bytes, 'recibo_${v.numeroVenda}.pdf');

  Future<void> _guardar(Venda v, Uint8List bytes) async {
    try {
      final path = await _guardarFicheiro(v, bytes);
      if (mounted) showSnack(context, 'PDF guardado em: $path');
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _partilhar(Venda v, Uint8List bytes) async {
    try {
      final path = await _guardarFicheiro(v, bytes);
      await Share.shareXFiles([XFile(path, mimeType: 'application/pdf')],
          subject: 'Recibo ${v.numeroVenda}', text: 'Recibo ${v.numeroVenda}');
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _imprimir(Uint8List bytes) async {
    try {
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      if (mounted) showSnack(context, 'Não foi possível imprimir: ${errorMessage(e)}', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({Venda venda, Uint8List bytes})?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Scaffold(appBar: AppBar(title: const Text('Recibo')), body: const Center(child: CircularProgressIndicator()));
        }
        final data = snap.data;
        if (data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Recibo')),
            body: const EmptyState(icon: Icons.receipt_long_outlined, message: 'Venda não encontrada.'),
          );
        }
        final bytes = data.bytes;
        return Scaffold(
          appBar: AppBar(
            title: Text('Recibo ${data.venda.numeroVenda}'),
            actions: [
              IconButton(tooltip: 'Guardar PDF', icon: const Icon(Icons.download_outlined), onPressed: () => _guardar(data.venda, bytes)),
              IconButton(tooltip: 'Partilhar', icon: const Icon(Icons.share_outlined), onPressed: () => _partilhar(data.venda, bytes)),
              IconButton(tooltip: 'Imprimir', icon: const Icon(Icons.print_outlined), onPressed: () => _imprimir(bytes)),
            ],
          ),
          body: PdfPreview(
            build: (_) async => bytes,
            allowPrinting: false,
            allowSharing: false,
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
            pdfFileName: 'recibo_${data.venda.numeroVenda}.pdf',
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../models/relatorio.dart';
import '../../../providers/app_data.dart';
import '../../../providers/config_provider.dart';
import '../../../services/pdf_service.dart';

/// Mostra um relatório no ecrã com filtro de período e exporta para PDF.
class ReportViewScreen extends StatefulWidget {
  const ReportViewScreen({super.key, required this.titulo, required this.gerar, this.periodoInicial});

  final String titulo;
  final Future<ReportData> Function(DateTimeRange periodo) gerar;
  final DateTimeRange? periodoInicial;

  @override
  State<ReportViewScreen> createState() => _ReportViewScreenState();
}

class _ReportViewScreenState extends State<ReportViewScreen> {
  late DateTimeRange? _periodo = widget.periodoInicial;
  late Future<ReportData> _future = _carregar();

  Future<ReportData> _carregar() {
    final hoje = DateTime.now();
    return widget.gerar(_periodo ?? DateTimeRange(start: hoje, end: hoje));
  }

  void _recarregar() => setState(() => _future = _carregar());

  Future<void> _escolherPeriodo() async {
    final r = await pickDateRange(context, _periodo);
    if (r != null) {
      _periodo = r;
      _recarregar();
    }
  }

  Future<void> _exportar(ReportData r, {required bool partilhar}) async {
    final config = context.read<ConfigProvider>().config;
    try {
      final bytes = await PdfService.relatorio(r, config);
      final nome = 'relatorio_${r.titulo.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}_'
          '${Fmt.fileStamp(DateTime.now())}.pdf';
      final path = await PdfService.guardar(bytes, nome);
      if (!mounted) return;
      if (partilhar) {
        await Share.shareXFiles([XFile(path, mimeType: 'application/pdf')], subject: r.titulo);
      } else {
        showSnack(context, 'PDF guardado em: $path');
        await Printing.sharePdf(bytes: bytes, filename: nome);
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Não foi possível exportar: ${errorMessage(e)}', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Recarrega o relatório quando os dados da aplicação mudam.
    context.select<AppData, int>((d) => d.version);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titulo),
        actions: [
          if (widget.periodoInicial != null)
            IconButton(tooltip: 'Período', icon: const Icon(Icons.date_range), onPressed: _escolherPeriodo),
        ],
      ),
      body: FutureBuilder<ReportData>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return EmptyState(icon: Icons.error_outline, message: errorMessage(snap.error!));
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final r = snap.data!;
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  children: [
                    Text('Período: ${r.periodo}', style: TextStyle(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 10),
                    if (r.resumo.isNotEmpty)
                      AppCard(
                        child: Column(
                          children: [
                            for (final e in r.resumo.entries)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(child: Text(e.key)),
                                    const SizedBox(width: 8),
                                    Text(e.value, style: const TextStyle(fontWeight: FontWeight.w800)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (r.linhas.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: EmptyState(icon: Icons.bar_chart_rounded, message: 'Sem registos no período.'),
                      )
                    else
                      AppCard(
                        padding: EdgeInsets.zero,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowHeight: 40,
                            dataRowMinHeight: 38,
                            dataRowMaxHeight: 52,
                            columnSpacing: 22,
                            columns: [
                              for (var i = 0; i < r.colunas.length; i++)
                                DataColumn(
                                  label: Text(r.colunas[i], style: const TextStyle(fontWeight: FontWeight.w700)),
                                  numeric: r.colunasNumericas.contains(i),
                                ),
                            ],
                            rows: [
                              for (final l in r.linhas)
                                DataRow(cells: [for (final c in l) DataCell(Text(c))]),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: BoxDecoration(
                  color: cs.surface,
                  border: Border(top: BorderSide(color: cs.outlineVariant)),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _exportar(r, partilhar: true),
                          icon: const Icon(Icons.share_outlined),
                          label: const Text('Partilhar'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _exportar(r, partilhar: false),
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: const Text('Exportar PDF'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

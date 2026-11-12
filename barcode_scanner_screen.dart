import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../models/produto.dart';
import '../../../providers/cart_provider.dart';
import '../../../services/produto_service.dart';
import '../../products/screens/product_form_screen.dart';

enum ScannerMode {
  /// Lê um código e devolve-o (Navigator.pop com a String).
  single,

  /// Modo de venda: lê vários produtos seguidos e adiciona-os ao carrinho.
  sale,
}

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key, this.mode = ScannerMode.single});

  final ScannerMode mode;

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> with SingleTickerProviderStateMixin {
  /// Tempo mínimo entre duas leituras do mesmo código (evita duplicados do scanner).
  static const _intervaloRepeticao = Duration(milliseconds: 1800);

  final MobileScannerController _controller = MobileScannerController(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
    ],
    facing: CameraFacing.back,
    detectionSpeed: DetectionSpeed.normal,
    detectionTimeoutMs: 400,
  );

  late final AnimationController _linha;
  final _produtos = ProdutoService();

  bool _ocupado = false;
  bool _lanterna = false;
  String? _ultimoCodigo;
  DateTime _ultimaLeitura = DateTime.fromMillisecondsSinceEpoch(0);
  Produto? _ultimoProduto;
  String? _aviso;

  bool get _modoVenda => widget.mode == ScannerMode.sale;

  @override
  void initState() {
    super.initState();
    _linha = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _linha.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _alternarLanterna() async {
    try {
      await _controller.toggleTorch();
      if (mounted) setState(() => _lanterna = !_lanterna);
    } catch (_) {
      if (mounted) showSnack(context, 'Este dispositivo não tem lanterna disponível.', error: true);
    }
  }

  Future<void> _aoDetectar(BarcodeCapture captura) async {
    if (_ocupado) return;
    String? codigo;
    for (final b in captura.barcodes) {
      final v = b.rawValue;
      if (v != null && v.trim().isNotEmpty) {
        codigo = v.trim();
        break;
      }
    }
    if (codigo == null) return;

    // Controlo contra leituras duplicadas consecutivas do mesmo código.
    final agora = DateTime.now();
    if (codigo == _ultimoCodigo && agora.difference(_ultimaLeitura) < _intervaloRepeticao) return;
    _ultimoCodigo = codigo;
    _ultimaLeitura = agora;

    HapticFeedback.mediumImpact();

    if (!_modoVenda) {
      _ocupado = true; // ignora detecções seguintes enquanto o ecrã fecha
      if (mounted) Navigator.pop(context, codigo);
      return;
    }

    _ocupado = true;
    try {
      await _tratarVenda(codigo);
    } finally {
      _ultimaLeitura = DateTime.now();
      _ocupado = false;
    }
  }

  Future<void> _tratarVenda(String codigo) async {
    final cart = context.read<CartProvider>();
    final produto = await _produtos.porCodigo(codigo);
    if (!mounted) return;

    if (produto == null) {
      await _produtoNaoCadastrado(codigo);
      return;
    }
    _adicionar(cart, produto);
  }

  void _adicionar(CartProvider cart, Produto produto) {
    final resultado = cart.add(produto);
    setState(() {
      _ultimoProduto = produto;
      switch (resultado) {
        case AddResult.ok:
          _aviso = null;
        case AddResult.semStock:
          _aviso = '"${produto.nome}" está sem stock.';
        case AddResult.stockInsuficiente:
          _aviso = 'Stock insuficiente: só há ${produto.quantidade} unidade(s) de "${produto.nome}".';
      }
    });
    if (resultado != AddResult.ok) HapticFeedback.heavyImpact();
  }

  Future<void> _produtoNaoCadastrado(String codigo) async {
    final cadastrar = await confirmDialog(
      context,
      title: 'Produto não cadastrado',
      message: 'Produto não cadastrado. Deseja cadastrar este produto?\n\nCódigo: $codigo',
      confirmLabel: 'Cadastrar',
    );
    if (!cadastrar || !mounted) return;

    final cart = context.read<CartProvider>();
    try {
      await _controller.stop();
    } catch (_) {}
    if (!mounted) return;
    final novo = await Navigator.push<Produto>(
      context,
      MaterialPageRoute(builder: (_) => ProductFormScreen(codigoInicial: codigo)),
    );
    try {
      await _controller.start();
    } catch (_) {}
    if (novo != null && mounted) {
      final fresco = await _produtos.porId(novo.id!);
      if (fresco != null && mounted) _adicionar(cart, fresco);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, box) {
          final largura = math.min(box.maxWidth * 0.82, 340.0);
          final altura = largura * 0.62;
          final janela = Rect.fromLTWH((box.maxWidth - largura) / 2, box.maxHeight * 0.24, largura, altura);

          return Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                controller: _controller,
                onDetect: _aoDetectar,
                errorBuilder: (context, error, child) => _ErroCamara(error: error),
              ),
              CustomPaint(painter: _MascaraPainter(janela)),
              AnimatedBuilder(
                animation: _linha,
                builder: (context, _) => Positioned(
                  left: janela.left + 12,
                  width: janela.width - 24,
                  top: janela.top + 10 + (janela.height - 20) * _linha.value,
                  child: Container(
                    height: 2.5,
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [BoxShadow(color: Colors.redAccent.withAlpha(150), blurRadius: 8)],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: janela.bottom + 18,
                left: 24,
                right: 24,
                child: const Text(
                  'Posicione o código de barras dentro da área de leitura',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton.filled(
                        style: IconButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: Colors.white),
                        tooltip: 'Fechar',
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      Text(_modoVenda ? 'Leitura para venda' : 'Ler código de barras',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                      const Spacer(),
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: _lanterna ? Colors.amber : Colors.black54,
                          foregroundColor: _lanterna ? Colors.black : Colors.white,
                        ),
                        tooltip: _lanterna ? 'Desligar lanterna' : 'Ligar lanterna',
                        icon: Icon(_lanterna ? Icons.flash_on : Icons.flash_off),
                        onPressed: _alternarLanterna,
                      ),
                    ],
                  ),
                ),
              ),
              if (_modoVenda)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _PainelVenda(
                        produto: _ultimoProduto,
                        aviso: _aviso,
                        noCarrinho: _ultimoProduto == null ? 0 : cart.quantidadeNoCarrinho(_ultimoProduto!.id!),
                        unidades: cart.totalUnidades,
                        total: cart.total,
                        onConcluir: () => Navigator.pop(context),
                      ),
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

class _PainelVenda extends StatelessWidget {
  const _PainelVenda({
    required this.produto,
    required this.aviso,
    required this.noCarrinho,
    required this.unidades,
    required this.total,
    required this.onConcluir,
  });

  final Produto? produto;
  final String? aviso;
  final int noCarrinho;
  final int unidades;
  final double total;
  final VoidCallback onConcluir;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (aviso != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.warning, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.black87),
                const SizedBox(width: 8),
                Expanded(child: Text(aviso!, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600))),
              ],
            ),
          ),
        if (produto != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                ProductImage(path: produto!.imagem, size: 54),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(produto!.nome,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      Text(Fmt.money(produto!.precoVenda),
                          style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700)),
                      Text('Disponível: ${produto!.quantidade} · No carrinho: $noCarrinho',
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle, color: AppColors.success),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$unidades unidade(s) no carrinho', style: TextStyle(color: cs.onSurfaceVariant)),
                    Text(Fmt.money(total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: onConcluir,
                icon: const Icon(Icons.shopping_cart_checkout),
                label: const Text('Concluir'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErroCamara extends StatelessWidget {
  const _ErroCamara({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final semPermissao = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.no_photography_outlined, color: Colors.white70, size: 56),
          const SizedBox(height: 16),
          Text(
            semPermissao
                ? 'Sem permissão para usar a câmara. Autorize o acesso nas definições do telemóvel.'
                : 'Não foi possível iniciar a câmara.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          const SizedBox(height: 16),
          if (semPermissao)
            FilledButton(onPressed: openAppSettings, child: const Text('Abrir definições')),
        ],
      ),
    );
  }
}

/// Escurece o ecrã e deixa uma janela de leitura com cantos destacados.
class _MascaraPainter extends CustomPainter {
  _MascaraPainter(this.janela);

  final Rect janela;

  @override
  void paint(Canvas canvas, Size size) {
    final fundo = Path()..addRect(Offset.zero & size);
    final buraco = Path()..addRRect(RRect.fromRectAndRadius(janela, const Radius.circular(18)));
    canvas.drawPath(
      Path.combine(PathOperation.difference, fundo, buraco),
      Paint()..color = Colors.black.withAlpha(150),
    );

    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const l = 30.0;
    final r = janela;
    // cantos
    canvas.drawLine(r.topLeft + const Offset(0, l), r.topLeft, p);
    canvas.drawLine(r.topLeft, r.topLeft + const Offset(l, 0), p);
    canvas.drawLine(r.topRight - const Offset(l, 0), r.topRight, p);
    canvas.drawLine(r.topRight, r.topRight + const Offset(0, l), p);
    canvas.drawLine(r.bottomLeft - const Offset(0, l), r.bottomLeft, p);
    canvas.drawLine(r.bottomLeft, r.bottomLeft + const Offset(l, 0), p);
    canvas.drawLine(r.bottomRight - const Offset(l, 0), r.bottomRight, p);
    canvas.drawLine(r.bottomRight, r.bottomRight - const Offset(0, l), p);
  }

  @override
  bool shouldRepaint(covariant _MascaraPainter old) => old.janela != janela;
}

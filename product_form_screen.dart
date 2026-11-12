import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../models/categoria.dart';
import '../../../models/produto.dart';
import '../../../providers/product_provider.dart';
import '../../../services/config_service.dart';
import '../../../services/produto_service.dart';
import '../../barcode_scanner/screens/barcode_scanner_screen.dart';

/// Cadastro e edição de produtos. Ao guardar, devolve o [Produto] gravado.
class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.produto, this.codigoInicial});

  final Produto? produto;
  final String? codigoInicial;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _nome;
  late final TextEditingController _descricao;
  late final TextEditingController _compra;
  late final TextEditingController _venda;
  late final TextEditingController _quantidade;
  late final TextEditingController _minimo;
  late final TextEditingController _codigo;
  int? _categoriaId;
  String? _imagem;
  bool _saving = false;

  bool get _editar => widget.produto != null;

  @override
  void initState() {
    super.initState();
    final p = widget.produto;
    _nome = TextEditingController(text: p?.nome ?? '');
    _descricao = TextEditingController(text: p?.descricao ?? '');
    _compra = TextEditingController(text: p == null ? '' : p.precoCompra.toStringAsFixed(2));
    _venda = TextEditingController(text: p == null ? '' : p.precoVenda.toStringAsFixed(2));
    _quantidade = TextEditingController(text: p == null ? '0' : '${p.quantidade}');
    _minimo = TextEditingController(text: p == null ? '5' : '${p.stockMinimo}');
    _codigo = TextEditingController(text: p?.codigoBarras ?? widget.codigoInicial ?? '');
    _categoriaId = p?.categoriaId;
    _imagem = p?.imagem;
  }

  @override
  void dispose() {
    for (final c in [_nome, _descricao, _compra, _venda, _quantidade, _minimo, _codigo]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _lerCodigo() async {
    final codigo = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen(mode: ScannerMode.single)),
    );
    if (codigo != null) setState(() => _codigo.text = codigo);
  }

  Future<void> _escolherImagem() async {
    final origem = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tirar fotografia'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Escolher da galeria'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            if (_imagem != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remover fotografia'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _imagem = null);
                },
              ),
          ],
        ),
      ),
    );
    if (origem == null) return;
    try {
      final f = await ImagePicker().pickImage(source: origem, maxWidth: 1024, imageQuality: 80);
      if (f == null) return;
      final guardado = await ConfigService.guardarImagem(f.path, 'produto');
      if (mounted) setState(() => _imagem = guardado);
    } catch (e) {
      if (mounted) showSnack(context, 'Não foi possível obter a imagem.', error: true);
    }
  }

  Future<void> _novaCategoria() async {
    final ctrl = TextEditingController();
    final nome = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova categoria'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Nome da categoria'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Guardar')),
        ],
      ),
    );
    ctrl.dispose();
    if (nome == null || nome.trim().isEmpty || !mounted) return;
    try {
      final id = await context.read<ProductProvider>().salvarCategoria(Categoria(nome: nome));
      if (mounted) setState(() => _categoriaId = id);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _guardar() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final provider = context.read<ProductProvider>();
    try {
      final antigo = widget.produto;
      final produto = Produto(
        id: antigo?.id,
        nome: _nome.text.trim(),
        descricao: _descricao.text.trim().isEmpty ? null : _descricao.text.trim(),
        categoriaId: _categoriaId,
        precoCompra: Fmt.parseMoney(_compra.text) ?? 0,
        precoVenda: Fmt.parseMoney(_venda.text) ?? 0,
        quantidade: int.parse(_quantidade.text.trim()),
        stockMinimo: int.parse(_minimo.text.trim()),
        codigoBarras: _codigo.text.trim().isEmpty ? null : _codigo.text.trim(),
        imagem: _imagem,
        dataCadastro: antigo?.dataCadastro ?? DateTime.now(),
      );
      final id = await provider.salvar(produto);
      final gravado = await ProdutoService().porId(id);
      if (!mounted) return;
      showSnack(context, _editar ? 'Produto actualizado.' : 'Produto guardado.');
      Navigator.pop(context, gravado);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showSnack(context, errorMessage(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categorias = context.watch<ProductProvider>().categorias;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(_editar ? 'Editar produto' : 'Novo produto')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            Center(
              child: GestureDetector(
                onTap: _escolherImagem,
                child: Stack(
                  children: [
                    ProductImage(path: _imagem, size: 112, radius: 20),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: cs.primary,
                        child: Icon(Icons.photo_camera, size: 16, color: cs.onPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nome,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nome do produto *'),
              validator: (v) => Validators.required(v, 'Indique o nome do produto'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descricao,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Descrição'),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    value: categorias.any((c) => c.id == _categoriaId) ? _categoriaId : null,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Sem categoria')),
                      for (final c in categorias) DropdownMenuItem<int?>(value: c.id, child: Text(c.nome)),
                    ],
                    onChanged: (v) => setState(() => _categoriaId = v),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Nova categoria',
                  onPressed: _novaCategoria,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _compra,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Preço de compra *', suffixText: 'MZN'),
                    validator: Validators.money,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _venda,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Preço de venda *', suffixText: 'MZN'),
                    validator: Validators.money,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _quantidade,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: _editar ? 'Quantidade em stock' : 'Quantidade inicial',
                    ),
                    validator: (v) => Validators.integer(v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _minimo,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Stock mínimo'),
                    validator: (v) => Validators.integer(v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _codigo,
              decoration: InputDecoration(
                labelText: 'Código de barras',
                suffixIcon: IconButton(
                  tooltip: 'Ler com a câmara',
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: _lerCodigo,
                ),
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _saving ? null : _guardar,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check),
              label: Text(_editar ? 'Guardar alterações' : 'Guardar produto'),
            ),
          ],
        ),
      ),
    );
  }
}

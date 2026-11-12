import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../providers/app_data.dart';
import '../../../providers/config_provider.dart';
import '../../../providers/product_provider.dart';
import '../../../services/config_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _nome;
  late final TextEditingController _end;
  late final TextEditingController _tel;
  late final TextEditingController _rodape;
  String? _logo;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = context.read<ConfigProvider>().config;
    _nome = TextEditingController(text: c.nomeEstabelecimento);
    _end = TextEditingController(text: c.endereco ?? '');
    _tel = TextEditingController(text: c.telefone ?? '');
    _rodape = TextEditingController(text: c.rodapeRecibo ?? '');
    _logo = c.logotipo;
  }

  @override
  void dispose() {
    for (final c in [_nome, _end, _tel, _rodape]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _escolherLogo() async {
    try {
      final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 600, imageQuality: 85);
      if (f == null) return;
      final guardado = await ConfigService.guardarImagem(f.path, 'logotipo');
      if (mounted) setState(() => _logo = guardado);
    } catch (_) {
      if (mounted) showSnack(context, 'Não foi possível obter a imagem.', error: true);
    }
  }

  Future<void> _guardar() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final cfg = context.read<ConfigProvider>();
    try {
      await cfg.salvar(cfg.config.copyWith(
        nomeEstabelecimento: _nome.text.trim(),
        logotipo: _logo,
        endereco: _end.text.trim(),
        telefone: _tel.text.trim(),
        rodapeRecibo: _rodape.text.trim(),
      ));
      if (mounted) showSnack(context, 'Configurações guardadas.');
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _criarBackup() async {
    try {
      final f = await BackupService().criar();
      if (!mounted) return;
      showSnack(context, 'Cópia criada: ${p.basename(f.path)}');
      await Share.shareXFiles([XFile(f.path)], subject: 'Cópia de segurança - ${AppConstants.appName}');
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _restaurar() async {
    final backups = await BackupService().listar();
    if (!mounted) return;
    if (backups.isEmpty) {
      showSnack(context, 'Ainda não existem cópias de segurança neste telemóvel.', error: true);
      return;
    }
    final escolhido = await showModalBottomSheet<File>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Escolha a cópia a restaurar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            for (final f in backups)
              ListTile(
                leading: const Icon(Icons.backup_outlined),
                title: Text(p.basename(f.path)),
                subtitle: Text('${(f.lengthSync() / 1024).toStringAsFixed(0)} KB'),
                onTap: () => Navigator.pop(ctx, f),
              ),
          ],
        ),
      ),
    );
    if (escolhido == null || !mounted) return;
    final ok = await confirmDialog(
      context,
      title: 'Restaurar cópia',
      message: 'Todos os dados actuais serão substituídos pelos desta cópia. Continuar?',
      confirmLabel: 'Restaurar',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final bus = context.read<AppData>();
    final cfg = context.read<ConfigProvider>();
    try {
      await BackupService().restaurar(escolhido);
      await cfg.load();
      bus.bump();
      if (mounted) showSnack(context, 'Cópia restaurada com sucesso.');
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _repor(bool demo) async {
    final ok = await confirmDialog(
      context,
      title: demo ? 'Recarregar dados de demonstração' : 'Apagar todos os dados',
      message: demo
          ? 'Os dados actuais serão apagados e substituídos por dados de demonstração. Continuar?'
          : 'Todos os produtos, vendas, clientes e despesas serão apagados. Esta acção não pode ser desfeita. Continuar?',
      confirmLabel: demo ? 'Recarregar' : 'Apagar tudo',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final bus = context.read<AppData>();
    try {
      final db = DatabaseHelper.instance;
      if (demo) {
        await db.recarregarDemonstracao();
      } else {
        await db.limparTudo();
      }
      await context.read<ProductProvider>().load();
      bus.bump();
      if (mounted) showSnack(context, demo ? 'Dados de demonstração carregados.' : 'Dados apagados.');
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = context.watch<ConfigProvider>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Form(
            key: _form,
            child: Column(
              children: [
                GestureDetector(
                  onTap: _escolherLogo,
                  child: Stack(
                    children: [
                      _logo != null && File(_logo!).existsSync()
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.file(File(_logo!), width: 96, height: 96, fit: BoxFit.cover))
                          : Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(20)),
                              child: Icon(Icons.add_photo_alternate_outlined, color: cs.primary, size: 36),
                            ),
                      if (_logo != null)
                        Positioned(
                          right: -4,
                          top: -4,
                          child: IconButton.filled(
                            visualDensity: VisualDensity.compact,
                            style: IconButton.styleFrom(backgroundColor: AppColors.error),
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () => setState(() => _logo = null),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text('Logotipo (aparece nos recibos)', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nome,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nome do estabelecimento *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Indique o nome do estabelecimento' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _end,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Endereço'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _tel,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Contacto'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _rodape,
                  decoration: const InputDecoration(labelText: 'Mensagem no fim do recibo'),
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: const InputDecoration(labelText: 'Moeda padrão'),
                  child: Text('Metical (${cfg.config.moeda})'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _guardar,
                    icon: const Icon(Icons.check),
                    label: const Text('Guardar configurações'),
                  ),
                ),
              ],
            ),
          ),
          const SectionTitle('Aparência'),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'system', label: Text('Sistema'), icon: Icon(Icons.brightness_auto)),
              ButtonSegment(value: 'light', label: Text('Claro'), icon: Icon(Icons.light_mode_outlined)),
              ButtonSegment(value: 'dark', label: Text('Escuro'), icon: Icon(Icons.dark_mode_outlined)),
            ],
            selected: {cfg.config.tema},
            onSelectionChanged: (s) => cfg.setTema(s.first),
          ),
          const SectionTitle('Cópias de segurança'),
          AppCard(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.backup_outlined, color: cs.primary),
                  title: const Text('Criar cópia de segurança'),
                  subtitle: const Text('Guarda e permite partilhar uma cópia dos dados'),
                  onTap: _criarBackup,
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.restore, color: cs.primary),
                  title: const Text('Restaurar cópia'),
                  subtitle: const Text('Substitui os dados actuais por uma cópia'),
                  onTap: _restaurar,
                ),
              ],
            ),
          ),
          const SectionTitle('Dados'),
          AppCard(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.science_outlined, color: cs.primary),
                  title: const Text('Recarregar dados de demonstração'),
                  onTap: () => _repor(true),
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.delete_forever_outlined, color: AppColors.error),
                  title: const Text('Apagar todos os dados', style: TextStyle(color: AppColors.error)),
                  subtitle: const Text('Começar do zero com a loja vazia'),
                  onTap: () => _repor(false),
                ),
              ],
            ),
          ),
          const SectionTitle('Informações da aplicação'),
          AppCard(
            child: Column(
              children: [
                _info('Aplicação', AppConstants.appName),
                _info('Versão', AppConstants.appVersion),
                _info('Moeda', 'Metical (MZN)'),
                _info('Armazenamento', 'SQLite (offline)'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _info(String a, String b) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(a), Text(b, style: const TextStyle(fontWeight: FontWeight.w600))],
        ),
      );
}

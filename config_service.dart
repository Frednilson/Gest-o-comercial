import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../core/utils/app_exception.dart';
import '../core/utils/formatters.dart';
import '../models/configuracao.dart';

class ConfigService {
  final _helper = DatabaseHelper.instance;

  Future<Configuracao> obter() async {
    final db = await _helper.database;
    final rows = await db.query('configuracoes', where: 'id = 1', limit: 1);
    return rows.isEmpty ? const Configuracao() : Configuracao.fromMap(rows.first);
  }

  Future<void> guardar(Configuracao c) async {
    if (c.nomeEstabelecimento.trim().isEmpty) {
      throw AppException('O nome do estabelecimento é obrigatório.');
    }
    final db = await _helper.database;
    await db.insert('configuracoes', c.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Copia uma imagem escolhida para a pasta da aplicação (para persistir).
  static Future<String> guardarImagem(String origem, String prefixo) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'imagens'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final ext = p.extension(origem).isEmpty ? '.jpg' : p.extension(origem);
    final destino = p.join(dir.path, '${prefixo}_${DateTime.now().millisecondsSinceEpoch}$ext');
    await File(origem).copy(destino);
    return destino;
  }
}

/// Cópias de segurança da base de dados.
class BackupService {
  final _helper = DatabaseHelper.instance;

  Future<Directory> _pasta() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'backups'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> criar() async {
    final origem = File(await _helper.path);
    if (!await origem.exists()) throw AppException('Base de dados não encontrada.');
    final destino = p.join((await _pasta()).path, 'backup_${Fmt.fileStamp(DateTime.now())}.db');
    return origem.copy(destino);
  }

  /// Cópias existentes, da mais recente para a mais antiga.
  Future<List<File>> listar() async {
    final dir = await _pasta();
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.db')).toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  Future<void> restaurar(File backup) async {
    if (!await backup.exists()) throw AppException('Ficheiro de cópia não encontrado.');
    final destino = await _helper.path;
    await _helper.close();
    await backup.copy(destino);
    await _helper.database; // reabre a base de dados restaurada
  }
}

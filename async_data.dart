import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_data.dart';
import '../utils/app_exception.dart';

/// Carrega dados de forma assíncrona e recarrega automaticamente sempre que
/// os dados da aplicação mudam (venda registada, produto editado, etc.).
class AsyncData<T> extends StatefulWidget {
  const AsyncData({super.key, required this.loader, required this.builder});

  final Future<T> Function() loader;
  final Widget Function(BuildContext context, T data) builder;

  @override
  State<AsyncData<T>> createState() => _AsyncDataState<T>();
}

class _AsyncDataState<T> extends State<AsyncData<T>> {
  Future<T>? _future;
  int? _version;

  @override
  Widget build(BuildContext context) {
    final version = context.watch<AppData>().version;
    if (_future == null || _version != version) {
      _version = version;
      _future = widget.loader();
    }
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasData) return widget.builder(context, snapshot.data as T);
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(errorMessage(snapshot.error!), textAlign: TextAlign.center),
            ),
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}

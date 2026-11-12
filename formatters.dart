import 'package:intl/intl.dart';

/// Formatação de valores monetários, datas e conversões.
class Fmt {
  Fmt._();

  static final NumberFormat _money = NumberFormat('#,##0.00', 'pt_PT');
  static final DateFormat _date = DateFormat('dd/MM/yyyy');
  static final DateFormat _dateTime = DateFormat('dd/MM/yyyy HH:mm');
  static final DateFormat _isoDate = DateFormat('yyyy-MM-dd');
  static final DateFormat _fileStamp = DateFormat('yyyyMMdd_HHmmss');

  static String money(num value) => '${_money.format(value)} MZN';

  static String number(num value) => _money.format(value);

  static String date(DateTime d) => _date.format(d);

  static String dateTime(DateTime d) => _dateTime.format(d);

  /// 'yyyy-MM-dd' (usado nas consultas SQL).
  static String isoDate(DateTime d) => _isoDate.format(d);

  static String fileStamp(DateTime d) => _fileStamp.format(d);

  static String shortWeekday(DateTime d) {
    const dias = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    return dias[d.weekday - 1];
  }

  /// Aceita vírgula ou ponto decimal. Devolve null se inválido.
  static double? parseMoney(String? text) {
    if (text == null) return null;
    final cleaned = text.trim().replaceAll(' ', '').replaceAll(',', '.');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  static String periodLabel(DateTime from, DateTime to) {
    if (isoDate(from) == isoDate(to)) return date(from);
    return '${date(from)} - ${date(to)}';
  }
}

import 'package:intl/intl.dart';

abstract final class Formatters {
  static final _integer = NumberFormat.decimalPattern('pt_BR');
  static final _decimal = NumberFormat.decimalPatternDigits(
    locale: 'pt_BR',
    decimalDigits: 1,
  );
  static final _currency = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 2,
  );

  static String integer(num value) => _integer.format(value);
  static String decimal(num value) => _decimal.format(value);
  static String currency(num value) => _currency.format(value);
  static String percent(num value, {int decimals = 1}) =>
      '${value.toStringAsFixed(decimals).replaceAll('.', ',')}%';
}

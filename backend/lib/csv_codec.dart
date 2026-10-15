String csvEncode(
  List<Map<String, dynamic>> rows, {
  List<String>? columns,
  bool spreadsheetSafe = true,
}) {
  final fields =
      columns ??
      (rows.isEmpty ? <String>[] : rows.expand((r) => r.keys).toSet().toList()
        ..sort());
  String cell(Object? value) {
    var text = value?.toString() ?? '';
    if (spreadsheetSafe &&
        value is String &&
        RegExp(r'^\s*[=+@-]').hasMatch(text)) {
      text = "'$text";
    }
    return '"${text.replaceAll('"', '""')}"';
  }

  return '${[fields.map(cell).join(','), ...rows.map((r) => fields.map((f) => cell(r[f])).join(','))].join('\r\n')}\r\n';
}

List<List<String>> csvDecode(String input) {
  final result = <List<String>>[];
  var row = <String>[];
  var cell = StringBuffer();
  var quoted = false;
  input = input.replaceFirst('\uFEFF', '');
  for (var i = 0; i < input.length; i++) {
    final char = input[i];
    if (char == '"') {
      if (quoted && i + 1 < input.length && input[i + 1] == '"') {
        cell.write('"');
        i++;
      } else {
        quoted = !quoted;
      }
    } else if (char == ',' && !quoted) {
      row.add(cell.toString());
      cell = StringBuffer();
    } else if ((char == '\r' || char == '\n') && !quoted) {
      if (char == '\r' && i + 1 < input.length && input[i + 1] == '\n') i++;
      row.add(cell.toString());
      if (row.any((s) => s.isNotEmpty)) result.add(row);
      row = [];
      cell = StringBuffer();
    } else {
      cell.write(char);
    }
  }
  if (quoted) throw const FormatException('CSV contém aspas não fechadas.');
  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    result.add(row);
  }
  return result;
}

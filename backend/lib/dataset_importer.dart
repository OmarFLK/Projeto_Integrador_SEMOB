import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:html/parser.dart';
import 'csv_codec.dart';
import 'document_store.dart';
import 'errors.dart';

// Field mapping is also the public normalized CSV contract. "#" marks numbers.
const schemas = <String, Map<String, String>>{
  'operation_days': {
    'date': 'data',
    'weekday': 'diasem',
    'vehicles': '#nrveiculos',
    'max_vehicles_in_range': '#nrmaxveicfx',
    'scheduled_trips': '#nrviagensprogr',
    'completed_trips': '#nrviagensrealiz',
    'productive_km': '#kmprod',
    'unproductive_km': '#kmimprod',
    'total_km': '#kmtotal',
  },
  'fleet_compliance_days': {
    'date': 'data',
    'morning_planned': '#manhap',
    'morning_completed': '#manhar',
    'afternoon_planned': '#tardep',
    'afternoon_completed': '#tarder',
    'evening_planned': '#noitep',
    'evening_completed': '#noiter',
    'scheduled_trips': '#programadas',
    'completed_trips': '#realizadas',
  },
  'line_days': {
    'date': 'data',
    'line': 'linha',
    'total_km': '#kmtotal',
    'trips': '#nrviagens',
  },
  'time_range_line_stats': {
    'date': 'data',
    'line': 'linha',
    'time_range': 'fxhor',
    'vehicles': '#nrveiculos',
    'trips': '#nrviagens',
    'departures': 'partidas',
  },
  'time_range_summaries': {
    'date': 'data',
    'time_range': 'fxhor',
    'vehicles': '#nrveiculos',
    'trips': '#nrviagens',
  },
  'trips': {
    'date': 'data',
    'line': 'linha',
    'prefix': 'prefixo',
    'activity': 'atividade',
    'direction': 'sentido',
    'time_range': 'fxhor',
    'started_at': 'iniciorealizado',
    'finished_at': 'fimrealizado',
    'productive_km': '#kmprod',
    'unproductive_km': '#kmimprod',
    'total_km': '#kmtotal',
  },
  'anomalies': {
    'date': 'data',
    'line': 'linha',
    'service': 'atendimento',
    'prefix': 'prefixo',
    'activity': 'atividade',
    'driver': 'motorista',
    'direction': 'sentido',
    'schedule_code': 'tabela',
    'departure_status': 'statussaida',
    'arrival_status': 'statuschegada',
    'scheduled_start': 'inicioprogramado',
    'actual_start': 'iniciorealizado',
    'scheduled_end': 'fimprogramado',
    'actual_end': 'fimrealizado',
    'productive_km': '#kmprod',
  },
  'passenger_days': {
    'date': '',
    'turnstile': '#catraca',
    'advance_sales': '#antecipados',
    'non_paying': '#naopagantes',
    'total': '#totalpassageiros',
  },
  'credit_balances': {
    'date': '',
    'series': 'serie',
    'transferred_credits': '#creditostransferidosparacartoes',
    'final_balance': '#saldofinal',
  },
  'financial_flows': {
    'date': '',
    'total_sales': '#totalvendas',
    'total_usage': '#totalutilizacao',
    'circulating_credit': '#creditocirculante',
  },
};

class ParsedDataset {
  ParsedDataset(this.rows, this.rawFiles, this.warnings);
  final List<Document> rows;
  final Map<String, String> rawFiles;
  final List<String> warnings;
}

class DatasetImporter {
  DatasetImporter(this.store);
  final DocumentStore store;
  bool _busy = false;

  ParsedDataset parseArchive(List<int> bytes) {
    if (bytes.length > 25 * 1024 * 1024) {
      throw const ApiError(413, 'ZIP excede 25 MB.');
    }
    // Inspect metadata before ZipDecoder can decode symbolic-link contents.
    final directory = ZipDirectory()..read(InputMemoryStream(bytes));
    var totalSize = 0;
    if (directory.fileHeaders.length > 1000) {
      throw const ApiError(400, 'ZIP acima do limite de entradas.');
    }
    for (final header in directory.fileHeaders) {
      final file = header.file!;
      final path = file.filename.replaceAll('\\', '/');
      final type = (header.externalFileAttributes >> 16) & 0xf000;
      if (type == 0xa000 ||
          path.startsWith('/') ||
          path.contains(':') ||
          path.split('/').contains('..')) {
        throw const ApiError(400, 'ZIP contém link ou caminho não permitido.');
      }
      totalSize += file.uncompressedSize;
      if (file.uncompressedSize < 0 || totalSize > 200 * 1024 * 1024) {
        throw const ApiError(
          400,
          'ZIP acima do limite descompactado (200 MB).',
        );
      }
    }
    final archive = ZipDecoder().decodeBytes(bytes);
    final files =
        archive.files
            .where((f) => f.isFile && f.name.toLowerCase().endsWith('.html'))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    if (files.isEmpty ||
        files.length > 300 ||
        files.fold<int>(0, (s, f) => s + f.size) > 200 * 1024 * 1024) {
      throw const ApiError(
        400,
        'ZIP vazio ou acima do limite descompactado (200 MB/300 HTML).',
      );
    }
    final rows = <Document>[];
    final rawFiles = <String, String>{};
    final warnings = <String>[];
    for (final file in files) {
      final path = file.name.replaceAll('\\', '/');
      final period = _sourcePeriod(path);
      if (period == null) {
        throw ApiError(400, 'Pasta sem período reconhecido: $path');
      }
      final scope = path.toLowerCase().contains('/mensal/')
          ? 'monthly'
          : 'fortnightly';
      final content = file.content as List<int>;
      // ZipDecoder.verify is not implemented by the current archive package.
      if (content.length != file.size || getCrc32(content) != file.crc32) {
        throw const ApiError(400, 'Integridade do ZIP inválida.');
      }
      final sourceHash = sha256.convert(content).toString();
      String html;
      try {
        html = utf8.decode(content);
      } on FormatException {
        html = latin1.decode(content);
      }
      var count = 0;
      var index = 0;
      for (final table in parse(html).querySelectorAll('table.data')) {
        final headers = table
            .querySelectorAll('th')
            .map((e) => e.text.replaceAll(RegExp(r'\s+'), ' ').trim())
            .toList();
        if (headers.isEmpty) continue;
        final keys = headers.map(_key).toList();
        final dataset = _identify(keys);
        final raw = <Document>[];
        for (final tr in table.querySelectorAll('tr')) {
          final cells = tr
              .querySelectorAll('td')
              .map((e) => e.text.replaceAll(RegExp(r'\s+'), ' ').trim())
              .toList();
          if (cells.length != headers.length) continue;
          raw.add({
            for (var i = 0; i < headers.length; i++) headers[i]: cells[i],
          });
          if (dataset == null) continue;
          final values = {
            for (var i = 0; i < keys.length; i++) keys[i]: cells[i],
          };
          final date = values.containsKey('data')
              ? _date(values['data']!)
              : _monthDay(values['mes'], values['dia']);
          if (date == null) {
            final candidate = values['data'] ?? values['dia'] ?? '';
            if (RegExp(r'^\d').hasMatch(candidate)) {
              throw ApiError(400, 'Data inválida em $path: $candidate');
            }
            continue; // Footer and totals, not facts.
          }
          final row = <String, dynamic>{
            'date': date,
            'period': date.substring(0, 7),
            'table': dataset,
            'source': path,
            'sourcePeriod': period,
            'scope': scope,
            'sourceHash': sourceHash,
          };
          for (final field in schemas[dataset]!.entries) {
            if (field.key == 'date') continue;
            final numeric = field.value.startsWith('#');
            final sourceKey = numeric ? field.value.substring(1) : field.value;
            final value = values[sourceKey];
            if (numeric && (value == null || value.isEmpty)) {
              if (!['credit_balances', 'financial_flows'].contains(dataset)) {
                throw ApiError(
                  400,
                  'Valor obrigatório ausente: $sourceKey em $path ($date).',
                );
              }
              row[field.key] = null;
              if (warnings.length < 100) {
                warnings.add(
                  'Valor ausente preservado: $sourceKey em $path ($date).',
                );
              }
            } else {
              row[field.key] = numeric ? _number(value!) : value ?? '';
            }
          }
          if (dataset == 'anomalies') {
            final name = path.toLowerCase();
            row['kind'] = name.contains('nrealiz')
                ? 'notCompleted'
                : name.contains('ninic')
                ? 'notStarted'
                : 'notFinished';
          }
          validateRecord(dataset, row);
          row['key'] = recordKey(dataset, row);
          rows.add(row);
          count++;
        }
        if (raw.isNotEmpty) {
          rawFiles['${path.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_')}_${index++}.csv'] =
              csvEncode(raw, columns: headers, spreadsheetSafe: false);
        }
        if (dataset == null && !keys.contains('smartdatasourcecombr')) {
          warnings.add(
            'Tabela auxiliar preservada em CSV: $path (${headers.join(', ')}).',
          );
        }
      }
      rows.add({
        'table': 'source_files',
        'key': recordKey('source_files', {'path': path}),
        'path': path,
        'period': period,
        'scope': scope,
        'source': path,
        'sourcePeriod': period,
        'sourceHash': sourceHash,
        'row_count': count,
      });
    }
    if (!rows.any((r) => r['table'] == 'trips') &&
        rows.every((r) => r['table'] == 'source_files')) {
      throw const ApiError(400, 'Nenhuma tabela de dados reconhecida.');
    }
    return ParsedDataset(rows, rawFiles, warnings);
  }

  ParsedDataset parseCsv(String text, String dataset, String filename) {
    final schema = schemas[dataset];
    if (schema == null) throw const ApiError(400, 'Tipo de CSV inválido.');
    final csv = csvDecode(text);
    if (csv.length < 2 || csv.length > 150001) {
      throw const ApiError(
        400,
        'CSV deve conter cabeçalho e até 150 mil registros.',
      );
    }
    final headers = csv.first;
    final required = [...schema.keys, if (dataset == 'anomalies') 'kind'];
    if (!required.every(headers.contains)) {
      throw ApiError(400, 'Colunas obrigatórias: ${required.join(', ')}');
    }
    final rows = <Document>[];
    final sourceHash = sha256.convert(utf8.encode(text)).toString();
    for (final values in csv.skip(1)) {
      if (values.length != headers.length) {
        throw const ApiError(
          400,
          'Linha CSV com número de colunas diferente do cabeçalho.',
        );
      }
      final raw = {
        for (var i = 0; i < headers.length; i++) headers[i]: values[i],
      };
      final date = _isoDate(raw['date']!);
      if (date == null) {
        throw const ApiError(400, 'CSV exige data válida AAAA-MM-DD.');
      }
      final row = <String, dynamic>{
        'table': dataset,
        'date': date,
        'period': date.substring(0, 7),
        'source': filename,
        'sourcePeriod': date.substring(0, 7),
        'scope': 'uploaded',
        'sourceHash': sourceHash,
      };
      for (final field in schema.entries) {
        if (field.key == 'date') continue;
        if (field.value.startsWith('#')) {
          if (raw[field.key]!.isEmpty &&
              ['credit_balances', 'financial_flows'].contains(dataset)) {
            row[field.key] = null;
            continue;
          }
          final number = num.tryParse(raw[field.key]!);
          if (number == null || !number.isFinite) {
            throw ApiError(
              400,
              'Valor inválido em ${field.key}. Use ponto decimal sem separador de milhar.',
            );
          }
          row[field.key] = number;
        } else {
          row[field.key] = raw[field.key];
        }
      }
      if (dataset == 'anomalies') {
        if (![
          'notCompleted',
          'notStarted',
          'notFinished',
        ].contains(raw['kind'])) {
          throw const ApiError(400, 'Status de exceção inválido.');
        }
        row['kind'] = raw['kind'];
      }
      validateRecord(dataset, row);
      row['key'] = recordKey(dataset, row);
      rows.add(row);
    }
    final sourcePath = 'csv/$filename/$sourceHash';
    rows.add({
      'table': 'source_files',
      'key': recordKey('source_files', {'path': sourcePath}),
      'path': sourcePath,
      'source': filename,
      'period': rows.first['period'],
      'sourcePeriod': rows.first['period'],
      'scope': 'uploaded',
      'sourceHash': sourceHash,
      'row_count': rows.length,
    });
    return ParsedDataset(rows, {filename: text}, []);
  }

  Future<Document> import(
    ParsedDataset parsed, {
    String? exportDirectory,
    String actor = 'cli',
  }) async {
    if (_busy) {
      throw const ApiError(409, 'Uma importação já está em andamento.');
    }
    _busy = true;
    try {
      final previous = await store.generation();
      final merged = <String, Document>{};
      for (final table in dataTables) {
        for (final row in await store.read(previous, table)) {
          merged['$table:${row['key']}'] = row;
        }
      }
      var conflicts = 0;
      for (final file in parsed.rawFiles.entries) {
        final fileBytes = utf8.encode(file.value);
        final digest = sha256.convert(fileBytes).toString();
        for (var index = 0; index < fileBytes.length; index += 200000) {
          final part = index ~/ 200000;
          final key = sha256
              .convert(utf8.encode('${file.key}:$digest:$part'))
              .toString();
          merged['source_chunks:$key'] = {
            'table': 'source_chunks',
            'key': key,
            'file': file.key,
            'sha256': digest,
            'part': part,
            'parts': (fileBytes.length / 200000).ceil(),
            'encoding': 'base64',
            'content': base64Encode(
              fileBytes.sublist(
                index,
                (index + 200000).clamp(0, fileBytes.length),
              ),
            ),
            'period': _sourcePeriod(file.key) ?? parsed.rows.first['period'],
          };
        }
      }
      for (final candidate in parsed.rows) {
        final key = '${candidate['table']}:${candidate['key']}';
        final old = merged[key];
        if (old == null || _rank(candidate) >= _rank(old)) {
          if (old != null && old['sourceHash'] != candidate['sourceHash']) {
            conflicts++;
          }
          merged[key] = candidate;
        }
      }
      final generation = DateTime.now()
          .toUtc()
          .microsecondsSinceEpoch
          .toString();
      final counts = <String, int>{};
      for (final row in merged.values) {
        counts.update(row['table'] as String, (n) => n + 1, ifAbsent: () => 1);
      }
      final manifest = <String, dynamic>{
        'periods':
            merged.values
                .map((r) => r['period'])
                .whereType<String>()
                .toSet()
                .toList()
              ..sort(),
        'importedAt': DateTime.now().toUtc().toIso8601String(),
        'actor': actor,
        'counts': counts,
        'inputRows': parsed.rows.length,
        'reconciledOverlaps': conflicts,
        'warnings': parsed.warnings,
      };
      await store.publish(
        previous,
        generation,
        merged.values
            .map((r) => Map<String, dynamic>.from(r)..remove('generation'))
            .toList(),
        manifest,
      );
      if (exportDirectory != null) {
        final rawDirectory = Directory('$exportDirectory/raw');
        await rawDirectory.create(recursive: true);
        for (final file in parsed.rawFiles.entries) {
          await File(
            '${rawDirectory.path}/${file.key.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_')}',
          ).writeAsString(file.value, encoding: utf8);
        }
        for (final table in dataTables) {
          if (table == 'source_chunks') continue;
          final records = merged.values
              .where((r) => r['table'] == table)
              .map((r) => Map<String, dynamic>.from(r)..remove('generation'))
              .toList();
          await File('$exportDirectory/$table.csv').writeAsString(
            csvEncode(records, spreadsheetSafe: false),
            encoding: utf8,
          );
        }
        await File('$exportDirectory/manifest.json').writeAsString(
          const JsonEncoder.withIndent(
            '  ',
          ).convert({...manifest, 'generation': generation}),
          encoding: utf8,
        );
      }
      return {...manifest, 'generation': generation};
    } finally {
      _busy = false;
    }
  }
}

int _rank(Document row) =>
    (row['sourcePeriod'] == row['period'] ? 100 : 0) +
    switch (row['scope']) {
      'uploaded' => 50,
      'monthly' => 20,
      _ => 10,
    };
String _key(String s) {
  const from = 'áàãâéêíóõôúç';
  const to = 'aaaaeeiooouc';
  s = s.toLowerCase();
  for (var i = 0; i < from.length; i++) {
    s = s.replaceAll(from[i], to[i]);
  }
  return s.replaceAll(RegExp('[^a-z0-9]'), '');
}

String? _identify(List<String> k) {
  if (k.contains('nrviagensprogr')) return 'operation_days';
  if (k.contains('manhap')) return 'fleet_compliance_days';
  if (k.contains('partidas')) return 'time_range_line_stats';
  if (k.contains('fxhor') && k.contains('nrveiculos') && !k.contains('linha')) {
    return 'time_range_summaries';
  }
  if (k.contains('linha') && k.contains('nrviagens') && k.length == 4) {
    return 'line_days';
  }
  if (k.contains('atendimento') && k.contains('statussaida')) {
    return 'anomalies';
  }
  if (k.contains('prefixo') && k.contains('kmtotal')) return 'trips';
  if (k.contains('catraca')) return 'passenger_days';
  if (k.contains('creditostransferidosparacartoes')) return 'credit_balances';
  if (k.contains('totalvendas')) return 'financial_flows';
  return null;
}

String? _sourcePeriod(String path) {
  const months = [
    'janeiro',
    'fevereiro',
    'marco',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];
  final match = RegExp(
    r'(janeiro|fevereiro|marco|abril|maio|junho|julho|agosto|setembro|outubro|novembro|dezembro)_(\d{4})(?:/|_)',
  ).firstMatch(path.toLowerCase().replaceAll('março', 'marco'));
  if (match == null) return null;
  final month = months.indexOf(match[1]!) + 1;
  if (month == 0) return null;
  return '${match[2]}-${month.toString().padLeft(2, '0')}';
}

String? _isoDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
  final d = DateTime.tryParse(value);
  return d != null && d.toIso8601String().startsWith(value) ? value : null;
}

String? _date(String s) {
  final p = s.split('/');
  if (p.length != 3) return null;
  return _isoDate('${p[2]}-${p[1]}-${p[0]}');
}

String? _monthDay(String? month, String? day) => month == null || day == null
    ? null
    : _isoDate('$month-${day.padLeft(2, '0')}');
num _number(String s) {
  final value = num.tryParse(s.replaceAll('.', '').replaceAll(',', '.'));
  if (value == null || !value.isFinite) {
    throw ApiError(400, 'Número inválido: $s');
  }
  return value;
}

void validateRecord(String table, Document row) {
  const integers = {
    'vehicles',
    'max_vehicles_in_range',
    'scheduled_trips',
    'completed_trips',
    'morning_planned',
    'morning_completed',
    'afternoon_planned',
    'afternoon_completed',
    'evening_planned',
    'evening_completed',
    'trips',
    'turnstile',
    'advance_sales',
    'non_paying',
    'total',
  };
  for (final field in schemas[table]!.entries.where(
    (e) => e.value.startsWith('#'),
  )) {
    final value = row[field.key];
    if (value == null &&
        ['credit_balances', 'financial_flows'].contains(table)) {
      continue;
    }
    if (value is! num || !value.isFinite || value.abs() > 1e12) {
      throw ApiError(400, 'Valor inválido em ${field.key}.');
    }
    if (integers.contains(field.key)) {
      if (value < 0 || value != value.roundToDouble()) {
        throw ApiError(400, '${field.key} exige inteiro não negativo.');
      }
      row[field.key] = value.toInt();
    }
    if (field.key.endsWith('_km') && value < 0) {
      throw const ApiError(400, 'Quilometragem negativa.');
    }
    if ([
      'transferred_credits',
      'final_balance',
      'total_sales',
      'total_usage',
      'circulating_credit',
    ].contains(field.key)) {
      row['${field.key}_cents'] = (value * 100).round();
    }
  }
  if (table == 'passenger_days' &&
      row['total'] !=
          (row['turnstile'] as num) +
              (row['advance_sales'] as num) +
              (row['non_paying'] as num)) {
    throw const ApiError(
      400,
      'Total de passageiros difere da soma das categorias.',
    );
  }
}

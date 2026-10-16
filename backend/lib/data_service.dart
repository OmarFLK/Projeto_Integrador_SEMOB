import 'document_store.dart';
import 'errors.dart';

class DataService {
  DataService(this.store);
  final DocumentStore store;
  final Map<String, Future<List<Document>>> _cache = {};
  final Map<String, Future<Document>> _optionsCache = {};
  Future<List<Document>> table(
    String name,
    String? period, {
    String? generation,
  }) async {
    final gen = generation ?? await store.generation();
    final key = '$gen:$name:$period';
    if (_cache.length > 80) _cache.clear();
    try {
      return await _cache.putIfAbsent(
        key,
        () => store.read(gen, name, period: period),
      );
    } catch (_) {
      _cache.remove(key);
      rethrow;
    }
  }

  Future<List<Document>> periods() async {
    final known = (await store.manifest())['periods'];
    if (known is List) {
      final values = known.cast<String>().toList()
        ..sort((a, b) => b.compareTo(a));
      return [
        for (final p in values) {'value': p, 'label': periodLabel(p)},
      ];
    }
    final gen = await store.generation();
    final rows = await table('operation_days', null, generation: gen);
    final periods = rows.map((r) => r['period'] as String).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    return [
      for (final period in periods)
        {'value': period, 'label': periodLabel(period)},
    ];
  }

  Future<String> period(Map<String, String> query) async {
    final value =
        query['period'] ?? (await periods()).firstOrNull?['value'] as String?;
    if (value == null) throw const ApiError(404, 'Nenhum período importado.');
    if (!RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(value)) {
      throw const ApiError(400, 'Período inválido. Use AAAA-MM.');
    }
    return value;
  }

  Future<List<Document>> resource(
    String name,
    Map<String, String> query,
  ) async {
    final p = await period(query);
    final gen = await store.generation();
    Future<List<Document>> read(String tableName) =>
        table(tableName, p, generation: gen);
    List<Document> filter(List<Document> rows, {bool dimensions = false}) =>
        rows.where((r) {
          final date = r['date'] as String? ?? '';
          if (query['from'] != null && date.compareTo(query['from']!) < 0 ||
              query['to'] != null && date.compareTo(query['to']!) > 0) {
            return false;
          }
          if (dimensions) {
            for (final pair in {
              'line': 'line',
              'vehicle': 'prefix',
              'direction': 'direction',
              'timeRange': 'time_range',
            }.entries) {
              final value = query[pair.key];
              if (value != null && value.isNotEmpty && r[pair.value] != value) {
                return false;
              }
            }
          }
          return true;
        }).toList()..sort(
          (a, b) => (a['date'] as String? ?? '').compareTo(
            b['date'] as String? ?? '',
          ),
        );
    if (name == 'operation') {
      return filter(await read('operation_days'))
          .map(
            (r) => {
              'date': r['date'],
              'day': day(r),
              'weekday': r['weekday'],
              'vehicles': r['vehicles'],
              'maxVehiclesInRange': r['max_vehicles_in_range'],
              'scheduledTrips': r['scheduled_trips'],
              'completedTrips': r['completed_trips'],
              'productiveKm': r['productive_km'],
              'unproductiveKm': r['unproductive_km'],
              'totalKm': r['total_km'],
            },
          )
          .toList();
    }
    if (name == 'passengers') {
      return filter(await read('passenger_days'))
          .map(
            (r) => {
              'date': r['date'],
              'day': day(r),
              'turnstile': r['turnstile'],
              'advance': r['advance_sales'],
              'nonPaying': r['non_paying'],
              'total': r['total'],
            },
          )
          .toList();
    }
    if (name == 'financial') {
      final balances = filter(await read('credit_balances'));
      final byDate = <String, Document>{};
      for (final row in balances) {
        final date = row['date'] as String;
        final daily = byDate.putIfAbsent(
          date,
          () => {
            'date': date,
            'day': day(row),
            'transferredCredits': 0.0,
            'finalBalance': 0.0,
            'creditsCents': 0,
            'balanceCents': 0,
            'series': 0,
            'incomplete': false,
          },
        );
        daily['creditsCents'] =
            (daily['creditsCents'] as int) +
            ((row['transferred_credits_cents'] as int?) ??
                (((row['transferred_credits'] as num?) ?? 0) * 100).round());
        daily['balanceCents'] =
            (daily['balanceCents'] as int) +
            ((row['final_balance_cents'] as int?) ??
                (((row['final_balance'] as num?) ?? 0) * 100).round());
        daily['transferredCredits'] = (daily['creditsCents'] as int) / 100;
        daily['finalBalance'] = (daily['balanceCents'] as int) / 100;
        daily['incomplete'] =
            daily['incomplete'] == true ||
            row['transferred_credits'] == null ||
            row['final_balance'] == null;
        daily['series'] = (daily['series'] as int) + 1;
      }
      return byDate.values.toList()
        ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    }
    if (name == 'anomalies') {
      return filter(await read('anomalies'), dimensions: true)
          .map(
            (r) => {
              'id': r['key'],
              'level': r['kind'] == 'notCompleted' ? 'critical' : 'attention',
              'date': r['date'],
              'line': r['line'],
              'vehicle': r['prefix'],
              'direction': r['direction'],
              'description':
                  '${statusLabel(r['kind'] as String)}: ${r['activity']}',
              'metric': statusLabel(r['kind'] as String),
              'status': r['kind'],
              'source': r['source'],
            },
          )
          .toList();
    }
    if (name == 'trips') {
      final records = filter(await read('trips'), dimensions: true)
          .map(
            (r) => {
              'id': r['key'],
              'date': r['date'],
              'line': r['line'],
              'vehicle': r['prefix'],
              'activity': r['activity'],
              'direction': r['direction'],
              'timeRange': r['time_range'],
              'start': r['started_at'],
              'end': r['finished_at'],
              'productiveKm': r['productive_km'],
              'unproductiveKm': r['unproductive_km'],
              'status': _recordStatus(r),
              'source': r['source'],
            },
          )
          .toList();
      final exceptions = (await read(
        'anomalies',
      )).map((r) => {...r, 'time_range': _hour(r['scheduled_start'])}).toList();
      for (final r in filter(exceptions, dimensions: true)) {
        final exception = <String, dynamic>{
          'id': r['key'],
          'date': r['date'],
          'line': r['line'],
          'vehicle': r['prefix'] ?? '',
          'activity': r['activity'],
          'direction': r['direction'],
          'timeRange': r['time_range'] ?? '',
          'start': r['actual_start'],
          'end': r['actual_end'],
          'productiveKm': r['productive_km'],
          'unproductiveKm': 0,
          'status': r['kind'],
          'source': r['source'],
        };
        final duplicate = records.any(
          (row) => [
            'date',
            'line',
            'vehicle',
            'direction',
            'start',
            'end',
            'status',
          ].every((key) => row[key] == exception[key]),
        );
        if (!duplicate) records.add(exception);
      }
      final search = (query['search'] ?? '').toLowerCase();
      final status = query['status'];
      return records
          .where(
            (r) =>
                (status == null || r['status'] == status) &&
                (search.isEmpty ||
                    ['line', 'vehicle', 'activity'].any(
                      (k) => r[k].toString().toLowerCase().contains(search),
                    )),
          )
          .toList()
        ..sort((a, b) {
          final result = '${a['date']}:${a['start']}:${a['id']}'.compareTo(
            '${b['date']}:${b['start']}:${b['id']}',
          );
          return query['order'] == 'desc' ? -result : result;
        });
    }
    if (name == 'lines') {
      final rows = filter(
        await read('line_days'),
      ).where((r) => query['line'] == null || r['line'] == query['line']);
      final grouped = <String, Document>{};
      for (final r in rows) {
        final entry = grouped.putIfAbsent(
          r['line'] as String,
          () => {'code': r['line'], 'trips': 0, 'totalKm': 0.0},
        );
        entry['trips'] = (entry['trips'] as num) + (r['trips'] as num);
        entry['totalKm'] = (entry['totalKm'] as num) + (r['total_km'] as num);
      }
      final total = grouped.values.fold<num>(
        0,
        (s, r) => s + (r['trips'] as num),
      );
      for (final r in grouped.values) {
        r['performance'] = total == 0 ? 0 : (r['trips'] as num) / total * 100;
      }
      return grouped.values.toList()
        ..sort((a, b) => (a['code'] as String).compareTo(b['code'] as String));
    }
    if (name == 'line-history') {
      return filter(await read('line_days'))
          .where((r) => query['line'] == null || r['line'] == query['line'])
          .map(
            (r) => {
              'date': r['date'],
              'line': r['line'],
              'trips': r['trips'],
              'totalKm': r['total_km'],
            },
          )
          .toList();
    }
    if (name == 'vehicles') {
      final rows = filter(await read('trips'), dimensions: true);
      final grouped = <String, Document>{};
      for (final r in rows) {
        final prefix = r['prefix'] as String;
        if (prefix.isEmpty) continue;
        final entry = grouped.putIfAbsent(
          prefix,
          () => {
            'prefix': prefix,
            'lines': <String>[],
            'trips': 0,
            'totalKm': 0.0,
            'firstRecord': r['date'],
            'lastRecord': r['date'],
            'status': 'Registrado no período',
          },
        );
        final lines = entry['lines'] as List<String>;
        if (!lines.contains(r['line'])) lines.add(r['line'] as String);
        entry['trips'] = (entry['trips'] as int) + 1;
        entry['totalKm'] = (entry['totalKm'] as num) + (r['total_km'] as num);
        entry['lastRecord'] = r['date'];
      }
      for (final r in grouped.values) {
        (r['lines'] as List<String>).sort();
      }
      return grouped.values.toList()..sort(
        (a, b) => (a['prefix'] as String).compareTo(b['prefix'] as String),
      );
    }
    throw const ApiError(404, 'Recurso não encontrado.');
  }

  Future<Document> page(Map<String, String> query) async {
    final rows = await resource('trips', query);
    final limit = integer(query['limit'], 50, 1, 500);
    final offset = integer(query['offset'], 0, 0, 100000000);
    return {
      'items': rows.skip(offset).take(limit).toList(),
      'total': rows.length,
      'limit': limit,
      'offset': offset,
    };
  }

  Future<Document> coverage(Map<String, String> query) async {
    final p = await period(query);
    final result = <String, dynamic>{
      'period': p,
      'domains': <String, dynamic>{},
    };
    for (final entry in {
      'operation': 'operation_days',
      'passengers': 'passenger_days',
      'financial': 'credit_balances',
    }.entries) {
      final records = await table(entry.value, p);
      final dates = records.map((r) => r['date'] as String).toSet().toList()
        ..sort();
      final parts = p.split('-');
      final expected = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]) + 1,
        0,
      ).day;
      (result['domains'] as Document)[entry.key] = {
        'days': dates.length,
        'expectedDays': expected,
        'from': dates.firstOrNull,
        'to': dates.lastOrNull,
        'complete': dates.length == expected,
        'missingDays': expected - dates.length,
      };
    }
    return result;
  }

  Future<Document> options(Map<String, String> query) async {
    final p = await period(query);
    final gen = await store.generation();
    final key = '$gen:$p';
    if (_optionsCache.length > 12) _optionsCache.clear();
    try {
      return await _optionsCache.putIfAbsent(key, () async {
        var dimensions = await store.filterOptions(gen, p);
        if (dimensions == null) {
          final records = await table('trips', p, generation: gen);
          List<String> values(String field) =>
              records
                  .map((r) => r[field]?.toString() ?? '')
                  .where((s) => s.isNotEmpty)
                  .toSet()
                  .toList()
                ..sort();
          dimensions = {
            'lines': values('line'),
            'vehicles': values('prefix'),
            'directions': values('direction'),
            'timeRanges': values('time_range'),
          };
        }
        return {
          'periods': await periods(),
          ...dimensions,
          'datasets': dataTables
              .where((s) => !['source_files', 'source_chunks'].contains(s))
              .toList(),
        };
      });
    } catch (_) {
      _optionsCache.remove(key);
      rethrow;
    }
  }

  Future<List<Document>> insights(Map<String, String> query) async {
    final p = await period(query);
    final ops = await resource('operation', query);
    final lines = await resource('lines', query);
    final passengers = await resource('passengers', query);
    final cov = await coverage(query);
    final domains = cov['domains'] as Document;
    final scheduled = ops.fold<num>(
      0,
      (s, r) => s + (r['scheduledTrips'] as num),
    );
    final completed = ops.fold<num>(
      0,
      (s, r) => s + (r['completedTrips'] as num),
    );
    final ranking = [...lines]
      ..sort((a, b) => (b['trips'] as num).compareTo(a['trips'] as num));
    return [
      {
        'title': 'Cumprimento da programação',
        'description':
            '${completed.toInt()} de ${scheduled.toInt()} viagens no período $p.',
        'metric': scheduled == 0
            ? 'Sem dados'
            : '${(completed / scheduled * 100).toStringAsFixed(2)}%',
        'kind': 'neutral',
      },
      if (scheduled > completed)
        {
          'title': 'Diferença operacional',
          'description':
              'Investigue as exceções e a diferença entre programação e realização.',
          'metric': '${(scheduled - completed).toInt()} viagens',
          'kind': 'danger',
        },
      if (ranking.isNotEmpty)
        {
          'title': 'Linha com maior volume',
          'description':
              'Linha ${ranking.first['code']} lidera os registros consolidados. Isso não mede cumprimento por linha.',
          'metric': '${ranking.first['trips']} viagens',
          'kind': 'good',
        },
      {
        'title': 'Cobertura de passageiros',
        'description':
            '${(domains['passengers'] as Document)['days']} dias registrados; comparações mensais exigem cobertura equivalente. Dados provisórios.',
        'metric':
            '${passengers.fold<num>(0, (s, r) => s + (r['total'] as num)).toInt()} passageiros',
        'kind': (domains['passengers'] as Document)['complete'] == true
            ? 'neutral'
            : 'warning',
      },
    ];
  }

  Future<Document> assistantContext(Map<String, String> query) async => {
    'period': await period(query),
    'filters': query,
    'coverage': await coverage(query),
    'insights': await insights(query),
    'sources': (await table(
      'source_files',
      await period(query),
    )).map((r) => r['path']).toList(),
  };
}

String _hour(Object? value) {
  final match = RegExp(r'(\d{2}):(\d{2})').firstMatch('$value');
  return match == null ? '' : int.parse(match[1]!).toString();
}

String _recordStatus(Document r) {
  final start = _hour(r['started_at']).isNotEmpty;
  final end = _hour(r['finished_at']).isNotEmpty;
  return !start && !end
      ? 'notCompleted'
      : !start
      ? 'notStarted'
      : !end
      ? 'notFinished'
      : 'completed';
}

int day(Document r) => int.parse((r['date'] as String).substring(8));
int integer(String? value, int fallback, int minimum, int maximum) {
  final parsed = value == null ? fallback : int.tryParse(value);
  if (parsed == null || parsed < minimum || parsed > maximum) {
    throw ApiError(400, 'Valor deve estar entre $minimum e $maximum.');
  }
  return parsed;
}

String periodLabel(String period) {
  const months = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];
  final p = period.split('-');
  return '${months[int.parse(p[1]) - 1]} de ${p[0]}';
}

String statusLabel(String status) => switch (status) {
  'notStarted' => 'Não iniciada',
  'notFinished' => 'Não terminada',
  'notCompleted' => 'Não realizada',
  _ => 'Realizada',
};

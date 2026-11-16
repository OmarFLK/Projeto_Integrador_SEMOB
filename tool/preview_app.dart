import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:semob_dashboard/app.dart';
import 'package:semob_dashboard/services/api_client.dart';

const previewEmail = 'demo@semob.local';
const previewPassword = 'SemobDemo2026!';

/// This entry point is never imported by lib/main.dart. The HTTP adapter below
/// serves every request in memory and has no fallback to a network adapter.
Widget createPreviewApp({PreviewAdapter? adapter}) {
  final memory = adapter ?? PreviewAdapter();
  final dio = Dio(BaseOptions(baseUrl: 'http://semob-preview.invalid/api/v1/'));
  final client = ApiClient(http: dio);
  // ApiClient installs a browser adapter on web: replace it afterwards, too.
  dio.httpClientAdapter = memory;
  return ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(client)],
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        children: [
          Material(
            color: const Color(0xFFCBEA65),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              child: Row(
                children: [
                  const Icon(
                    Icons.science_outlined,
                    size: 17,
                    color: Color(0xFF0F1F17),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'DEMONSTRAÇÃO LOCAL · Dados fictícios · Sem banco ou API · Alterações são apagadas ao recarregar.',
                      style: TextStyle(
                        color: Color(0xFF0F1F17),
                        fontFamily: 'NotoSans',
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Expanded(child: SemobApp()),
        ],
      ),
    ),
  );
}

class PreviewAdapter implements HttpClientAdapter {
  bool signedIn = false;
  final preferences = <String, dynamic>{
    'theme': 'dark',
    'compact': false,
    'sidebarPinned': false,
    'reduceMotion': false,
    'chatTextSize': 'normal',
    'chatAssistant': 'last',
    'chatStreaming': false,
    'chatShowTimestamps': false,
    'chatDateFormat': 'dd/MM/yyyy',
    'aiPreset': 'balanced',
    'aiTemperature': .25,
    'aiMaxTokens': 1200,
    'aiReasoning': false,
    'aiResponseMode': 'balanced',
    'aiDepth': 'normal',
    'aiUseContext': true,
  };
  final user = <String, dynamic>{
    'id': 'preview-admin',
    'name': 'Administrador de demonstração',
    'email': previewEmail,
    'identifier': 'demo',
    'jobTitle': 'Usuário de teste',
    'department': 'Ambiente de demonstração',
    'accessLevel': 'administrator',
    'active': true,
    'createdAt': '2026-08-01T12:00:00Z',
    'lastAccess': '2026-08-31T12:00:00Z',
    'permissions': [
      'read',
      'financial',
      'export',
      'assistant',
      'import',
      'users',
    ],
  };
  final datasets = <String, _PreviewData>{};

  ResponseBody json(Object value, [int status = 200]) =>
      ResponseBody.fromString(
        jsonEncode(value),
        status,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path.replaceFirst('/api/v1/', '');
    final body = options.data is Map ? options.data as Map : const {};
    if (path == 'auth/login' && options.method == 'POST') {
      if (![previewEmail, 'demo'].contains(body['identifier']) ||
          body['password'] != previewPassword) {
        return json({
          'message': 'Credenciais inválidas. Use o usuário de demonstração.',
        }, 401);
      }
      signedIn = true;
      return json({'token': 'local-preview-only', 'user': user});
    }
    if (path == 'auth/logout') {
      signedIn = false;
      return json({'ok': true});
    }
    if (path == 'auth/password-recovery/modes') {
      return json({'manual': false, 'automatic': false});
    }
    if (!signedIn) {
      return json({'message': 'Entre com o usuário de demonstração.'}, 401);
    }
    if (path == 'preferences') {
      if (options.method == 'PUT') {
        preferences.addAll(Map<String, dynamic>.from(body));
      }
      return json(preferences);
    }
    if (path == 'auth/profile' && options.method == 'PATCH') {
      for (final key in ['name', 'jobTitle', 'department']) {
        if (body[key] is String) user[key] = body[key];
      }
      return json(user);
    }
    if (options.method != 'GET' ||
        path.startsWith('exports/') ||
        path.startsWith('templates/') ||
        path.startsWith('normalized/')) {
      return json({
        'message':
            'Esta ação não é executada na demonstração local. Nenhum dado foi enviado ou alterado em um servidor.',
      }, 501);
    }
    final q = options.uri.queryParameters;
    final period = const ['2026-07', '2026-08', '2026-09'].contains(q['period'])
        ? q['period']!
        : '2026-08';
    final data = datasets.putIfAbsent(period, () => _PreviewData(period));
    final filtered = data.trips
        .where(
          (r) =>
              ['line', 'vehicle', 'direction', 'timeRange', 'status'].every(
                (key) => q[key] == null || q[key]!.isEmpty || r[key] == q[key],
              ) &&
              ['line', 'vehicle', 'activity'].any(
                (key) => r[key].toString().toLowerCase().contains(
                  (q['search'] ?? '').toLowerCase(),
                ),
              ),
        )
        .toList();
    final lines = const ['01', '02', '03', '04', '05', '06', '07', '08'];
    final vehicles = [for (var i = 0; i < 18; i++) '${1501 + i}'];
    switch (path) {
      case 'auth/me':
        return json(user);
      case 'auth/sessions':
        return json({'active': 1});
      case 'users':
        return json([
          user,
          {
            ...user,
            'id': 'preview-operator',
            'name': 'Operador de demonstração',
            'email': 'operador@example.org',
            'identifier': 'operador',
            'accessLevel': 'operator',
            'permissions': ['read'],
          },
        ]);
      case 'options':
        return json({
          'periods': [
            {'value': '2026-08', 'label': 'Agosto de 2026'},
            {'value': '2026-07', 'label': 'Julho de 2026'},
            {'value': '2026-09', 'label': 'Setembro de 2026'},
          ],
          'lines': lines,
          'vehicles': vehicles,
          'directions': ['Ida', 'Volta'],
          'timeRanges': ['Manhã', 'Tarde', 'Noite'],
          'datasets': ['operation_days', 'passenger_days', 'trips'],
        });
      case 'operation':
        return json(data.operation);
      case 'passengers':
        return json(data.passengers);
      case 'financial':
        return json(data.financial);
      case 'coverage':
        return json({
          'domains': {
            for (final domain in ['operation', 'passengers', 'financial'])
              domain: {
                'days': data.operation.length,
                'expectedDays': data.operation.length,
                'complete': true,
              },
          },
        });
      case 'trips':
        if (q['order'] == 'desc') {
          filtered.sort(
            (a, b) => '${b['date']}:${b['start']}'.compareTo(
              '${a['date']}:${a['start']}',
            ),
          );
        }
        final offset = (int.tryParse(q['offset'] ?? '') ?? 0).clamp(
          0,
          filtered.length,
        );
        final limit = (int.tryParse(q['limit'] ?? '') ?? 50).clamp(1, 100);
        return json({
          'items': filtered.skip(offset).take(limit).toList(),
          'total': filtered.length,
          'offset': offset,
          'limit': limit,
        });
      case 'lines':
        return json([
          for (final code in lines)
            if (q['line'] == null || q['line'] == code)
              {
                'code': code,
                'trips': data.trips.where((r) => r['line'] == code).length,
                'totalKm': _km(data.trips.where((r) => r['line'] == code)),
                'performance':
                    data.trips.where((r) => r['line'] == code).length /
                    data.trips.length *
                    100,
              },
        ]);
      case 'vehicles':
        return json([
          for (final prefix in vehicles)
            if (filtered.any((r) => r['vehicle'] == prefix))
              {
                'prefix': prefix,
                'lines': filtered
                    .where((r) => r['vehicle'] == prefix)
                    .map((r) => r['line'])
                    .toSet()
                    .toList(),
                'trips': filtered.where((r) => r['vehicle'] == prefix).length,
                'totalKm': _km(filtered.where((r) => r['vehicle'] == prefix)),
                'firstRecord': filtered.firstWhere(
                  (r) => r['vehicle'] == prefix,
                )['date'],
                'lastRecord': filtered.lastWhere(
                  (r) => r['vehicle'] == prefix,
                )['date'],
                'status': 'Histórico demonstrativo',
              },
        ]);
      case 'line-history':
        return json([
          for (final day in data.operation)
            {
              'date': day['date'],
              'trips': filtered.where((r) => r['date'] == day['date']).length,
              'totalKm': _km(filtered.where((r) => r['date'] == day['date'])),
            },
        ]);
      case 'anomalies':
        return json([
          for (final trip in filtered)
            if (trip['status'] != 'completed')
              {
                'date': trip['date'],
                'line': trip['line'],
                'vehicle': trip['vehicle'],
                'description': 'Ocorrência fictícia para demonstração',
                'level': 'attention',
                'metric': switch (trip['status']) {
                  'notStarted' => 'Não iniciada',
                  'notFinished' => 'Não terminada',
                  _ => 'Não realizada',
                },
              },
        ]);
      case 'insights':
        return json([
          {
            'title': 'Ambiente de demonstração',
            'metric': 'Dados sintéticos',
            'description':
                'Os indicadores deste ambiente foram gerados em memória apenas para explorar a interface. Não são dados oficiais da SEMOB.',
            'kind': 'information',
          },
          {
            'title': 'Viagens de teste',
            'metric': '${data.trips.length} registros',
            'description':
                'Use os filtros de linha, prefixo e status para experimentar a consulta e a paginação.',
            'kind': 'information',
          },
        ]);
      case 'assistant/status':
        return json({'configured': false});
      case 'meta':
        return json({
          'counts': {'trips': data.trips.length, 'source_files': 0},
          'importedAt': 'Demonstração local · sem importação real',
        });
      case 'access-requests':
        return json({
          'items': q['status'] == 'pending'
              ? [
                  {
                    'id': 'demo-request-0000000000000001',
                    'declared_name': 'Pessoa fictícia',
                    'identifier': 'pessoa@example.org',
                    'account_name': 'Pessoa fictícia',
                    'account_email': 'pessoa@example.org',
                    'account_active': 1,
                    'status': 'pending',
                    'created_at': '2026-11-16T12:00:00Z',
                    'expires_at': '2026-11-17T12:00:00Z',
                  },
                ]
              : [],
          'notificationConfigured': false,
        });
      default:
        return json({
          'message': 'Recurso indisponível na demonstração local.',
        }, 501);
    }
  }

  @override
  void close({bool force = false}) {}
}

double _km(Iterable<Map<String, dynamic>> trips) => trips.fold<double>(
  0,
  (sum, r) =>
      sum +
      (r['productiveKm'] as num).toDouble() +
      (r['unproductiveKm'] as num).toDouble(),
);

class _PreviewData {
  _PreviewData(String period) {
    final year = int.parse(period.substring(0, 4)),
        month = int.parse(period.substring(5));
    final days = DateTime(year, month + 1, 0).day;
    for (var day = 1; day <= days; day++) {
      final date = '$period-${day.toString().padLeft(2, '0')}';
      for (var i = 0; i < 48; i++) {
        final seed = day * 48 + i;
        trips.add({
          'date': date,
          'line': (i % 8 + 1).toString().padLeft(2, '0'),
          'vehicle': '${1501 + seed % 18}',
          'activity': 'Viagem demonstrativa',
          'direction': i.isEven ? 'Ida' : 'Volta',
          'timeRange': i < 16
              ? 'Manhã'
              : i < 32
              ? 'Tarde'
              : 'Noite',
          'start':
              '${(5 + i ~/ 3).toString().padLeft(2, '0')}:${(i % 3 * 20).toString().padLeft(2, '0')}',
          'end':
              '${(6 + i ~/ 3).toString().padLeft(2, '0')}:${(i % 3 * 20).toString().padLeft(2, '0')}',
          'productiveKm': 9.5 + seed % 12,
          'unproductiveKm': 0.5 + seed % 4 / 10,
          'status': seed % 59 == 0
              ? 'notCompleted'
              : seed % 83 == 0
              ? 'notStarted'
              : seed % 97 == 0
              ? 'notFinished'
              : 'completed',
        });
      }
      final records = trips.where((r) => r['date'] == date).toList();
      operation.add({
        'date': date,
        'day': day,
        'weekday': const [
          'Seg',
          'Ter',
          'Qua',
          'Qui',
          'Sex',
          'Sáb',
          'Dom',
        ][DateTime(year, month, day).weekday - 1],
        'vehicles': 18,
        'maxVehiclesInRange': 12,
        'scheduledTrips': records.length,
        'completedTrips': records
            .where((r) => r['status'] == 'completed')
            .length,
        'productiveKm': records.fold<double>(
          0,
          (sum, r) => sum + (r['productiveKm'] as num),
        ),
        'unproductiveKm': records.fold<double>(
          0,
          (sum, r) => sum + (r['unproductiveKm'] as num),
        ),
      });
      final demand = (2400 + math.sin(day * .55) * 650 + day * 20).round();
      passengers.add({
        'date': date,
        'day': day,
        'turnstile': demand,
        'advance': demand ~/ 4,
        'nonPaying': demand ~/ 3,
      });
      financial.add({
        'date': date,
        'day': day,
        'transferredCredits': 3200.0 + day % 7 * 425,
        'finalBalance': 350000.0 - day * 1800,
        'incomplete': false,
      });
    }
  }
  final operation = <Map<String, dynamic>>[],
      passengers = <Map<String, dynamic>>[],
      financial = <Map<String, dynamic>>[],
      trips = <Map<String, dynamic>>[];
}

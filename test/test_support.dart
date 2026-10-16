import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:semob_dashboard/app.dart';
import 'package:semob_dashboard/features/auth/presentation/auth_controller.dart';
import 'package:semob_dashboard/models/user.dart';
import 'package:semob_dashboard/mocks/mock_operation_data.dart';
import 'package:semob_dashboard/mocks/mock_passenger_financial_data.dart';
import 'package:semob_dashboard/services/api_client.dart';

AppUser testUser({String role = 'administrator'}) => AppUser.fromJson({
  'id': 'test-user',
  'email': 'admin@example.org',
  'name': 'Admin Teste',
  'identifier': 'test',
  'jobTitle': 'Administrador',
  'department': 'SEMOB',
  'accessLevel': role,
  'active': true,
  'permissions': [
    'read',
    if (role != 'operator') ...['financial', 'export', 'assistant'],
    if (role == 'administrator') ...['import', 'users'],
  ],
});

class TestAuthRepository implements AuthRepository {
  TestAuthRepository({this.role = 'administrator'});
  final String role;
  @override
  Future<AppUser?> restore() async => null;
  @override
  Future<AppUser> login(
    String identifier,
    String password,
    bool remember,
  ) async {
    if (password != 'semob2026') throw Exception('Credenciais inválidas');
    return testUser(role: role);
  }

  @override
  Future<void> logout() async {}
}

class TestHttpAdapter implements HttpClientAdapter {
  final preferences = <String, dynamic>{'compact': false, 'theme': 'system'};
  final profile = <String, dynamic>{
    'id': 'test-user',
    'email': 'admin@example.org',
    'name': 'Admin Teste',
    'identifier': 'test',
    'jobTitle': 'Administrador',
    'department': 'SEMOB',
    'accessLevel': 'administrator',
    'active': true,
    'createdAt': '2026-10-01T12:00:00Z',
    'lastAccess': '2026-10-15T20:00:00Z',
    'permissions': [
      'read',
      'financial',
      'export',
      'assistant',
      'import',
      'users',
    ],
  };
  final queries = <String, Map<String, dynamic>>{};
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    final path = options.uri.path.split('/').last;
    if (path == 'preferences' && options.method == 'PUT') {
      preferences.addAll(Map<String, dynamic>.from(options.data as Map));
    }
    if (path == 'profile' && options.method == 'PATCH') {
      profile.addAll(Map<String, dynamic>.from(options.data as Map));
    }
    queries[path] = options.uri.queryParameters;
    final date = '${options.uri.queryParameters['period'] ?? '2026-08'}-01';
    final operation = [
      for (final r in operationDays)
        {
          'date': date,
          'day': r.day,
          'weekday': r.weekday,
          'vehicles': r.vehicles,
          'maxVehiclesInRange': r.maxVehiclesInRange,
          'scheduledTrips': r.scheduledTrips,
          'completedTrips': r.completedTrips,
          'productiveKm': r.productiveKm,
          'unproductiveKm': r.unproductiveKm,
        },
    ];
    final passengers = [
      for (final r in passengerDays)
        {
          'date': date,
          'day': r.day,
          'turnstile': r.turnstile,
          'advance': r.advance,
          'nonPaying': r.nonPaying,
        },
    ];
    final lines = [
      for (final r in lineSummaries)
        {
          'code': r.code,
          'trips': r.trips,
          'totalKm': r.totalKm,
          'performance': r.performance,
        },
    ];
    final vehicles = [
      for (final r in vehicleSummaries)
        {
          'prefix': r.prefix,
          'lines': r.lines,
          'trips': r.trips,
          'totalKm': r.totalKm,
          'firstRecord': date,
          'lastRecord': date,
          'status': 'Registrado no período',
        },
    ];
    final trips = [
      for (final r in tripRecords)
        {
          'date': date,
          'line': r.line,
          'vehicle': r.vehicle,
          'activity': r.activity,
          'direction': r.direction,
          'timeRange': r.timeRange,
          'start': r.start,
          'end': r.end,
          'productiveKm': r.productiveKm,
          'unproductiveKm': r.unproductiveKm,
          'status': r.status.name,
        },
    ];
    final response = switch (path) {
      'options' => {
        'periods': [
          {'value': '2026-08', 'label': 'Agosto de 2026'},
          {'value': '2026-07', 'label': 'Julho de 2026'},
        ],
        'lines': ['01', '02', '03'],
        'vehicles': ['1502', '1769'],
        'directions': ['Ida', 'Volta'],
        'timeRanges': ['04h–05h'],
        'datasets': ['operation_days', 'passenger_days', 'trips'],
      },
      'preferences' => preferences,
      'profile' || 'me' => profile,
      'sessions' => {'active': 2},
      'revoke-others' => {'active': 1},
      'coverage' => {
        'domains': {
          for (final d in ['operation', 'passengers', 'financial'])
            d: {'days': 17, 'expectedDays': 31, 'complete': false},
        },
      },
      'operation' => operation,
      'passengers' => passengers,
      'lines' => lines,
      'vehicles' => vehicles,
      'financial' => [
        for (final r in financialDays)
          {
            'date': date,
            'day': r.day,
            'transferredCredits': r.transferredCredits,
            'finalBalance': r.finalBalance,
          },
      ],
      'anomalies' => [
        for (final r in anomalyRecords)
          {
            'date': date,
            'line': r.line,
            'vehicle': r.vehicle,
            'description': r.description,
            'level': r.level.name,
            'metric': r.metric,
          },
      ],
      'trips' => {
        'items': trips,
        'total': 2101,
        'offset': int.parse(options.uri.queryParameters['offset'] ?? '0'),
        'limit': 50,
      },
      'line-history' => [
        {'date': date, 'trips': 100, 'totalKm': 1000},
      ],
      'insights' => [
        {
          'title': 'Cobertura parcial',
          'description': 'Comparações exigem períodos equivalentes.',
          'metric': '17 dias',
          'kind': 'warning',
        },
      ],
      'meta' => {
        'counts': {'trips': 91108, 'source_files': 44},
        'importedAt': '2026-10-15',
      },
      'users' => [
        {
          'id': 'test-user',
          'email': 'admin@example.org',
          'name': 'Admin Teste',
          'identifier': 'test',
          'jobTitle': 'Admin',
          'department': 'SEMOB',
          'accessLevel': 'administrator',
          'active': true,
        },
      ],
      'status' => {'configured': false},
      _ => <String, dynamic>{},
    };
    return ResponseBody.fromString(
      jsonEncode(response),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ProviderScope testApp({
  TestHttpAdapter? adapter,
  String role = 'administrator',
  AuthRepository? authRepository,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1/'))
    ..httpClientAdapter = adapter ?? TestHttpAdapter();
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(ApiClient(http: dio)),
      authRepositoryProvider.overrideWithValue(
        authRepository ?? TestAuthRepository(role: role),
      ),
    ],
    child: const SemobApp(),
  );
}

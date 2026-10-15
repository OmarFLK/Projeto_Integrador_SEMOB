import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'auth_store.dart';
import 'csv_codec.dart';
import 'data_service.dart';
import 'dataset_importer.dart';
import 'document_store.dart';
import 'errors.dart';

class SemobApi {
  SemobApi(
    this.data,
    this.auth, {
    this.production = false,
    this.allowedOrigins = const [],
    this.aiUrl,
    this.aiKey,
    this.aiRequestField = 'message',
    this.aiResponseField = 'answer',
    this.recoveryWebhook,
    this.recoveryWebhookKey,
    this.exposeRecoveryCode = false,
  });
  final DataService data;
  final AuthStore auth;
  final bool production, exposeRecoveryCode;
  final List<String> allowedOrigins;
  final String? aiUrl, aiKey, recoveryWebhook, recoveryWebhookKey;
  final String aiRequestField, aiResponseField;
  final Map<String, ({int count, DateTime until})> _limits = {};
  late final DatasetImporter importer = DatasetImporter(data.store);
  late final Router router = Router()
    ..get('/health', _health)
    ..get('/ready', _ready)
    ..post('/api/v1/auth/login', _login)
    ..post('/api/v1/auth/logout', _logout)
    ..get('/api/v1/auth/me', _me)
    ..post('/api/v1/auth/password-recovery/request', _requestRecovery)
    ..post('/api/v1/auth/password-recovery/verify', _verifyRecovery)
    ..post('/api/v1/auth/password-recovery/reset', _resetRecovery)
    ..get('/api/v1/users', _users)
    ..post('/api/v1/users', _createUser)
    ..patch('/api/v1/users/<id>', _updateUser)
    ..get('/api/v1/preferences', _preferences)
    ..put('/api/v1/preferences', _savePreferences)
    ..get('/api/v1/audit', _audit)
    ..get('/api/v1/templates/<dataset>', _template)
    ..get('/api/v1/datasets/<dataset>', _dataset)
    ..get('/api/v1/normalized/<dataset>', _normalized)
    ..get('/api/v1/meta', _meta)
    ..get('/api/v1/periods', (Request r) async {
      await _require(r);
      return json(await data.periods());
    })
    ..get('/api/v1/options', (Request r) async {
      await _require(r);
      return json(await data.options(r.url.queryParameters));
    })
    ..get('/api/v1/coverage', (Request r) async {
      await _require(r);
      return json(await data.coverage(r.url.queryParameters));
    })
    ..get('/api/v1/insights', (Request r) async {
      await _require(r);
      return json(await data.insights(r.url.queryParameters));
    })
    ..get('/api/v1/assistant/status', (Request r) async {
      await _require(r, 'assistant');
      return json({'configured': aiUrl != null, 'mode': 'external-api'});
    })
    ..post('/api/v1/assistant', _assistant)
    ..post('/api/v1/imports', _import)
    ..get('/api/v1/exports/<resource>', _export)
    ..get('/api/v1/<resource>', _resource);

  Handler get handler => (request) async {
    final origin = request.headers['origin'];
    final validOrigin =
        origin != null &&
        (allowedOrigins.contains(origin) ||
            !production &&
                [
                  'localhost',
                  '127.0.0.1',
                ].contains(Uri.tryParse(origin)?.host));
    final headers = <String, String>{
      'X-Content-Type-Options': 'nosniff',
      'Cache-Control': 'no-store',
      'Vary': 'Origin',
      if (validOrigin) 'Access-Control-Allow-Origin': origin,
      if (validOrigin) 'Access-Control-Allow-Credentials': 'true',
      if (validOrigin)
        'Access-Control-Allow-Headers':
            'Content-Type, Authorization, X-Requested-With',
      if (validOrigin)
        'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, OPTIONS',
      'Access-Control-Expose-Headers': 'Content-Disposition',
    };
    try {
      if (origin != null && !validOrigin) {
        throw const ApiError(403, 'Origem não autorizada.');
      }
      if (request.method == 'OPTIONS') return Response(204, headers: headers);
      if (!['GET', 'HEAD'].contains(request.method) &&
          request.headers.containsKey('cookie') &&
          request.headers['x-requested-with'] != 'SEMOB') {
        throw const ApiError(403, 'Cabeçalho de segurança ausente.');
      }
      _limit('global:${_ip(request)}', 600, const Duration(minutes: 1));
      final response = await router.call(request);
      return response.change(headers: {...response.headers, ...headers});
    } on ApiError catch (e) {
      return json({
        'message': e.message,
      }, status: e.status).change(headers: headers);
    } on FormatException {
      return json({
        'message': 'Formato de arquivo ou JSON inválido.',
      }, status: 400).change(headers: headers);
    } catch (e) {
      stderr.writeln(
        'request_error ${request.method} ${request.url.path} ${e.runtimeType}',
      );
      return json({
        'message': 'Não foi possível concluir a operação. Tente novamente.',
      }, status: 500).change(headers: headers);
    }
  };
  String? _token(Request r) {
    final header = r.headers['authorization'];
    if (header?.startsWith('Bearer ') == true) return header!.substring(7);
    final cookie = r.headers['cookie'] ?? '';
    for (final part in cookie.split(';')) {
      final pair = part.trim();
      if (pair.startsWith('semob_session=')) return pair.substring(14);
    }
    return null;
  }

  Future<Document> _require(Request r, [String permission = 'read']) async {
    final user = await auth.authenticate(_token(r));
    if (user == null) {
      throw const ApiError(401, 'Sua sessão expirou. Entre novamente.');
    }
    if (!(user['permissions'] as List).contains(permission)) {
      throw const ApiError(403, 'Seu perfil não tem permissão para esta ação.');
    }
    return user;
  }

  Response _health(Request r) => json({'status': 'ok', 'service': 'semob-api'});
  Future<Response> _ready(Request r) async {
    try {
      await auth.db.select('SELECT 1');
      final ready =
          await data.store.ready() &&
          (await data.store.generation()).isNotEmpty;
      return json({
        'status': ready ? 'ok' : 'not-ready',
        'identity': 'postgresql',
        'data': data.store.engine,
        'schemaVersion': 1,
      }, status: ready ? 200 : 503);
    } catch (_) {
      return json({'status': 'not-ready'}, status: 503);
    }
  }

  Future<Response> _login(Request r) async {
    final body = await readBody(r);
    final identifier = text(body, 'identifier').trim();
    if (identifier.length > 250) throw const ApiError(400, 'Acesso inválido.');
    _limit('login:${_ip(r)}', 30, const Duration(minutes: 15));
    _limit(
      'account:${identifier.toLowerCase()}',
      10,
      const Duration(minutes: 15),
    );
    final result = await auth.login(
      identifier,
      text(body, 'password'),
      remember: body['remember'] == true,
    );
    final age = body['remember'] == true ? '; Max-Age=604800' : '';
    return json(result).change(
      headers: {
        'Set-Cookie':
            'semob_session=${result['token']}; HttpOnly; Path=/api/v1/; SameSite=${production ? 'None' : 'Lax'}${production ? '; Secure' : ''}$age',
      },
    );
  }

  Future<Response> _me(Request r) async => json(await _require(r));
  Future<Response> _logout(Request r) async {
    final token = _token(r);
    if (token != null) await auth.logout(token);
    return json({'ok': true}).change(
      headers: {
        'Set-Cookie':
            'semob_session=; HttpOnly; Path=/api/v1/; Max-Age=0; SameSite=${production ? 'None' : 'Lax'}${production ? '; Secure' : ''}',
      },
    );
  }

  Future<Response> _users(Request r) async {
    await _require(r, 'users');
    return json(await auth.listUsers());
  }

  Future<Response> _createUser(Request r) async {
    final actor = await _require(r, 'users');
    return json(
      await auth.createUser(await readBody(r), actor: actor['id'] as String),
      status: 201,
    );
  }

  Future<Response> _updateUser(Request r, String id) async {
    final actor = await _require(r, 'users');
    await auth.updateUser(id, await readBody(r), actor['id'] as String);
    return json(await auth.getUser(id));
  }

  Future<Response> _preferences(Request r) async =>
      json(await auth.preferences((await _require(r))['id'] as String));
  Future<Response> _savePreferences(Request r) async {
    final user = await _require(r);
    await auth.savePreferences(user['id'] as String, await readBody(r));
    return json(await auth.preferences(user['id'] as String));
  }

  Future<Response> _audit(Request r) async {
    await _require(r, 'users');
    return json(await auth.audit());
  }

  Future<Response> _meta(Request r) async {
    await _require(r);
    return json({'engine': data.store.engine, ...await data.store.manifest()});
  }

  Future<Response> _template(Request r, String dataset) async {
    await _require(r, 'import');
    final schema = schemas[dataset];
    if (schema == null) {
      throw const ApiError(404, 'Tipo de CSV não encontrado.');
    }
    return Response.ok(
      utf8.encode(
        '\uFEFF${csvEncode([], columns: [...schema.keys, if (dataset == 'anomalies') 'kind'])}',
      ),
      headers: {
        'Content-Type': 'text/csv; charset=utf-8',
        'Content-Disposition': 'attachment; filename="modelo_$dataset.csv"',
      },
    );
  }

  Future<List<Document>> _datasetRows(Request r, String dataset) async {
    final user = await _require(r, 'export');
    if (!schemas.containsKey(dataset)) {
      throw const ApiError(404, 'Domínio não encontrado.');
    }
    if (['credit_balances', 'financial_flows'].contains(dataset)) {
      await _require(r, 'financial');
    }
    _validateQuery(r.url.queryParameters);
    final p = await data.period(r.url.queryParameters);
    var rows = await data.table(dataset, p);
    rows = rows
        .where((row) {
          final date = row['date'] as String? ?? '';
          final from = r.url.queryParameters['from'],
              to = r.url.queryParameters['to'];
          if (from != null && date.compareTo(from) < 0 ||
              to != null && date.compareTo(to) > 0) {
            return false;
          }
          for (final e in {
            'line': 'line',
            'vehicle': 'prefix',
            'direction': 'direction',
            'timeRange': 'time_range',
          }.entries) {
            final value = r.url.queryParameters[e.key];
            if (value != null && row[e.value] != value) return false;
          }
          return true;
        })
        .map((row) => Map<String, dynamic>.from(row)..remove('generation'))
        .toList();
    rows.sort(
      (a, b) =>
          '${a['date']}:${a['key']}'.compareTo('${b['date']}:${b['key']}'),
    );
    if (!(user['permissions'] as List).contains('users')) {
      for (final row in rows) {
        row.remove('driver');
      }
    }
    return rows;
  }

  Future<Response> _dataset(Request r, String dataset) async {
    final rows = await _datasetRows(r, dataset);
    final limit = integer(r.url.queryParameters['limit'], 50, 1, 500);
    final offset = integer(r.url.queryParameters['offset'], 0, 0, 100000000);
    return json({
      'items': rows.skip(offset).take(limit).toList(),
      'total': rows.length,
      'offset': offset,
      'limit': limit,
    });
  }

  Future<Response> _normalized(Request r, String dataset) async {
    await _require(r, 'import');
    final rows = await _datasetRows(r, dataset);
    return Response.ok(
      utf8.encode(
        '\uFEFF${csvEncode(rows, columns: [...schemas[dataset]!.keys, if (dataset == 'anomalies') 'kind'], spreadsheetSafe: false)}',
      ),
      headers: {
        'Content-Type': 'text/csv; charset=utf-8',
        'Content-Disposition': 'attachment; filename="$dataset.csv"',
      },
    );
  }

  Future<Response> _resource(Request r, String resource) async {
    await _require(r, resource == 'financial' ? 'financial' : 'read');
    _validateQuery(r.url.queryParameters);
    return json(
      resource == 'trips'
          ? await data.page(r.url.queryParameters)
          : await data.resource(resource, r.url.queryParameters),
    );
  }

  Future<Response> _import(Request r) async {
    final user = await _require(r, 'import');
    _limit('import:${user['id']}', 5, const Duration(minutes: 15));
    final body = await readBody(r, maxBytes: 36 * 1024 * 1024);
    final filename = text(body, 'filename');
    if (filename.isEmpty || filename.length > 200) {
      throw const ApiError(400, 'Nome de arquivo inválido.');
    }
    final bytes = base64Decode(text(body, 'content'));
    ParsedDataset parsed;
    if (filename.toLowerCase().endsWith('.zip')) {
      parsed = importer.parseArchive(bytes);
    } else if (filename.toLowerCase().endsWith('.csv')) {
      parsed = importer.parseCsv(
        utf8.decode(bytes),
        text(body, 'dataset'),
        filename,
      );
    } else {
      throw const ApiError(400, 'Selecione ZIP de HTMLs ou CSV normalizado.');
    }
    final result = await importer.import(parsed, actor: user['id'] as String);
    await auth.log(user['id'] as String, 'data.import', {
      'generation': result['generation'],
      'filename': filename,
    });
    return json(result, status: 201);
  }

  Future<Response> _export(Request r, String resource) async {
    final user = await _require(r, 'export');
    if (resource == 'financial') await _require(r, 'financial');
    _validateQuery(r.url.queryParameters);
    final rows = await data.resource(resource, r.url.queryParameters);
    final format = r.url.queryParameters['format'] ?? 'csv';
    final p = await data.period(r.url.queryParameters);
    final filename = 'semob_${resource}_$p.$format';
    await auth.log(user['id'] as String, 'data.export', {
      'resource': resource,
      'period': p,
      'rows': rows.length,
      'format': format,
    });
    if (format == 'csv') {
      return Response.ok(
        utf8.encode('\uFEFF${csvEncode(rows)}'),
        headers: {
          'Content-Type': 'text/csv; charset=utf-8',
          'Content-Disposition': 'attachment; filename="$filename"',
        },
      );
    }
    if (format != 'pdf') {
      throw const ApiError(400, 'Formato deve ser csv ou pdf.');
    }
    if (rows.length > 5000) {
      throw const ApiError(
        413,
        'PDF limitado a 5.000 registros. Refine os filtros ou exporte CSV.',
      );
    }
    final font = pw.Font.ttf(
      ByteData.sublistView(
        await File('assets/fonts/NotoSans-Regular.ttf').readAsBytes(),
      ),
    );
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: font,
        bold: font,
        italic: font,
        boldItalic: font,
      ),
    );
    final columns = rows.isEmpty
        ? <String>[]
        : rows.first.keys.where((k) => !['source', 'id'].contains(k)).toList();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        maxPages: 500,
        build: (_) => [
          pw.Text('SEMOB - $resource - $p'),
          pw.SizedBox(height: 12),
          pw.Text(
            'Registros: ${rows.length}. Filtros: ${r.url.queryParameters}',
          ),
          pw.SizedBox(height: 12),
          if (rows.isEmpty)
            pw.Text('Nenhum registro.')
          else
            pw.TableHelper.fromTextArray(
              headers: columns,
              data: rows
                  .map((row) => columns.map((c) => '${row[c] ?? ''}').toList())
                  .toList(),
              cellStyle: const pw.TextStyle(fontSize: 7),
            ),
        ],
      ),
    );
    return Response.ok(
      await pdf.save(),
      headers: {
        'Content-Type': 'application/pdf',
        'Content-Disposition': 'attachment; filename="$filename"',
      },
    );
  }

  Future<Response> _requestRecovery(Request r) async {
    _limit('recovery:${_ip(r)}', 5, const Duration(minutes: 15));
    final body = await readBody(r);
    final email = text(body, 'email').trim().toLowerCase();
    if (email.length > 250 ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      throw const ApiError(400, 'E-mail inválido.');
    }
    if (email != text(body, 'emailConfirmation').trim().toLowerCase()) {
      throw const ApiError(400, 'Os e-mails precisam ser iguais.');
    }
    if (recoveryWebhook == null && !exposeRecoveryCode) {
      throw const ApiError(
        503,
        'Recuperação indisponível. Entre em contato com a administração.',
      );
    }
    final challenge = await auth.startRecovery(email);
    if (challenge['code'] != null && recoveryWebhook != null) {
      try {
        await _post(recoveryWebhook!, {
          'email': email,
          'code': challenge['code'],
          'expiresInMinutes': 10,
        }, key: recoveryWebhookKey);
      } catch (_) {
        throw const ApiError(
          503,
          'Não foi possível enviar a recuperação. Tente novamente.',
        );
      }
    }
    return json({
      'challengeId': challenge['challengeId'],
      'deliveryHint': 'o e-mail informado, se cadastrado',
      'message': 'Se o e-mail estiver cadastrado, você receberá as instruções.',
      if (exposeRecoveryCode && !production && challenge['code'] != null)
        'developmentCode': challenge['code'],
    });
  }

  Future<Response> _verifyRecovery(Request r) async {
    _limit('verify:${_ip(r)}', 20, const Duration(minutes: 15));
    final body = await readBody(r);
    return json({
      'resetToken': await auth.verifyRecovery(
        text(body, 'challengeId'),
        text(body, 'code'),
      ),
    });
  }

  Future<Response> _resetRecovery(Request r) async {
    _limit('reset:${_ip(r)}', 10, const Duration(minutes: 15));
    final body = await readBody(r);
    await auth.resetPassword(
      text(body, 'challengeId'),
      text(body, 'resetToken'),
      text(body, 'password'),
    );
    return json({'ok': true});
  }

  Future<Response> _assistant(Request r) async {
    final user = await _require(r, 'assistant');
    _limit('assistant:${user['id']}', 20, const Duration(minutes: 15));
    if (aiUrl == null) {
      throw const ApiError(
        503,
        'A conexão com a IA institucional ainda não foi configurada.',
      );
    }
    final body = await readBody(r);
    final message = text(body, 'message');
    if (message.isEmpty || message.length > 4000) {
      throw const ApiError(400, 'Digite uma pergunta de até 4.000 caracteres.');
    }
    final filters = body['filters'];
    if (filters != null && filters is! Map) {
      throw const ApiError(400, 'Filtros inválidos.');
    }
    final query = <String, String>{
      if (filters is Map)
        for (final e in filters.entries)
          if (e.value is String) e.key.toString(): e.value as String,
    };
    _validateQuery(query);
    final context = await data.assistantContext(query);
    try {
      final response = await _post(aiUrl!, {
        aiRequestField: message,
        'context': context,
      }, key: aiKey);
      final answer = response[aiResponseField];
      if (answer is! String || answer.trim().isEmpty) {
        throw const ApiError(502, 'A IA respondeu em formato incompatível.');
      }
      await auth.log(user['id'] as String, 'assistant.request', {
        'period': context['period'],
      });
      return json({
        'answer': answer,
        'context': context,
        'sources': context['sources'],
      });
    } on ApiError {
      rethrow;
    } catch (_) {
      throw const ApiError(
        502,
        'Não foi possível acessar a IA institucional. Tente novamente.',
      );
    }
  }

  void _limit(String key, int maximum, Duration duration) {
    final now = DateTime.now();
    _limits.removeWhere((k, v) => v.until.isBefore(now));
    if (_limits.length > 20000) {
      throw const ApiError(429, 'Serviço ocupado. Tente mais tarde.');
    }
    final entry = _limits[key];
    if (entry != null && entry.count >= maximum) {
      throw const ApiError(
        429,
        'Muitas tentativas. Aguarde e tente novamente.',
      );
    }
    _limits[key] = (
      count: (entry?.count ?? 0) + 1,
      until: entry?.until ?? now.add(duration),
    );
  }
}

Response json(Object? body, {int status = 200}) => Response(
  status,
  body: jsonEncode(body),
  headers: {'Content-Type': 'application/json; charset=utf-8'},
);
String text(Document body, String key) {
  final value = body[key];
  if (value is! String) throw ApiError(400, 'Campo $key inválido.');
  return value;
}

Future<Document> readBody(Request request, {int maxBytes = 65536}) async {
  final bytes = <int>[];
  await for (final chunk in request.read()) {
    if (bytes.length + chunk.length > maxBytes) {
      throw const ApiError(413, 'Requisição muito grande.');
    }
    bytes.addAll(chunk);
  }
  final value = jsonDecode(utf8.decode(bytes));
  if (value is! Map<String, dynamic>) {
    throw const ApiError(400, 'O corpo deve ser um objeto JSON.');
  }
  return value;
}

String _ip(Request r) =>
    (r.context['shelf.io.connection_info'] as HttpConnectionInfo?)
        ?.remoteAddress
        .address ??
    'in-process';
void _validateQuery(Map<String, String> q) {
  for (final field in ['from', 'to']) {
    final value = q[field];
    if (value != null &&
        (value.length != 10 ||
            DateTime.tryParse(value)?.toIso8601String().startsWith(value) !=
                true)) {
      throw const ApiError(400, 'Data inválida. Use AAAA-MM-DD.');
    }
  }
  if (q['from'] != null &&
      q['to'] != null &&
      q['from']!.compareTo(q['to']!) > 0) {
    throw const ApiError(400, 'Intervalo de datas inválido.');
  }
  for (final value in q.values) {
    if (value.length > 200) throw const ApiError(400, 'Filtro muito longo.');
  }
  if (q['status'] != null &&
      ![
        'completed',
        'notCompleted',
        'notStarted',
        'notFinished',
      ].contains(q['status'])) {
    throw const ApiError(400, 'Status inválido.');
  }
}

Future<Document> _post(String url, Document body, {String? key}) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    return await (() async {
      final request = await client.postUrl(Uri.parse(url));
      request.followRedirects = false;
      request.headers.contentType = ContentType.json;
      if (key != null) request.headers.set('Authorization', 'Bearer $key');
      request.write(jsonEncode(body));
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const ApiError(502, 'Serviço externo indisponível.');
      }
      var size = 0;
      final bytes = <int>[];
      await for (final chunk in response) {
        size += chunk.length;
        if (size > 2 * 1024 * 1024) {
          throw const ApiError(502, 'Resposta externa muito grande.');
        }
        bytes.addAll(chunk);
      }
      final value = jsonDecode(utf8.decode(bytes));
      if (value is! Map<String, dynamic>) {
        throw const ApiError(502, 'Resposta externa inválida.');
      }
      return value;
    })().timeout(const Duration(seconds: 45));
  } finally {
    client.close(force: true);
  }
}

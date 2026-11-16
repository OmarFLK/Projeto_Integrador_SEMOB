import 'dart:async';
import 'dart:io';

/// Loopback-only server for the separately compiled, database-free preview.
Future<void> main(List<String> arguments) async {
  final port = arguments.isEmpty ? 8080 : int.parse(arguments.single);
  final root = Directory('.dart_tool/preview-web').absolute;
  if (!File('${root.path}/index.html').existsSync()) {
    stderr.writeln(
      'Execute scripts/run_preview.ps1 para compilar a demonstração.',
    );
    exitCode = 1;
    return;
  }
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  server.autoCompress = true;
  stdout.writeln('SEMOB DEMO release: http://127.0.0.1:$port');
  await for (final request in server) {
    unawaited(serve(request, root));
  }
}

Future<void> serve(HttpRequest request, Directory root) async {
  try {
    if (request.method != 'GET' && request.method != 'HEAD') {
      request.response.statusCode = HttpStatus.methodNotAllowed;
    } else {
      final parts = request.uri.pathSegments
          .where((p) => p.isNotEmpty)
          .toList();
      if (parts.any((p) => p == '..' || p.contains('\\') || p.contains('/'))) {
        request.response.statusCode = HttpStatus.badRequest;
      } else {
        final path = parts.isEmpty ? 'index.html' : parts.join('/');
        final file = File('${root.path}/$path');
        if (!await file.exists()) {
          request.response.statusCode = HttpStatus.notFound;
        } else {
          final extension = path.split('.').last;
          const types = {
            'html': 'text/html; charset=utf-8',
            'js': 'application/javascript; charset=utf-8',
            'json': 'application/json',
            'css': 'text/css',
            'wasm': 'application/wasm',
            'png': 'image/png',
            'jpg': 'image/jpeg',
            'ico': 'image/x-icon',
            'svg': 'image/svg+xml',
            'ttf': 'font/ttf',
            'otf': 'font/otf',
            'woff2': 'font/woff2',
          };
          request.response.headers.set(
            HttpHeaders.contentTypeHeader,
            types[extension] ?? 'application/octet-stream',
          );
          request.response.headers.set(
            HttpHeaders.cacheControlHeader,
            'no-cache',
          );
          final stat = await file.stat();
          final etag =
              'W/"${stat.size}-${stat.modified.microsecondsSinceEpoch}"';
          request.response.headers.set(HttpHeaders.etagHeader, etag);
          if (request.headers.value(HttpHeaders.ifNoneMatchHeader) == etag) {
            request.response.statusCode = HttpStatus.notModified;
          } else if (request.method == 'GET') {
            await request.response.addStream(file.openRead());
          }
        }
      }
    }
  } catch (_) {
    request.response.statusCode = HttpStatus.internalServerError;
  } finally {
    try {
      await request.response.close();
    } catch (_) {
      // A browser may cancel an asset while reloading the local preview.
    }
  }
}

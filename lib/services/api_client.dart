import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'http_adapter.dart' if (dart.library.js_interop) 'http_adapter_web.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

class ApiClient {
  ApiClient({
    String baseUrl = const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://127.0.0.1:8081/api/v1/',
    ),
    Dio? http,
  }) : dio =
           http ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl,
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 60),
               headers: {
                 'Accept': 'application/json',
                 'Content-Type': 'application/json',
                 'X-Requested-With': 'SEMOB',
               },
             ),
           ) {
    configureHttp(dio);
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (token != null) options.headers['Authorization'] = 'Bearer $token';
          handler.next(options);
        },
        onError: (error, handler) {
          if (error.response?.statusCode == 401 &&
              !error.requestOptions.path.contains('auth/login') &&
              error.requestOptions.headers['Authorization'] ==
                  (token == null ? null : 'Bearer $token')) {
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }
  final Dio dio;
  String? token;
  void Function()? onUnauthorized;
}

String apiError(Object error) {
  if (error is DioException) {
    var body = error.response?.data;
    if (body is List<int>) {
      try {
        body = jsonDecode(utf8.decode(body));
      } catch (_) {}
    }
    if (body is Map && body['message'] is String) {
      return body['message'] as String;
    }
    return 'Não foi possível acessar o serviço. Verifique a conexão e tente novamente.';
  }
  return 'Não foi possível concluir a operação.';
}

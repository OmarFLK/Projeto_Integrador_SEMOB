import 'package:dio/dio.dart';

class ApiClient {
  ApiClient({String baseUrl = 'https://api.semob.example/v1'})
    : dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          headers: const {'Accept': 'application/json'},
        ),
      ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Ponto preparado para inclusão do token quando a API for ligada.
          handler.next(options);
        },
      ),
    );
  }

  final Dio dio;
}

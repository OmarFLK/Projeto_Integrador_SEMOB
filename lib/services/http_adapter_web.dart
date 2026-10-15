import 'package:dio/browser.dart';
import 'package:dio/dio.dart';

void configureHttp(Dio dio) {
  dio.httpClientAdapter = BrowserHttpClientAdapter()..withCredentials = true;
}

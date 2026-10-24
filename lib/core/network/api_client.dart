import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:fedmind_mobile_app/core/constants/constants.dart';

class ApiClient {
  late final Dio dio;

  ApiClient({String baseUrl = ApiConstants.baseUrl}) {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Logging interceptor untuk mempermudah debugging request/response
    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => debugPrint('[DIO] $obj'),
      ),
    );
  }
}

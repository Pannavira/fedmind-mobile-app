import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:fedmind_mobile_app/core/constants/constants.dart';

class ApiClient {
  late final Dio dio;
  late final Dio edgeDio;

  ApiClient({
    String baseUrl = ApiConstants.baseUrl,
    String edgeBaseUrl = ApiConstants.edgeBaseUrl,
  }) {
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

    edgeDio = Dio(
      BaseOptions(
        baseUrl: edgeBaseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.edgeReceiveTimeout,
        headers: {
          'Accept': 'application/json',
        },
      ),
    );

    // Logging interceptor untuk mempermudah debugging request/response
    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => debugPrint('[DIO-CENTRAL] $obj'),
      ),
    );

    edgeDio.interceptors.add(
      LogInterceptor(
        requestBody: false, // Jangan dump byte video multipart ke log
        responseBody: true,
        logPrint: (obj) => debugPrint('[DIO-EDGE] $obj'),
      ),
    );
  }
}

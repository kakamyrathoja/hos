import 'package:dio/dio.dart';
import 'token_storage.dart';

class ApiClient {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://api.hossarpay.com/api', // Backend URL
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  static bool _interceptorsReady = false;

  static void _ensureInterceptors() {
    if (_interceptorsReady) return;
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Token her istekte taze okunur (login/logout sonrası sorun olmaz).
          // Tek kaynak: TokenStorage.tokenKey ('token')
          try {
            final token = await TokenStorage.readToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          } catch (_) {
            // Token okunamazsa isteğe devam et, backend 401 döner.
          }
          return handler.next(options);
        },
      ),
    );
    _interceptorsReady = true;
  }

  static Future<Dio> get client async {
    _ensureInterceptors();
    return _dio;
  }
}

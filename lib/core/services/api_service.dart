import 'package:dio/dio.dart';

class ApiService {
  static const String _defaultBaseUrl = "https://api.libsoar.com/api/v1";
  static const int _defaultTimeoutSeconds = 20;

  /// Configurable base URL.
  /// Can be overridden at compile time via:
  ///   `--dart-define=API_BASE_URL=http://<host>:4000/api/v1`
  /// or at runtime via [setBaseUrl].
  static String baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultBaseUrl,
  );

  /// Configurable timeout duration.
  /// Can be overridden at compile time via:
  ///   `--dart-define=API_TIMEOUT_SECONDS=25`
  /// or at runtime via [setTimeout].
  static const int timeoutSeconds = int.fromEnvironment(
    'API_TIMEOUT_SECONDS',
    defaultValue: _defaultTimeoutSeconds,
  );

  static Duration timeout = const Duration(seconds: timeoutSeconds);

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: timeout,
      receiveTimeout: timeout,
      sendTimeout: timeout,
      headers: {
        "Content-Type": "application/json",
      },
      // Accept all 2xx status codes (200, 201, 204, etc.) as valid responses
      validateStatus: (status) => status != null && status >= 200 && status < 300,
    ),
  );

  /// Direct client accessor (for testing or advanced configuration).
  static Dio get client => _dio;

  /// Updates the base URL dynamically at runtime.
  static void setBaseUrl(String newUrl) {
    baseUrl = newUrl;
    _dio.options.baseUrl = newUrl;
  }

  /// Updates connection and receive timeouts dynamically at runtime.
  static void setTimeout(Duration newTimeout) {
    timeout = newTimeout;
    _dio.options.connectTimeout = newTimeout;
    _dio.options.receiveTimeout = newTimeout;
    _dio.options.sendTimeout = newTimeout;
  }

  // 🔐 Headers
  static Map<String, String> headers({String? token}) {
    return {
      "Content-Type": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };
  }

  // 🚀 POST API
  static Future<dynamic> post(String endpoint, Map<String, dynamic> body, {String? token}) async {
    try {
      final response = await _dio.post(
        endpoint,
        data: body,
        options: Options(headers: headers(token: token)),
      );
      return _handleResponse(response);
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  // 🔄 PUT API
  static Future<dynamic> put(String endpoint, dynamic body, {String? token}) async {
    try {
      final response = await _dio.put(
        endpoint,
        data: body,
        options: Options(headers: headers(token: token)),
      );
      return _handleResponse(response);
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  // 📝 PATCH API
  static Future<dynamic> patch(String endpoint, dynamic body, {String? token}) async {
    try {
      final response = await _dio.patch(
        endpoint,
        data: body,
        options: Options(headers: headers(token: token)),
      );
      return _handleResponse(response);
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  // 📥 GET API
  static Future<dynamic> get(String endpoint, String token, {Map<String, dynamic>? queryParams}) async {
    try {
      final response = await _dio.get(
        endpoint,
        queryParameters: queryParams,
        options: Options(headers: headers(token: token)),
      );
      return _handleResponse(response);
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  // 🗑️ DELETE API
  static Future<dynamic> delete(String endpoint, {String? token}) async {
    try {
      final response = await _dio.delete(
        endpoint,
        options: Options(headers: headers(token: token)),
      );
      return _handleResponse(response);
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  // 🧠 RESPONSE HANDLER
  static dynamic _handleResponse(Response response) {
    final statusCode = response.statusCode ?? 0;

    if (statusCode >= 200 && statusCode < 300) {
      return response.data;
    } else {
      final data = response.data;
      if (data is Map<String, dynamic>) {
        throw Exception(data["message"] ?? "Unknown server error ($statusCode)");
      }
      throw Exception("Server Error $statusCode");
    }
  }

  // ⚠️ CENTRALIZED DIO EXCEPTION HANDLER
  static Never _handleDioException(DioException e) {
    // 1. Check for response-based errors (HTTP status returned by server or proxy)
    if (e.response != null) {
      final statusCode = e.response?.statusCode;
      final data = e.response?.data;

      // Handle Cloudflare edge and gateway errors
      if (statusCode != null) {
        if (statusCode == 522 || statusCode == 521 || statusCode == 524 || statusCode == 523) {
          throw Exception(
            'The LibSoar server is currently unreachable (Error $statusCode: Origin server connection failed). '
            'Please verify the backend service is running.',
          );
        }
        if (statusCode == 502 || statusCode == 503 || statusCode == 504) {
          throw Exception(
            'Server is temporarily unavailable (Error $statusCode). Please try again shortly.',
          );
        }
      }

      // Handle structured JSON errors from the backend API
      if (data is Map<String, dynamic>) {
        final error = data['error'];
        String? msg = data['message']?.toString();
        if (msg == null && error is Map) {
          msg = error['message']?.toString();
          final details = error['details'];
          if (details is Map && details.isNotEmpty) {
            final firstDetail = details.values.first?.toString();
            if (firstDetail != null) msg = '$msg: $firstDetail';
          }
        }
        throw Exception(msg ?? (error?.toString() ?? 'Server error ($statusCode)'));
      } else if (data is String && data.trim().isNotEmpty) {
        if (data.contains('error code: 522') || data.contains('Error 522')) {
          throw Exception(
            'The backend server is currently offline or unreachable (Error 522). Please verify the server is running.',
          );
        }
        throw Exception('Server error ($statusCode): ${data.trim()}');
      }
      throw Exception('Server error ($statusCode)');
    }

    // 2. Response is null -> Network, Timeout, or Socket level error
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        throw Exception(
          'Connection timed out. The server took too long to respond. '
          'Please check your internet connection or verify the server is running.',
        );
      case DioExceptionType.connectionError:
        final host = e.requestOptions.uri.host;
        if (host == 'localhost' || host == '127.0.0.1') {
          throw Exception(
            'Cannot reach local server at $host. '
            'If testing on an Android device or emulator, use your computer LAN IP or 10.0.2.2 instead of localhost.',
          );
        }
        throw Exception(
          'Network connection failed. Unable to reach $host. Please check your internet connection.',
        );
      case DioExceptionType.badCertificate:
        throw Exception('Security error: SSL certificate verification failed.');
      case DioExceptionType.cancel:
        throw Exception('Request was cancelled.');
      default:
        throw Exception(
          'Network error: ${e.message ?? 'Unable to complete request. Please try again.'}',
        );
    }
  }
}
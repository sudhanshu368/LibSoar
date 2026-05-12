import 'package:dio/dio.dart';

class ApiService {
  static const String baseUrl = "https://api.libsoar.com/api/v1";

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        "Content-Type": "application/json",
      },
      // Accept all 2xx status codes (200, 201, 204, etc.) as valid responses
      validateStatus: (status) => status != null && status >= 200 && status < 300,
    ),
  );

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
      // 🔥 DEBUG LOGS
      //print("🚀 API CALL → POST $endpoint");
      //print("📤 BODY → $body");

      final response = await _dio.post(
        endpoint,
        data: body,
        options: Options(headers: headers(token: token)),
      );

      //print("✅ RESPONSE → ${response.data}");

      return _handleResponse(response);

    } on DioException catch (e) {
      //print("❌ ERROR STATUS → ${e.response?.statusCode}");
      //print("❌ ERROR DATA → ${e.response?.data}");

      if (e.response != null) {
        final data = e.response?.data;
        if (data is Map<String, dynamic>) {
          final error = data['error'];
          String? msg = data['message']?.toString();
          if (msg == null && error is Map) {
            msg = error['message']?.toString();
            // For VALIDATION_ERROR, append first detail
            final details = error['details'];
            if (details is Map && details.isNotEmpty) {
              final firstDetail = details.values.first?.toString();
              if (firstDetail != null) msg = '$msg: $firstDetail';
            }
          }
          throw Exception(msg ?? data.toString());
        } else {
          throw Exception(data?.toString() ?? 'Something went wrong');
        }
      } else {
        throw Exception('Network Error: ${e.message}');
      }
    }
  }

  // 🔄 PUT API
  static Future<dynamic> put(String endpoint, dynamic body, {String? token}) async {
    try {
      //print("🚀 API CALL → PUT $endpoint");
      //print("📤 BODY → $body");

      final response = await _dio.put(
        endpoint,
        data: body,
        options: Options(headers: headers(token: token)),
      );

      //print("✅ RESPONSE → ${response.data}");

      return _handleResponse(response);

    } on DioException catch (e) {
      //print("❌ ERROR STATUS → ${e.response?.statusCode}");
      //print("❌ ERROR DATA → ${e.response?.data}");

      if (e.response != null) {
        final data = e.response?.data;
        if (data is Map<String, dynamic>) {
          throw Exception(data["message"] ?? data.toString());
        } else {
          throw Exception(data?.toString() ?? "Something went wrong");
        }
      } else {
        throw Exception("Network Error: ${e.message}");
      }
    }
  }

  // 📝 PATCH API
  static Future<dynamic> patch(String endpoint, dynamic body, {String? token}) async {
    try {
      //print("🚀 API CALL → PATCH $endpoint");
      //print("📤 BODY → $body");

      final response = await _dio.patch(
        endpoint,
        data: body,
        options: Options(headers: headers(token: token)),
      );

      //print("✅ RESPONSE → ${response.data}");

      return _handleResponse(response);

    } on DioException catch (e) {
      //print("❌ ERROR STATUS → ${e.response?.statusCode}");
      //print("❌ ERROR DATA → ${e.response?.data}");

      if (e.response != null) {
        final data = e.response?.data;
        if (data is Map<String, dynamic>) {
          throw Exception(data["message"] ??
              data.toString());
        } else {
          throw Exception(data?.toString() ?? "Something went wrong");
        }
      } else {
        throw Exception("Network Error: ${e.message}");
      }
    }
  }

  // 📥 GET API
  static Future<dynamic> get(String endpoint, String token, {Map<String, dynamic>? queryParams}) async {
    try {
      //print("🚀 API CALL → GET $endpoint");
      if (queryParams != null && queryParams.isNotEmpty) {
        //print("🔍 QUERY PARAMS → $queryParams");
      }

      final response = await _dio.get(
        endpoint,
        queryParameters: queryParams,
        options: Options(headers: headers(token: token)),
      );

      //print("✅ RESPONSE → ${response.data}");

      return _handleResponse(response);

    } on DioException catch (e) {
      //print("❌ ERROR STATUS → ${e.response?.statusCode}");
      //print("❌ ERROR DATA → ${e.response?.data}");

      if (e.response != null) {
        final data = e.response?.data;
        if (data is Map<String, dynamic>) {
          throw Exception(data["message"] ?? data.toString());
        } else {
          throw Exception(data?.toString() ?? "Something went wrong");
        }
      } else {
        throw Exception("Network Error: ${e.message}");
      }
    }
  }

  // 🗑️ DELETE API
  static Future<dynamic> delete(String endpoint, {String? token}) async {
    try {
      //print("🚀 API CALL → DELETE $endpoint");

      final response = await _dio.delete(
        endpoint,
        options: Options(headers: headers(token: token)),
      );

      //print("✅ RESPONSE → ${response.data}");

      return _handleResponse(response);

    } on DioException catch (e) {
      //print("❌ ERROR STATUS → ${e.response?.statusCode}");
      //print("❌ ERROR DATA → ${e.response?.data}");

      if (e.response != null) {
        final data = e.response?.data;
        if (data is Map<String, dynamic>) {
          throw Exception(data["message"] ?? data.toString());
        } else {
          throw Exception(data?.toString() ?? "Something went wrong");
        }
      } else {
        throw Exception("Network Error: ${e.message}");
      }
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
        throw Exception(data["message"] ?? "Unknown server error");
      }

      throw Exception("Server Error $statusCode");
    }
  }
}
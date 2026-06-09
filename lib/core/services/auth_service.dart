import '../../data/models/profile_model.dart';
import 'api_service.dart';
import '../utils/storage_helper.dart';

class VerifyOtpResult {
  final bool needsRegistration;
  final String? phoneToken;
  final Map<String, dynamic>? authData;

  const VerifyOtpResult({
    required this.needsRegistration,
    this.phoneToken,
    this.authData,
  });

  bool get isLoggedIn => !needsRegistration && authData != null;
}

class AuthService {
  static String formatPhone(String phone) {
    phone = phone.replaceAll('+91', '').replaceAll(' ', '').trim();
    if (phone.length > 10) {
      phone = phone.substring(phone.length - 10);
    }
    return phone;
  }

  static Future<void> sendOtp(String phone) async {
    await ApiService.post('/auth/send-otp', {
      'phone': formatPhone(phone),
    });
  }

  static Future<VerifyOtpResult> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    final response = await ApiService.post('/auth/verify-otp', {
      'phone': formatPhone(phone),
      'otp': otp,
    });

    if (response is! Map) {
      throw Exception('Invalid server response');
    }

    final data = response['data'];
    if (data is! Map) {
      throw Exception('Invalid server response');
    }

    if (data['needsRegistration'] == true) {
      final phoneToken = data['phoneToken']?.toString();
      if (phoneToken == null || phoneToken.isEmpty) {
        throw Exception('Phone verification failed');
      }
      return VerifyOtpResult(
        needsRegistration: true,
        phoneToken: phoneToken,
      );
    }

    return VerifyOtpResult(
      needsRegistration: false,
      authData: Map<String, dynamic>.from(data),
    );
  }

  static Future<void> persistAuthData(Map<String, dynamic> data) async {
    final token = data['accessToken']?.toString();
    final refreshToken = data['refreshToken']?.toString();

    if (token == null || token.isEmpty) {
      throw Exception('Token not found');
    }

    await StorageHelper.saveToken(token);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await StorageHelper.saveRefreshToken(refreshToken);
    }

    final user = data['user'];
    if (user is Map && user['library'] is Map) {
      final libraryId = user['library']['id']?.toString();
      if (libraryId != null && libraryId.isNotEmpty) {
        await StorageHelper.saveLibraryId(libraryId);
      }
    }
  }

  static Future<void> persistAuthResponse(Map response) async {
    final data = response['data'];
    if (data is! Map) {
      throw Exception('Token not found');
    }
    await persistAuthData(Map<String, dynamic>.from(data));
  }

  static Future<dynamic> registerWithOnboarding({
    required String phoneToken,
    required String name,
    required String libraryName,
    required Map<String, dynamic> onboardingData,
  }) async {
    return ApiService.post('/auth/register', {
      'phoneToken': phoneToken,
      'name': name,
      'libraryName': libraryName,
      'onboardingData': onboardingData,
    });
  }

  static Future<dynamic> completeOnboarding(
    Map<String, dynamic> payload,
  ) async {
    final token = await StorageHelper.getToken();
    if (token == null) throw Exception('Unauthorized: Token not found');
    return ApiService.post('/onboarding/complete', payload, token: token);
  }

  static Future<UserModel?> getProfile() async {
    try {
      final token = await StorageHelper.getToken();
      if (token == null) throw Exception('Unauthorized: Token not found');

      final response = await ApiService.get('/auth/me', token);
      final profileResponse = ProfileResponse.fromJson(response);

      if (profileResponse.success && profileResponse.data != null) {
        return profileResponse.data!.user;
      }
      return null;
    } catch (e) {
      print('❌ Profile fetch failed: ${e.toString()}');
      rethrow;
    }
  }

  static Future<UserModel?> updateProfile(Map<String, dynamic> data) async {
    try {
      final token = await StorageHelper.getToken();
      if (token == null) throw Exception('Unauthorized: Token not found');

      final response = await ApiService.patch('/auth/me', data, token: token);
      final profileResponse = ProfileResponse.fromJson(response);

      if (profileResponse.success && profileResponse.data != null) {
        return profileResponse.data!.user;
      }
      return null;
    } catch (e) {
      print('❌ Profile update failed: ${e.toString()}');
      rethrow;
    }
  }

  static Future<void> refreshToken() async {
    try {
      final refreshToken = await StorageHelper.getRefreshToken();
      if (refreshToken == null) return;

      final response = await ApiService.post(
        '/auth/refresh',
        {'refreshToken': refreshToken},
      );

      if (response is Map) {
        await persistAuthResponse(Map<String, dynamic>.from(response));
      }
    } catch (e) {
      print('❌ Token refresh failed: ${e.toString()}');
    }
  }

  static Future<void> logout() async {
    try {
      final token = await StorageHelper.getToken();
      final refreshToken = await StorageHelper.getRefreshToken();

      if (token != null && refreshToken != null) {
        await ApiService.post(
          '/auth/logout',
          {'refreshToken': refreshToken},
          token: token,
        );
      }
    } catch (e) {
      print('❌ Logout API failed: ${e.toString()}');
    } finally {
      await StorageHelper.logout();
    }
  }

  static Future<void> logoutAll() async {
    try {
      final token = await StorageHelper.getToken();
      final refreshToken = await StorageHelper.getRefreshToken();

      if (token != null && refreshToken != null) {
        await ApiService.post(
          '/auth/logout-all',
          {'refreshToken': refreshToken},
          token: token,
        );
      }
    } catch (e) {
      print('❌ Logout All API failed: ${e.toString()}');
    } finally {
      await StorageHelper.logout();
    }
  }
}

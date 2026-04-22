import 'package:firebase_auth/firebase_auth.dart';
import '../../data/models/profile_model.dart';
import 'api_service.dart';
import '../utils/storage_helper.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // 📱 FORMAT PHONE
  static String formatPhone(String phone) {
    phone = phone.replaceAll("+91", "").replaceAll(" ", "").trim();

    if (phone.length > 10) {
      phone = phone.substring(phone.length - 10);
    }

    return phone;
  }

  // 🚀 SEND OTP (Firebase)
  static Future<void> sendOtp({
    required String phone,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
  }) async {
    try {
      String formattedPhone = "+91${formatPhone(phone)}";

      await _auth.verifyPhoneNumber(
        phoneNumber: formattedPhone,

        // 🔥 Auto verification (rare)
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await _auth.signInWithCredential(credential);
          } catch (e) {
            onError("Auto verification failed");
          }
        },

        // ❌ Failed
        verificationFailed: (FirebaseAuthException e) {
          onError(e.message ?? "OTP send failed");
        },

        // ✅ Code sent
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },

        // ⏱ Timeout
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      onError(e.toString());
    }
  }

  // ✅ VERIFY OTP + GET idToken + CALL BACKEND
  static Future<dynamic> verifyOtp({
    required String phone,
    required String verificationId,
    required String otp,
    bool isLogin = false,
  }) async {
    try {
      // 🔐 Create credential
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );

      // 🔑 Firebase sign in
      UserCredential userCredential =
      await _auth.signInWithCredential(credential);

      // 👤 USER CHECK
      final user = userCredential.user;

      if (user == null) {
        throw Exception("User not found");
      }

      // 🎯 GET idToken (NULL SAFE)
      final idToken = await user.getIdToken();

      if (idToken == null) {
        throw Exception("Failed to get idToken");
      }

      String formattedPhone = formatPhone(phone);

      // 🌐 BACKEND CALL
      String endpoint = isLogin ? "/auth/login" : "/auth/register";
      final response = await ApiService.post(endpoint, {
        "phone": formattedPhone,
        "idToken": idToken,
      });

      return response;

    } catch (e) {
      throw Exception("OTP verification failed: ${e.toString()}");
    }
  }

  // 👤 GET PROFILE
  static Future<UserModel?> getProfile() async {
    try {
      final token = await StorageHelper.getToken();
      if (token == null) throw Exception("Unauthorized: Token not found");

      final response = await ApiService.get("/auth/me", token);
      final profileResponse = ProfileResponse.fromJson(response);
      
      if (profileResponse.success && profileResponse.data != null) {
        return profileResponse.data!.user;
      }
      return null;
    } catch (e) {
      print("❌ Profile fetch failed: ${e.toString()}");
      rethrow;
    }
  }

  // 🚀 ONBOARDING
  static Future<dynamic> completeOnboarding(Map<String, dynamic> data) async {
    await refreshToken();
    final token = await StorageHelper.getToken();
    if (token == null) throw Exception("Unauthorized: Token not found");

    final response = await ApiService.post(
      "/onboarding/complete",
      data,
      token: token,
    );

    // Update token if server rotated it
    if (response is Map) {
      String? newToken = response["token"] ?? response["accessToken"] ?? response["access_token"];
      if (newToken == null && response.containsKey("data") && response["data"] is Map) {
        final d = response["data"];
        newToken = d["token"] ?? d["accessToken"] ?? d["access_token"];
      }
      if (newToken != null) {
        await StorageHelper.saveToken(newToken);
      }
    }
    return response;
  }

  // 🚀 UPDATE PROFILE (PATCH)
  static Future<UserModel?> updateProfile(Map<String, dynamic> data) async {
    try {
      final token = await StorageHelper.getToken();
      if (token == null) throw Exception("Unauthorized: Token not found");

      final response = await ApiService.patch("/auth/me", data, token: token);
      final profileResponse = ProfileResponse.fromJson(response);
      
      if (profileResponse.success && profileResponse.data != null) {
        return profileResponse.data!.user;
      }
      return null;
    } catch (e) {
      print("❌ Profile update failed: ${e.toString()}");
      rethrow;
    }
  }

  // 🔄 REFRESH TOKEN
  static Future<void> refreshToken() async {
    try {
      final token = await StorageHelper.getToken();
      if (token == null) return;
      
      final response = await ApiService.post("/auth/refresh", {}, token: token);
      
      if (response is Map) {
        String? newToken = response["token"] ?? response["accessToken"] ?? response["access_token"];
        if (newToken == null && response.containsKey("data") && response["data"] is Map) {
          final d = response["data"];
          newToken = d["token"] ?? d["accessToken"] ?? d["access_token"];
        }
        if (newToken != null) {
          await StorageHelper.saveToken(newToken);
        }
      }
    } catch (e) {
      print("❌ Token refresh failed: ${e.toString()}");
    }
  }

  // 🚪 LOGOUT
  static Future<void> logout() async {
    try {
      final token = await StorageHelper.getToken();
      if (token != null) {
        await ApiService.post("/auth/logout", {}, token: token);
      }
    } catch (e) {
      print("❌ Logout API failed: ${e.toString()}");
    } finally {
      await _auth.signOut();
      await StorageHelper.logout();
    }
  }

  // 🚪 LOGOUT ALL
  static Future<void> logoutAll() async {
    try {
      final token = await StorageHelper.getToken();
      if (token != null) {
        await ApiService.post("/auth/logout-all", {}, token: token);
      }
    } catch (e) {
      print("❌ Logout All API failed: ${e.toString()}");
    } finally {
      await _auth.signOut();
      await StorageHelper.logout();
    }
  }
}
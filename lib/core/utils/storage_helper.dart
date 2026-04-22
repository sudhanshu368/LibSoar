import 'package:shared_preferences/shared_preferences.dart';

class StorageHelper {

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("token", token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("token");
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Future<void> saveBranchId(String branchId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("selectedBranchId", branchId);
  }

  static Future<String?> getBranchId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("selectedBranchId");
  }

}
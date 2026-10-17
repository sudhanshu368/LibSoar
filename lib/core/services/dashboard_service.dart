import 'package:flutter/foundation.dart';
import 'api_service.dart';
import '../utils/storage_helper.dart';

Map<String, dynamic> _asStringKeyMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return {};
}

Map<String, dynamic> _normalizeRevenuePayload(dynamic raw) {
  if (raw is List) {
    return {"weekly": raw};
  }
  if (raw is Map) {
    final m = _asStringKeyMap(raw);
    if (m["data"] is Map) {
      final inner = _asStringKeyMap(m["data"]);
      final merged = {...m, ...inner};
      merged.remove("data");
      return merged;
    }
    return m;
  }
  return {};
}

/// Prefer period-specific keys first, then generic list fields (APIs differ).
List<dynamic> _extractRevenueSeries(Map<String, dynamic> m, {required bool forWeekly}) {
  final preferred = forWeekly
      ? <String>["weekly", "week", "daily", "days"]
      : <String>["monthly", "month", "months", "yearly"];
  for (final k in preferred) {
    final v = m[k];
    if (v is List && v.isNotEmpty) return List<dynamic>.from(v);
  }
  for (final k in ["series", "data", "items", "results", "points"]) {
    final v = m[k];
    if (v is List && v.isNotEmpty) return List<dynamic>.from(v);
  }
  for (final v in m.values) {
    if (v is List && v.isNotEmpty) return List<dynamic>.from(v);
  }
  return [];
}

double? _parseDynamicNum(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().replaceAll(",", ""));
}

/// Aggregate rows that should not appear as pie slices / method lines.
bool _shouldSkipPaymentSummaryLabel(String name) {
  final n = name.toLowerCase().trim();
  if (n.isEmpty) return false;
  final compact = n.replaceAll(RegExp(r'[\s_-]+'), '');
  if (compact == 'totalrevenue' || compact.contains('totalrevenue')) {
    return true;
  }
  if (n.contains('total revenue') || n.contains('total_revenue')) {
    return true;
  }
  if (n == 'transaction' ||
      n == 'transactions' ||
      n == 'transcation' ||
      n == 'transcations') {
    return true;
  }
  return false;
}

/// Rows from a map like `{ "UPI": 1200, "Cash": 800 }` or nested maps.
List<Map<String, dynamic>> _paymentMapToRows(Map<dynamic, dynamic> src) {
  final out = <Map<String, dynamic>>[];
  for (final e in src.entries) {
    final name = e.key?.toString().trim() ?? "";
    if (name.isEmpty) continue;
    if (_shouldSkipPaymentSummaryLabel(name)) continue;
    final val = e.value;
    if (val is Map) {
      final row = _asStringKeyMap(val);
      if (row["name"] == null && row["method"] == null) {
        row["name"] = name;
      }
      out.add(row);
    } else {
      final amt = _parseDynamicNum(val) ?? 0;
      out.add({"name": name, "amount": amt});
    }
  }
  return out;
}

/// Unwrap payment summary from various API shapes into `{ methods: [...] }`.
Map<String, dynamic> _normalizePaymentSummaryRoot(dynamic raw) {
  if (raw is List) {
    return {"methods": raw};
  }
  if (raw is! Map) {
    return {};
  }
  var m = _asStringKeyMap(raw);
  if (m["data"] is Map) {
    final inner = _asStringKeyMap(m["data"]);
    m = {...m, ...inner};
    m.remove("data");
  }

  const listKeys = [
    "methods",
    "paymentMethods",
    "byMethod",
    "breakdown",
    "items",
    "distribution",
    "splits",
    "details",
    "rows",
    "payment_breakdown",
    "payments",
  ];

  for (final key in listKeys) {
    final v = m[key];
    if (v is List && v.isNotEmpty) {
      m["methods"] = List<dynamic>.from(v);
      return m;
    }
    if (v is Map && v.isNotEmpty) {
      m["methods"] = _paymentMapToRows(v);
      return m;
    }
  }

  final methodsMap = m["methods"];
  if (methodsMap is Map && methodsMap.isNotEmpty) {
    m["methods"] = _paymentMapToRows(methodsMap);
    return m;
  }

  if (m["summary"] is Map) {
    final s = _asStringKeyMap(m["summary"]);
    for (final key in listKeys) {
      final v = s[key];
      if (v is List && v.isNotEmpty) {
        m["methods"] = List<dynamic>.from(v);
        return m;
      }
      if (v is Map && v.isNotEmpty) {
        m["methods"] = _paymentMapToRows(v);
        return m;
      }
    }
  }

  const skipFlat = <String>{
    "success",
    "message",
    "status",
    "code",
    "meta",
    "data",
    "summary",
    "total",
    "grandtotal",
    "grand_total",
    "totalamount",
    "branchid",
    "branch_id",
  };
  final flat = <Map<String, dynamic>>[];
  for (final e in m.entries) {
    final k = e.key.toString().toLowerCase();
    if (skipFlat.contains(k)) continue;
    if (_shouldSkipPaymentSummaryLabel(e.key.toString())) continue;
    final v = e.value;
    if (v is Map || v is List) continue;
    final amt = _parseDynamicNum(v);
    if (amt == null) continue;
    flat.add({"name": e.key.toString(), "amount": amt});
  }
  if (flat.isNotEmpty) {
    m["methods"] = flat;
  }

  return m;
}

class DashboardService {

  /// 🔐 COMMON TOKEN GETTER (SAFE)
  static Future<String> _getToken() async {
    final token = await StorageHelper.getToken();
    if (token == null) {
      throw Exception("Unauthorized: Token not found");
    }
    return token;
  }

  // 📊 Stats
  static Future<Map<String, dynamic>> getStats([String? branchId]) async {
    try {
      final token = await _getToken();
      final queryParams = branchId != null ? {"branchId": branchId} : null;
      final res = await ApiService.get("/dashboard/stats", token, queryParams: queryParams);
      // Try res["data"] first, fallback to res directly
      final data = res["data"] ?? res;
      return data is Map<String, dynamic> ? data : {};
    } catch (e) {
      debugPrint("Stats error: $e");
      return {};
    }
  }

  // 💰 Revenue — weekly + monthly (separate API calls; many backends only honor one period per request)
  static Future<Map<String, dynamic>> getRevenue([String? branchId]) async {
    try {
      final token = await _getToken();
      final base = <String, dynamic>{
        if (branchId != null) "branchId": branchId,
      };

      Future<Map<String, dynamic>> fetch(String period) async {
        final res = await ApiService.get(
          "/dashboard/revenue",
          token,
          queryParams: {...base, "period": period},
        );
        return _normalizeRevenuePayload(res["data"] ?? res);
      }

      Future<Map<String, dynamic>> safeFetch(String period) async {
        try {
          return await fetch(period);
        } catch (e) {
          debugPrint("Revenue ($period) error: $e");
          return {};
        }
      }

      final results = await Future.wait([
        safeFetch("weekly"),
        safeFetch("monthly"),
      ]);
      final w = results[0];
      final mo = results[1];

      final weeklySeries = _extractRevenueSeries(w, forWeekly: true);
      final monthlySeries = _extractRevenueSeries(mo, forWeekly: false);

      return {
        "weekly": weeklySeries,
        "monthly": monthlySeries,
        "growth": w["growth"] ?? w["weekOverWeek"] ?? w["changePercent"],
        "monthlyGrowth":
            mo["monthlyGrowth"] ?? mo["monthOverMonth"] ?? mo["growth"] ?? mo["changePercent"],
      };
    } catch (e) {
      debugPrint("Revenue error: $e");
      return {};
    }
  }

  // 💳 Payment Summary
  static Future<Map<String, dynamic>> getPaymentSummary([String? branchId]) async {
    try {
      final token = await _getToken();
      final queryParams = branchId != null ? {"branchId": branchId} : null;
      final res = await ApiService.get("/payments/summary", token, queryParams: queryParams);
      return _normalizePaymentSummaryRoot(res["data"] ?? res);
    } catch (e) {
      debugPrint("Payment summary error: $e");
      return {};
    }
  }

  // ⚠️ Payment Due (Fee Dues) - Simple list
  static Future<List<dynamic>> getDuePayments([String? branchId]) async {
    try {
      final token = await _getToken();
      final queryParams = branchId != null ? {"branchId": branchId} : null;
      final res = await ApiService.get("/reports/today-actions", token, queryParams: queryParams);
      
      final data = res["data"];
      if (data is Map<String, dynamic>) {
        final paymentDues = data["paymentDues"];
        if (paymentDues is List) {
          return paymentDues;
        }
      }
      return [];
    } catch (e) {
      debugPrint("Fee dues error: $e");
      return [];
    }
  }

  // 💰 Detailed Due Payments (Subscriptions with Dues)
  static Future<Map<String, dynamic>> getDetailedDuePayments({
    required String branchId,
    int page = 1,
    int limit = 20,
    String? search,
    String? shiftId,
    String sortBy = 'endDate',
    String sortOrder = 'asc',
  }) async {
    try {
      final token = await _getToken();
      final queryParams = <String, dynamic>{
        "status": "active",
        "hasDue": "true",
        "page": page,
        "limit": limit,
        "branchId": branchId,
        "sortBy": sortBy,
        "sortOrder": sortOrder,
      };
      if (search != null && search.isNotEmpty) queryParams["search"] = search;
      if (shiftId != null && shiftId.isNotEmpty) queryParams["shiftId"] = shiftId;

      final res = await ApiService.get("/subscriptions", token, queryParams: queryParams);
      return res;
    } catch (e) {
      debugPrint("Detailed Due Payments error: $e");
      return {"data": [], "meta": {}};
    }
  }

  // 💸 Record Payment
  static Future<Map<String, dynamic>> recordPayment({
    required String studentId,
    required String subscriptionId,
    required double amount,
    required String mode,
    String? transactionId,
    String? notes,
  }) async {
    try {
      final token = await _getToken();
      final body = {
        "studentId": studentId,
        "subscriptionId": subscriptionId,
        "amount": amount,
        "mode": mode,
        if (transactionId != null && transactionId.isNotEmpty) "transactionId": transactionId,
        if (notes != null && notes.isNotEmpty) "notes": notes,
      };
      final res = await ApiService.post("/payments", body, token: token);
      return res;
    } catch (e) {
      debugPrint("Record Payment error: $e");
      rethrow;
    }
  }

  // Endpoint: GET /subscriptions/expiring?branchId=...
  static Future<Map<String, dynamic>> getDashboardSubscriptions([String? branchId]) async {
    try {
      final token = await _getToken();
      final queryParams = <String, dynamic>{
        if (branchId != null && branchId.isNotEmpty) "branchId": branchId,
      };
      final res = await ApiService.get("/subscriptions/expiring", token, queryParams: queryParams);
      final data = res["data"];
      final list = data is List ? List<dynamic>.from(data) : <dynamic>[];
      var total = list.length;
      if (res["total"] is num) total = (res["total"] as num).toInt();
      return {"list": list, "total": total};
    } catch (e) {
      debugPrint("Get Dashboard Subs error: $e");
      return {"list": [], "total": 0};
    }
  }

  /// Expired subscriptions (home): `GET /subscriptions?status=expired&limit=10&sortBy=endDate&sortOrder=desc`
  static Future<Map<String, dynamic>> getExpiredSubscriptions([String? branchId]) async {
    try {
      final token = await _getToken();
      final queryParams = <String, dynamic>{
        "status": "expired",
        "limit": 10,
        "sortBy": "endDate",
        "sortOrder": "desc",
        if (branchId != null && branchId.isNotEmpty) "branchId": branchId,
      };
      final res = await ApiService.get("/subscriptions", token, queryParams: queryParams);
      final data = res["data"] ?? [];
      final list = data is List ? List<dynamic>.from(data) : <dynamic>[];
      var total = list.length;
      final meta = res["meta"];
      if (meta is Map && meta["pagination"] is Map) {
        final t = (meta["pagination"] as Map)["total"];
        if (t is num) total = t.toInt();
      }
      return {"list": list, "total": total};
    } catch (e) {
      debugPrint("Expired subs error: $e");
      return {"list": <dynamic>[], "total": 0};
    }
  }

  /// Pending join requests. Matches `GET /students?status=PENDING&...`
  static Future<Map<String, dynamic>> getPendingStudentRequests([String? branchId, int page = 1, int limit = 10]) async {
    try {
      final token = await _getToken();
      final queryParams = <String, dynamic>{
        "status": "PENDING",
        "page": page,
        "limit": limit,
        "sortBy": "createdAt",
        "sortOrder": "desc",
        if (branchId != null && branchId.isNotEmpty) "branchId": branchId,
      };
      final res = await ApiService.get("/students", token, queryParams: queryParams);
      final data = res["data"] ?? [];
      final list = data is List ? List<dynamic>.from(data) : <dynamic>[];
      var total = list.length;
      final meta = res["meta"];
      if (meta is Map && meta["pagination"] is Map) {
        final p = meta["pagination"] as Map;
        final t = p["total"];
        if (t is num) total = t.toInt();
      }
      return {"list": list, "total": total};
    } catch (e) {
      debugPrint("Pending students error: $e");
      return {"list": <dynamic>[], "total": 0};
    }
  }

  // ✅ APPROVE STUDENT
  static Future<void> approveStudent(String id) async {
    try {
      final token = await _getToken();
      await ApiService.patch("/students/$id/approve", {}, token: token);
    } catch (e) {
      debugPrint("Approve error: $e");
      rethrow;
    }
  }

  // ❌ REJECT STUDENT
  static Future<void> rejectStudent(String id) async {
    try {
      final token = await _getToken();
      await ApiService.patch("/students/$id/reject", {}, token: token);
    } catch (e) {
      debugPrint("Reject error: $e");
      rethrow;
    }
  }

  // 🏢 Branch list
  static Future<List<Map<String, dynamic>>> getBranches() async {
    try {
      final token = await _getToken();
      final res = await ApiService.get("/branches", token);
      final data = res["data"];

      if (data is List) {
        return data.map((item) {
          if (item is Map<String, dynamic>) {
            return item;
          } else if (item is String) {
            // If API returns strings, create objects with name only
            return {"name": item, "id": item};
          } else {
            return {"name": item.toString(), "id": item.toString()};
          }
        }).toList();
      }

      return [];
    } catch (e) {
      debugPrint("Branches error: $e");
      return [];
    }
  }

  // 🔔 Notifications
  static Future<List<dynamic>> getNotifications() async {
    try {
      final token = await _getToken();
      final res = await ApiService.get("/notifications", token);
      // Try res["data"] first, fallback to res directly
      final data = res["data"] ?? res;
      return data is List ? data : [];
    } catch (e) {
      debugPrint("Notifications error: $e");
      return [];
    }
  }

  // 🪑 Seat Map
  static Future<List<dynamic>> getSeatMap({required String date, required String branchId}) async {
    try {
      final token = await _getToken();
      final queryParams = {
        "date": date,
        "branchId": branchId,
      };
      final res = await ApiService.get("/seats/map", token, queryParams: queryParams);
      final data = res["data"] ?? res;
      return data is List ? data : [];
    } catch (e) {
      debugPrint("Seat Map error: $e");
      return [];
    }
  }

  // 👨‍🎓 Search Active Students
  static Future<List<dynamic>> searchActiveStudents({required String query, String? branchId}) async {
    try {
      final token = await _getToken();
      final queryParams = {
        "search": query,
        "status": "ACTIVE",
        "limit": 20,
        if (branchId != null) "branchId": branchId,
      };
      final res = await ApiService.get("/students", token, queryParams: queryParams);
      final data = res["data"] ?? res;
      return data is List ? data : [];
    } catch (e) {
      debugPrint("Search students error: $e");
      return [];
    }
  }

  // 📋 Get Full Students List
  static Future<Map<String, dynamic>> getStudents({
    String? branchId,
    int page = 1,
    int limit = 10,
    String? status,
    String sortBy = 'createdAt',
    String sortOrder = 'desc',
    String? search,
  }) async {
    try {
      final token = await _getToken();
      final queryParams = <String, dynamic>{
        "page": page,
        "limit": limit,
        "sortBy": sortBy,
        "sortOrder": sortOrder,
      };
      if (branchId != null) queryParams["branchId"] = branchId;
      if (status != null && status != 'All') queryParams["status"] = status.toUpperCase();
      if (search != null && search.isNotEmpty) queryParams["search"] = search;

      final res = await ApiService.get("/students", token, queryParams: queryParams);
      return res;
    } catch (e) {
      debugPrint("Get students list error: $e");
      return {"data": [], "meta": {}};
    }
  }
  
  // 🔍 Get Single Student by ID
  static Future<Map<String, dynamic>> getStudentById(String id) async {
    try {
      final token = await _getToken();
      final res = await ApiService.get("/students/$id", token);
      return res;
    } catch (e) {
      debugPrint("Get student by ID error: $e");
      rethrow;
    }
  }

  // 📝 Book Seat
  static Future<void> bookSeat({required String seatId, required String shiftId, required String studentId, required String date}) async {
    try {
      final token = await _getToken();
      String isoDate = date;
      if (date.length == 10) { // Format: YYYY-MM-DD
        isoDate = "${date}T00:00:00.000Z";
      }
      final body = {
        "shiftId": shiftId,
        "studentId": studentId,
        "date": isoDate,
      };
      await ApiService.post("/seats/$seatId/book", body, token: token);
    } catch (e) {
      debugPrint("Book seat error: $e");
      rethrow;
    }
  }

  // ❌ Cancel Booking
  // Endpoint: DELETE /seats/{seatId}/book/{bookingId}
  static Future<void> cancelBooking({required String seatId, String? bookingId}) async {
    try {
      final token = await _getToken();
      // If bookingId is null, use "null" as requested by user example
      final bId = bookingId ?? "null";
      await ApiService.delete("/seats/$seatId/book/$bId", token: token);
    } catch (e) {
      debugPrint("Cancel booking error: $e");
      rethrow;
    }
  }

  // 📊 Attendance / Check-ins
  static Future<Map<String, dynamic>> getAttendance({required String date, String status = 'ALL', required String branchId, int page = 1, int limit = 50}) async {
    try {
      final token = await _getToken();
      final queryParams = {
        "date": date,
        "status": status,
        "branchId": branchId,
        "page": page.toString(),
        "limit": limit.toString(),
      };
      final res = await ApiService.get("/attendance", token, queryParams: queryParams);
      final data = res["data"] ?? {};
      return data is Map<String, dynamic> ? data : {};
    } catch (e) {
      debugPrint("Attendance error: $e");
      return {};
    }
  }

  // 📝 Mark Attendance
  static Future<Map<String, dynamic>?> markAttendance({required String studentId, required String status, String? date}) async {
    try {
      final token = await _getToken();
      final body = <String, dynamic>{
        "studentId": studentId,
        "status": status,
      };
      
      if (date != null && date.isNotEmpty) {
        body["date"] = date;
      }
      
      final res = await ApiService.post("/attendance/mark", body, token: token);
      return res is Map<String, dynamic> ? res : null;
    } catch (e) {
      debugPrint("Mark attendance error: $e");
      rethrow;
    }
  }

  // 🕒 Shifts
  static Future<List<dynamic>> getShifts([String? branchId, bool includeInactive = false]) async {
    try {
      final token = await _getToken();
      final queryParams = <String, dynamic>{};
      if (branchId != null) queryParams["branchId"] = branchId;
      if (includeInactive) queryParams["includeInactive"] = true;
      
      final res = await ApiService.get("/shifts", token, queryParams: queryParams);
      final data = res["data"] ?? res;
      return data is List ? data : [];
    } catch (e) {
      debugPrint("Shifts error: $e");
      return [];
    }
  }

  // 🏢 Floor Stats
  static Future<List<dynamic>> getFloorStats([String? branchId]) async {
    try {
      final token = await _getToken();
      final queryParams = branchId != null ? {"branchId": branchId} : null;
      final res = await ApiService.get("/seats/floor-stats", token, queryParams: queryParams);
      final data = res["data"] ?? res;
      return data is List ? data : [];
    } catch (e) {
      debugPrint("Floor stats error: $e");
      return [];
    }
  }

  // 🧾 Library Subscriptions — all records (active, cancelled, expired)
  // Endpoint: GET /library-subscriptions
  static Future<List<dynamic>> getBillingHistory({int limit = 100}) async {
    try {
      final token = await _getToken();
      final res = await ApiService.get(
        '/library-subscriptions',
        token,
        queryParams: {'limit': limit},
      );
      final data = res['data'] ?? res;
      return data is List ? List<dynamic>.from(data) : [];
    } catch (e) {
      debugPrint('Billing history error: $e');
      rethrow;
    }
  }

  // 🎟️ Active Library Subscription
  // Endpoint: GET /library-subscriptions/active
  static Future<dynamic> getActiveSubscription() async {
    try {
      final token = await _getToken();
      final res = await ApiService.get('/library-subscriptions/active', token);
      return res['data'] ?? res;
    } catch (e) {
      debugPrint('Active subscription error: $e');
      return null;
    }
  }

  // 📦 Subscription Plans
  // Endpoint: GET /plans
  static Future<List<dynamic>> getSubscriptionPlans() async {
    try {
      final token = await _getToken();
      final res = await ApiService.get('/plans', token);
      final data = res['data'] ?? res;
      return data is List ? List<dynamic>.from(data) : [];
    } catch (e) {
      debugPrint('Subscription plans error: $e');
      return [];
    }
  }

  // ⚙️ Library Settings
  static Future<Map<String, dynamic>> getLibrarySettings([String? branchId]) async {
    try {
      final token = await _getToken();
      final queryParams = branchId != null ? {"branchId": branchId} : null;
      final res = await ApiService.get("/settings/library", token, queryParams: queryParams);
      // Ensure we return the data part
      return res["data"] ?? {};
    } catch (e) {
      debugPrint("Library settings error: $e");
      return {};
    }
  }
}
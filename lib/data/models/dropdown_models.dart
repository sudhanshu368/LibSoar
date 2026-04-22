class ApiBranchModel {
  final String id;
  final String code;
  final String name;
  final bool isDefault;

  ApiBranchModel({
    required this.id,
    required this.code,
    required this.name,
    required this.isDefault,
  });

  factory ApiBranchModel.fromJson(Map<String, dynamic> json) {
    return ApiBranchModel(
      id: json['id'] ?? '',
      code: json['code'] ?? '',
      name: json['name'] ?? 'Unknown Branch',
      isDefault: json['isDefault'] ?? false,
    );
  }
}

class ApiShiftModel {
  final String id;
  final String name;
  final String timing;
  final int fee;
  final int floatingPrice;

  ApiShiftModel({
    required this.id,
    required this.name,
    required this.timing,
    required this.fee,
    required this.floatingPrice,
  });

  factory ApiShiftModel.fromJson(Map<String, dynamic> json) {
    return ApiShiftModel(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown Shift',
      timing: json['timing'] ?? '',
      fee: json['fee'] ?? 0,
      floatingPrice: json['floatingPrice'] ?? 0,
    );
  }
}
class ApiSeatModel {
  final String id;
  final String seatNumber;

  ApiSeatModel({
    required this.id,
    required this.seatNumber,
  });

  factory ApiSeatModel.fromJson(Map<String, dynamic> json) {
    // Some API responses might give "number" instead of "seatNumber"
    String label = json['seatNumber'] ?? json['number']?.toString() ?? 'Unknown';
    return ApiSeatModel(
      id: json['id'] ?? '',
      seatNumber: label,
    );
  }
}

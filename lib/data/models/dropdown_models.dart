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
    // In your response, 'id' is the UUID and 'number' is the label.
    // However, some responses might have them swapped or use '_id', 'seatId', or 'uuid'.
    String idVal = json['id']?.toString() ?? '';
    String underscoreId = json['_id']?.toString() ?? '';
    String seatIdField = json['seatId']?.toString() ?? '';
    String uuidField = json['uuid']?.toString() ?? '';
    String numVal = json['number']?.toString() ?? json['seatNumber']?.toString() ?? '';

    // Label should be the seat number/label
    String label = numVal.isNotEmpty ? numVal : idVal;

    // Robust Logic to find the real UUID:
    String realId = idVal;
    
    // 1. Check common fields first
    if (underscoreId.length > 30) realId = underscoreId;
    else if (seatIdField.length > 30) realId = seatIdField;
    else if (uuidField.length > 30) realId = uuidField;
    // 2. Otherwise scan all fields for a UUID-like string
    else {
      json.forEach((key, value) {
        final valStr = value?.toString() ?? '';
        if (valStr.length > 30 && valStr.contains('-')) {
          realId = valStr;
        }
      });
    }

    return ApiSeatModel(
      id: realId,
      seatNumber: label,
    );
  }
}

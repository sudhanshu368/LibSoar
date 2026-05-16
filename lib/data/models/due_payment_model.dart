class DuePaymentModel {
  final String id;
  final String studentId;
  final StudentSummary student;
  final ShiftSummary shiftData;
  final String shiftId;
  final String startDate;
  final String endDate;
  final String status;
  final double totalFee;
  final double paidAmount;
  final double dueAmount;

  DuePaymentModel({
    required this.id,
    required this.studentId,
    required this.student,
    required this.shiftData,
    required this.shiftId,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.totalFee,
    required this.paidAmount,
    required this.dueAmount,
  });

  factory DuePaymentModel.fromJson(Map<String, dynamic> json) {
    return DuePaymentModel(
      id: json['id'] ?? '',
      studentId: json['studentId'] ?? '',
      student: StudentSummary.fromJson(json['student'] ?? {}),
      shiftData: ShiftSummary.fromJson(json['shiftData'] ?? {}),
      shiftId: json['shift'] ?? '',
      startDate: json['startDate'] ?? '',
      endDate: json['endDate'] ?? '',
      status: json['status'] ?? '',
      totalFee: (json['totalFee'] ?? 0).toDouble(),
      paidAmount: (json['paidAmount'] ?? 0).toDouble(),
      dueAmount: (json['dueAmount'] ?? 0).toDouble(),
    );
  }
}

class StudentSummary {
  final String id;
  final String name;
  final String phone;
  final String memberId;
  final String? seatId;
  final String? seatType;
  final String? seatNumber;

  StudentSummary({
    required this.id,
    required this.name,
    required this.phone,
    required this.memberId,
    this.seatId,
    this.seatType,
    this.seatNumber,
  });

  factory StudentSummary.fromJson(Map<String, dynamic> json) {
    return StudentSummary(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown',
      phone: json['phone'] ?? '',
      memberId: json['memberId'] ?? '',
      seatId: json['seatId'],
      seatType: json['seatType'],
      seatNumber: json['seatNumber'],
    );
  }
}

class ShiftSummary {
  final String id;
  final String name;

  ShiftSummary({
    required this.id,
    required this.name,
  });

  factory ShiftSummary.fromJson(Map<String, dynamic> json) {
    return ShiftSummary(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown',
    );
  }
}

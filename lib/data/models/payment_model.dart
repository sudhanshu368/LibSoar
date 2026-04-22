class PaymentModel {
  final String id;
  final String studentId;
  final String studentName;
  final String studentPhone;
  final double amount;
  final String paymentMethod;
  final String status;
  final String paymentDate;
  final String? notes;
  final String? receiptNo;
  final String? receivedBy;
  final String? refundedAt;
  final String? refundReason;
  final String? refundedBy;

  PaymentModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.studentPhone,
    required this.amount,
    required this.paymentMethod,
    required this.status,
    required this.paymentDate,
    this.notes,
    this.receiptNo,
    this.receivedBy,
    this.refundedAt,
    this.refundReason,
    this.refundedBy,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'] ?? '',
      studentId: json['studentId'] ?? '',
      studentName: json['studentName'] ?? 'Unknown',
      studentPhone: json['studentPhone'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      paymentMethod: json['paymentMethod'] ?? 'UNKNOWN',
      status: json['status'] ?? 'pending',
      paymentDate: json['paymentDate'] ?? '',
      notes: json['notes'],
      receiptNo: json['receiptNo'],
      receivedBy: json['receivedBy'],
      refundedAt: json['refundedAt'],
      refundReason: json['refundReason'],
      refundedBy: json['refundedBy'],
    );
  }
}

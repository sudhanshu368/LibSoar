import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../widgets/custom_image_widget.dart';

class HomePaymentDueWidget extends StatelessWidget {
  final List<dynamic> data; // 🔥 backend data

  const HomePaymentDueWidget({super.key, required this.data});

  String formatAmount(dynamic val) {
    final v = (val ?? 0).toDouble();
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(0)}k';
    return '₹${v.toStringAsFixed(0)}';
  }

  int _calculateOverdueDays(dynamic item) {
    try {
      final subscriptionEndDate = item["subscriptionEndDate"];
      if (subscriptionEndDate == null) return 0;

      final endDate = DateTime.parse(subscriptionEndDate);
      final now = DateTime.now();
      final difference = now.difference(endDate).inDays;

      return difference > 0 ? difference : 0;
    } catch (e) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          /// 🔹 HEADER
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Payment Due',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${data.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 8),

          /// 🔹 EMPTY STATE
          if (data.isEmpty)
            const Center(child: Text("No pending dues")),

          /// 🔹 LIST
          ...data.map((item) {
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [

                  /// 👤 AVATAR
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: CustomImageWidget(
                      imageUrl: item["avatar"] ??
                          "https://ui-avatars.com/api/?name=${item["studentName"] ?? item["name"] ?? 'S'}",
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                    ),
                  ),

                  const SizedBox(width: 10),

                  /// 👤 INFO
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item["studentName"] ?? item["name"] ?? "",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_calculateOverdueDays(item) > 0)
                          Text(
                            "${_calculateOverdueDays(item)} days overdue",
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                      ],
                    ),
                  ),

                  /// 💰 AMOUNT
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatAmount(item["dueAmount"] ?? item["feeDue"] ?? 0),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                      const Text(
                        "Due",
                        style: TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum BadgeStatus { active, pending, expired, warning, info }

class StatusBadgeWidget extends StatelessWidget {
  final String label;
  final BadgeStatus status;
  final double fontSize;

  const StatusBadgeWidget({
    super.key,
    required this.label,
    required this.status,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _getColors();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.$2,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: colors.$1,
        ),
      ),
    );
  }

  (Color, Color) _getColors() {
    switch (status) {
      case BadgeStatus.active:
        return (const Color(0xFF059669), const Color(0xFFD1FAE5));
      case BadgeStatus.pending:
        return (const Color(0xFFD97706), const Color(0xFFFEF3C7));
      case BadgeStatus.expired:
        return (const Color(0xFFDC2626), const Color(0xFFFEE2E2));
      case BadgeStatus.warning:
        return (const Color(0xFFD97706), const Color(0xFFFEF3C7));
      case BadgeStatus.info:
        return (const Color(0xFF2563EB), const Color(0xFFDBEAFE));
    }
  }
}

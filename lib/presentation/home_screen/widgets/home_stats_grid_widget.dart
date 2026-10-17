import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
  });
}

class HomeStatsGridWidget extends StatefulWidget {
  final Map<String, dynamic>? data; // 🔥 backend data

  const HomeStatsGridWidget({super.key, this.data});

  @override
  State<HomeStatsGridWidget> createState() => _HomeStatsGridWidgetState();
}

class _HomeStatsGridWidgetState extends State<HomeStatsGridWidget> {
  List<_StatItem> _stats = [];

  @override
  void initState() {
    super.initState();
    _prepareData();
  }

  // 🔥 DATA MAPPING — Matches exact reference layout:
  // TOTAL STUDENTS, ACTIVE STUDENTS, TOTAL SEATS, BOOKED SEATS
  void _prepareData() {
    final d = widget.data ?? {};

    final totalStudents = (d["totalStudents"] ?? 0).toString();
    final activeStudents = (d["activeStudents"] ??
            d["todayAttendance"] ??
            d["presentToday"] ??
            d["attendance"] ??
            0)
        .toString();
    final totalSeats = (d["totalSeats"] ?? 0).toString();
    final bookedSeats = (d["bookedSeats"] ?? 0).toString();

    _stats = [
      // 1. TOTAL STUDENTS (Lavender Tint / Indigo Icon)
      _StatItem(
        label: 'TOTAL STUDENTS',
        value: totalStudents,
        icon: Icons.people_alt_rounded,
        iconColor: const Color(0xFF4F46E5),
        iconBgColor: const Color(0xFFEDE9FE),
      ),
      // 2. ACTIVE STUDENTS (Mint Green Tint / Emerald Icon)
      _StatItem(
        label: 'ACTIVE STUDENTS',
        value: activeStudents,
        icon: Icons.person_rounded,
        iconColor: const Color(0xFF10B981),
        iconBgColor: const Color(0xFFD1FAE5),
      ),
      // 3. TOTAL SEATS (Soft Blue Tint / Blue Icon)
      _StatItem(
        label: 'TOTAL SEATS',
        value: totalSeats,
        icon: Icons.chair_rounded,
        iconColor: const Color(0xFF3B82F6),
        iconBgColor: const Color(0xFFDBEAFE),
      ),
      // 4. BOOKED SEATS (Soft Purple Tint / Purple Icon)
      _StatItem(
        label: 'BOOKED SEATS',
        value: bookedSeats,
        icon: Icons.chair_alt_rounded,
        iconColor: const Color(0xFF8B5CF6),
        iconBgColor: const Color(0xFFF3E8FF),
      ),
    ];
  }

  @override
  void didUpdateWidget(covariant HomeStatsGridWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _prepareData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_stats.isEmpty) {
      _prepareData();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
        final childAspectRatio = constraints.maxWidth < 360 ? 1.25 : 1.34;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: _stats.length,
          itemBuilder: (context, i) => _StatCard(stat: _stats[i]),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final _StatItem stat;

  const _StatCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.surface,
            cs.surfaceContainerHighest.withValues(alpha: 0.45),
          ],
        ),
        border: Border.all(
          color: cs.outline.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ─── Line 1: Uppercase Label & Pastel Icon Badge ───
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  stat.label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF94A3B8),
                    letterSpacing: 0.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: stat.iconBgColor,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  stat.icon,
                  size: 20,
                  color: stat.iconColor,
                ),
              ),
            ],
          ),

          // ─── Line 2: Large Bold Value ───
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              stat.value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
                height: 1.0,
                letterSpacing: -0.5,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
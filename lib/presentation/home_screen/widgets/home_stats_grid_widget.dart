import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String? trend;
  final bool trendUp;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    this.trend,
    this.trendUp = true,
  });
}

class HomeStatsGridWidget extends StatefulWidget {
  final Map<String, dynamic>? data; // 🔥 backend data

  const HomeStatsGridWidget({super.key, this.data});

  @override
  State<HomeStatsGridWidget> createState() => _HomeStatsGridWidgetState();
}

class _HomeStatsGridWidgetState extends State<HomeStatsGridWidget>
    with TickerProviderStateMixin {

  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;
  List<_StatItem> _stats = [];

  @override
  void initState() {
    super.initState();

    // _prepareData() moved to didChangeDependencies to safely use Theme.of(context)

    _controllers = List.generate(
      4,
          (i) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 400 + i * 80),
      ),
    );

    _animations = _controllers
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeOutCubic))
        .toList();

    for (var i = 0; i < 4; i++) {
      Future.delayed(Duration(milliseconds: i * 80), () {
        if (mounted) _controllers[i].forward();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _prepareData(); // 🔥 Safe to use Theme.of(context) here
  }

  // 🔥 DATA MAPPING (IMPORTANT)
  void _prepareData() {
    final d = widget.data ?? {};
    final isDark = Theme.of(context).brightness == Brightness.dark;

    _stats = [
      _StatItem(
        label: 'Total Students',
        value: (d["totalStudents"] ?? 0).toString(),
        icon: Icons.people_outline_rounded,
        iconColor: const Color(0xFF4F46E5),
        iconBg: const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.15 : 0.08),
      ),
      _StatItem(
        label: 'Active Students',
        value: (d["activeStudents"] ?? 0).toString(),
        icon: Icons.person_outline_rounded,
        iconColor: const Color(0xFF10B981),
        iconBg: const Color(0xFF10B981).withValues(alpha: isDark ? 0.15 : 0.08),
      ),
      _StatItem(
        label: 'Total Seats',
        value: (d["totalSeats"] ?? 0).toString(),
        icon: Icons.chair_outlined,
        iconColor: const Color(0xFF3B82F6),
        iconBg: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.15 : 0.08),
      ),
      _StatItem(
        label: 'Booked Seats',
        value: (d["bookedSeats"] ?? 0).toString(),
        icon: Icons.event_seat_outlined,
        iconColor: const Color(0xFF8B5CF6),
        iconBg: const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.15 : 0.08),
      ),
    ];
  }

  @override
  void didUpdateWidget(covariant HomeStatsGridWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _prepareData(); // 🔄 refresh when API data changes
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_stats.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.45,
          ),
          itemCount: _stats.length,
          itemBuilder: (context, i) => FadeTransition(
            opacity: _animations[i],
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.1),
                end: Offset.zero,
              ).animate(_animations[i]),
              child: _StatCard(stat: _stats[i]),
            ),
          ),
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
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.surface,
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
          ],
        ),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  stat.label.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: stat.iconBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: stat.iconColor.withValues(alpha: 0.1)),
                ),
                child: Icon(stat.icon, size: 20, color: stat.iconColor),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  stat.value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    letterSpacing: -1,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // Optional: Add a small trend or descriptive text here if needed
              // Currently just keeping it clean as per original design but more modern
            ],
          ),
        ],
      ),
    );
  }
}
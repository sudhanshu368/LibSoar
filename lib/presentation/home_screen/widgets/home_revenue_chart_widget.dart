import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeRevenueChartWidget extends StatefulWidget {
  final Map<String, dynamic>? data;

  const HomeRevenueChartWidget({super.key, this.data});

  @override
  State<HomeRevenueChartWidget> createState() => _HomeRevenueChartWidgetState();
}

class _HomeRevenueChartWidgetState extends State<HomeRevenueChartWidget> {
  bool _isWeekly = true;

  List<FlSpot> _weeklySpots = [];
  List<FlSpot> _monthlySpots = [];

  List<String> _weekLabels = [];
  List<String> _monthLabels = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepareData();
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant HomeRevenueChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _prepareData();
    }
  }

  Map<String, dynamic>? _itemAsMap(dynamic item) {
    if (item is Map<String, dynamic>) return item;
    if (item is Map) return Map<String, dynamic>.from(item);
    return null;
  }

  double _readRevenue(Map<String, dynamic> m) {
    final v = m["revenue"] ?? m["amount"] ?? m["total"] ?? m["value"];
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  String _readLabel(Map<String, dynamic> m) {
    final v = m["name"] ?? m["day"] ?? m["label"] ?? m["period"] ?? m["month"];
    return v?.toString() ?? "";
  }

  void _prepareData() {
    dynamic weeklyData = [];
    dynamic monthlyData = [];
    final raw = widget.data;

    if (raw is List) {
      weeklyData = raw;
    } else if (raw is Map) {
      final m = Map<String, dynamic>.from(raw as Map);
      final inner = m["data"];
      if (inner is Map) {
        final im = Map<String, dynamic>.from(inner);
        weeklyData =
            im["weekly"] ?? im["week"] ?? m["weekly"] ?? m["week"] ?? [];
        monthlyData =
            im["monthly"] ?? im["month"] ?? m["monthly"] ?? m["month"] ?? [];
      } else if (inner is List) {
        weeklyData = inner;
        monthlyData = m["monthly"] ?? m["month"] ?? [];
      } else {
        weeklyData = m["weekly"] ?? m["week"] ?? [];
        monthlyData = m["monthly"] ?? m["month"] ?? [];
      }
    }

    final weekly = (weeklyData is List && weeklyData.isNotEmpty)
        ? weeklyData
        : _createDefaultWeeklyData();

    final monthly = (monthlyData is List && monthlyData.isNotEmpty)
        ? monthlyData
        : _createDefaultMonthlyData();

    _weeklySpots = [];
    _weekLabels = [];
    for (int i = 0; i < weekly.length; i++) {
      final item = _itemAsMap(weekly[i]);
      if (item != null) {
        _weeklySpots.add(FlSpot(i.toDouble(), _readRevenue(item)));
        final lbl = _readLabel(item);
        _weekLabels.add(
          lbl.isNotEmpty ? lbl : _defaultDayShort(i, weekly.length),
        );
      }
    }

    _monthlySpots = [];
    _monthLabels = [];
    for (int i = 0; i < monthly.length; i++) {
      final item = _itemAsMap(monthly[i]);
      if (item != null) {
        _monthlySpots.add(FlSpot(i.toDouble(), _readRevenue(item)));
        final lbl = _readLabel(item);
        _monthLabels.add(lbl.isNotEmpty ? lbl : _defaultMonthShort(i));
      }
    }
  }

  String _defaultDayShort(int i, int len) {
    const days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    if (len <= 7 && i < days.length) return days[i];
    return "${i + 1}";
  }

  String _defaultMonthShort(int i) {
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    return i < months.length ? months[i] : "${i + 1}";
  }

  List<Map<String, dynamic>> _createDefaultWeeklyData() {
    return [
      {"revenue": 0.0, "name": "Mon"},
      {"revenue": 0.0, "name": "Tue"},
      {"revenue": 0.0, "name": "Wed"},
      {"revenue": 0.0, "name": "Thu"},
      {"revenue": 0.0, "name": "Fri"},
      {"revenue": 0.0, "name": "Sat"},
      {"revenue": 0.0, "name": "Sun"},
    ];
  }

  List<Map<String, dynamic>> _createDefaultMonthlyData() {
    return [
      {"revenue": 0.0, "name": "Jan"},
      {"revenue": 0.0, "name": "Feb"},
      {"revenue": 0.0, "name": "Mar"},
      {"revenue": 0.0, "name": "Apr"},
      {"revenue": 0.0, "name": "May"},
      {"revenue": 0.0, "name": "Jun"},
      {"revenue": 0.0, "name": "Jul"},
      {"revenue": 0.0, "name": "Aug"},
      {"revenue": 0.0, "name": "Sep"},
      {"revenue": 0.0, "name": "Oct"},
      {"revenue": 0.0, "name": "Nov"},
      {"revenue": 0.0, "name": "Dec"},
    ];
  }

  String _formatRupee(double val) {
    if (val >= 100000) return '₹${(val / 100000).toStringAsFixed(1)}L';
    if (val >= 1000) return '₹${(val / 1000).toStringAsFixed(1)}k';
    return '₹${val.toStringAsFixed(0)}';
  }

  double _chartMaxY(List<FlSpot> spots) {
    if (spots.isEmpty) return 8;
    final m = spots.map((s) => s.y).reduce(math.max);
    if (m <= 0) return 8;
    return m * 1.22;
  }

  String _growthLabel() {
    final d = widget.data;
    if (d == null) return "+0%";
    if (_isWeekly) {
      final g = d["growth"] ?? d["weekOverWeek"];
      return g == null ? "+0%" : g.toString();
    }
    final g = d["monthlyGrowth"] ?? d["monthOverMonth"] ?? d["growth"];
    return g == null ? "+0%" : g.toString();
  }

  @override
  Widget build(BuildContext context) {
    var spots = _isWeekly ? _weeklySpots : _monthlySpots;
    var labels = _isWeekly ? _weekLabels : _monthLabels;

    if (spots.isEmpty) {
      if (_isWeekly) {
        spots = List.generate(7, (i) => FlSpot(i.toDouble(), 0));
        labels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
      } else {
        spots = List.generate(12, (i) => FlSpot(i.toDouble(), 0));
        labels = [
          "Jan",
          "Feb",
          "Mar",
          "Apr",
          "May",
          "Jun",
          "Jul",
          "Aug",
          "Sep",
          "Oct",
          "Nov",
          "Dec",
        ];
      }
    }

    final maxY = _chartMaxY(spots);
    final total = spots.fold(0.0, (sum, e) => sum + e.y);
    final growthStr = _growthLabel();
    final isPositiveGrowth = !growthStr.trim().startsWith("-");

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;

        return Container(
          padding: EdgeInsets.all(isNarrow ? 12 : 20),
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
            border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
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
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isNarrow ? 8 : 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5B4DFF),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF5B4DFF).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.show_chart_rounded,
                      color: Colors.white,
                      size: isNarrow ? 18 : 22,
                    ),
                  ),
                  SizedBox(width: isNarrow ? 8 : 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Revenue\nOverview',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: isNarrow ? 14 : 16,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _isWeekly ? 'Last 7 days' : 'Year to month view',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: isNarrow ? 11 : 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF94A3B8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _SegmentedToggle(
                    isWeekly: _isWeekly,
                    isNarrow: isNarrow,
                    onWeekly: () => setState(() => _isWeekly = true),
                    onMonthly: () => setState(() => _isWeekly = false),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    _formatRupee(total),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (isPositiveGrowth
                          ? const Color(0xFFD1FAE5)
                          : const Color(0xFFFEE2E2)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      growthStr,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isPositiveGrowth
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: _isWeekly ? 200 : 210,
                child: LineChart(
                  LineChartData(
                    clipData: const FlClipData.all(),
                    lineTouchData: LineTouchData(
                      enabled: true,
                      handleBuiltInTouches: true,
                      touchTooltipData: LineTouchTooltipData(
                        tooltipBgColor: const Color(0xFF0F172A),
                        tooltipRoundedRadius: 10,
                        tooltipPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            final i = spot.x.toInt();
                            final label = (i >= 0 && i < labels.length)
                                ? labels[i]
                                : "";
                            return LineTooltipItem(
                              "",
                              const TextStyle(),
                              children: [
                                TextSpan(
                                  text: label.isNotEmpty ? "$label\n" : "",
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                TextSpan(
                                  text: "₹${spot.y.round()}",
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            );
                          }).toList();
                        },
                      ),
                    ),
                    minY: 0,
                    maxY: maxY,
                    minX: 0,
                    maxX: math.max(0, spots.length - 1.0),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: maxY > 0 ? maxY / 4 : 2,
                      getDrawingHorizontalLine: (value) {
                        return const FlLine(
                          color: Color(0xFFF1F5F9),
                          strokeWidth: 1.2,
                        );
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 44,
                          interval: maxY > 0 ? maxY / 4 : 2,
                          getTitlesWidget: (val, meta) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Text(
                                _formatRupee(val),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF94A3B8),
                                ),
                                textAlign: TextAlign.end,
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: _isWeekly ? 28 : 32,
                          interval: 1,
                          getTitlesWidget: (val, meta) {
                            final i = val.toInt();
                            if (i < 0 || i >= labels.length) {
                              return const SizedBox();
                            }
                            if (!_isWeekly && labels.length > 6 && i % 2 == 1) {
                              return const SizedBox(height: 22);
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                labels[i],
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: _isWeekly ? 11 : 10,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        curveSmoothness: 0.35,
                        color: const Color(0xFF5B4DFF),
                        barWidth: 3.2,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF5B4DFF).withValues(alpha: 0.22),
                              const Color(0xFF5B4DFF).withValues(alpha: 0.0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SegmentedToggle extends StatelessWidget {
  final bool isWeekly;
  final bool isNarrow;
  final VoidCallback onWeekly;
  final VoidCallback onMonthly;

  const _SegmentedToggle({
    required this.isWeekly,
    this.isNarrow = false,
    required this.onWeekly,
    required this.onMonthly,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isNarrow ? 3 : 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SegBtn(
            label: 'Weekly',
            selected: isWeekly,
            isNarrow: isNarrow,
            onTap: onWeekly,
          ),
          _SegBtn(
            label: 'Monthly',
            selected: !isWeekly,
            isNarrow: isNarrow,
            onTap: onMonthly,
          ),
        ],
      ),
    );
  }
}

class _SegBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isNarrow;
  final VoidCallback onTap;

  const _SegBtn({
    required this.label,
    required this.selected,
    this.isNarrow = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: isNarrow ? 9 : 14,
            vertical: isNarrow ? 6 : 7,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: selected ? const Color(0xFF5B4DFF) : Colors.transparent,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFF5B4DFF).withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: isNarrow ? 11 : 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: selected ? Colors.white : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }
}

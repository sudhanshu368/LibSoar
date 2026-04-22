import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class _PaymentMethod {
  final String name;
  final double amount;
  final double pct;
  final Color color;

  const _PaymentMethod({
    required this.name,
    required this.amount,
    required this.pct,
    required this.color,
  });
}

class HomePaymentMethodsWidget extends StatefulWidget {
  final Map<String, dynamic>? data;

  const HomePaymentMethodsWidget({super.key, this.data});

  @override
  State<HomePaymentMethodsWidget> createState() =>
      _HomePaymentMethodsWidgetState();
}

class _HomePaymentMethodsWidgetState extends State<HomePaymentMethodsWidget> {
  int _touchedIndex = -1;

  List<_PaymentMethod> _methods = [];

  @override
  void initState() {
    super.initState();
    _prepareData();
  }

  @override
  void didUpdateWidget(covariant HomePaymentMethodsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _prepareData();
      setState(() {});
    }
  }

  Map<String, dynamic>? _rowAsMap(dynamic m) {
    if (m is Map<String, dynamic>) return m;
    if (m is Map) return Map<String, dynamic>.from(m);
    return null;
  }

  double _readAmount(Map<String, dynamic> m) {
    dynamic raw = m["amount"] ??
        m["total"] ??
        m["sum"] ??
        m["value"] ??
        m["paid"] ??
        m["netAmount"] ??
        m["amountInRupees"] ??
        m["collected"];
    if (raw == null) return 0;
    if (raw is num) return raw.toDouble();
    final s = raw.toString().replaceAll(",", "");
    final v = double.tryParse(s) ?? 0;
    // Some APIs send paise
    if (m["unit"]?.toString().toLowerCase() == "paise" ||
        m["currencyUnit"]?.toString().toLowerCase() == "paise") {
      return v / 100;
    }
    if (m["amountPaise"] != null) {
      final p = m["amountPaise"];
      final n = p is num ? p.toDouble() : double.tryParse(p.toString()) ?? 0;
      return n / 100;
    }
    return v;
  }

  double _readPct(Map<String, dynamic> m) {
    final raw = m["percentage"] ?? m["percent"] ?? m["pct"] ?? m["share"];
    if (raw == null) return 0;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString().replaceAll("%", "")) ?? 0;
  }

  double? _parseAmountLiteral(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(",", ""));
  }

  /// Skip aggregate / non-method rows some APIs include in the list.
  bool _shouldSkipPaymentRowName(String name) {
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

  /// Same skip check on any field (name is often empty but label/title = "Total Revenue").
  bool _shouldSkipPaymentRow(Map<String, dynamic> m) {
    const keys = [
      'name',
      'method',
      'label',
      'type',
      'title',
      'category',
      'paymentMode',
      'payment_type',
      'channel',
      'mode',
    ];
    for (final k in keys) {
      final v = m[k];
      if (v != null && _shouldSkipPaymentRowName(v.toString())) {
        return true;
      }
    }
    return false;
  }

  /// Overall collection total (100% base). Prefer API root/summary total over sum of rows.
  double? _readGrandTotalFromPayload(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final maps = <Map<String, dynamic>>[
      m,
      if (m["summary"] is Map)
        Map<String, dynamic>.from(m["summary"] as Map),
      if (m["data"] is Map) Map<String, dynamic>.from(m["data"] as Map),
    ];
    const keys = [
      "total",
      "grandTotal",
      "grand_total",
      "totalAmount",
      "total_amount",
      "netTotal",
      "overallTotal",
      "sum",
      "totalRevenue",
    ];
    for (final map in maps) {
      for (final key in keys) {
        final v = map[key];
        final n = _parseAmountLiteral(v);
        if (n != null && n > 0) return n;
      }
    }
    return null;
  }

  void _prepareData() {
    final raw = widget.data;
    dynamic listData = [];

    if (raw is List) {
      listData = raw;
    } else if (raw is Map) {
      final d = Map<String, dynamic>.from(raw as Map);
      listData = d["methods"] ??
          d["paymentMethods"] ??
          d["byMethod"] ??
          d["breakdown"] ??
          d["distribution"] ??
          d["items"] ??
          d["details"] ??
          d["rows"] ??
          [];
    }

    var list = (listData is List && listData.isNotEmpty)
        ? listData
        : _getDefaultMethods();

    final built = <_PaymentMethod>[];

    for (var row in list) {
      final m = _rowAsMap(row);
      if (m == null) continue;

      if (_shouldSkipPaymentRow(m)) continue;

      final name = (m["name"] ??
              m["method"] ??
              m["mode"] ??
              m["type"] ??
              m["label"] ??
              m["paymentMode"] ??
              m["payment_type"] ??
              m["channel"] ??
              "")
          .toString()
          .trim();

      if (_shouldSkipPaymentRowName(name)) continue;

      final amount = _readAmount(m);
      final pct = _readPct(m);

      built.add(
        _PaymentMethod(
          name: name.isEmpty ? "Other" : name,
          amount: amount,
          pct: pct,
          color: _getColor(name),
        ),
      );
    }

    if (built.isEmpty) {
      for (final def in _getDefaultMethods()) {
        final m = _rowAsMap(def)!;
        built.add(
          _PaymentMethod(
            name: (m["name"] ?? "Other").toString(),
            amount: _readAmount(m),
            pct: _readPct(m),
            color: _getColor((m["name"] ?? "").toString()),
          ),
        );
      }
    }

    built.sort((a, b) => b.amount.compareTo(a.amount));

    final rowSum = built.fold(0.0, (a, b) => a + b.amount);
    final grandTotal = _readGrandTotalFromPayload(raw);

    // 100% = grand total from API when present (e.g. ₹9.3k); else sum of rows.
    // Example: total ₹9.3k, UPI ₹5.6k → 5.6/9.3 ≈ 60.2%
    double denomForPercent = rowSum > 0 ? rowSum : 0.0;
    if (grandTotal != null && grandTotal > 0) {
      if (rowSum <= grandTotal * 1.02) {
        denomForPercent = grandTotal;
      }
      // If lines sum above API total (bad/rounded data), fall back to rowSum so % stays valid
    }

    if (rowSum > 0 && denomForPercent > 0) {
      _methods = built
          .map(
            (m) => _PaymentMethod(
              name: m.name,
              amount: m.amount,
              pct: (m.amount / denomForPercent) * 100,
              color: m.color,
            ),
          )
          .toList();
      return;
    }

    final pctSum = built.fold(0.0, (a, b) => a + b.pct);
    if (pctSum > 0) {
      _methods = built
          .map(
            (m) => _PaymentMethod(
              name: m.name,
              amount: m.amount,
              pct: (m.pct / pctSum) * 100,
              color: m.color,
            ),
          )
          .toList();
      return;
    }

    _methods = built;
  }

  List<Map<String, dynamic>> _getDefaultMethods() {
    return [
      {"name": "Cash", "amount": 0.0, "percentage": 0.0},
      {"name": "UPI", "amount": 0.0, "percentage": 0.0},
      {"name": "Card", "amount": 0.0, "percentage": 0.0},
      {"name": "Bank Transfer", "amount": 0.0, "percentage": 0.0},
    ];
  }

  Color _getColor(String name) {
    final n = name.toLowerCase();
    if (n.contains("upi")) return const Color(0xFF4F46E5);
    if (n.contains("cash")) return const Color(0xFF10B981);
    if (n.contains("card")) return const Color(0xFFF59E0B);
    if (n.contains("bank") || n.contains("transfer") || n.contains("neft")) {
      return const Color(0xFF8B5CF6);
    }
    return const Color(0xFF64748B);
  }

  String _formatAmount(double val) {
    if (val >= 100000) return '₹${(val / 100000).toStringAsFixed(1)}L';
    if (val >= 1000) return '₹${(val / 1000).toStringAsFixed(1)}k';
    return '₹${val.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final amountTotal = _methods.fold(0.0, (a, b) => a + b.amount);
    final usePctForPie = amountTotal <= 0 &&
        _methods.fold(0.0, (a, b) => a + b.pct) > 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.surface,
            cs.surfaceContainerHighest.withValues(alpha: 0.45),
          ],
        ),
        border: Border.all(
          color: cs.outline.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF06B6D4)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.pie_chart_outline_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Methods',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    Text(
                      'Share by how fees were collected',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 132,
                height: 132,
                child: PieChart(
                  PieChartData(
                    centerSpaceRadius: 36,
                    sectionsSpace: 2,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        setState(() {
                          if (response?.touchedSection != null) {
                            _touchedIndex =
                                response!.touchedSection!.touchedSectionIndex;
                          } else {
                            _touchedIndex = -1;
                          }
                        });
                      },
                    ),
                    sections: List.generate(_methods.length, (i) {
                      final m = _methods[i];
                      final value = amountTotal > 0
                          ? m.amount
                          : usePctForPie
                              ? m.pct
                              : (100 / _methods.length);
                      return PieChartSectionData(
                        color: m.color,
                        value: value <= 0 ? 0.001 : value,
                        radius: _touchedIndex == i ? 28 : 24,
                        showTitle: false,
                        borderSide: BorderSide(
                          color: cs.surface.withValues(alpha: 0.9),
                          width: 2,
                        ),
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  children: _methods.map((m) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: m.color,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: m.color.withValues(alpha: 0.45),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              m.name,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            _formatAmount(m.amount),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 44,
                            child: Text(
                              "${m.pct.toStringAsFixed(1)}%",
                              textAlign: TextAlign.end,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

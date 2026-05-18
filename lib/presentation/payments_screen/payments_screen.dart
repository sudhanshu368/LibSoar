import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../widgets/app_drawer.dart';
import '../../core/utils/storage_helper.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/dashboard_service.dart';
import '../../data/models/payment_model.dart';
import '../../core/utils/pdf_helper.dart';
import './widgets/payment_receipt_modal.dart';

class PaymentsScreen extends StatefulWidget {
  final bool fromBottomNav;
  const PaymentsScreen({super.key, this.fromBottomNav = false});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final List<String> _dashboardFilters = [
    'This week',
    'This month',
    'This year',
    'All time',
  ];

  String _selectedMonth = 'This month';
  String _selectedPendingMonth = 'This month';
  String _selectedPeriod = 'This year';
  String _transactionFilter = 'This month';
  String _selectedPaymentMode = 'Cash';
  String _amountInput = '0.00';
  final TextEditingController _amountController = TextEditingController(text: '0.00');
  bool _advancedMode = false;
  String? _selectedStudentId;
  String? _branchId;
  bool _isLoadingTable = false;
  List<PaymentModel> _payments = [];
  List<dynamic> _activeStudents = [];

  double _totalRevenueAmount = 0.0;
  double _totalDueAmount = 0.0;
  List<FlSpot> _revenueSpots = List.generate(12, (i) => FlSpot(i.toDouble(), 0));
  List<FlSpot> _dueSpots = List.generate(12, (i) => FlSpot(i.toDouble(), 0));

  @override
  void initState() {
    super.initState();
    _initData();
    _amountController.addListener(() {
      _amountInput = _amountController.text;
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    setState(() => _isLoadingTable = true);
    _branchId = await StorageHelper.getBranchId();
    await Future.wait([
      _fetchPayments(),
      _fetchDashboardData(),
      _fetchActiveStudents(),
    ]);
  }

  Future<void> _fetchActiveStudents() async {
    if (_branchId == null) return;
    try {
      final res = await DashboardService.getStudents(
        branchId: _branchId, 
        limit: 100, 
        status: 'ACTIVE'
      );
      if (res['success'] == true && res['data'] != null) {
        setState(() {
           _activeStudents = res['data'] as List<dynamic>;
        });
      }
    } catch (e) {
      debugPrint("Error fetching quick payment students: $e");
    }
  }

  // --- Generic period parser exactly matching the UI drops ---
  Map<String, String> _getDateRangeForFilter(String filter) {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate = now;

    switch (filter.toLowerCase()) {
      case 'today':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'this week':
        startDate = now.subtract(Duration(days: now.weekday - 1));
        break;
      case 'last month':
        startDate = DateTime(now.year, now.month - 1, 1);
        endDate = DateTime(now.year, now.month, 0);
        break;
      case 'this year':
        startDate = DateTime(now.year, 1, 1);
        break;
      case 'all time':
        startDate = DateTime(2000, 1, 1);
        break;
      case 'this month':
      default:
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 0);
        break;
    }

    return {
      'startDate': "${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}",
      'endDate': "${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}",
    };
  }

  Future<void> _fetchDashboardData() async {
    if (_branchId == null) return;
    try {
      final token = await StorageHelper.getToken();
      if (token == null) return;

      final now = DateTime.now();

      // 1. Fetch Total Revenue Card Data
      final trRange = _getDateRangeForFilter(_selectedMonth);
      final reqTr = ApiService.get('/payments/summary', token, queryParams: {
        'startDate': trRange['startDate']!,
        'endDate': trRange['endDate']!,
        'branchId': _branchId,
      }).catchError((_) => {'data': null});

      // 2. Fetch Pending Dues Card Data
      final pdRange = _getDateRangeForFilter(_selectedPendingMonth);
      final reqPd = ApiService.get('/payments/summary', token, queryParams: {
        'startDate': pdRange['startDate']!,
        'endDate': pdRange['endDate']!,
        'branchId': _branchId,
      }).catchError((_) => {'data': null});

      // 3. Dynamic intervals for the Line Chart based on _selectedPeriod
      List<Map<String, String>> chartPeriods = [];
      switch (_selectedPeriod.toLowerCase()) {
        case 'this week': // 7 days
          for (int i = 0; i < 7; i++) {
             final d = now.subtract(Duration(days: (now.weekday - 1) - i));
             chartPeriods.add({
                'start': "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}",
                'end': "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}"
             });
          }
          chartPeriods = chartPeriods.reversed.toList(); // order Mon-Sun sequentially
          break;
        case 'this month': // 4 weeks approximation
          final dm = DateTime(now.year, now.month + 1, 0).day;
          chartPeriods.add({'start': "${now.year}-${now.month.toString().padLeft(2, '0')}-01", 'end': "${now.year}-${now.month.toString().padLeft(2, '0')}-07"});
          chartPeriods.add({'start': "${now.year}-${now.month.toString().padLeft(2, '0')}-08", 'end': "${now.year}-${now.month.toString().padLeft(2, '0')}-14"});
          chartPeriods.add({'start': "${now.year}-${now.month.toString().padLeft(2, '0')}-15", 'end': "${now.year}-${now.month.toString().padLeft(2, '0')}-21"});
          chartPeriods.add({'start': "${now.year}-${now.month.toString().padLeft(2, '0')}-22", 'end': "${now.year}-${now.month.toString().padLeft(2, '0')}-${dm.toString().padLeft(2, '0')}"});
          break;
        case 'this year': // 12 months
          for (int i = 1; i <= 12; i++) {
             final em = DateTime(now.year, i + 1, 0);
             chartPeriods.add({
                'start': "${now.year}-${i.toString().padLeft(2, '0')}-01",
                'end': "${now.year}-${i.toString().padLeft(2, '0')}-${em.day.toString().padLeft(2, '0')}"
             });
          }
          break;
        case 'all time': // last 5 years mapping purely across years
          for (int i = 4; i >= 0; i--) {
             chartPeriods.add({
                'start': "${now.year - i}-01-01",
                'end': "${now.year - i}-12-31"
             });
          }
          break;
        default:
          chartPeriods.add({'start': '2000-01-01', 'end': '2040-01-01'});
          break;
      }

      List<Future<dynamic>> graphFutures = [];
      for (var p in chartPeriods) {
         graphFutures.add(ApiService.get('/payments/summary', token, queryParams: {
           'startDate': p['start'],
           'endDate': p['end'],
           'branchId': _branchId,
         }).catchError((_) => {'data': null}));
      }

      // Execute exactly (1 for TR) + (1 for PD) + N graph periods concurrently
      final resultsAll = await Future.wait([reqTr, reqPd, ...graphFutures]);

      final trData = resultsAll[0]['data'];
      final pdData = resultsAll[1]['data'];

      double currentMonthRev = (trData != null ? (trData['totalRevenue'] ?? 0.0) : 0.0).toDouble();
      double currentMonthDue = (pdData != null ? (pdData['duePayment'] ?? 0.0) : 0.0).toDouble();

      List<FlSpot> revSpots = [];
      List<FlSpot> dueSpots = [];
      double graphTotalCollected = 0.0;
      double graphTotalPending = 0.0;

      for (int i = 0; i < chartPeriods.length; i++) {
         final data = resultsAll[i + 2]['data'];
         double r = 0;
         double d = 0;
         if (data != null) {
            r = (data['totalRevenue'] ?? 0.0).toDouble();
            d = (data['duePayment'] ?? 0.0).toDouble();
         }
         revSpots.add(FlSpot(i.toDouble(), r));
         dueSpots.add(FlSpot(i.toDouble(), d));
         graphTotalCollected += r;
         graphTotalPending += d;
      }

      if (mounted) {
        setState(() {
          _totalRevenueAmount = currentMonthRev;
          _totalDueAmount = currentMonthDue;
          _revenueSpots = revSpots;
          _dueSpots = dueSpots;
          
          _graphStatsCollected = graphTotalCollected;
          _graphStatsPending = graphTotalPending;
        });
      }
    } catch (e) {
      debugPrint("Error fetching dashboard stats: $e");
    }
  }

  double _graphStatsCollected = 0.0;
  double _graphStatsPending = 0.0;

  Future<void> _fetchPayments() async {
    if (_branchId == null) return;
    setState(() => _isLoadingTable = true);
    try {
      final token = await StorageHelper.getToken();
      if (token == null) return;

      final now = DateTime.now();
      final dateRange = _getDateRangeForFilter(_transactionFilter);
      final query = {
        'startDate': dateRange['startDate'],
        'endDate': dateRange['endDate'],
        'branchId': _branchId,
        'page': '1',
        'limit': '50',
      };

      final response = await ApiService.get('/payments', token, queryParams: query);
      
      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> data = response['data'];
        setState(() {
          _payments = data.map((e) => PaymentModel.fromJson(e)).toList();
        });
      }
    } catch (e) {
      debugPrint("Error fetching payments: $e");
    } finally {
      if (mounted) setState(() => _isLoadingTable = false);
    }
  }

  Future<void> _submitPayment() async {
    if (_selectedStudentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a student')));
      return;
    }
    double amt = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid amount')));
      return;
    }

    try {
      final token = await StorageHelper.getToken();
      final body = {
        "studentId": _selectedStudentId,
        "amount": amt,
        "mode": _selectedPaymentMode.toUpperCase(),
        "paidAt": DateTime.now().toUtc().toIso8601String(),
        if (_branchId != null) "branchId": _branchId,
      };

      await ApiService.post('/payments', body, token: token);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment recorded successfully!'), backgroundColor: Colors.green));
      
      setState(() {
        _amountInput = '0.00';
        _amountController.text = '0.00';
        _selectedStudentId = null;
      });

      // Refresh data
      await Future.wait([
        _fetchPayments(),
        _fetchDashboardData(),
      ]);

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to record payment: $e'), backgroundColor: Colors.red));
    }
  }

  final List<String> _months = [
    'This Month',
    'Last Month',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  final List<String> _periods = [
    'Last year',
    'Last 6 months',
    'Last 3 months',
    'This month',
  ];

  final List<String> _paymentModes = ['Cash', 'UPI', 'Card', 'Bank Transfer'];

  final List<String> _transactionFilters = [
    'Current Month',
    'Last Month',
    'Last 3 Months',
    'This Year',
    'All Time',
  ];

  void _onQuickAmount(String amount) {
    if (amount == 'Clear') {
      setState(() {
        _amountInput = '0.00';
        _amountController.text = '0.00';
        _amountController.selection = TextSelection.collapsed(offset: _amountController.text.length);
      });
    } else {
      final val = amount.replaceAll('₹', '');
      setState(() {
        _amountInput = val;
        _amountController.text = val;
        _amountController.selection = TextSelection.collapsed(offset: val.length);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: widget.fromBottomNav
          ? null
          : const AppDrawer(activeItem: 'Revenue'),
      body: SafeArea(
        child: Column(
          children: [
            // AppBar row - only show when opened from drawer
            if (!widget.fromBottomNav)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Builder(
                      builder: (ctx) => GestureDetector(
                        onTap: () => Scaffold.of(ctx).openDrawer(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.menu_rounded,
                            size: 20,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Payments',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFF4F46E5),
                onRefresh: _initData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Gradient Header
                      _buildGradientHeader(),
                      const SizedBox(height: 16),
                    // Summary Cards Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            title: 'Total Revenue',
                            value: '₹${_totalRevenueAmount.toStringAsFixed(0)}',
                            color: const Color(0xFF4F46E5),
                            selectedMonth: _selectedMonth,
                            onMonthChanged: (v) {
                                setState(() => _selectedMonth = v!);
                                _fetchDashboardData();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSummaryCard(
                            title: 'Pending Dues',
                            value: '₹${_totalDueAmount.toStringAsFixed(0)}',
                            color: const Color(0xFFEF4444),
                            selectedMonth: _selectedPendingMonth,
                            onMonthChanged: (v) {
                                setState(() => _selectedPendingMonth = v!);
                                _fetchDashboardData();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Revenue Overview + Quick Payment
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth > 700) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: _buildRevenueOverview()),
                              const SizedBox(width: 16),
                              Expanded(flex: 2, child: _buildQuickPayment()),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            _buildRevenueOverview(),
                            const SizedBox(height: 16),
                            _buildQuickPayment(),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    // Transactions Table
                    _buildTransactionsTable(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(40),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                '₹',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Library Revenue',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Dashboard / Revenue',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withAlpha(180),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {});
              _fetchPayments();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(40),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withAlpha(60)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Refresh',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required Color color,
    required String selectedMonth,
    required ValueChanged<String?> onMonthChanged,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _buildDropdown(
                value: selectedMonth,
                items: _dashboardFilters,
                onChanged: onMonthChanged,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: color.withAlpha(180),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueOverview() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + dropdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Revenue overview',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              _buildDropdown(
                value: _selectedPeriod,
                items: _dashboardFilters,
                onChanged: (v) {
                   setState(() => _selectedPeriod = v!);
                   _fetchDashboardData();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Legend
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _buildLegendItem('Total Revenue', const Color(0xFF4F46E5)),
              _buildLegendItem('Pending Dues', const Color(0xFFEF4444)),
            ],
          ),
          const SizedBox(height: 16),
          // Line chart
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (value) =>
                      FlLine(color: const Color(0xFFE2E8F0), strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        const months = [
                          'Jan',
                          'Feb',
                          'Mar',
                          'Apr',
                          'May',
                          'Jun',
                          'Jul',
                          'Aug',
                          'Sep',
                          'Oct',
                          'Nov',
                          'Dec',
                        ];
                        final idx = value.toInt();
                        if (idx < 0 || idx >= months.length) {
                          return const SizedBox();
                        }
                        return Text(
                          months[idx],
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            color: const Color(0xFF94A3B8),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: const Color(0xFF1E293B),
                  ),
                ),
                lineBarsData: [
                  _buildLineBar(
                    spots: _revenueSpots,
                    color: const Color(0xFF4F46E5),
                  ),
                  _buildLineBar(
                    spots: _dueSpots,
                    color: const Color(0xFFEF4444),
                  ),
                ],
                minX: 0,
                maxX: 11,
                minY: 0,
                maxY: _getMaxRevenueValue(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),
          // Bottom stats
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  label: 'Collected (period)',
                  value: '₹${_graphStatsCollected.toStringAsFixed(0)}',
                  color: const Color(0xFF10B981),
                ),
              ),
              Container(width: 1, height: 36, color: const Color(0xFFE2E8F0)),
              Expanded(
                child: _buildStatItem(
                  label: 'Pending dues',
                  value: '₹${_graphStatsPending.toStringAsFixed(0)}',
                  color: const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _getMaxRevenueValue() {
    double max = 1000.0;
    for (var s in _revenueSpots) {
      if (s.y > max) max = s.y;
    }
    for (var s in _dueSpots) {
      if (s.y > max) max = s.y;
    }
    return max * 1.2; // Add headroom
  }

  LineChartBarData _buildLineBar({
    required List<FlSpot> spots,
    required Color color,
  }) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: const Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPayment() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + Advanced toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Quick payment',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Row(
                children: [
                  Text(
                    'Advanced',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: _advancedMode,
                      onChanged: (v) => setState(() => _advancedMode = v),
                      activeThumbColor: const Color(0xFF4F46E5),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Select Student
          Text(
            'Select student',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${_activeStudents.length} active • tap one to select',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 10),
          // Student list
          Column(
            children: _activeStudents.take(5).map((student) {
              final isSelected = _selectedStudentId == student['id'];
              return GestureDetector(
                onTap: () => setState(
                  () => _selectedStudentId = isSelected ? null : student['id'],
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFEEF2FF)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFFE2E8F0),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF4F46E5)
                              : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            (student['name'] as String?)?.isNotEmpty == true ? (student['name'] as String)[0].toUpperCase() : '?',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student['name'] ?? 'Unknown',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              '${student['phone'] ?? 'No Phone'}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF4F46E5),
                          size: 18,
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Payment Mode
          Text(
            'Payment mode',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          _buildDropdown(
            value: _selectedPaymentMode,
            items: _paymentModes,
            onChanged: (v) => setState(() => _selectedPaymentMode = v!),
            fullWidth: true,
          ),
          const SizedBox(height: 16),
          // Amount Input
          Text(
            'Amount',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFFF8FAFC),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Text(
                    '₹',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF4F46E5),
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      border: InputBorder.none,
                      hintText: '0.00',
                    ),
                    onChanged: (v) => _amountInput = v,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Quick amount buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['₹100', '₹500', '₹1000', '₹2000', 'Clear'].map((amt) {
              final isClear = amt == 'Clear';
              return GestureDetector(
                onTap: () => _onQuickAmount(amt),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: isClear
                        ? const Color(0xFFFEE2E2)
                        : const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isClear
                          ? const Color(0xFFFCA5A5)
                          : const Color(0xFFC7D2FE),
                    ),
                  ),
                  child: Text(
                    amt,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isClear
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF4F46E5),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          // Record Payment button
          GestureDetector(
            onTap: _submitPayment,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  'Record payment',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Browse all students
          Center(
            child: GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, '/student-management-screen');
              },
              child: Text(
                'Browse all students',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF4F46E5),
                  decoration: TextDecoration.underline,
                  decorationColor: const Color(0xFF4F46E5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'All transactions (${_payments.length} total)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                _buildDropdown(
                  value: _transactionFilter,
                  items: _dashboardFilters,
                  onChanged: (v) {
                     setState(() => _transactionFilter = v!);
                     _fetchPayments();
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          // Table header
          if (_isLoadingTable)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_payments.isEmpty)
            // Empty state
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    const Icon(
                      Icons.receipt_long_outlined,
                      size: 40,
                      color: Color(0xFFCBD5E1),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'No transactions found',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: const Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                headingTextStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
                dataTextStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: const Color(0xFF0F172A),
                ),
                columnSpacing: 20,
                horizontalMargin: 18,
                dividerThickness: 1,
                columns: const [
                  DataColumn(label: Text('Receipt No')),
                  DataColumn(label: Text('Student')),
                  DataColumn(label: Text('Amount')),
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Method')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Received by')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: _payments.map((p) {
                  return DataRow(cells: [
                    DataCell(Text(p.receiptNo ?? '-')),
                    DataCell(
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.studentName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            p.studentPhone.isNotEmpty ? p.studentPhone : '-',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      Text(
                        '₹${p.amount.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    DataCell(Text(
                      p.paymentDate.split('T')[0],
                      style: const TextStyle(color: Color(0xFF475569)),
                    )),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          p.paymentMethod.toUpperCase(),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    DataCell(_buildStatusBadge(p.status)),
                    DataCell(Text(p.receivedBy ?? '-')),
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTableAction(Icons.visibility_outlined, const Color(0xFF4F46E5), () {
                          debugPrint("View button tapped for payment ${p.id}");
                          PaymentReceiptModal.show(context, p);
                        }),
                        const SizedBox(width: 4),
                        _buildTableAction(Icons.file_download_outlined, const Color(0xFF10B981), () async {
                           final profile = await AuthService.getProfile();
                           PdfHelper.generatePaymentReceipt(
                             payment: p, 
                             library: profile?.library, 
                             receivedBy: p.receivedBy ?? profile?.name,
                           );
                        }),
                        const SizedBox(width: 4),
                        if (p.status.toUpperCase() != 'REFUNDED')
                          _buildTableAction(Icons.refresh_outlined, const Color(0xFFEF4444), () => _showRefundDialog(p)),
                      ],
                    )),
                  ]);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    
    switch (status.toLowerCase()) {
      case 'completed':
      case 'paid':
        bgColor = const Color(0xFFDCFCE7);
        textColor = const Color(0xFF166534);
        break;
      case 'refunded':
        bgColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFF991B1B);
        break;
      default:
        bgColor = const Color(0xFFFEF9C3);
        textColor = const Color(0xFF854D0E);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool compact = false,
    bool fullWidth = false,
  }) {
    final widget = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 16,
            color: Color(0xFF64748B),
          ),
          style: GoogleFonts.plusJakartaSans(
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF0F172A),
          ),
          items: items
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );

    if (fullWidth) {
      return SizedBox(width: double.infinity, child: widget);
    }
    return widget;
  }

  Widget _buildTableAction(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }

  void _showRefundDialog(PaymentModel payment) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Confirm Refund", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Are you sure you want to refund ₹${payment.amount} to ${payment.studentName}?"),
            const SizedBox(height: 16),
            Text("Reason for refund:", style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: "Enter reason...",
                hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a reason for refund")));
                return;
              }
              Navigator.pop(ctx);
              try {
                final token = await StorageHelper.getToken();
                await ApiService.patch('/payments/${payment.id}/refund', {
                  "reason": reasonController.text.trim(),
                }, token: token);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Refund successful")));
                _fetchPayments();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Refund failed: $e"), backgroundColor: Colors.red));
              }
            }, 
            child: const Text("Confirm Refund", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

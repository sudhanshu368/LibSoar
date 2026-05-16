import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/app_drawer.dart';
import '../../core/services/dashboard_service.dart';
import 'widgets/payment_receipt_bottom_sheet.dart';

// ══════════════════════════════════════════════════════════════
//  BILLING RECORD MODEL
// ══════════════════════════════════════════════════════════════

enum _BillingStatus { active, cancelled, expired }
enum _PaymentStatus { paid, failed }

class _BillingRecord {
  final String id;
  final String planName;
  final String periodFrom;
  final String periodTo;
  final String cycle;
  final int amount;
  final _BillingStatus status;
  final _PaymentStatus payment;
  final bool hasReceipt;
  final String? paymentReference;
  final String? paymentMethod;
  final String? gatewayMode;
  final bool autoRenew;
  final String? nextBillingDate;
  final String? rawStartDate;
  final String? rawEndDate;
  final int maxSeats;
  final int maxStudents;
  final int maxBranches;

  const _BillingRecord({
    required this.id,
    required this.planName,
    required this.periodFrom,
    required this.periodTo,
    required this.cycle,
    required this.amount,
    required this.status,
    required this.payment,
    this.hasReceipt = false,
    this.paymentReference,
    this.paymentMethod,
    this.gatewayMode,
    this.autoRenew = false,
    this.nextBillingDate,
    this.rawStartDate,
    this.rawEndDate,
    this.maxSeats = 0,
    this.maxStudents = 0,
    this.maxBranches = 0,
  });

  factory _BillingRecord.fromJson(Map<String, dynamic> json) {
    _BillingStatus parseStatus(String? s) {
      switch ((s ?? '').toLowerCase()) {
        case 'active':    return _BillingStatus.active;
        case 'cancelled': return _BillingStatus.cancelled;
        default:          return _BillingStatus.expired;
      }
    }

    _PaymentStatus parsePayment(String? s) =>
        (s ?? '').toLowerCase() == 'completed'
            ? _PaymentStatus.paid
            : _PaymentStatus.failed;

    String fmtDate(String? iso) {
      if (iso == null || iso.isEmpty) return '—';
      try {
        final dt = DateTime.parse(iso).toLocal();
        const mo = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
        return '${dt.day} ${mo[dt.month - 1]} ${dt.year}';
      } catch (_) { return '—'; }
    }

    String fmtCycle(String? c) {
      if (c == null || c.isEmpty) return 'Monthly';
      return '${c[0].toUpperCase()}${c.substring(1).toLowerCase()}';
    }

    final pyStatus = parsePayment(json['paymentStatus']?.toString());
    return _BillingRecord(
      id:               json['id']?.toString() ?? '',
      planName:         (json['plan'] as Map?)?['name']?.toString() ?? '—',
      periodFrom:       fmtDate(json['startDate']?.toString()),
      periodTo:         fmtDate(json['endDate']?.toString()),
      cycle:            fmtCycle(json['billingCycle']?.toString()),
      amount:           (json['amount'] as num?)?.toInt() ?? 0,
      status:           parseStatus(json['status']?.toString()),
      payment:          pyStatus,
      hasReceipt:       json['paidAt'] != null && pyStatus == _PaymentStatus.paid,
      paymentReference: json['paymentReference']?.toString(),
      paymentMethod:    json['paymentMethod']?.toString(),
      gatewayMode:      json['gatewayMode']?.toString(),
      autoRenew:        json['autoRenew'] == true,
      nextBillingDate:  fmtDate(json['nextBillingDate']?.toString()),
      rawStartDate:     json['startDate']?.toString(),
      rawEndDate:       json['endDate']?.toString(),
      maxSeats:         int.tryParse((json['plan'] as Map?)?['maxSeats']?.toString() ?? (json['plan'] as Map?)?['seatsLimit']?.toString() ?? '0') ?? 0,
      maxStudents:      int.tryParse((json['plan'] as Map?)?['maxStudents']?.toString() ?? (json['plan'] as Map?)?['studentsLimit']?.toString() ?? '0') ?? 0,
      maxBranches:      int.tryParse((json['plan'] as Map?)?['maxBranches']?.toString() ?? (json['plan'] as Map?)?['branchesLimit']?.toString() ?? '0') ?? 0,
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  DATA MODELS
// ══════════════════════════════════════════════════════════════

class _Feature {
  final String label;
  final bool available;
  final bool soon;
  const _Feature(this.label, {this.available = true, this.soon = false});
}

class _Plan {
  final String id;
  final String name;
  final String? badge;
  final bool isCurrent;
  final bool isEnterprise;

  /// Monthly rate when billed monthly (null = enterprise)
  final int? monthlyPrice;

  /// Monthly-equivalent rate when billed yearly (shown as "₹X/month")
  final int? yearlyMonthlyRate;

  /// Original yearly total (struck-through)
  final int? yearlyOriginalTotal;

  /// Discounted yearly total (highlighted)
  final int? yearlyDiscountedTotal;

  final Color accentColor;
  final IconData icon;
  final List<_Feature> features;

  const _Plan({
    required this.id,
    required this.name,
    this.badge,
    this.isCurrent = false,
    this.isEnterprise = false,
    this.monthlyPrice,
    this.yearlyMonthlyRate,
    this.yearlyOriginalTotal,
    this.yearlyDiscountedTotal,
    required this.accentColor,
    required this.icon,
    required this.features,
  });
}

// ══════════════════════════════════════════════════════════════
//  SCREEN
// ══════════════════════════════════════════════════════════════

class SubscriptionManagementScreen extends StatefulWidget {
  const SubscriptionManagementScreen({super.key});

  @override
  State<SubscriptionManagementScreen> createState() =>
      _SubscriptionManagementScreenState();
}

class _SubscriptionManagementScreenState
    extends State<SubscriptionManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _selectedTabIndex = 0;
  bool _isYearly = false;
  String _billingFilter = 'All Status';

  // ── Design tokens ────────────────────────────────────────────
  static const _primary   = Color(0xFF4F46E5);
  static const _bgColor   = Color(0xFFF5F7FB);
  static const _cardWhite = Colors.white;

  final List<String> _tabs = ['Overview', 'Plans', 'Billing', 'Settings'];

  // ── Billing History (live API) ───────────────────────────
  List<_BillingRecord> _allBillingRecords = [];
  bool _isBillingLoading  = false;
  String? _billingError;
  _BillingRecord? _currentSubscription;
  
  // ── Stats (live API) ──────────────────────────────────────────
  Map<String, dynamic> _stats = {};
  int _branchCount = 0;
  int _totalLibrarySeats = 0;
  int _totalLibraryStudents = 0;
  bool _isStatsLoading = false;
  bool _isInitialLoading = true;

  List<_BillingRecord> get _filteredRecords {
    if (_billingFilter == 'All Status') return _allBillingRecords;
    return _allBillingRecords.where((r) {
      switch (_billingFilter) {
        case 'Active':    return r.status == _BillingStatus.active;
        case 'Cancelled': return r.status == _BillingStatus.cancelled;
        case 'Expired':   return r.status == _BillingStatus.expired;
        default:          return true;
      }
    }).toList();
  }

  // ── Plan catalogue ───────────────────────────────────────────
  static const List<_Plan> _plans = [
    // ── Free ──────────────────────────────────────────────────
    _Plan(
      id: 'free',
      name: 'Free',
      monthlyPrice: 0,
      yearlyMonthlyRate: 0,
      yearlyOriginalTotal: 0,
      yearlyDiscountedTotal: 0,
      accentColor: Color(0xFF6B7280),
      icon: Icons.layers_outlined,
      features: [
        _Feature('Up to 20 students'),
        _Feature('Up to 1 branches'),
        _Feature('Up to 50 seats'),
        _Feature('Attendance tracking'),
        _Feature('Student management'),
        _Feature('Seat management'),
        _Feature('Basic reports'),
      ],
    ),

    // ── Starter ────────────────────────────────────────────────
    _Plan(
      id: 'starter',
      name: 'Starter',
      badge: 'EARLY BIRD',
      monthlyPrice: 299,
      yearlyMonthlyRate: 250,
      yearlyOriginalTotal: 4999,
      yearlyDiscountedTotal: 2999,
      accentColor: Color(0xFF0EA5E9),
      icon: Icons.rocket_launch_outlined,
      features: [
        _Feature('Up to 150 students'),
        _Feature('Up to 1 branches'),
        _Feature('Up to 100 seats'),
        _Feature('Attendance tracking'),
        _Feature('Student management'),
        _Feature('Seat management'),
        _Feature('Basic reports'),
        _Feature('Fee & payment tracking'),
        _Feature('Digital ID cards', available: false, soon: true),
        _Feature('WhatsApp & email notifications', available: false, soon: true),
      ],
    ),

    // ── Growth (current) ───────────────────────────────────────
    _Plan(
      id: 'growth',
      name: 'Growth',
      badge: 'Current plan',
      isCurrent: true,
      monthlyPrice: 999,
      yearlyMonthlyRate: 750,
      yearlyOriginalTotal: 12999,
      yearlyDiscountedTotal: 8999,
      accentColor: Color(0xFF4F46E5),
      icon: Icons.trending_up_rounded,
      features: [
        _Feature('Up to 400 students'),
        _Feature('Up to 3 branches'),
        _Feature('Up to 250 seats'),
        _Feature('Staff access'),
        _Feature('Attendance tracking'),
        _Feature('Student management'),
        _Feature('Seat management'),
        _Feature('Basic reports'),
        _Feature('Fee & payment tracking'),
        _Feature('Digital ID cards', available: false, soon: true),
        _Feature('WhatsApp & email notifications', available: false, soon: true),
        _Feature('Staff accounts'),
        _Feature('Advanced analytics & reports', available: false, soon: true),
        _Feature('Shift-based seat booking'),
        _Feature('Priority support'),
      ],
    ),

    // ── Pro ────────────────────────────────────────────────────
    _Plan(
      id: 'pro',
      name: 'Pro',
      badge: 'EARLY BIRD',
      monthlyPrice: 1999,
      yearlyMonthlyRate: 1500,
      yearlyOriginalTotal: 26999,
      yearlyDiscountedTotal: 17999,
      accentColor: Color(0xFF7C3AED),
      icon: Icons.workspace_premium_rounded,
      features: [
        _Feature('Unlimited students'),
        _Feature('Unlimited branches'),
        _Feature('Unlimited seats'),
        _Feature('Staff access'),
        _Feature('Attendance tracking'),
        _Feature('Student management'),
        _Feature('Seat management'),
        _Feature('Basic reports'),
        _Feature('Fee & payment tracking'),
        _Feature('Digital ID cards', available: false, soon: true),
        _Feature('WhatsApp & email notifications', available: false, soon: true),
        _Feature('Staff accounts'),
        _Feature('Advanced analytics & reports', available: false, soon: true),
        _Feature('Shift-based seat booking'),
        _Feature('Priority support'),
        _Feature('Custom branding', available: false, soon: true),
        _Feature('Data export & API access', available: false, soon: true),
        _Feature('Dedicated support', available: false, soon: true),
        _Feature('Onboarding assistance', available: false, soon: true),
      ],
    ),

    // ── Enterprise ─────────────────────────────────────────────
    _Plan(
      id: 'enterprise',
      name: 'Enterprise',
      isEnterprise: true,
      accentColor: Color(0xFF0F172A),
      icon: Icons.business_rounded,
      features: [
        _Feature('Everything in Pro'),
        _Feature('Unlimited Branches'),
        _Feature('Custom Integrations'),
        _Feature('SLA Guarantee'),
        _Feature('White-label Option'),
        _Feature('Custom Reporting'),
        _Feature('Onboarding Support'),
        _Feature('24/7 Priority Support'),
      ],
    ),
  ];

  // ── Helpers ──────────────────────────────────────────────────

  String _fmt(int n) {
    // Simple Indian number format with commas
    if (n < 1000) return '₹$n';
    final s = n.toString();
    if (s.length <= 3) return '₹$s';
    final last3  = s.substring(s.length - 3);
    final rest   = s.substring(0, s.length - 3);
    final buf    = StringBuffer('₹');
    for (int i = 0; i < rest.length; i++) {
      if (i > 0 && (rest.length - i) % 2 == 0) buf.write(',');
      buf.write(rest[i]);
    }
    buf.write(',$last3');
    return buf.toString();
  }

  // ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _selectedTabIndex) {
        setState(() => _selectedTabIndex = _tabController.index);
      }
    });

    // Start fetching data immediately
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isInitialLoading = true);
    await Future.wait([
      _fetchBillingHistory(),
      _fetchStats(),
      _fetchLibraryUsage(), // replaces _fetchBranchCount
    ]);
    if (mounted) setState(() => _isInitialLoading = false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════
  //  BILLING HISTORY – API FETCH
  // ══════════════════════════════════════════════════════════════

  Future<void> _fetchBillingHistory() async {
    if (_isBillingLoading) return;
    if (mounted) setState(() { _isBillingLoading = true; _billingError = null; });
    try {
      final raw = await DashboardService.getBillingHistory();
      final mapped = raw
          .whereType<Map<String, dynamic>>()
          .map((j) => _BillingRecord.fromJson(j))
          .toList();
      if (mounted) {
        setState(() {
          _allBillingRecords = mapped;
          _isBillingLoading  = false;
          
          if (mapped.isNotEmpty) {
            // Priority: Active -> Newest
            _currentSubscription = mapped.firstWhere(
              (r) => r.status == _BillingStatus.active,
              orElse: () => mapped.first,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _billingError     = e.toString().replaceFirst('Exception: ', '');
          _isBillingLoading = false;
        });
      }
    }
  }

  Future<void> _fetchStats() async {
    if (_isStatsLoading) return;
    if (mounted) setState(() => _isStatsLoading = true);
    try {
      final data = await DashboardService.getStats();
      if (mounted) {
        setState(() {
          _stats = data;
          _isStatsLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Stats error: $e");
      if (mounted) setState(() => _isStatsLoading = false);
    }
  }

  Future<void> _fetchLibraryUsage() async {
    try {
      final branches = await DashboardService.getBranches();
      if (mounted) {
        int seats = 0;
        int students = 0;
        for (var b in branches) {
          seats += int.tryParse(b['totalSeats']?.toString() ?? '0') ?? 0;
          students += int.tryParse((b['totalStudents'] ?? b['activeStudents'] ?? '0').toString()) ?? 0;
        }
        setState(() {
          _branchCount = branches.length;
          _totalLibrarySeats = seats;
          _totalLibraryStudents = students;
        });
      }
    } catch (e) {
      debugPrint("Library usage error: $e");
    }
  }

  // ── Billing shimmer (first load) ────────────────────────────────

  Widget _buildBillingShimmer() {
    return Container(
      height: 340,
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(
            width: 36, height: 36,
            child: CircularProgressIndicator(color: _primary, strokeWidth: 2.5),
          ),
          const SizedBox(height: 16),
          Text('Loading billing history…',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF6B7280))),
          const SizedBox(height: 6),
          Text('Fetching from server',
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFD1D5DB))),
        ]),
      ),
    );
  }

  // ── Billing error state ──────────────────────────────────────

  Widget _buildBillingErrorState() {
    return Container(
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.symmetric(vertical: 52, horizontal: 24),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.cloud_off_rounded, size: 26, color: Color(0xFFDC2626)),
          ),
          const SizedBox(height: 14),
          Text('Failed to load billing history',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF374151))),
          const SizedBox(height: 6),
          Text(_billingError ?? 'Something went wrong',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF9CA3AF)),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _fetchBillingHistory,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.refresh_rounded, size: 15, color: _primary),
                const SizedBox(width: 6),
                Text('Try Again',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _primary)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      drawer: const AppDrawer(activeItem: 'Settings'),
      body: SafeArea(
        child: Column(
          children: [
            _buildGradientHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildOverviewTab(),
                  _buildPlansTab(),
                  _buildBillingTab(),
                  _buildSettingsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  HEADER
  // ══════════════════════════════════════════════════════════════

  Widget _buildGradientHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Builder(
            builder: (ctx) => GestureDetector(
              onTap: () => Scaffold.of(ctx).openDrawer(),
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(color: Colors.white.withAlpha(40), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.menu_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text('Subscription', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _bcrumb('Dashboard'),
          _bcrumbSep(),
          _bcrumb('Settings'),
          _bcrumbSep(),
          _bcrumb('Subscription', active: true),
        ]),
      ]),
    );
  }

  Widget _bcrumb(String l, {bool active = false}) => Text(l,
      style: GoogleFonts.inter(fontSize: 12, fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          color: active ? Colors.white : Colors.white.withAlpha(170)));

  Widget _bcrumbSep() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Icon(Icons.chevron_right_rounded, size: 14, color: Colors.white.withAlpha(150)));

  // ══════════════════════════════════════════════════════════════
  //  TAB BAR
  // ══════════════════════════════════════════════════════════════

  Widget _buildTabBar() {
    return Container(
      color: _cardWhite,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(50)),
        child: Row(
          children: List.generate(_tabs.length, (i) {
            final sel = _selectedTabIndex == i;
            return Expanded(
              child: GestureDetector(
                onTap: () { setState(() => _selectedTabIndex = i); _tabController.animateTo(i); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220), curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: sel ? _primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: sel ? [BoxShadow(color: _primary.withAlpha(60), blurRadius: 6, offset: const Offset(0, 2))] : [],
                  ),
                  child: Text(_tabs[i],
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                        color: sel ? Colors.white : const Color(0xFF6B7280)),
                    textAlign: TextAlign.center),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  OVERVIEW TAB
  // ══════════════════════════════════════════════════════════════

  Widget _buildOverviewTab() {
    if (_isInitialLoading) {
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _buildOverviewShimmer(),
            const SizedBox(height: 16),
            _buildOverviewShimmer(),
          ]),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildCurrentPlanCard(),
        const SizedBox(height: 16),
        _buildUsageSection(),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _buildCurrentPlanCard() {
    final sub = _currentSubscription;
    
    // If no data and still loading
    if (sub == null && _isBillingLoading) {
      return _buildOverviewShimmer();
    }

    // If no subscription at all (not even after fetch)
    if (sub == null && !_isBillingLoading) {
      return _buildNoActiveSubscriptionCard();
    }

    // Default Fallbacks
    final planName = sub?.planName ?? 'No Plan';
    final amount = sub?.amount ?? 0;
    final cycle = sub?.cycle ?? 'Monthly';
    final status = sub?.status == _BillingStatus.active ? 'Active' : 'Regular';
    final statusColor = sub?.status == _BillingStatus.active ? const Color(0xFF16A34A) : const Color(0xFF6B7280);
    final statusBg = sub?.status == _BillingStatus.active ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9);
    final renewalDate = sub?.periodTo ?? '—';
    final isPaid = sub?.payment == _PaymentStatus.paid;
    final autoRenew = sub?.autoRenew ?? false;

    // Progress math
    int totalDays = 365;
    int daysLeft = 0;
    double progress = 0.0;
    String startDateStr = '—';
    String endDateStr = '—';

    if (sub != null && sub.rawStartDate != null && sub.rawEndDate != null) {
      try {
        final start = DateTime.parse(sub.rawStartDate!);
        final end = DateTime.parse(sub.rawEndDate!);
        final now = DateTime.now();
        
        totalDays = end.difference(start).inDays;
        if (totalDays <= 0) totalDays = 1;
        
        daysLeft = end.difference(now).inDays;
        if (daysLeft < 0) daysLeft = 0;
        
        progress = ((totalDays - daysLeft) / totalDays).clamp(0.0, 1.0);
        
        startDateStr = sub.periodFrom;
        endDateStr = sub.periodTo;
      } catch (_) {}
    }

    return Container(
      decoration: BoxDecoration(color: _cardWhite, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('CURRENT PLAN', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: const Color(0xFF9CA3AF))),
          const SizedBox(height: 8),
          Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.workspace_premium_rounded, color: _primary, size: 24)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(planName, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF111827))),
              const SizedBox(height: 2),
              Text('${_fmt(amount)} / ${cycle.toLowerCase()}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF6B7280))),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(50)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 7, height: 7, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text(status, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor)),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _infoMini(icon: Icons.calendar_today_rounded, iconColor: _primary, iconBg: const Color(0xFFEEF2FF), label: 'Renewal Date', value: renewalDate)),
            const SizedBox(width: 10),
            Expanded(child: _infoMini(
              icon: isPaid ? Icons.check_circle_rounded : Icons.error_rounded, 
              iconColor: isPaid ? const Color(0xFF16A34A) : const Color(0xFFDC2626), 
              iconBg: isPaid ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2), 
              label: 'Payment Status', 
              value: isPaid ? 'Paid' : 'Failed'
            )),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Icon(autoRenew ? Icons.autorenew_rounded : Icons.sync_disabled_rounded, size: 15, color: const Color(0xFF6B7280)),
            const SizedBox(width: 6),
            Text(
              autoRenew 
                ? 'Auto-renew enabled on ${sub?.nextBillingDate != null && sub!.nextBillingDate != "—" ? sub.nextBillingDate : renewalDate}' 
                : 'Auto-renew is disabled', 
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280))
            ),
          ]),
          const SizedBox(height: 14),
          _billingProgress(daysLeft: daysLeft, totalDays: totalDays, progress: progress, start: startDateStr, end: endDateStr),
        ])),
        Container(height: 1, color: const Color(0xFFF1F5F9)),
        Padding(padding: const EdgeInsets.all(16), child: Row(children: [
          Expanded(child: ElevatedButton.icon(
            onPressed: () { setState(() => _selectedTabIndex = 2); _tabController.animateTo(2); },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF1F5F9), foregroundColor: const Color(0xFF374151),
                elevation: 0, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            icon: const Icon(Icons.receipt_long_rounded, size: 17),
            label: Text('View Billing', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
          )),
          const SizedBox(width: 12),
          Expanded(child: OutlinedButton.icon(
            onPressed: () { setState(() => _selectedTabIndex = 1); _tabController.animateTo(1); },
            style: OutlinedButton.styleFrom(foregroundColor: _primary, side: const BorderSide(color: _primary, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            icon: const Icon(Icons.swap_horiz_rounded, size: 17),
            label: Text('Change Plan', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
          )),
        ])),
      ]),
    );
  }

  Widget _buildOverviewShimmer() {
    return Container(
      height: 320,
      width: double.infinity,
      decoration: BoxDecoration(color: _cardWhite, borderRadius: BorderRadius.circular(20)),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }

  Widget _buildNoActiveSubscriptionCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: _cardWhite, borderRadius: BorderRadius.circular(20)),
      child: Column(children: [
        const Icon(Icons.info_outline_rounded, size: 40, color: Color(0xFF9CA3AF)),
        const SizedBox(height: 16),
        Text('No active subscription found', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('Please select a plan to get started.', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF6B7280))),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () { setState(() => _selectedTabIndex = 1); _tabController.animateTo(1); },
          child: const Text('View Plans'),
        )
      ]),
    );
  }

  Widget _billingProgress({required int daysLeft, required int totalDays, required double progress, required String start, required String end}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Billing Period', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF374151))),
        Text('$daysLeft days left', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _primary)),
      ]),
      const SizedBox(height: 8),
      ClipRRect(borderRadius: BorderRadius.circular(50),
          child: LinearProgressIndicator(value: progress, minHeight: 7, backgroundColor: const Color(0xFFE2E8F0), valueColor: const AlwaysStoppedAnimation<Color>(_primary))),
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(start, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF9CA3AF))),
        Text(end, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF9CA3AF))),
      ]),
    ]);
  }

  Widget _infoMini({required IconData icon, required Color iconColor, required Color iconBg, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(children: [
        Container(width: 34, height: 34, decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(9)), child: Icon(icon, color: iconColor, size: 17)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF111827)), overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }


  Widget _buildUsageSection() {
    final sub = _currentSubscription;
    final int usedStudents = _totalLibraryStudents > 0 ? _totalLibraryStudents : ((_stats['totalStudents'] ?? _stats['activeStudents'] ?? _stats['students_count'] ?? 0) as int);
    final int usedSeats    = _totalLibrarySeats > 0 ? _totalLibrarySeats : ((_stats['totalSeats'] ?? _stats['activeSeats'] ?? _stats['seats_count'] ?? 0) as int);
    final int usedBranches = _branchCount > 0 ? _branchCount : ((_stats['totalBranches'] ?? _stats['branchesCount'] ?? 1) as int);

    // Based on current plan limits (fallback to Growth plan limits)
    final plan = _plans.firstWhere((p) => p.name == (_currentSubscription?.planName ?? 'Growth'), orElse: () => _plans[2]);
    
    // Extract limits from API record if available, otherwise fallback to hardcoded
    int maxStudents = sub?.maxStudents ?? 0;
    int maxSeats    = sub?.maxSeats    ?? 0;
    int maxBranches = sub?.maxBranches ?? 0;

    if (maxStudents == 0 || maxSeats == 0) {
      if (plan.id == 'free') { maxStudents = 50;  maxSeats = 5;   maxBranches = 1; }
      else if (plan.id == 'starter') { maxStudents = 200; maxSeats = 50;  maxBranches = 2; }
      else if (plan.id == 'growth')  { maxStudents = 400; maxSeats = 250; maxBranches = 3; }
      else if (plan.id == 'pro')     { maxStudents = 1000; maxSeats = 500; maxBranches = 10; }
      else if (plan.id == 'enterprise') { maxStudents = 99999; maxSeats = 99999; maxBranches = 99; }
    }

    final items = [
      {'label': 'Students', 'used': usedStudents, 'max': maxStudents, 'color': _primary},
      {'label': 'Seats',    'used': usedSeats,    'max': maxSeats,    'color': const Color(0xFF0EA5E9)},
      {'label': 'Branches', 'used': usedBranches, 'max': maxBranches, 'color': const Color(0xFFEF4444)},
    ];

    final double overall = (
      (usedStudents / maxStudents).clamp(0.0, 1.0) + 
      (usedSeats / maxSeats).clamp(0.0, 1.0) + 
      (usedBranches / maxBranches).clamp(0.0, 1.0)
    ) / 3 * 100;

    final bool isHealthy = usedStudents < maxStudents && usedSeats < maxSeats;

    return Container(
      decoration: BoxDecoration(color: _cardWhite, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(children: [
            Text('Usage', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF111827))),
            const SizedBox(width: 10),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isHealthy ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2), 
                  borderRadius: BorderRadius.circular(50)
                ),
                child: Text(
                  isHealthy ? 'Within limits' : 'Near limit', 
                  style: GoogleFonts.inter(
                    fontSize: 11, 
                    fontWeight: FontWeight.w600, 
                    color: isHealthy ? const Color(0xFF16A34A) : const Color(0xFFDC2626)
                  )
                )),
          ])),
        const SizedBox(height: 16),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Overall Usage', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF374151))),
            Text('${overall.toStringAsFixed(0)}%', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF374151))),
          ]),
          const SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(50),
              child: LinearProgressIndicator(value: overall / 100, minHeight: 8, backgroundColor: const Color(0xFFE2E8F0), valueColor: const AlwaysStoppedAnimation<Color>(_primary))),
        ])),
        const SizedBox(height: 16),
        Container(height: 1, color: const Color(0xFFF1F5F9)),
        Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Column(children: items.map((item) {
            final int used = item['used'] as int, max = item['max'] as int;
            final Color color = item['color'] as Color;
            final double pct = max > 0 ? used / max : 0;
            final bool full = used >= max;
            return Padding(padding: const EdgeInsets.only(bottom: 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Row(children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(item['label'] as String, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF374151))),
                    if (full) ...[
                      const SizedBox(width: 6),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(4)),
                          child: Text('Full', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFFDC2626)))),
                    ],
                  ])),
                  Text('$used/$max', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: full ? const Color(0xFFDC2626) : const Color(0xFF374151))),
                  const SizedBox(width: 8),
                  SizedBox(width: 36, child: Text('${(pct * 100).toStringAsFixed(0)}%',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: full ? const Color(0xFFDC2626) : const Color(0xFF9CA3AF)), textAlign: TextAlign.right)),
                ]),
                const SizedBox(height: 6),
                ClipRRect(borderRadius: BorderRadius.circular(50),
                    child: LinearProgressIndicator(value: pct, minHeight: 6, backgroundColor: const Color(0xFFE2E8F0), valueColor: AlwaysStoppedAnimation<Color>(color))),
              ]),
            );
          }).toList())),
        Container(height: 1, color: const Color(0xFFF1F5F9)),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(children: [
            const Icon(Icons.update_rounded, size: 14, color: Color(0xFF9CA3AF)),
            const SizedBox(width: 6),
            Text('Last updated: Apr 12, 2026', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF9CA3AF))),
          ])),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  PLANS TAB
  // ══════════════════════════════════════════════════════════════

  Widget _buildPlansTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      physics: const BouncingScrollPhysics(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildBillingToggle(),
        const SizedBox(height: 24),
        _buildPlansGrid(),
      ]),
    );
  }

  // ── Billing Toggle ────────────────────────────────────────────

  Widget _buildBillingToggle() {
    return Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      // Pill toggle
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFEEF2FF),
          borderRadius: BorderRadius.circular(50),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _togglePill(label: 'Monthly', selected: !_isYearly, onTap: () => setState(() => _isYearly = false)),
          _togglePill(label: 'Yearly',  selected: _isYearly,  onTap: () => setState(() => _isYearly = true), badge: 'Save 25%'),
        ]),
      ),
      const SizedBox(height: 12),

      // Animated hint row
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        transitionBuilder: (child, anim) => FadeTransition(opacity: anim,
            child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(anim), child: child)),
        child: _isYearly
            ? _savingsHint(key: const ValueKey('yearly'))
            : _monthlyHint(key: const ValueKey('monthly')),
      ),
    ]);
  }

  Widget _togglePill({required String label, required bool selected, required VoidCallback onTap, String? badge}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240), curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(horizontal: badge != null ? 16 : 20, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? _primary : Colors.transparent,
          borderRadius: BorderRadius.circular(50),
          boxShadow: selected ? [BoxShadow(color: _primary.withAlpha(60), blurRadius: 8, offset: const Offset(0, 2))] : [],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? Colors.white : const Color(0xFF6B7280))),
          if (badge != null) ...[
            const SizedBox(width: 7),
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: selected ? Colors.white.withAlpha(45) : const Color(0xFF16A34A).withAlpha(30),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Text(badge, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : const Color(0xFF16A34A))),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _savingsHint({Key? key}) {
    return Row(key: key, mainAxisSize: MainAxisSize.min, children: [
      Container(width: 20, height: 20,
          decoration: BoxDecoration(color: const Color(0xFFDCFCE7), shape: BoxShape.circle),
          child: const Icon(Icons.savings_outlined, size: 12, color: Color(0xFF16A34A))),
      const SizedBox(width: 6),
      Text('You\'re saving ~25% with annual billing  🎉',
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF16A34A))),
    ]);
  }

  Widget _monthlyHint({Key? key}) {
    return Text(key: key, 'Switch to yearly and save up to 25%',
        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280)));
  }

  // ── Plans Grid ────────────────────────────────────────────────

  Widget _buildPlansGrid() {
    return LayoutBuilder(builder: (context, box) {
      final isTablet = box.maxWidth >= 580;
      if (!isTablet) {
        return Column(
          children: _plans.asMap().entries.map((e) => Padding(
            padding: EdgeInsets.only(bottom: e.key < _plans.length - 1 ? 16 : 0),
            child: _buildPlanCard(e.value),
          )).toList(),
        );
      }
      // Two-column
      final rows = <Widget>[];
      for (int i = 0; i < _plans.length; i += 2) {
        final hasRight = i + 1 < _plans.length;
        rows.add(IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: _buildPlanCard(_plans[i])),
            const SizedBox(width: 14),
            hasRight ? Expanded(child: _buildPlanCard(_plans[i + 1])) : const Expanded(child: SizedBox()),
          ]),
        ));
        if (i + 2 < _plans.length) rows.add(const SizedBox(height: 16));
      }
      return Column(children: rows);
    });
  }

  // ── Single Plan Card ──────────────────────────────────────────

  Widget _buildPlanCard(_Plan plan) {
    final accent = plan.accentColor;
    final isCurrent = plan.isCurrent;
    final isEnterprise = plan.isEnterprise;
    final isFree = plan.monthlyPrice == 0 && !isEnterprise;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300), curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: isCurrent ? Border.all(color: accent, width: 2) : Border.all(color: Colors.transparent, width: 2),
        boxShadow: [BoxShadow(
          color: isCurrent ? accent.withAlpha(40) : Colors.black.withAlpha(12),
          blurRadius: isCurrent ? 20 : 10, offset: const Offset(0, 4),
        )],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        // ── Card header (tinted bg) ──
        Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            color: accent.withAlpha(isCurrent ? 22 : 14),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Icon + badge
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 44, height: 44,
                  decoration: BoxDecoration(color: accent.withAlpha(35), borderRadius: BorderRadius.circular(12)),
                  child: Icon(plan.icon, color: accent, size: 22)),
              const Spacer(),
              if (plan.badge != null) _buildBadge(plan),
            ]),
            const SizedBox(height: 12),

            // Plan name
            Text(plan.name, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF111827))),
            const SizedBox(height: 8),

            // Price block
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, anim) => FadeTransition(opacity: anim,
                  child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(anim), child: child)),
              child: KeyedSubtree(
                key: ValueKey('${plan.id}_${_isYearly ? 'y' : 'm'}'),
                child: isEnterprise
                    ? _enterprisePriceBlock()
                    : isFree
                        ? _freePriceBlock()
                        : _isYearly
                            ? _yearlyPriceBlock(plan, accent)
                            : _monthlyPriceBlock(plan),
              ),
            ),
          ]),
        ),

        // ── Features ──
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
          child: isEnterprise
              ? _buildEnterpriseFeatures(plan.features)
              : _buildFeatureList(plan.features),
        ),

        // ── CTA ──
        Padding(
          padding: const EdgeInsets.all(16),
          child: _buildPlanButton(plan, accent),
        ),
      ]),
    );
  }

  // ── Badge ────────────────────────────────────────────────────

  Widget _buildBadge(_Plan plan) {
    final isCurrent = plan.isCurrent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isCurrent ? _primary.withAlpha(22) : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(plan.badge!,
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.4,
              color: isCurrent ? _primary : const Color(0xFFD97706))),
    );
  }

  // ── Price blocks ─────────────────────────────────────────────

  Widget _freePriceBlock() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('₹0', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: const Color(0xFF111827))),
      Text('Free forever', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF9CA3AF))),
    ]);
  }

  Widget _monthlyPriceBlock(_Plan plan) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(_fmt(plan.monthlyPrice!), style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: const Color(0xFF111827))),
        const SizedBox(width: 4),
        Padding(padding: const EdgeInsets.only(bottom: 4),
            child: Text('/month', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF9CA3AF)))),
      ]),
      Text('Billed monthly', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF9CA3AF))),
    ]);
  }

  Widget _yearlyPriceBlock(_Plan plan, Color accent) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Monthly-equivalent rate
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(_fmt(plan.yearlyMonthlyRate!), style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: const Color(0xFF111827))),
        const SizedBox(width: 4),
        Padding(padding: const EdgeInsets.only(bottom: 4),
            child: Text('/month', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF9CA3AF)))),
      ]),
      const SizedBox(height: 5),
      // Yearly billing line: ₹X,XXX → ₹Y,YYY billed yearly
      Row(children: [
        Text(_fmt(plan.yearlyOriginalTotal!),
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF9CA3AF), decoration: TextDecoration.lineThrough)),
        const SizedBox(width: 6),
        Text(_fmt(plan.yearlyDiscountedTotal!),
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: accent)),
        const SizedBox(width: 4),
        Text('billed yearly', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF9CA3AF))),
      ]),
    ]);
  }

  Widget _enterprisePriceBlock() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Custom pricing', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF111827))),
      const SizedBox(height: 4),
      Text('Tailored to your organisation\'s scale', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF9CA3AF))),
    ]);
  }

  // ── Features ─────────────────────────────────────────────────

  Widget _buildFeatureList(List<_Feature> features) {
    return Column(children: features.map(_featureRow).toList());
  }

  Widget _buildEnterpriseFeatures(List<_Feature> features) {
    final half = (features.length / 2).ceil();
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Column(children: features.sublist(0, half).map(_featureRow).toList())),
      const SizedBox(width: 6),
      Expanded(child: Column(children: features.sublist(half).map(_featureRow).toList())),
    ]);
  }

  Widget _featureRow(_Feature f) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 18, height: 18, margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            color: f.available ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
            shape: BoxShape.circle,
          ),
          child: Icon(f.available ? Icons.check_rounded : Icons.remove_rounded, size: 11,
              color: f.available ? const Color(0xFF16A34A) : const Color(0xFF9CA3AF)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 5, children: [
          Text(f.label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500,
              color: f.available ? const Color(0xFF374151) : const Color(0xFF9CA3AF))),
          if (f.soon)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(4)),
              child: Text('soon', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFFD97706))),
            ),
        ])),
      ]),
    );
  }

  // ── CTA Button ────────────────────────────────────────────────

  Widget _buildPlanButton(_Plan plan, Color accent) {
    // Current plan → disabled
    if (plan.isCurrent) {
      return SizedBox(width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: null,
            style: ElevatedButton.styleFrom(
              disabledBackgroundColor: accent.withAlpha(22),
              disabledForegroundColor: accent,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.check_circle_rounded, size: 16),
            label: Text('Current Plan', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
          ));
    }

    // Enterprise
    if (plan.isEnterprise) {
      return SizedBox(width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.headset_mic_rounded, size: 16),
            label: Text('Contact Sales', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
          ));
    }

    // Others
    return SizedBox(width: double.infinity,
        child: ElevatedButton(
          onPressed: () => _showSwitchDialog(plan),
          style: ElevatedButton.styleFrom(
            backgroundColor: accent, foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text('Switch plan', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
        ));
  }

  void _showSwitchDialog(_Plan plan) {
    final price = _isYearly
        ? '${_fmt(plan.yearlyDiscountedTotal!)} / year'
        : '${_fmt(plan.monthlyPrice!)} / month';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Switch to ${plan.name}?', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Text(
          'You\'ll be charged $price. Your current plan will be replaced immediately.',
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF6B7280)))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Plan switch to ${plan.name} coming soon!', style: GoogleFonts.inter()),
                backgroundColor: _primary, behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ));
            },
            style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text('Confirm Switch', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  BILLING TAB
  // ══════════════════════════════════════════════════════════════

  Widget _buildBillingTab() {
    final records = _filteredRecords;
    return RefreshIndicator(
      color: _primary,
      strokeWidth: 2.5,
      onRefresh: _fetchBillingHistory,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── KPI Summary (SaaS Dashboard style) ──
          if (_allBillingRecords.isNotEmpty) ...[
            _buildBillingSummary(),
            const SizedBox(height: 24),
          ],

          // First-load shimmer
          if (_isBillingLoading && _allBillingRecords.isEmpty)
            _buildBillingShimmer()
          // Error with no cached data
          else if (_billingError != null && _allBillingRecords.isEmpty)
            _buildBillingErrorState()
          // Data (or pull-to-refresh over existing data)
          else
            _buildBillingCard(records),
        ]),
      ),
    );
  }

  Widget _buildBillingSummary() {
    final paidRecords = _allBillingRecords.where((r) => r.payment == _PaymentStatus.paid).toList();
    final int totalSpent = paidRecords.fold(0, (sum, r) => sum + r.amount);
    final lastInvoice = paidRecords.isNotEmpty ? paidRecords.first : null;
    final nextBilling = _currentSubscription?.nextBillingDate ?? '—';

    return Row(children: [
      Expanded(child: _billingKPI(
        label: 'Total Investment',
        value: _fmtAmt(totalSpent),
        icon: Icons.payments_outlined,
        color: const Color(0xFF4F46E5),
        bgColor: const Color(0xFFEEF2FF)
      )),
      const SizedBox(width: 12),
      Expanded(child: _billingKPI(
        label: 'Last Invoice',
        value: lastInvoice != null ? _fmtAmt(lastInvoice.amount) : '—',
        icon: Icons.description_outlined,
        color: const Color(0xFF10B981),
        bgColor: const Color(0xFFECFDF5)
      )),
      const SizedBox(width: 12),
      Expanded(child: _billingKPI(
        label: 'Next Billing',
        value: nextBilling,
        icon: Icons.event_repeat_rounded,
        color: const Color(0xFFF59E0B),
        bgColor: const Color(0xFFFFFBEB)
      )),
    ]);
  }

  Widget _billingKPI({required String label, required String value, required IconData icon, required Color color, required Color bgColor}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(height: 12),
        Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF9CA3AF), letterSpacing: 0.3)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF111827)), overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  String _fmtAmt(int amount) {
    if (amount >= 10000) {
      return '₹${amount.toString().replaceAllMapped(RegExp(r"(\d)(?=(\d{3})+$)"), (m) => "${m[1]},")}';
    } else if (amount >= 1000) {
      final s = amount.toString();
      return '₹${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
    }
    return '₹$amount';
  }

  Widget _buildBillingCard(List<_BillingRecord> records) {
    return Container(
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Card Header ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
          child: Row(children: [
            // Icon
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(11)),
              child: const Icon(Icons.receipt_long_rounded, color: _primary, size: 20),
            ),
            const SizedBox(width: 12),
            // Title + record count
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Billing History',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF111827))),
              const SizedBox(height: 2),
              Text(
                _isBillingLoading
                    ? 'Loading…'
                    : '${_allBillingRecords.length} records',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280)),
              ),
            ])),
            // Filter dropdown
            _buildFilterDropdown(),
          ]),
        ),

        // Divider
        Container(height: 1, color: const Color(0xFFF1F5F9)),

        // ── Table (horizontal scroll on small screens) ───────────
        if (records.isEmpty)
          _buildBillingEmptyState()
        else
          _buildScrollableTable(records),

        // ── Footer ──────────────────────────────────────────────
        if (records.isNotEmpty)
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 6),
              Text('Showing ${records.length} of ${_allBillingRecords.length} records',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF9CA3AF))),
            ]),
          ),
      ]),
    );
  }

  // ── Filter Dropdown ──────────────────────────────────────────

  Widget _buildFilterDropdown() {
    return PopupMenuButton<String>(
      onSelected: (v) => setState(() => _billingFilter = v),
      offset: const Offset(0, 45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      shadowColor: Colors.black.withAlpha(40),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: _cardWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.filter_list_rounded, size: 16, color: Color(0xFF64748B)),
          const SizedBox(width: 8),
          Text(_billingFilter, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF94A3B8)),
        ]),
      ),
      itemBuilder: (ctx) => ['All Status', 'Active', 'Cancelled', 'Expired'].map((o) => PopupMenuItem(
        value: o,
        height: 42,
        child: Row(children: [
          Icon(Icons.circle, size: 8, color: _billingFilter == o ? _primary : Colors.transparent),
          const SizedBox(width: 10),
          Text(o, style: GoogleFonts.inter(fontSize: 13, fontWeight: _billingFilter == o ? FontWeight.w600 : FontWeight.w500,
                  color: _billingFilter == o ? _primary : const Color(0xFF1E293B))),
        ]),
      )).toList(),
    );
  }

  // ── Scrollable Table ─────────────────────────────────────────

  Widget _buildScrollableTable(List<_BillingRecord> records) {
    // Fixed column widths
    const colWidths = <double>[130, 175, 100, 110, 100, 110];
    const headers  = ['PLAN', 'PERIOD', 'AMOUNT', 'STATUS', 'PAYMENT', 'RECEIPT'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 800),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header row
          Container(
            color: const Color(0xFFF8FAFC),
            child: Row(
              children: List.generate(headers.length, (i) => _tableHeaderCell(headers[i], colWidths[i])),
            ),
          ),
          Container(height: 1, color: const Color(0xFFF1F5F9)),
          // Data rows
          ...records.asMap().entries.map((e) => _buildTableRow(e.value, colWidths, isEven: e.key.isEven)),
        ]),
      ),
    );
  }

  Widget _tableHeaderCell(String label, double width) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Text(label,
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700,
                color: const Color(0xFF64748B), letterSpacing: 0.8)),
      ),
    );
  }

  // ── Table Row ────────────────────────────────────────────────

  Widget _buildTableRow(_BillingRecord r, List<double> widths, {required bool isEven}) {
    return Column(children: [
      Container(
        color: isEven ? Colors.white : const Color(0xFFFAFAFC),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // Plan
          _dataCell(width: widths[0], child: _planNameCell(r.planName)),
          // Period
          _dataCell(width: widths[1], child: _periodCell(r)),
          // Amount
          _dataCell(width: widths[2], child: _amountCell(r.amount)),
          // Status
          _dataCell(width: widths[3], child: _statusBadge(r.status)),
          // Payment
          _dataCell(width: widths[4], child: _paymentCell(r.payment)),
          // Receipt
          _dataCell(width: widths[5], child: _receiptCell(r)),
        ]),
      ),
      Container(height: 1, color: const Color(0xFFF1F5F9)),
    ]);
  }

  Widget _dataCell({required double width, required Widget child}) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), 
        child: Align(alignment: Alignment.centerLeft, child: child)
      ),
    );
  }

  // ── Cell Widgets ─────────────────────────────────────────────

  Widget _planNameCell(String name) {
    const colors = {
      'Growth':  Color(0xFF4F46E5),
      'Pro':     Color(0xFF7C3AED),
      'Starter': Color(0xFF0EA5E9),
    };
    final color = colors[name] ?? const Color(0xFF6B7280);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 8, height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 8),
      Text(name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF111827))),
    ]);
  }

  Widget _periodCell(_BillingRecord r) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(r.periodFrom, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B))),
      const SizedBox(height: 2),
      Row(mainAxisSize: MainAxisSize.min, children: [
        Text(r.cycle, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.circle, size: 2, color: Color(0xFFCBD5E1))),
        Text('Expires ${r.periodTo}', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
      ]),
    ]);
  }

  Widget _amountCell(int amount) {
    String formatted;
    if (amount >= 10000) {
      formatted = '₹${amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';
    } else if (amount >= 1000) {
      final s = amount.toString();
      formatted = '₹${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
    } else {
      formatted = '₹$amount';
    }
    return Text(formatted,
        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF111827)));
  }

  Widget _statusBadge(_BillingStatus status) {
    String label;
    Color bg, fg;
    switch (status) {
      case _BillingStatus.active:
        label = 'Active'; bg = const Color(0xFFF0FDF4); fg = const Color(0xFF15803D);
        break;
      case _BillingStatus.cancelled:
        label = 'Cancelled'; bg = const Color(0xFFF8FAFC); fg = const Color(0xFF64748B);
        break;
      case _BillingStatus.expired:
        label = 'Expired'; bg = const Color(0xFFFEF2F2); fg = const Color(0xFFB91C1C);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(50), border: Border.all(color: fg.withAlpha(25))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 5, height: 5, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: fg, letterSpacing: 0.2)),
      ]),
    );
  }

  Widget _paymentCell(_PaymentStatus payment) {
    final isPaid = payment == _PaymentStatus.paid;
    final fg = isPaid ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: fg.withAlpha(15), borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(isPaid ? Icons.check_circle_rounded : Icons.info_rounded,
            size: 11, color: fg),
        const SizedBox(width: 5),
        Text(isPaid ? 'Success' : 'Failed',
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
      ]),
    );
  }

  Widget _receiptCell(_BillingRecord r) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      // View
      Tooltip(
        message: r.hasReceipt ? 'View receipt' : 'Receipt unavailable',
        child: GestureDetector(
          onTap: r.hasReceipt ? () => _showReceiptSnackbar(r, 'view') : null,
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: r.hasReceipt ? const Color(0xFFEEF2FF) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.visibility_rounded, size: 15,
                color: r.hasReceipt ? _primary : const Color(0xFFD1D5DB)),
          ),
        ),
      ),
      const SizedBox(width: 8),
      // Download
      Tooltip(
        message: r.hasReceipt ? 'Download receipt' : 'Receipt unavailable',
        child: GestureDetector(
          onTap: r.hasReceipt ? () => _showReceiptSnackbar(r, 'download') : null,
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: r.hasReceipt ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.download_rounded, size: 15,
                color: r.hasReceipt ? const Color(0xFF16A34A) : const Color(0xFFD1D5DB)),
          ),
        ),
      ),
    ]);
  }

  void _showReceiptSnackbar(_BillingRecord r, String action) {
    final pMethod = r.paymentMethod != null ? r.paymentMethod![0].toUpperCase() + r.paymentMethod!.substring(1) : 'PayU';
    final gMode = r.gatewayMode ?? 'UPI';
    final pRef = (r.paymentReference?.isNotEmpty ?? false) ? r.paymentReference! : r.id;

    if (action == 'view') {
      PaymentReceiptBottomSheet.show(
        context,
        receiptNo: pRef,
        date: r.periodFrom,
        planName: r.planName,
        libraryName: 'Vin Library Patna',
        paymentMethod: '$pMethod - $gMode',
        remarks: '',
        amount: r.amount,
      );
    } else {
      PaymentReceiptBottomSheet.downloadReceipt(
        context,
        receiptNo: pRef,
        date: r.periodFrom,
        planName: r.planName,
        libraryName: 'Vin Library Patna',
        paymentMethod: '$pMethod - $gMode',
        remarks: '',
        amount: r.amount,
        popContext: false,
      );
    }
  }

  // ── Empty State ──────────────────────────────────────────────

  Widget _buildBillingEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 56, height: 56,
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.receipt_long_rounded, size: 26, color: Color(0xFF9CA3AF))),
        const SizedBox(height: 14),
        Text('No billing records found', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF374151))),
        const SizedBox(height: 6),
        Text('Try changing the filter above', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF9CA3AF))),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => setState(() => _billingFilter = 'All Status'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(10)),
            child: Text('Clear filter', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _primary)),
          ),
        ),
      ])),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  SETTINGS TAB
  // ══════════════════════════════════════════════════════════════

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPlanBillingCard(),
          const SizedBox(height: 16),
          _buildNeedHelpCard(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Card 1: Plan & Billing Settings ─────────────────────────

  Widget _buildPlanBillingCard() {
    final sub = _currentSubscription;
    final planName = sub?.planName ?? 'No active plan';
    final cycle = sub?.cycle ?? '—';
    final expiry = sub?.periodTo ?? '—';

    return Container(
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.tune_rounded, color: _primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Plan & Billing Settings',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: const Color(0xFFF1F5F9)),

          // Row 1 – Current Plan
          _settingsRow(
            icon: Icons.workspace_premium_rounded,
            iconColor: _primary,
            iconBg: const Color(0xFFEEF2FF),
            title: 'Current Plan',
            subtitle: 'Your active subscription plan',
            value: planName,
            valueColor: _primary,
          ),
          Container(height: 1, color: const Color(0xFFF1F5F9)),

          // Row 2 – Billing Cycle
          _settingsRow(
            icon: Icons.sync_rounded,
            iconColor: const Color(0xFF0EA5E9),
            iconBg: const Color(0xFFE0F2FE),
            title: 'Billing Cycle',
            subtitle: 'How often you are billed',
            value: cycle,
          ),
          Container(height: 1, color: const Color(0xFFF1F5F9)),

          // Row 3 – Subscription Expires
          _settingsRow(
            icon: Icons.event_rounded,
            iconColor: const Color(0xFFD97706),
            iconBg: const Color(0xFFFEF3C7),
            title: 'Subscription Expires',
            subtitle: 'Your plan will expire on this date',
            value: expiry,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _settingsRow({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required String value,
    Color? valueColor,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 14, 20, isLast ? 18 : 14),
      child: Row(
        children: [
          // Icon container
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 19),
          ),
          const SizedBox(width: 14),
          // Title + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Right-aligned value
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: valueColor ?? const Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }

  // ── Card 2: Need Help ────────────────────────────────────────

  Widget _buildNeedHelpCard() {
    return Container(
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.help_outline_rounded,
                    color: Color(0xFFD97706),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Need Help?',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: const Color(0xFFF1F5F9)),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Box 1 – Info
                _helpInfoBox(
                  icon: Icons.info_rounded,
                  iconColor: _primary,
                  iconBg: const Color(0xFFEEF2FF),
                  bgColor: const Color(0xFFF8FAFF),
                  borderColor: const Color(0xFFE0E7FF),
                  text:
                      'To upgrade, downgrade, or cancel your subscription, visit the Plans tab or contact support.',
                ),
                const SizedBox(height: 12),
                // Box 2 – Email
                _helpInfoBox(
                  icon: Icons.email_rounded,
                  iconColor: const Color(0xFF0EA5E9),
                  iconBg: const Color(0xFFE0F2FE),
                  bgColor: const Color(0xFFF0F9FF),
                  borderColor: const Color(0xFFBAE6FD),
                  text:
                      'Contact us at support@libsoar.in for billing assistance.',
                  highlightWord: 'support@libsoar.in',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _helpInfoBox({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required Color bgColor,
    required Color borderColor,
    required String text,
    String? highlightWord,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildRichText(text, highlightWord, iconColor),
          ),
        ],
      ),
    );
  }

  Widget _buildRichText(String text, String? highlight, Color highlightColor) {
    if (highlight == null || !text.contains(highlight)) {
      return Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: const Color(0xFF374151),
          height: 1.5,
        ),
      );
    }
    final parts = text.split(highlight);
    return RichText(
      text: TextSpan(
        style: GoogleFonts.inter(
          fontSize: 12,
          color: const Color(0xFF374151),
          height: 1.5,
        ),
        children: [
          TextSpan(text: parts[0]),
          TextSpan(
            text: highlight,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: highlightColor,
              height: 1.5,
            ),
          ),
          TextSpan(text: parts[1]),
        ],
      ),
    );
  }
}

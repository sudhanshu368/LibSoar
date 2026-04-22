import '../../core/app_export.dart';
import '../../core/services/dashboard_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_navigation.dart';
import '../attendance_screen/attendance_screen.dart';
import '../payments_screen/payments_screen.dart';
import '../profile_screen/profile_screen.dart';
import '../seat_management_screen/seat_management_screen.dart';
import './widgets/home_expiring_subscriptions_widget.dart';
import './widgets/home_header_widget.dart';
import './widgets/home_payment_due_widget.dart';
import './widgets/home_payment_methods_widget.dart';
import './widgets/home_recent_checkins_widget.dart';
import './widgets/home_revenue_chart_widget.dart';
import './widgets/home_stats_grid_widget.dart';
import './widgets/home_student_requests_widget.dart';
import '../../core/utils/storage_helper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentNavIndex = 0;
  bool _isLoading = true;
  String? _selectedBranchId;
  List<Map<String, dynamic>> _branches = [];

  // 🔥 API DATA
  Map<String, dynamic>? statsData;
  Map<String, dynamic>? revenueData;
  Map<String, dynamic>? paymentSummary;
  List<dynamic> duePayments = [];
  List<dynamic> expiringSubs = [];
  int expiringSubsTotal = 0;
  int _homeRefreshToken = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  // 🚀 LOAD BRANCHES FIRST, THEN DASHBOARD
  Future<void> _loadInitialData() async {
    try {
      final savedBranchId = await StorageHelper.getBranchId();
      final branches = await DashboardService.getBranches();
      setState(() {
        _branches = branches;
        if (_branches.isNotEmpty) {
          if (savedBranchId != null && _branches.any((b) => b['id'] == savedBranchId)) {
            _selectedBranchId = savedBranchId;
          } else {
            _selectedBranchId = _branches[0]["id"];
            StorageHelper.saveBranchId(_selectedBranchId!);
          }
        }
      });
      // Now load dashboard with the first branch
      await loadDashboard(_selectedBranchId);
    } catch (e) {
      //print("❌ Initial load error: $e");
      // Load dashboard without branch if branches fail
      await loadDashboard();
    }
  }

  // 🚀 LOAD ALL DATA
  Future<void> loadDashboard([String? branchId]) async {
    try {
      setState(() => _isLoading = true);

      final stats = await DashboardService.getStats(branchId);
      final revenue = await DashboardService.getRevenue(branchId);
      final payments = await DashboardService.getPaymentSummary(branchId);
      final due = await DashboardService.getDuePayments(branchId);
      final subsRes = await DashboardService.getDashboardSubscriptions(branchId);

      setState(() {
        statsData = stats;
        revenueData = revenue;
        paymentSummary = payments;
        duePayments = due;
        expiringSubs = subsRes["list"] is List
            ? List<dynamic>.from(subsRes["list"] as List)
            : <dynamic>[];
        expiringSubsTotal = subsRes["total"] is num
            ? (subsRes["total"] as num).toInt()
            : expiringSubs.length;
        _homeRefreshToken++;
        _isLoading = false;
      });

    } catch (e) {
      //print("❌ Dashboard Error: $e");
      setState(() => _isLoading = false);
    }
  }

  void _onBranchSelected(String branchId, String branchName) {
    setState(() => _selectedBranchId = branchId);
    StorageHelper.saveBranchId(branchId);
    loadDashboard(branchId);
  }

  void _onNavTap(int index) {
    if (index == _currentNavIndex) return;
    setState(() => _currentNavIndex = index);
  }

  Widget _buildBody() {
    switch (_currentNavIndex) {
      case 1:
        return SeatManagementScreen(fromBottomNav: true, branchId: _selectedBranchId);
      case 2:
        return const PaymentsScreen(fromBottomNav: true);
      case 3:
        return AttendanceScreen(embedded: true, fromBottomNav: true, branchId: _selectedBranchId);
      case 4:
        return ProfileScreen(embedded: true);
      default:
        return _buildHomeContent();
    }
  }

  Widget _buildHomeContent() {
    if (_isLoading) return const DashboardSkeletonWidget();

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () => loadDashboard(_selectedBranchId),
      child: CustomScrollView(
        slivers: [

          /// 🔹 HEADER
          SliverToBoxAdapter(child: HomeHeaderWidget(
            onBranchSelected: _onBranchSelected,
            branches: _branches,
            selectedBranchId: _selectedBranchId,
          )),

          /// 🔹 STATS
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: HomeStatsGridWidget(data: statsData),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          /// 🔹 REVENUE + PAYMENT METHODS
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  HomeRevenueChartWidget(data: revenueData),
                  const SizedBox(height: 16),
                  HomePaymentMethodsWidget(data: paymentSummary),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          /// 🔹 STUDENT REQUEST + DUE PAYMENTS
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  HomeStudentRequestsWidget(
                    branchId: _selectedBranchId,
                    refreshToken: _homeRefreshToken,
                  ),
                  const SizedBox(height: 16),
                  HomePaymentDueWidget(data: duePayments),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          /// 🔹 EXPIRING SUBS
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: HomeExpiringSubscriptionsWidget(
                data: expiringSubs,
                totalCount: expiringSubsTotal,
                branchId: _selectedBranchId,
                onRefresh: () => loadDashboard(_selectedBranchId),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          /// 🔹 CHECKINS (optional static)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: HomeRecentCheckInsWidget(
                branchId: _selectedBranchId,
                refreshToken: _homeRefreshToken,
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: const AppDrawer(activeItem: 'Dashboard'),
      body: SafeArea(
        child: isTablet
            ? Row(
          children: [
            AppNavigation(
              currentIndex: _currentNavIndex,
              onTap: _onNavTap,
            ),
            Container(width: 1, color: theme.colorScheme.outline),
            Expanded(child: _buildBody()),
          ],
        )
            : _buildBody(),
      ),
      bottomNavigationBar: isTablet
          ? null
          : AppNavigation(
        currentIndex: _currentNavIndex,
        onTap: _onNavTap,
      ),
    );
  }
}
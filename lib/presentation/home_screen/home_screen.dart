import '../../core/app_export.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/dashboard_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_navigation.dart';
import '../add_student_screen/add_student_screen.dart';
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
  String _userName = "Admin";
  int _bufferDays = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await AuthService.getProfile();
      if (profile != null && profile.name.isNotEmpty) {
        setState(() => _userName = profile.name.split(' ')[0]);
      }
    } catch (_) {}
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
      
      // Fetch library settings for bufferDays
      final libSettings = await DashboardService.getLibrarySettings(branchId);
      final bufferDays = libSettings["facilities"]?["bufferDays"] as int? ?? 0;

      setState(() {
        statsData = stats;
        revenueData = revenue;
        paymentSummary = payments;
        duePayments = due;
        _bufferDays = bufferDays;
        
        final rawList = subsRes["list"] is List
            ? List<dynamic>.from(subsRes["list"] as List)
            : <dynamic>[];
        
        // Filter based on bufferDays if bufferDays > 0
        if (bufferDays > 0) {
          expiringSubs = rawList.where((item) {
            final daysLeft = int.tryParse(item["daysLeft"]?.toString() ?? "0") ?? 0;
            // Show if it's already expired (<=0) or within bufferDays
            return daysLeft <= bufferDays;
          }).toList();
        } else {
          expiringSubs = rawList;
        }

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
        return const AddStudentScreen(fromBottomNav: true);
      case 3:
        return const PaymentsScreen(fromBottomNav: true);
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

          /// 🔹 GREETING
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getGreeting(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "$_userName 👋",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          /// 🔹 STATS
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: HomeStatsGridWidget(data: statsData),
            ),
          ),

          /// 🔹 REVENUE
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: HomeRevenueChartWidget(data: revenueData),
            ),
          ),

          /// 🔹 PAYMENT METHODS
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: HomePaymentMethodsWidget(data: paymentSummary),
            ),
          ),

          /// 🔹 STUDENT REQUESTS
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: HomeStudentRequestsWidget(
                branchId: _selectedBranchId,
                refreshToken: _homeRefreshToken,
              ),
            ),
          ),

          /// 🔹 DUE PAYMENTS
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: HomePaymentDueWidget(data: duePayments),
            ),
          ),

          /// 🔹 EXPIRING SUBS
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: HomeExpiringSubscriptionsWidget(
                data: expiringSubs,
                totalCount: expiringSubsTotal,
                branchId: _selectedBranchId,
                bufferDays: _bufferDays,
                onRefresh: () => loadDashboard(_selectedBranchId),
              ),
            ),
          ),

          /// 🔹 CHECKINS
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
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
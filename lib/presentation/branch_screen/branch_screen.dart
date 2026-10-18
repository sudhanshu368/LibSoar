import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/services/api_service.dart';
import '../../core/services/dashboard_service.dart';
import '../../core/utils/storage_helper.dart';
import '../../widgets/empty_state_widget.dart';
import './widgets/add_branch_sheet_widget.dart';
import './widgets/branch_card_widget.dart';
import './widgets/branch_details_sheet.dart';

class BranchModel {
  final String id;
  final String code;
  final String name;
  final String address;
  final int totalSeats;
  final int totalStudents;
  final int activeStudents;
  final int bookedSeats;
  final bool isActive;
  final bool isDefault;
  final String phone;
  final String email;
  final int memberships;
  final int staff;
  final double revenue;
  final String createdAt;

  BranchModel({
    required this.id,
    this.code = '',
    required this.name,
    required this.address,
    this.totalSeats = 0,
    this.totalStudents = 0,
    this.activeStudents = 0,
    this.bookedSeats = 0,
    this.isActive = true,
    this.isDefault = false,
    this.phone = '',
    this.email = '',
    this.memberships = 0,
    this.staff = 0,
    this.revenue = 0.0,
    this.createdAt = '',
  });

  factory BranchModel.fromMap(Map<String, dynamic> map) {
    return BranchModel(
      id: map['id'] as String? ?? '',
      code: map['code'] as String? ?? '',
      name: map['name'] as String? ?? '',
      address: map['address'] as String? ?? '',
      totalSeats: map['totalSeats'] as int? ?? 0,
      totalStudents: map['totalStudents'] as int? ?? 0,
      activeStudents: map['activeStudents'] as int? ?? 0,
      bookedSeats: map['bookedSeats'] as int? ?? 0,
      isActive: map['status'] == 'active' || map['isActive'] == true,
      isDefault: map['isDefault'] as bool? ?? false,
      phone: map['phone'] as String? ?? '',
      email: map['email'] as String? ?? '',
      memberships: map['memberships'] as int? ?? 0,
      staff: map['staffCount'] as int? ?? map['staff'] as int? ?? 0,
      revenue: (map['revenue'] as num?)?.toDouble() ?? 0.0,
      createdAt: map['createdAt'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'code': code,
    'name': name,
    'address': address,
    'totalSeats': totalSeats,
    'totalStudents': totalStudents,
    'activeStudents': activeStudents,
    'bookedSeats': bookedSeats,
    'isActive': isActive,
    'isDefault': isDefault,
    'phone': phone,
    'email': email,
    'memberships': memberships,
    'staffCount': staff,
    'revenue': revenue,
    'createdAt': createdAt,
  };
}

class BranchScreen extends StatefulWidget {
  final bool embedded;
  const BranchScreen({super.key, this.embedded = false});

  @override
  State<BranchScreen> createState() => _BranchScreenState();
}

class _BranchScreenState extends State<BranchScreen> {
  bool _isLoading = true;
  String _defaultBranchId = '';
  int _maxBranches = 999; // Default to neutral high value until API responds
  late List<BranchModel> _branches = [];

  bool get _isLimitReached => _branches.length >= _maxBranches;

  @override
  void initState() {
    super.initState();
    _fetchBranches();
  }

  Future<void> _fetchBranches() async {
    try {
      final token = await StorageHelper.getToken();
      final savedBranchId = await StorageHelper.getBranchId();
      final res = await ApiService.get('/branches', token ?? '');

      if (!mounted) return;

      final data = res['data'] as List?;
      if (data != null) {
        final branchList = data
            .map((b) => BranchModel.fromMap(b as Map<String, dynamic>))
            .toList();

        setState(() {
          _branches = branchList;

          String targetId = '';
          if (savedBranchId != null &&
              branchList.any((b) => b.id == savedBranchId)) {
            targetId = savedBranchId;
          } else {
            final defaultB = branchList.where((b) => b.isDefault).firstOrNull;
            if (defaultB != null) {
              targetId = defaultB.id;
            } else if (branchList.isNotEmpty) {
              targetId = branchList.first.id;
            }
          }

          _defaultBranchId = targetId;
        });

        // Fetch active subscription for branch limit (Library-wide)
        await _fetchActiveSubscription();

        setState(() => _isLoading = false);

        if (_defaultBranchId.isNotEmpty && savedBranchId != _defaultBranchId) {
          StorageHelper.saveBranchId(_defaultBranchId);
        }

        _fetchBranchStats(); // dynamically populate dashboard stats
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load branches: $e')));
    }
  }

  Future<void> _fetchActiveSubscription() async {
    try {
      final rawData = await DashboardService.getActiveSubscription();
      debugPrint("RAW SUBSCRIPTION DATA: $rawData");

      Map<String, dynamic>? activeSubscription;

      if (rawData is List) {
        // Search through a list of subscriptions
        for (var item in rawData) {
          if (item is Map<String, dynamic> &&
              item['status'] == 'active' &&
              item['plan'] is Map &&
              item['plan']['isActive'] == true) {
            activeSubscription = item;
            break;
          }
        }
      } else if (rawData is Map<String, dynamic>) {
        // Check a single subscription object
        if (rawData['plan'] is Map && rawData['plan']['isActive'] == true) {
          activeSubscription = rawData;
        }
      }

      if (activeSubscription != null) {
        final plan = activeSubscription['plan'] as Map;
        final limitValue =
            plan['maxBranches'] ??
            plan['max_branches'] ??
            plan['branchesLimit'] ??
            plan['branchLimit'];

        if (limitValue != null) {
          final parsedLimit =
              int.tryParse(limitValue.toString()) ??
              (limitValue is int ? limitValue : _maxBranches);
          setState(() {
            _maxBranches = parsedLimit;
            debugPrint(
              "DYNAMIC LIMIT SYNC -> maxBranches: $_maxBranches | branches.length: ${_branches.length} | isLimitReached: $_isLimitReached",
            );
          });
          return; // Successfully updated
        }
      }

      debugPrint(
        "NO VALID ACTIVE PLAN FOUND IN DATA. FETCHING FREE PLAN FALLBACK.",
      );
      try {
        final plans = await DashboardService.getSubscriptionPlans();
        for (var p in plans) {
          if (p is Map &&
              (p['name']?.toString().toLowerCase() == 'free' ||
                  p['price'] == 0)) {
            final limitValue =
                p['maxBranches'] ??
                p['max_branches'] ??
                p['branchesLimit'] ??
                p['branchLimit'];
            if (limitValue != null) {
              final parsedLimit =
                  int.tryParse(limitValue.toString()) ??
                  (limitValue is int ? limitValue : _maxBranches);
              setState(() {
                _maxBranches = parsedLimit;
                debugPrint(
                  "DYNAMIC LIMIT SYNC (FREE PLAN) -> maxBranches: $_maxBranches | branches.length: ${_branches.length} | isLimitReached: $_isLimitReached",
                );
              });
              return; // Successfully updated with free plan
            }
          }
        }
      } catch (planErr) {
        debugPrint("FREE PLAN FETCH ERROR: $planErr");
      }

      debugPrint(
        "NO VALID PLAN FOUND IN DATA OR FALLBACK. RETAINING CURRENT LIMIT: $_maxBranches",
      );
    } catch (subErr) {
      debugPrint("SUBSCRIPTION FETCH ERROR: $subErr");
    }
  }

  Future<void> _fetchBranchStats() async {
    final futures = _branches.map((b) async {
      final statsFuture = DashboardService.getStats(b.id);
      final paymentFuture = DashboardService.getPaymentSummary(b.id);

      final results = await Future.wait([statsFuture, paymentFuture]);
      final stats = results[0];
      final payments = results[1];

      double rev = 0.0;
      final val =
          payments['totalRevenue'] ??
          payments['totalamount'] ??
          payments['totalAmount'] ??
          0;
      rev = double.tryParse(val.toString()) ?? 0.0;

      return {'branchId': b.id, 'stats': stats, 'revenue': rev};
    }).toList();

    final results = await Future.wait(futures);
    if (!mounted) return;

    setState(() {
      for (var res in results) {
        final bId = res['branchId'] as String;
        final stats = res['stats'] as Map<String, dynamic>;
        final double dynamicRev = res['revenue'] as double;

        if (stats.isNotEmpty || dynamicRev > 0) {
          final idx = _branches.indexWhere((b) => b.id == bId);
          if (idx != -1) {
            final b = _branches[idx];
            _branches[idx] = BranchModel(
              id: b.id,
              code: b.code,
              name: b.name,
              address: b.address,
              isActive: b.isActive,
              isDefault: b.isDefault,
              phone: b.phone,
              email: b.email,
              staff: b.staff,
              createdAt: b.createdAt,
              memberships: b.memberships,
              revenue: dynamicRev > 0 ? dynamicRev : b.revenue,
              totalSeats: stats['totalSeats'] as int? ?? b.totalSeats,
              totalStudents: stats['totalStudents'] as int? ?? b.totalStudents,
              activeStudents:
                  stats['activeStudents'] as int? ?? b.activeStudents,
              bookedSeats: stats['bookedSeats'] as int? ?? b.bookedSeats,
            );
          }
        }
      }
    });
  }

  Future<void> _setDefaultBranch(String id) async {
    await StorageHelper.saveBranchId(id);
    setState(() => _defaultBranchId = id);

    final branchName =
        _branches.where((b) => b.id == id).firstOrNull?.name ??
        'selected branch';

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              'Switched to $branchName',
              style: GoogleFonts.plusJakartaSans(),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showAddBranchDialog() {
    showDialog(
      context: context,
      builder: (_) => AddBranchDialogWidget(
        onAdd: (branch) async {
          final token = await StorageHelper.getToken();
          final body = {
            "name": branch.name,
            "address": branch.address,
            "phone": branch.phone,
            "email": branch.email,
            "isDefault": branch.isDefault,
            "status": branch.isActive ? "ACTIVE" : "INACTIVE",
          };

          final res = await ApiService.post(
            '/branches',
            body,
            token: token ?? '',
          );
          final assignedId = (res is Map && res['data'] is Map)
              ? res['data']['id']
              : branch.id;

          final newBranch = BranchModel(
            id: assignedId ?? branch.id,
            name: branch.name,
            address: branch.address,
            phone: branch.phone,
            email: branch.email,
            isActive: branch.isActive,
            isDefault: branch.isDefault,
          );

          if (!mounted) return;
          setState(() => _branches.add(newBranch));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Branch created successfully')),
          );
        },
      ),
    );
  }

  void _showDetailsSheet(BranchModel branch) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BranchDetailsSheetWidget(branch: branch),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
      "[UI-BUILD] _maxBranches: $_maxBranches | Total Branches: ${_branches.length} | IsLimitReached: $_isLimitReached",
    );
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 800;

    int totalBranches = _branches.length;
    int overallTotalStudents = _branches.fold(0, (s, b) => s + b.totalStudents);
    int overallActiveStudents = _branches.fold(
      0,
      (s, b) => s + b.activeStudents,
    );
    int activeBranches = _branches.where((b) => b.isActive).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      MediaQuery.of(context).padding.top + 12,
                      16,
                      24,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(32),
                        bottomRight: Radius.circular(32),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Branch Management',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (_maxBranches < 999)
                                    Text(
                                      'Plan Usage: ${_branches.length}/$_maxBranches branches',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white70,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            _isLimitReached
                                ? ElevatedButton.icon(
                                    key:
                                        UniqueKey(), // Force complete widget swap
                                    onPressed: _showUpgradePlanDialog,
                                    icon: const Icon(
                                      Icons.workspace_premium_rounded,
                                      size: 18,
                                      color: Color(0xFF92400E),
                                    ),
                                    label: Text(
                                      'Upgrade Plan',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF92400E),
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFFEF3C7),
                                      foregroundColor: const Color(0xFF92400E),
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: const BorderSide(
                                          color: Color(0xFFFCD34D),
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  )
                                : ElevatedButton.icon(
                                    key:
                                        UniqueKey(), // Force complete widget swap
                                    onPressed: _showAddBranchDialog,
                                    icon: const Icon(
                                      Icons.add_rounded,
                                      size: 18,
                                      color: Color(0xFF4F46E5),
                                    ),
                                    label: Text(
                                      'Add Branch',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF4F46E5),
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFF4F46E5),
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        GridView.count(
                          crossAxisCount: isDesktop ? 4 : 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: isDesktop ? 2.5 : 2.2,
                          children: [
                            _buildStatCard(
                              title: 'Total Branches',
                              value: totalBranches.toString(),
                              icon: Icons.business_outlined,
                              iconColor: const Color(0xFF3B82F6),
                              bgColor: const Color(0xFFEFF6FF),
                            ),
                            _buildStatCard(
                              title: 'Total Students',
                              value: overallTotalStudents.toString(),
                              icon: Icons.people_outline_rounded,
                              iconColor: const Color(0xFF10B981),
                              bgColor: const Color(0xFFECFDF5),
                            ),
                            _buildStatCard(
                              title: 'Active Students',
                              value: overallActiveStudents.toString(),
                              icon: Icons.how_to_reg_outlined,
                              iconColor: const Color(0xFF8B5CF6),
                              bgColor: const Color(0xFFF5F3FF),
                            ),
                            _buildStatCard(
                              title: 'Active Branches',
                              value: activeBranches.toString(),
                              icon: Icons.check_circle_outline_rounded,
                              iconColor: const Color(0xFFF59E0B),
                              bgColor: const Color(0xFFFFFBEB),
                            ),
                          ],
                        ),
                        if (_isLimitReached) ..._buildPlanLimitBanner(),
                      ],
                    ),
                  ),
                ),
                if (_branches.isEmpty)
                  SliverFillRemaining(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: EmptyStateWidget(
                        icon: Icons.business_outlined,
                        title: 'No branches yet',
                        description:
                            'Add your first library branch to start managing seats and students.',
                        actionLabel: _isLimitReached
                            ? 'Upgrade Plan'
                            : 'Add Branch',
                        onAction: _isLimitReached
                            ? _showUpgradePlanDialog
                            : _showAddBranchDialog,
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isDesktop ? 2 : 1,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        mainAxisExtent:
                            380, // adjusted for new 2x2 grid inside card
                      ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final branch = _branches[index];
                        return BranchCardWidget(
                          branch: branch,
                          isDefault: branch.id == _defaultBranchId,
                          onSetDefault: () => _setDefaultBranch(branch.id),
                          onViewDetails: () => _showDetailsSheet(branch),
                          onEdit: () => _showEditDialog(branch),
                          onDelete: () => _deleteBranch(branch),
                        );
                      }, childCount: _branches.length),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E293B),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPlanLimitBanner() {
    final int branchCount = _branches.length;
    final int planLimit = _maxBranches;
    return [
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFCD34D), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.22),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFCD34D).withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_rounded,
                color: Color(0xFF92400E),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "You've reached your plan's branch limit ($branchCount/$planLimit).",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF78350F),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Upgrade to add more branches.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF92400E),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _showUpgradePlanDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  'Upgrade',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  void _showUpgradePlanDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFDE68A), Color(0xFFFCD34D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Color(0xFF92400E),
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Upgrade Your Plan',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "You've reached the maximum of $_maxBranches branches on your current plan. Upgrade to unlock unlimited branches and more premium features.",
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    // TODO: Navigate to subscription/upgrade screen
                  },
                  icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                  label: Text(
                    'View Upgrade Plans',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF94A3B8),
                ),
                child: Text(
                  'Maybe later',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog(BranchModel branch) {
    showDialog(
      context: context,
      builder: (_) => AddBranchDialogWidget(
        existingBranch: branch,
        onAdd: (updated) async {
          final token = await StorageHelper.getToken();
          final body = {
            "name": updated.name,
            "address": updated.address,
            "phone": updated.phone,
            "email": updated.email,
            "isDefault": updated.isDefault,
            "status": updated.isActive ? "ACTIVE" : "INACTIVE",
          };

          await ApiService.patch(
            '/branches/${updated.id}',
            body,
            token: token ?? '',
          );

          if (!mounted) return;
          setState(() {
            final idx = _branches.indexWhere((b) => b.id == branch.id);
            if (idx >= 0) _branches[idx] = updated;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Branch updated successfully')),
          );
        },
      ),
    );
  }

  Future<void> _deleteBranch(BranchModel branch) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Branch',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete ${branch.name}? This action cannot be undone.',
          style: GoogleFonts.plusJakartaSans(),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(color: Colors.grey.shade700),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: GoogleFonts.plusJakartaSans(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final token = await StorageHelper.getToken();
      await ApiService.delete('/branches/${branch.id}', token: token ?? '');

      if (!mounted) return;
      setState(() {
        _branches.removeWhere((b) => b.id == branch.id);
        if (_defaultBranchId == branch.id) {
          _defaultBranchId = _branches.isNotEmpty ? _branches.first.id : '';
          StorageHelper.saveBranchId(_defaultBranchId);
        }
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Branch deleted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete branch: $e')));
    }
  }
}

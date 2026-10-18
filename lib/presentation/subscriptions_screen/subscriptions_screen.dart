import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/app_drawer.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/storage_helper.dart';
import './widgets/renew_membership_dialog.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  String _selectedTab = 'All';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _showEntries = 20;
  bool _isLoading = true;
  String _branchId = '';

  final Map<String, int> _stats = {'active': 0, 'expiring': 0, 'expired': 0};

  final List<String> _tabs = ['All', 'Active', 'Expiring Soon', 'Expired'];
  final List<int> _entryOptions = [10, 20, 50, 100];

  final List<Map<String, dynamic>> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final branchId = await StorageHelper.getBranchId();
    if (branchId != null) {
      _branchId = branchId;
    }
    await Future.wait([_fetchStats(), _fetchSubscriptions()]);
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchStats() async {
    try {
      final token = await StorageHelper.getToken();
      final res = await ApiService.get(
        '/subscriptions/stats?branchId=$_branchId',
        token ?? '',
      );
      if (res['success'] == true && res['data'] != null) {
        if (mounted) {
          setState(() {
            _stats['active'] = res['data']['active'] ?? 0;
            _stats['expiring'] = res['data']['expiring'] ?? 0;
            _stats['expired'] = res['data']['expired'] ?? 0;
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to load stats: $e');
    }
  }

  Future<void> _fetchSubscriptions() async {
    try {
      final token = await StorageHelper.getToken();
      String url =
          '/subscriptions?page=1&limit=$_showEntries&branchId=$_branchId&sortBy=endDate&sortOrder=desc';

      final res = await ApiService.get(url, token ?? '');
      if (res['success'] == true && res['data'] is List) {
        if (mounted) {
          setState(() {
            _subscriptions.clear();
            for (var item in res['data']) {
              final student = item['student'] ?? {};
              final shiftData = item['shiftData'] ?? {};
              _subscriptions.add({
                'id': item['id'],
                'student': student['name'] ?? 'Unknown',
                'shift': shiftData['name'] ?? 'No Shift',
                'startDate': _formatDate(item['startDate']),
                'endDate': _formatDate(item['endDate']),
                'totalFee': '₹${item['totalFee'] ?? 0}',
                'paid': '₹${item['paidAmount'] ?? 0}',
                'due': '₹${item['dueAmount'] ?? 0}',
                'status': _capitalize(item['status'] ?? ''),
                'raw': item,
              });
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to load subscriptions: $e');
    }
  }

  String _formatDate(dynamic dateVal) {
    if (dateVal == null || dateVal.toString().isEmpty) return '-';
    try {
      final dtStr = dateVal.toString();
      final dt = DateTime.parse(dtStr).toLocal();
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
      return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
    } catch (e) {
      return dateVal.toString();
    }
  }

  String _capitalize(String s) {
    if (s.isEmpty) return '';
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  List<Map<String, dynamic>> get _filteredSubscriptions {
    List<Map<String, dynamic>> result = _subscriptions;
    if (_selectedTab != 'All') {
      result = result
          .where(
            (s) =>
                s['status'] == _selectedTab ||
                (_selectedTab == 'Expiring Soon' && s['status'] == 'Expiring'),
          )
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      result = result
          .where(
            (s) => s['student'].toString().toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ),
          )
          .toList();
    }
    return result;
  }

  int get _activeCount => _stats['active'] ?? 0;
  int get _expiringSoonCount => _stats['expiring'] ?? 0;
  int get _expiredCount => _stats['expired'] ?? 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const AppDrawer(activeItem: 'Subscriptions'),
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            _buildAppBar(),
            // Body
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF4F46E5),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Gradient Header Card
                          _buildGradientHeader(),
                          const SizedBox(height: 16),
                          // Summary Cards
                          _buildSummaryCards(),
                          const SizedBox(height: 16),
                          // Filter + Search Row
                          _buildFilterSearchRow(),
                          const SizedBox(height: 16),
                          // Table Controls + Table
                          _buildTableSection(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          Builder(
            builder: (context) => GestureDetector(
              onTap: () => Scaffold.of(context).openDrawer(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.menu_rounded,
                  color: Color(0xFF374151),
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Student Memberships',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
        ],
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
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(51),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Student Memberships',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Dashboard / Student Memberships',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withAlpha(204),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            title: 'Active',
            count: _activeCount,
            icon: Icons.trending_up_rounded,
            iconBgColor: const Color(0xFFDCFCE7),
            iconColor: const Color(0xFF16A34A),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            title: 'Expiring Soon',
            count: _expiringSoonCount,
            icon: Icons.currency_rupee_rounded,
            iconBgColor: const Color(0xFFFEF3C7),
            iconColor: const Color(0xFFD97706),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            title: 'Expired',
            count: _expiredCount,
            icon: Icons.refresh_rounded,
            iconBgColor: const Color(0xFFFEE2E2),
            iconColor: const Color(0xFFDC2626),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterSearchRow() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: _tabs.map((tab) => _buildTab(tab)).toList()),
          ),
          const SizedBox(height: 12),
          // Search + Refresh
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF111827),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search student...',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF9CA3AF),
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: Color(0xFF9CA3AF),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                    _selectedTab = 'All';
                    _isLoading = true;
                  });
                  _loadData();
                },
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Icon(
                    Icons.refresh_rounded,
                    size: 20,
                    color: Color(0xFF4F46E5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String tab) {
    final isSelected = _selectedTab == tab;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = tab),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          tab,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  Widget _buildTableSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table Controls
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Text(
                  'Show',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  height: 36,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _showEntries,
                      items: _entryOptions
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(
                                '$e',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: const Color(0xFF111827),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _showEntries = v;
                            _isLoading = true;
                          });
                          _fetchSubscriptions().then((_) {
                            if (mounted) setState(() => _isLoading = false);
                          });
                        }
                      },
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF111827),
                      ),
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'entries',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          // Divider
          Container(height: 1, color: const Color(0xFFF1F5F9)),
          // Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _buildTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    const headers = [
      'Student',
      'Shift',
      'Start Date',
      'End Date',
      'Total Fee',
      'Paid',
      'Due',
      'Status',
      'Actions',
    ];
    const colWidths = [
      160.0,
      120.0,
      130.0,
      130.0,
      100.0,
      90.0,
      90.0,
      110.0,
      220.0,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Row
        Container(
          color: const Color(0xFFF8FAFC),
          child: Row(
            children: List.generate(headers.length, (i) {
              return Container(
                width: colWidths[i],
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Text(
                  headers[i],
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6B7280),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
          ),
        ),
        Container(height: 1, color: const Color(0xFFF1F5F9)),
        // Data Rows or Empty State
        _filteredSubscriptions.isEmpty
            ? _buildEmptyState(colWidths)
            : Column(
                children: _filteredSubscriptions
                    .map((sub) => _buildDataRow(sub, colWidths))
                    .toList(),
              ),
      ],
    );
  }

  Widget _buildEmptyState(List<double> colWidths) {
    final totalWidth = colWidths.fold(0.0, (a, b) => a + b);
    return SizedBox(
      width: totalWidth,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(
                  Icons.inbox_rounded,
                  size: 28,
                  color: Color(0xFF9CA3AF),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'No memberships found',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataRow(Map<String, dynamic> sub, List<double> colWidths) {
    final statusColor = sub['status'] == 'Active'
        ? const Color(0xFF16A34A)
        : sub['status'] == 'Expiring Soon'
        ? const Color(0xFFD97706)
        : const Color(0xFFDC2626);
    final statusBg = sub['status'] == 'Active'
        ? const Color(0xFFDCFCE7)
        : sub['status'] == 'Expiring Soon'
        ? const Color(0xFFFEF3C7)
        : const Color(0xFFFEE2E2);

    return Column(
      children: [
        Row(
          children: [
            _cell(sub['student'] ?? '', colWidths[0], bold: true),
            _cell(sub['shift'] ?? '', colWidths[1]),
            _cell(sub['startDate'] ?? '', colWidths[2]),
            _cell(sub['endDate'] ?? '', colWidths[3]),
            _cell(sub['totalFee'] ?? '', colWidths[4]),
            _cell(sub['paid'] ?? '', colWidths[5]),
            _cell(sub['due'] ?? '', colWidths[6]),
            // Status
            Container(
              width: colWidths[7],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  sub['status'] ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // Actions
            Container(
              width: colWidths[8],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => RenewMembershipDialog(
                          branchId: _branchId,
                          subscription: sub['raw'],
                          onRenewed: () {
                            _isLoading = true;
                            _loadData();
                          },
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: const Size(0, 32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(
                      'Renew',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => RenewMembershipDialog(
                          branchId: _branchId,
                          subscription: sub['raw'],
                          onRenewed: () {
                            _isLoading = true;
                            _loadData();
                          },
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: const Size(0, 32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(
                      'Change Plan',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Container(height: 1, color: const Color(0xFFF8FAFC)),
      ],
    );
  }

  Widget _cell(String text, double width, {bool bold = false}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
          color: bold ? const Color(0xFF111827) : const Color(0xFF374151),
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;

  const _SummaryCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(height: 12),
          Text(
            '$count',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6B7280),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

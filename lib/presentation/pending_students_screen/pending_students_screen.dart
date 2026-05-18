import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/dashboard_service.dart';
import '../../core/utils/storage_helper.dart';
import '../../widgets/app_drawer.dart';

class PendingStudentsScreen extends StatefulWidget {
  const PendingStudentsScreen({super.key});

  @override
  State<PendingStudentsScreen> createState() => _PendingStudentsScreenState();
}

class _PendingStudentsScreenState extends State<PendingStudentsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _activeShift = 'All Shift';
  String _searchQuery = '';
  bool _isCardExpanded = true;
  bool _isGridView = false;
  int _showEntries = 10;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _shifts = [
    'All Shift',
    '24 Hours Shift',
    'Morning Shift',
    'Full Day Shift',
    'Afternoon Shift',
    'Evening Shift',
    'Night Shift',
  ];

  List<Map<String, dynamic>> _allStudents = [];
  bool _isLoading = true;
  String? _selectedBranchId;
  List<Map<String, dynamic>> _branches = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final savedBranchId = await StorageHelper.getBranchId();
      final branches = await DashboardService.getBranches();
      if (mounted) {
        setState(() {
          _branches = branches;
          if (_branches.isNotEmpty) {
            if (savedBranchId != null && _branches.any((b) => b['id'] == savedBranchId)) {
              _selectedBranchId = savedBranchId;
            } else {
              _selectedBranchId = _branches[0]["id"];
            }
          }
        });
        await _fetchPendingStudents();
      }
    } catch (e) {
      if (mounted) await _fetchPendingStudents();
    }
  }

  Future<void> _fetchPendingStudents() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final res = await DashboardService.getPendingStudentRequests(_selectedBranchId, 1, 100);
      final list = res["list"] as List<dynamic>;
      
      if (mounted) {
        setState(() {
          _allStudents = list.map((item) {
            final s = item as Map<String, dynamic>;
            final seat = s['seat'] as Map<String, dynamic>?;
            final subscriptions = s['subscriptions'] as List<dynamic>?;
            final subscriptionMap = s['subscription'] as Map<String, dynamic>?;
            
            final firstSub = (subscriptions != null && subscriptions.isNotEmpty) ? (subscriptions[0] as Map<String, dynamic>?) : null;
            final shiftData = firstSub?['shiftData'] as Map<String, dynamic>?;
            final shiftName = subscriptionMap?['shift'] ?? shiftData?['name'] ?? 'All Shift';

            final paymentStatus = subscriptionMap?['dueAmount'] != null 
                ? ((subscriptionMap!['dueAmount'] as num) > 0 ? 'Pending' : 'Paid') 
                : 'Pending';

            return {
              'id': s['id'],
              'name': s['name'] ?? 'Unknown',
              'phone': s['phone'] ?? '',
              'seat': seat?['number'] ?? 'N/A',
              'shift': shiftName ?? 'All Shift',
              'status': s['status'] == 'PENDING' ? 'Pending' : (s['status'] ?? 'Unknown'),
              'payment': paymentStatus,
              'type': s['seatType'] ?? (seat?['seatType'] == 'regular' ? 'Regular' : 'Premium'),
              'color': const Color(0xFF6366F1),
              '_raw': s,
            };
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching students: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  final Map<String, bool> _visibleColumns = {
    'Name': true,
    'Phone': true,
    'Seat': true,
    'Shift': true,
    'Status': true,
    'Payment': true,
    'Type': true,
    'Actions': true,
  };

  List<Map<String, dynamic>> get _filteredStudents {
    List<Map<String, dynamic>> result = List.from(_allStudents);
    if (_activeShift != 'All Shift') {
      result = result.where((s) => s['shift'] == _activeShift).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((s) {
        return (s['name'] as String).toLowerCase().contains(q) ||
            (s['phone'] as String).toLowerCase().contains(q) ||
            (s['seat'] as String).toLowerCase().contains(q);
      }).toList();
    }
    return result.take(_showEntries).toList();
  }

  int _shiftCount(String shift) {
    if (shift == 'All Shift') return _allStudents.length;
    return _allStudents.where((s) => s['shift'] == shift).length;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleExport() {
    final count = _filteredStudents.length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.download_done_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'Exported $count pending student${count == 1 ? '' : 's'} successfully',
              style: GoogleFonts.inter(fontSize: 13),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF4F46E5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showColumnToggle() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Toggle Columns',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ..._visibleColumns.keys.map(
                (col) => SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    col,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF374151),
                    ),
                  ),
                  value: _visibleColumns[col]!,
                  activeThumbColor: const Color(0xFF4F46E5),
                  onChanged: (val) {
                    setModalState(() => _visibleColumns[col] = val);
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showViewDialog(Map<String, dynamic> student) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF4F46E5).withAlpha(26),
                    child: Text(
                      (student['name'] as String)[0].toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF4F46E5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student['name'],
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        _StatusBadge(status: student['status']),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: Color(0xFF64748B),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 16),
              _DetailRow(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: student['phone'],
              ),
              _DetailRow(
                icon: Icons.chair_outlined,
                label: 'Seat',
                value: student['seat'],
              ),
              _DetailRow(
                icon: Icons.schedule_rounded,
                label: 'Shift',
                value: student['shift'],
              ),
              _DetailRow(
                icon: Icons.payment_rounded,
                label: 'Payment',
                value: student['payment'],
              ),
              _DetailRow(
                icon: Icons.badge_outlined,
                label: 'Type',
                value: student['type'],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Close',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showApproveDialog(Map<String, dynamic> student) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: Color(0xFF10B981),
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Approve Student',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to approve ${student['name']}?',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await DashboardService.approveStudent(student['id']);
                          if (mounted) {
                            Navigator.pop(ctx);
                            _fetchPendingStudents();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${student['name']} approved successfully',
                                  style: GoogleFonts.inter(fontSize: 13),
                                ),
                                backgroundColor: const Color(0xFF10B981),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to approve: $e')),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Approve',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRejectDialog(Map<String, dynamic> student) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(
                  Icons.cancel_outlined,
                  color: Color(0xFFEF4444),
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Reject Student',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to reject ${student['name']}? This action cannot be undone.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await DashboardService.rejectStudent(student['id']);
                          if (mounted) {
                            Navigator.pop(ctx);
                            _fetchPendingStudents();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${student['name']} rejected',
                                  style: GoogleFonts.inter(fontSize: 13),
                                ),
                                backgroundColor: const Color(0xFFEF4444),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to reject: $e')),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Reject',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const AppDrawer(activeItem: 'Pending Students'),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Color(0xFF0F172A)),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(
          'Pending Students',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0F172A),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.business_rounded, color: Color(0xFF0F172A)),
            tooltip: 'Select Branch',
            onPressed: () {
              if (_branches.isEmpty) return;
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (ctx) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _branches.map((b) {
                    final isSelected = _selectedBranchId == b['id'];
                    return ListTile(
                      title: Text(
                        b['name'] ?? '',
                        style: GoogleFonts.inter(
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF0F172A),
                        ),
                      ),
                      trailing: isSelected ? const Icon(Icons.check_rounded, color: Color(0xFF4F46E5)) : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        if (_selectedBranchId != b['id']) {
                          setState(() => _selectedBranchId = b['id']);
                          StorageHelper.saveBranchId(b['id']);
                          _fetchPendingStudents();
                        }
                      },
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF4F46E5),
        onRefresh: _fetchPendingStudents,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGradientHeader(),
              const SizedBox(height: 16),
              _buildManagementCard(),
            ],
          ),
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
              Icons.group_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Students',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'Dashboard',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white.withAlpha(204),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white.withAlpha(204),
                      size: 16,
                    ),
                  ),
                  Text(
                    'Pending Students',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildManagementCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Student Management',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isCardExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF64748B),
                  ),
                  onPressed: () =>
                      setState(() => _isCardExpanded = !_isCardExpanded),
                ),
              ],
            ),
          ),
          if (_isCardExpanded) ...[
            Container(height: 1, color: const Color(0xFFF1F5F9)),
            const SizedBox(height: 12),
            _buildShiftTabs(),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildSearchActionBar(),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildTableControls(),
            ),
            const SizedBox(height: 12),
            _buildStudentList(),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildShiftTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: _shifts.map((shift) {
          final isActive = _activeShift == shift;
          final count = _shiftCount(shift);
          return GestureDetector(
            onTap: () => setState(() => _activeShift = shift),
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isActive
                        ? const Color(0xFF4F46E5)
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    shift,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$count',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? Colors.white
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchActionBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 40,
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
                color: const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: 'Search by Name, ID, phone number, Seat Number...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF94A3B8),
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: Color(0xFF94A3B8),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _ActionIconButton(
          icon: _isGridView ? Icons.list_rounded : Icons.grid_view_rounded,
          tooltip: _isGridView ? 'Switch to List View' : 'Switch to Grid View',
          onTap: () => setState(() => _isGridView = !_isGridView),
        ),
        const SizedBox(width: 6),
        _ActionButton(
          label: 'Export',
          icon: Icons.download_rounded,
          onTap: _handleExport,
        ),
        const SizedBox(width: 6),
        _ActionButton(
          label: 'Columns',
          icon: Icons.view_column_rounded,
          onTap: _showColumnToggle,
        ),
      ],
    );
  }

  Widget _buildTableControls() {
    return Row(
      children: [
        Text(
          'Show',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _showEntries,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF0F172A),
              ),
              items: [10, 25, 50, 100]
                  .map((e) => DropdownMenuItem(value: e, child: Text('$e')))
                  .toList(),
              onChanged: (v) => setState(() => _showEntries = v ?? 10),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: Color(0xFF64748B),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'entries',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF64748B),
          ),
        ),
        const Spacer(),
        Text(
          'Showing ${_filteredStudents.length} of ${_allStudents.length}',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  Widget _buildStudentList() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))),
      );
    }
    final students = _filteredStudents;
    if (students.isEmpty) {
      return _buildEmptyState();
    }
    if (_isGridView) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.82,
          ),
          itemCount: students.length,
          itemBuilder: (context, index) => _buildGridCard(students[index]),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(children: students.map((s) => _buildTableRow(s)).toList()),
    );
  }

  Widget _buildGridCard(Map<String, dynamic> student) {
    final initial = (student['name'] as String)[0].toUpperCase();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF4F46E5).withAlpha(26),
                child: Text(
                  initial,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF4F46E5),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  student['name'],
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _StatusBadge(status: student['status']),
          const SizedBox(height: 6),
          Text(
            student['phone'],
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF64748B),
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '${student['seat']} • ${student['shift']}',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF64748B),
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 6),
          _PaymentBadge(payment: student['payment']),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _IconAction(
                icon: Icons.visibility_rounded,
                color: const Color(0xFF4F46E5),
                onTap: () => _showViewDialog(student),
              ),
              const SizedBox(width: 4),
              _IconAction(
                icon: Icons.check_circle_rounded,
                color: const Color(0xFF10B981),
                onTap: () => _showApproveDialog(student),
              ),
              const SizedBox(width: 4),
              _IconAction(
                icon: Icons.cancel_rounded,
                color: const Color(0xFFEF4444),
                onTap: () => _showRejectDialog(student),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(Map<String, dynamic> student) {
    final initial = (student['name'] as String)[0].toUpperCase();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFF4F46E5).withAlpha(26),
            child: Text(
              initial,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF4F46E5),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        student['name'],
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusBadge(status: student['status']),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.phone_outlined,
                      size: 13,
                      color: Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      student['phone'],
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.chair_outlined,
                      size: 13,
                      color: Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        '${student['seat']} • ${student['shift']}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _PaymentBadge(payment: student['payment']),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        student['type'],
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF374151),
                        ),
                      ),
                    ),
                    const Spacer(),
                    _IconAction(
                      icon: Icons.visibility_rounded,
                      color: const Color(0xFF4F46E5),
                      onTap: () => _showViewDialog(student),
                    ),
                    const SizedBox(width: 6),
                    _IconAction(
                      icon: Icons.check_circle_rounded,
                      color: const Color(0xFF10B981),
                      onTap: () => _showApproveDialog(student),
                    ),
                    const SizedBox(width: 6),
                    _IconAction(
                      icon: Icons.cancel_rounded,
                      color: const Color(0xFFEF4444),
                      onTap: () => _showRejectDialog(student),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(32),
            ),
            child: const Icon(
              Icons.inbox_rounded,
              size: 32,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No data found',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'There are no pending students at the moment.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper Widgets ─────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 10),
          Text(
            '$label:',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F172A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  const _EditField({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF4F46E5)),
            ),
          ),
        ),
      ],
    );
  }
}

class _EditDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  const _EditDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF0F172A),
              ),
              items: items
                  .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status) {
      case 'Active':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        break;
      case 'Inactive':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        break;
      default:
        bg = const Color(0xFFFEF9C3);
        fg = const Color(0xFFCA8A04);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

class _PaymentBadge extends StatelessWidget {
  final String payment;
  const _PaymentBadge({required this.payment});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (payment) {
      case 'Paid':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        break;
      case 'Unpaid':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        break;
      default:
        bg = const Color(0xFFFEF9C3);
        fg = const Color(0xFFCA8A04);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        payment,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  const _ActionIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF64748B)),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: const Color(0xFF64748B)),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _IconAction({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withAlpha(26),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 15, color: color),
      ),
    );
  }
}

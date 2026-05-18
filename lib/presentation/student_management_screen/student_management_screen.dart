import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/app_drawer.dart';
import '../../core/services/dashboard_service.dart';
import '../../core/utils/storage_helper.dart';
import 'dart:ui';
import '../../core/services/api_service.dart';

class StudentManagementScreen extends StatefulWidget {
  final bool fromBottomNav;
  const StudentManagementScreen({super.key, this.fromBottomNav = false});

  @override
  State<StudentManagementScreen> createState() =>
      _StudentManagementScreenState();
}

class _StudentManagementScreenState extends State<StudentManagementScreen> {
  String _activeShift = 'All Shift';
  String _statusFilter = 'All';
  String _searchQuery = '';
  bool _isCardExpanded = true;
  bool _isGridView = false;
  int _showEntries = 10;
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  List<Map<String, dynamic>> _apiStudents = [];
  int _totalEntries = 0;
  int _currentPage = 1;
  int _totalPages = 1;
  String? _selectedBranchId;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _initAndFetch();
  }

  Future<void> _initAndFetch() async {
    _selectedBranchId = await StorageHelper.getBranchId();
    _fetchStudents();
  }

  Future<void> _fetchStudents() async {
    setState(() {
      _isLoading = true;
    });

    final res = await DashboardService.getStudents(
      branchId: _selectedBranchId,
      page: _currentPage,
      limit: _showEntries,
      status: _statusFilter,
      search: _searchQuery,
      sortBy: 'createdAt',
      sortOrder: 'desc',
    );

    if (!mounted) return;

    final data = res['data'] as List?;
    final meta = res['meta']?['pagination'];

    List<Map<String, dynamic>> parsedSet = [];
    if (data != null) {
      for (var student in data) {
        final sub = student['subscription'];
        final due = sub != null ? (sub['dueAmount'] ?? 0) : 0;
        parsedSet.add({
          'id': student['id'] ?? '',
          'name': student['name'] ?? '',
          'phone': student['phone'] ?? '',
          'whatsappNumber': (student['whatsappNumber'] ?? student['whatsapp'] ?? student['whatsapp_number'] ?? student['profile']?['whatsappNumber'] ?? student['profile']?['whatsapp'] ?? '').toString(),
          'email': (student['email'] ?? student['profile']?['email'] ?? '').toString(),
          'address': (student['address'] ?? student['location'] ?? student['residence'] ?? student['profile']?['address'] ?? '').toString(),
          'gender': student['gender'] ?? 'male',
          'seat': student['seat']?['number'] ?? 'N/A',
          'shift': sub?['shift'] ?? 'N/A',
          'status': student['status'] ?? 'N/A',
          'payment': due > 0 ? 'Unpaid' : 'Paid',
          'type': student['seatType'] ?? 'Regular',
          '_raw': student,
        });
      }
    }

    setState(() {
      _apiStudents = parsedSet;
      if (meta != null) {
        _totalEntries = meta['total'] ?? 0;
        _totalPages = meta['totalPages'] ?? 1;
      }
      _isLoading = false;
    });
  }

  bool _isShiftMatch(String studentShift, String tabLabel) {
    if (tabLabel == 'All Shift') return true;
    final s1 = studentShift.toLowerCase().replaceAll('_', ' ');
    final s2 = tabLabel.toLowerCase().replaceAll(' shift', '');
    return s1 == s2 || s1.contains(s2) || s2.contains(s1);
  }

  List<Map<String, dynamic>> get _filteredStudents {
    return _apiStudents.where((s) {
      return _isShiftMatch(s['shift']?.toString() ?? '', _activeShift);
    }).toList();
  }

  List<Map<String, dynamic>> get _shiftTabs {
    final tabs = [
      'All Shift',
      '24 Hours Shift',
      'Morning Shift',
      'Full Day Shift',
      'Afternoon Shift',
      'Evening Shift',
      'Night Shift',
    ];
    return tabs.map((label) {
      final count = label == 'All Shift'
          ? _apiStudents.length
          : _apiStudents.where((s) => _isShiftMatch(s['shift']?.toString() ?? '', label)).length;
      return {'label': label, 'count': count};
    }).toList();
  }

  final List<String> _statusOptions = ['All', 'Active', 'Inactive', 'Pending'];
  final List<int> _entriesOptions = [10, 25, 50, 100];

  final Map<String, bool> _visibleColumns = {
    'Name': true,
    'Phone': true,
    'WhatsApp': false,
    'Address': false,
    'Seat': true,
    'Shift': true,
    'Status': true,
    'Payment': true,
    'Type': true,
    'Actions': true,
  };

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
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
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
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
                    style: GoogleFonts.plusJakartaSans(
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
              'Exported $count student${count == 1 ? '' : 's'} successfully',
              style: GoogleFonts.plusJakartaSans(fontSize: 13),
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

  Future<Map<String, dynamic>> _getFullStudentData(Map<String, dynamic> localStudent) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );
      final res = await DashboardService.getStudentById(localStudent['id']);
      if (mounted) Navigator.pop(context);

      final data = res['data'];
      if (data != null && data is Map<String, dynamic>) {
        final whatsapp = (data['whatsappNumber'] ?? data['whatsapp'] ?? data['whatsapp_number'] ?? data['profile']?['whatsappNumber'] ?? data['profile']?['whatsapp'] ?? '').toString();
        final address = (data['address'] ?? data['location'] ?? data['residence'] ?? data['profile']?['address'] ?? '').toString();
        final email = (data['email'] ?? data['profile']?['email'] ?? '').toString();

        return {
          ...localStudent,
          'whatsappNumber': whatsapp.isNotEmpty ? whatsapp : localStudent['whatsappNumber'],
          'address': address.isNotEmpty ? address : localStudent['address'],
          'email': email.isNotEmpty ? email : localStudent['email'],
          // Keep raw object for edit sheet if needed
          '_raw': {
            ...(localStudent['_raw'] as Map<String, dynamic>? ?? {}),
            ...data,
          }
        };
      }
      return localStudent;
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to fetch full details: $e')));
      return localStudent;
    }
  }

  Future<void> _handleView(Map<String, dynamic> student) async {
    final fullStudent = await _getFullStudentData(student);
    _showViewDialog(fullStudent);
  }

  Future<void> _handleEdit(Map<String, dynamic> student) async {
    final fullStudent = await _getFullStudentData(student);
    _showEditSheet(fullStudent);
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
                      style: GoogleFonts.plusJakartaSans(
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
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        _StatusBadge(status: student['status']),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: Color(0xFF6B7280),
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
              _DetailRow(
                icon: Icons.message_outlined,
                label: 'WhatsApp',
                value: (student['whatsappNumber']?.toString().trim().isEmpty ?? true) ? 'N/A' : student['whatsappNumber'].toString(),
              ),
              _DetailRow(
                icon: Icons.email_outlined,
                label: 'Email',
                value: student['email']?.toString() ?? 'N/A',
              ),
              _DetailRow(
                icon: Icons.location_on_outlined,
                label: 'Address',
                value: (student['address']?.toString().trim().isEmpty ?? true) ? 'N/A' : student['address'].toString(),
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
                    style: GoogleFonts.plusJakartaSans(
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

  void _showEditSheet(Map<String, dynamic> student) {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ModernEditForm(
        student: student,
        onSaved: (updatedData) async {
          final idx = _apiStudents.indexOf(student);
          if (idx != -1) {
            setState(() {
              _apiStudents[idx] = updatedData;
            });
          }
        },
      ),
    );
  }

  void _showDeleteDialog(Map<String, dynamic> student) {
    showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(20),
                  blurRadius: 40,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut,
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFFEE2E2), width: 4),
                        ),
                        child: const Icon(
                          Icons.delete_sweep_rounded,
                          color: Color(0xFFEF4444),
                          size: 32,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  'Remove Student?',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You are about to permanently delete',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                Text(
                  student['name'],
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Keep Student',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          // Call DELETE API
                          try {
                            final token = await StorageHelper.getToken();
                            final id = student['id'];
                            await ApiService.delete('/students/$id', token: token);
                            
                            setState(() => _apiStudents.remove(student));
                            if (mounted) Navigator.pop(ctx);
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: Colors.white),
                                    const SizedBox(width: 8),
                                    Text('Student removed successfully', style: GoogleFonts.plusJakartaSans()),
                                  ],
                                ),
                                backgroundColor: const Color(0xFFEF4444),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e', style: GoogleFonts.plusJakartaSans()),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Yes, Delete',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: widget.fromBottomNav
          ? null
          : const AppDrawer(activeItem: 'Student List'),
      body: SafeArea(
        child: Column(
          children: [
            if (!widget.fromBottomNav) _buildAppBar(),
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFF4F46E5),
                onRefresh: _fetchStudents,
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Builder(
            builder: (ctx) => GestureDetector(
              onTap: () => Scaffold.of(ctx).openDrawer(),
              child: Container(
                padding: const EdgeInsets.all(8),
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
            'Student Management',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
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
      padding: const EdgeInsets.all(18),
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(51),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.group_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Students',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    'Dashboard',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: Colors.white.withAlpha(179),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white.withAlpha(179),
                      size: 14,
                    ),
                  ),
                  Text(
                    'Students',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
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
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Student Management',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                ),
                GestureDetector(
                  onTap: () =>
                      setState(() => _isCardExpanded = !_isCardExpanded),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _isCardExpanded
                          ? Icons.unfold_less_rounded
                          : Icons.unfold_more_rounded,
                      color: const Color(0xFF6B7280),
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isCardExpanded) ...[
            Container(height: 1, color: const Color(0xFFF1F5F9)),
            _buildShiftTabs(),
            Container(height: 1, color: const Color(0xFFF1F5F9)),
            _buildSearchActionBar(),
            Container(height: 1, color: const Color(0xFFF1F5F9)),
            _buildTableControls(),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))),
              )
            else
              _buildTable(),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildShiftTabs() {
    final tabs = _shiftTabs;
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: tabs.length,
        itemBuilder: (context, index) {
          final tab = tabs[index];
          final isActive = _activeShift == tab['label'];
          return GestureDetector(
            onTap: () => setState(() => _activeShift = tab['label']),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF4F46E5)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tab['label'],
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      color: isActive ? Colors.white : const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.white.withAlpha(51)
                          : const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${tab['count']}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? Colors.white
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchActionBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (v) {
                _searchQuery = v;
                if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
                _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                  _currentPage = 1;
                  _fetchStudents();
                });
              },
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: const Color(0xFF374151),
              ),
              decoration: InputDecoration(
                hintText: 'Search by Name, ID, phone number, Seat Number...',
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: const Color(0xFF9CA3AF),
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF9CA3AF),
                  size: 18,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _ActionIconButton(
                  icon: _isGridView
                      ? Icons.grid_view_rounded
                      : Icons.view_list_rounded,
                  onTap: () => setState(() => _isGridView = !_isGridView),
                  tooltip: _isGridView
                      ? 'Switch to List View'
                      : 'Switch to Grid View',
                ),
                const SizedBox(width: 8),
                _StatusDropdown(
                  value: _statusFilter,
                  options: _statusOptions,
                  onChanged: (v) {
                    setState(() {
                      _statusFilter = v!;
                      _currentPage = 1;
                    });
                    _fetchStudents();
                  },
                ),
                const SizedBox(width: 8),
                _OutlineButton(
                  label: 'Export',
                  icon: Icons.download_rounded,
                  onTap: _handleExport,
                ),
                const SizedBox(width: 8),
                _OutlineButton(
                  label: 'Columns',
                  icon: Icons.view_column_rounded,
                  onTap: _showColumnToggle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Text(
            'Show',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _showEntries,
                isDense: true,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: const Color(0xFF374151),
                ),
                items: _entriesOptions
                    .map((e) => DropdownMenuItem(value: e, child: Text('$e')))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _showEntries = v!;
                    _currentPage = 1;
                  });
                  _fetchStudents();
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'entries',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: const Color(0xFF6B7280),
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              'Showing ${_filteredStudents.length} entries (Total: $_totalEntries)',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: const Color(0xFF9CA3AF),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          if (_totalPages > 1)
            Row(
              children: [
                IconButton(
                  onPressed: _currentPage > 1 ? () {
                    setState(() => _currentPage--);
                    _fetchStudents();
                  } : null,
                  icon: const Icon(Icons.chevron_left_rounded, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: _currentPage > 1 ? const Color(0xFF4F46E5) : const Color(0xFF9CA3AF),
                ),
                const SizedBox(width: 8),
                Text('$_currentPage / $_totalPages', style: GoogleFonts.plusJakartaSans(fontSize: 12)),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _currentPage < _totalPages ? () {
                    setState(() => _currentPage++);
                    _fetchStudents();
                  } : null,
                  icon: const Icon(Icons.chevron_right_rounded, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: _currentPage < _totalPages ? const Color(0xFF4F46E5) : const Color(0xFF9CA3AF),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTable() {
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
            childAspectRatio: 0.85,
          ),
          itemCount: students.length,
          itemBuilder: (context, index) => _buildGridCard(students[index]),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: students.map((s) => _buildStudentCard(s)).toList(),
      ),
    );
  }

  Widget _buildGridCard(Map<String, dynamic> student) {
    final initial = student['name'].toString().isNotEmpty
        ? student['name'].toString().substring(0, 1).toUpperCase()
        : '?';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
                  style: GoogleFonts.plusJakartaSans(
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
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
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
          Row(
            children: [
              const Icon(Icons.phone_outlined, size: 11, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  student['phone'],
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF6B7280)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (student['whatsappNumber'] != null && student['whatsappNumber'].toString().trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.message_outlined, size: 11, color: Color(0xFF10B981)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    student['whatsappNumber'],
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF6B7280)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          if (student['address'] != null && student['address'].toString().trim().isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 11, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    student['address'],
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF6B7280)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          Text(
            '${student['seat']} • ${student['shift']}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: const Color(0xFF6B7280),
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
              _RowActionBtn(
                icon: Icons.visibility_outlined,
                color: const Color(0xFF4F46E5),
                tooltip: 'View',
                onTap: () => _handleView(student),
              ),
              const SizedBox(width: 4),
              _RowActionBtn(
                icon: Icons.edit_outlined,
                color: const Color(0xFF10B981),
                tooltip: 'Edit',
                onTap: () => _handleEdit(student),
              ),
              const SizedBox(width: 4),
              _RowActionBtn(
                icon: Icons.delete_outline_rounded,
                color: const Color(0xFFEF4444),
                tooltip: 'Delete',
                onTap: () => _showDeleteDialog(student),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final initial = student['name'].toString().isNotEmpty
        ? student['name'].toString().substring(0, 1).toUpperCase()
        : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
              style: GoogleFonts.plusJakartaSans(
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
                        student['name'] ?? '-',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusBadge(status: student['status'] ?? '-'),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.phone_outlined,
                      size: 13,
                      color: Color(0xFF9CA3AF),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      student['phone'] ?? '-',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                    if (student['whatsappNumber'] != null && student['whatsappNumber'].toString().trim().isNotEmpty) ...[
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.message_outlined,
                        size: 13,
                        color: Color(0xFF10B981),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        student['whatsappNumber'].toString(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (student['address'] != null && student['address'].toString().trim().isNotEmpty) ...[
                      const Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: Color(0xFF9CA3AF),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          student['address'].toString(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: const Color(0xFF6B7280),
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.chair_outlined,
                      size: 13,
                      color: Color(0xFF9CA3AF),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        '${student['seat'] ?? '-'} • ${student['shift'] ?? '-'}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: const Color(0xFF6B7280),
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
                    _PaymentBadge(payment: student['payment'] ?? '-'),
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
                        student['type'] ?? '-',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF374151),
                        ),
                      ),
                    ),
                    const Spacer(),
                    _RowActionBtn(
                      icon: Icons.visibility_outlined,
                      color: const Color(0xFF4F46E5),
                      tooltip: 'View',
                      onTap: () => _handleView(student),
                    ),
                    const SizedBox(width: 6),
                    _RowActionBtn(
                      icon: Icons.edit_outlined,
                      color: const Color(0xFF10B981),
                      tooltip: 'Edit',
                      onTap: () => _handleEdit(student),
                    ),
                    const SizedBox(width: 6),
                    _RowActionBtn(
                      icon: Icons.delete_outline_rounded,
                      color: const Color(0xFFEF4444),
                      tooltip: 'Delete',
                      onTap: () => _showDeleteDialog(student),
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
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(
              Icons.people_outline_rounded,
              color: Color(0xFF9CA3AF),
              size: 32,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No data found',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'No students match the current filters',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: const Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helper Widgets ──────────────────────────────────────────────────────────

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
          Icon(icon, size: 16, color: const Color(0xFF9CA3AF)),
          const SizedBox(width: 10),
          Text(
            '$label:',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF111827),
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
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: const Color(0xFF111827),
          ),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
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
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: const Color(0xFF111827),
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
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF065F46);
        break;
      case 'Inactive':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFF991B1B);
        break;
      default:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: GoogleFonts.plusJakartaSans(
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
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF065F46);
        break;
      case 'Unpaid':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFF991B1B);
        break;
      default:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        payment,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

class _RowActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _RowActionBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 15, color: color),
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
          height: 36,
          width: 36,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: Icon(icon, color: const Color(0xFF6B7280), size: 18),
        ),
      ),
    );
  }
}

class _StatusDropdown extends StatelessWidget {
  final String value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  const _StatusDropdown({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: const Color(0xFF374151),
          ),
          hint: Text(
            'Status: All',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: const Color(0xFF6B7280),
            ),
          ),
          items: options
              .map((o) => DropdownMenuItem(value: o, child: Text('Status: $o')))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _OutlineButton({
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
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: const Color(0xFF6B7280)),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
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

class _TableHeaderCell extends StatelessWidget {
  final String label;
  final int flex;
  const _TableHeaderCell({required this.label, this.flex = 1});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF6B7280),
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _ModernEditForm extends StatefulWidget {
  final Map<String, dynamic> student;
  final Function(Map<String, dynamic>) onSaved;

  const _ModernEditForm({required this.student, required this.onSaved});

  @override
  State<_ModernEditForm> createState() => _ModernEditFormState();
}

class _ModernEditFormState extends State<_ModernEditForm> {
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _whatsappCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _seatCtrl;
  late String _selectedShift;
  late String _selectedStatus;
  late String _selectedGender;
  late String _selectedType;
  bool _isWhatsAppSameAsPhone = false;
  bool _isLoading = false;

  final _shifts = ['Morning Shift', 'Evening Shift', 'Night Shift', 'Full Day Shift', 'Afternoon Shift', '24 Hours Shift'];
  final _statuses = ['ACTIVE', 'INACTIVE', 'PENDING'];
  final _genders = ['male', 'female', 'others'];
  final _types = ['FIXED', 'FLEXIBLE'];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.student['name']);
    _phoneCtrl = TextEditingController(text: widget.student['phone']);
    _whatsappCtrl = TextEditingController(text: widget.student['whatsappNumber'] ?? '');
    _emailCtrl = TextEditingController(text: widget.student['email'] ?? '');
    _addressCtrl = TextEditingController(text: widget.student['address'] ?? '');
    _seatCtrl = TextEditingController(text: widget.student['seat']?.toString());
    _selectedShift = widget.student['shift'] ?? 'Morning Shift';
    if (!_shifts.contains(_selectedShift)) _selectedShift = _shifts.first;
    
    _selectedStatus = widget.student['status']?.toUpperCase() ?? 'ACTIVE';
    if (!_statuses.contains(_selectedStatus)) _selectedStatus = _statuses.first;

    _selectedGender = widget.student['gender']?.toLowerCase() ?? 'male';
    if (!_genders.contains(_selectedGender)) _selectedGender = _genders.first;

    _isWhatsAppSameAsPhone = (_phoneCtrl.text == (_whatsappCtrl?.text ?? widget.student['whatsappNumber']?.toString() ?? ""));

    _selectedType = widget.student['type']?.toUpperCase() ?? 'FIXED';
    if (!_types.contains(_selectedType)) _selectedType = _types.first;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _seatCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() => _isLoading = true);
    try {
      final token = await StorageHelper.getToken();
      final id = widget.student['id'];
      
      final payload = {
        "name": _nameCtrl.text,
        "phone": _phoneCtrl.text,
        "whatsappNumber": _whatsappCtrl.text,
        "email": _emailCtrl.text,
        "address": _addressCtrl.text,
        "gender": _selectedGender, // Sent as lower-case as expected by API
        "status": _selectedStatus.toUpperCase(),
        "seatType": _selectedType.toUpperCase(),
      };
      
      await ApiService.patch('/students/$id', payload, token: token);
      
      final updatedData = {
        ...widget.student,
        'name': _nameCtrl.text,
        'phone': _phoneCtrl.text,
        'whatsappNumber': _whatsappCtrl.text,
        'email': _emailCtrl.text,
        'address': _addressCtrl.text,
        'gender': _selectedGender,
        'seat': _seatCtrl.text,
        'shift': _selectedShift,
        'status': _selectedStatus,
        'type': _selectedType,
      };

      widget.onSaved(updatedData);
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Text('Student updated successfully!', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e', style: GoogleFonts.plusJakartaSans()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(25),
              blurRadius: 40,
              offset: const Offset(0, -10),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.edit_document, color: Color(0xFF4F46E5), size: 22),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Edit Student', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF111827))),
                          Text(widget.student['name'], style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF6B7280))),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF9CA3AF)),
                    )
                  ],
                ),
              ),
              // Body
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
                  child: Column(
                    children: [
                      _buildModernTextField(label: 'Full Name', icon: Icons.person_outline, controller: _nameCtrl),
                      const SizedBox(height: 16),
                       _buildModernTextField(
                        label: 'Phone Number', 
                        icon: Icons.phone_outlined, 
                        controller: _phoneCtrl, 
                        keyboardType: TextInputType.phone,
                        onChanged: (v) {
                          if (_isWhatsAppSameAsPhone) {
                            setState(() => _whatsappCtrl.text = v);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildModernTextField(label: 'Seat', icon: Icons.chair_alt_outlined, controller: _seatCtrl)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildModernDropdown(label: 'Type', icon: Icons.badge_outlined, value: _selectedType, items: _types, onChanged: (v) => setState(() => _selectedType = v!)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildModernDropdown(label: 'Shift', icon: Icons.schedule_rounded, value: _selectedShift, items: _shifts, onChanged: (v) => setState(() => _selectedShift = v!)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('WhatsApp Number', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF374151))),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isWhatsAppSameAsPhone = !_isWhatsAppSameAsPhone;
                                if (_isWhatsAppSameAsPhone) {
                                  _whatsappCtrl.text = _phoneCtrl.text;
                                }
                              });
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: Checkbox(
                                    value: _isWhatsAppSameAsPhone,
                                    onChanged: (v) {
                                      setState(() {
                                        _isWhatsAppSameAsPhone = v ?? false;
                                        if (_isWhatsAppSameAsPhone) {
                                          _whatsappCtrl.text = _phoneCtrl.text;
                                        }
                                      });
                                    },
                                    activeColor: const Color(0xFF4F46E5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Same as phone',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: _isWhatsAppSameAsPhone ? const Color(0xFF4F46E5) : const Color(0xFF6B7280),
                                    fontWeight: _isWhatsAppSameAsPhone ? FontWeight.w600 : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildModernTextField(
                        label: '', 
                        showLabel: false,
                        icon: Icons.message_outlined, 
                        controller: _whatsappCtrl, 
                        keyboardType: TextInputType.phone,
                        enabled: !_isWhatsAppSameAsPhone,
                      ),
                      const SizedBox(height: 16),
                      _buildModernTextField(label: 'Email Address', icon: Icons.email_outlined, controller: _emailCtrl, keyboardType: TextInputType.emailAddress),
                      const SizedBox(height: 16),
                      _buildModernTextField(label: 'Address', icon: Icons.location_on_outlined, controller: _addressCtrl),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildModernDropdown(label: 'Status', icon: Icons.auto_graph_rounded, value: _selectedStatus, items: _statuses, onChanged: (v) => setState(() => _selectedStatus = v!)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildModernDropdown(label: 'Gender', icon: Icons.person_search_outlined, value: _selectedGender, items: _genders, onChanged: (v) => setState(() => _selectedGender = v!)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text('Save Changes', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required String label, 
    required IconData icon, 
    required TextEditingController controller, 
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
    bool showLabel = true,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF374151))),
          const SizedBox(height: 8),
        ],
        Container(
          decoration: BoxDecoration(
            color: enabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            enabled: enabled,
            onChanged: onChanged,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14, 
              color: enabled ? const Color(0xFF111827) : const Color(0xFF94A3B8),
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, size: 20, color: const Color(0xFF94A3B8)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernDropdown({required String label, required IconData icon, required String value, required List<String> items, required ValueChanged<String?> onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF374151))),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF94A3B8)),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: value,
                    isExpanded: true,
                    icon: const Icon(Icons.expand_more_rounded, color: Color(0xFF94A3B8)),
                    dropdownColor: Colors.white,
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFF111827)),
                    items: items.map((i) => DropdownMenuItem(
                      value: i, 
                      child: Text(i[0].toUpperCase() + i.substring(1).toLowerCase()),
                    )).toList(),
                    onChanged: onChanged,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
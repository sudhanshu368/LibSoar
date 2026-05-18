import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/app_drawer.dart';
import '../../core/services/dashboard_service.dart';
import '../../core/utils/storage_helper.dart';

class _AttendanceRecord {
  final String id;
  final String name;
  final String phone;
  final String seat;
  final String shift;
  String time;
  final String source;
  String status; // Present, Absent, Pending

  _AttendanceRecord({
    required this.id,
    required this.name,
    required this.phone,
    required this.seat,
    required this.shift,
    required this.time,
    required this.source,
    required this.status,
  });
}

class AttendanceScreen extends StatefulWidget {
  final bool embedded;
  final bool fromBottomNav;
  final String? branchId;
  const AttendanceScreen({
    super.key,
    this.embedded = false,
    this.fromBottomNav = false,
    this.branchId,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  String _activeFilter = 'All';
  String _selectedShift = 'All Shifts';
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _markedIds = {};
  bool _isLoading = true;

  final List<String> _filterTabs = ['All', 'Pending', 'Present', 'Absent'];
  List<String> _shifts = ['All Shifts'];
  final Map<String, String> _shiftMap = {};

  List<_AttendanceRecord> _allRecords = [];

  List<_AttendanceRecord> get _filteredRecords {
    return _allRecords.where((record) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          record.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          record.phone.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          record.seat.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesFilter =
          _activeFilter == 'All' || record.status == _activeFilter;
      final matchesShift =
          _selectedShift == 'All Shifts' || record.shift == _selectedShift;
      return matchesSearch && matchesFilter && matchesShift;
    }).toList();
  }

  int get _presentCount =>
      _allRecords.where((r) => r.status == 'Present').length;
  int get _absentCount => _allRecords.where((r) => r.status == 'Absent').length;
  int get _pendingCount =>
      _allRecords.where((r) => r.status == 'Pending').length;

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  @override
  void didUpdateWidget(covariant AttendanceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.branchId != widget.branchId) {
      _loadAttendance();
    }
  }

  Future<void> _loadAttendance() async {
    String? currentBranchId = widget.branchId;
    if (currentBranchId == null) {
      try {
        final savedBranchId = await StorageHelper.getBranchId();
        final branches = await DashboardService.getBranches();
        if (branches.isNotEmpty) {
           if (savedBranchId != null && branches.any((b) => b['id'] == savedBranchId)) {
             currentBranchId = savedBranchId;
           } else {
             currentBranchId = branches[0]['id'];
           }
        }
      } catch (e) {
          print("Failed to load branches in AttendanceScreen: $e");
      }
    }

    if (currentBranchId == null) {
      setState(() {
        _allRecords = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final dateStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
      
      // Fetch shifts and build map
      final shiftsData = await DashboardService.getShifts(currentBranchId);
      _shiftMap.clear();
      List<String> tempShifts = ['All Shifts'];
      for (var s in shiftsData) {
        if (s['id'] != null && s['name'] != null) {
          _shiftMap[s['id'].toString()] = s['name'].toString();
          tempShifts.add(s['name'].toString());
        }
      }

      final data = await DashboardService.getAttendance(
        date: dateStr,
        branchId: currentBranchId,
      );
      
      final dataList = data['data'] as List? ?? [];
      final mapped = dataList.map((item) {
        String rawStatus = item['status']?.toString().toLowerCase() ?? 'pending';
        String uiStatus = 'Pending';
        if (rawStatus == 'present') uiStatus = 'Present';
        if (rawStatus == 'absent') uiStatus = 'Absent';

        final rawShift = item['shift']?.toString() ?? '-';
        final mappedShift = _shiftMap[rawShift] ?? rawShift;

        final markedBy = item['markedBy']?.toString() ?? '-';

        return _AttendanceRecord(
          id: item['id']?.toString() ?? '',
          name: item['name']?.toString() ?? '',
          phone: item['phone']?.toString() ?? '',
          seat: item['seat']?.toString() ?? '-',
          shift: mappedShift,
          time: item['checkInTime']?.toString() ?? '--:--',
          source: markedBy == 'null' || markedBy.isEmpty ? 'System' : markedBy,
          status: uiStatus,
        );
      }).toList();

      setState(() {
        _shifts = tempShifts;
        if (!_shifts.contains(_selectedShift)) {
          _selectedShift = 'All Shifts';
        }
        _allRecords = mapped;
        _isLoading = false;
      });
    } catch (e) {
      print("Attendance load error: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAttendance(_AttendanceRecord record, String status) async {
    final oldStatus = record.status;
    setState(() {
      record.status = status;
    });

    try {
      final dateStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
      final res = await DashboardService.markAttendance(
        studentId: record.id,
        status: status.toUpperCase(),
        date: dateStr,
      );
      
      if (res != null && res['success'] == true) {
        final data = res['data'];
        if (data != null && data['checkIn'] != null) {
          final DateTime? checkInDate = DateTime.tryParse(data['checkIn'].toString());
          if (checkInDate != null) {
            final localDate = checkInDate.toLocal();
            setState(() {
              record.time = "${localDate.hour > 12 ? localDate.hour - 12 : (localDate.hour == 0 ? 12 : localDate.hour)}:${localDate.minute.toString().padLeft(2, '0')} ${localDate.hour >= 12 ? 'PM' : 'AM'}";
            });
          }
        }
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${record.name} marked as $status',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
          ),
          backgroundColor: status == 'Present' ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      setState(() {
        record.status = oldStatus;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to mark attendance'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    const months = [
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
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatShortDate(DateTime date) {
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
    return '${date.day} ${months[date.month - 1]}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4F46E5),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF111827),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadAttendance();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final filtered = _filteredRecords;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      drawer: widget.fromBottomNav
          ? null
          : const AppDrawer(activeItem: 'Attendance'),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF4F46E5),
          onRefresh: _loadAttendance,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!widget.fromBottomNav) _buildHeaderCard(),
                if (!widget.fromBottomNav) const SizedBox(height: 16),
                _buildGradientHeaderCard(),
                const SizedBox(height: 16),
                _buildStatsRow(isDark),
                const SizedBox(height: 16),
                _buildMainCard(isDark, filtered),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Builder(
            builder: (ctx) => GestureDetector(
              onTap: () => Scaffold.of(ctx).openDrawer(),
              child: const Icon(
                Icons.menu_rounded,
                color: Color(0xFF374151),
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Attendance Management',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.assignment_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Attendance',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Dashboard / Attendance',
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

  Widget _buildStatsRow(bool isDark) {
    final stats = [
      _StatData(
        label: 'Total Students',
        count: _allRecords.length,
        icon: Icons.people_outline_rounded,
        iconBg: const Color(0xFFEEF2FF),
        iconColor: const Color(0xFF4F46E5),
        countColor: const Color(0xFF4F46E5),
      ),
      _StatData(
        label: 'Present',
        count: _presentCount,
        icon: Icons.check_rounded,
        iconBg: const Color(0xFFDCFCE7),
        iconColor: const Color(0xFF16A34A),
        countColor: const Color(0xFF16A34A),
      ),
      _StatData(
        label: 'Absent',
        count: _absentCount,
        icon: Icons.close_rounded,
        iconBg: const Color(0xFFFEE2E2),
        iconColor: const Color(0xFFDC2626),
        countColor: const Color(0xFFDC2626),
      ),
      _StatData(
        label: 'Pending',
        count: _pendingCount,
        icon: Icons.access_time_rounded,
        iconBg: const Color(0xFFFEF3C7),
        iconColor: const Color(0xFFD97706),
        countColor: const Color(0xFFD97706),
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(stats.length, (i) {
          return Padding(
            padding: EdgeInsets.only(right: i < stats.length - 1 ? 10 : 0),
            child: SizedBox(
              width: 160,
              child: _StatCard(stat: stats[i], isDark: isDark),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMainCard(bool isDark, List<_AttendanceRecord> filtered) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
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
          // Date + Filter Row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          _formatDate(_selectedDate),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF111827),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${filtered.length} records',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF6B7280),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _formatShortDate(_selectedDate),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF374151),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _ShiftDropdown(
                  value: _selectedShift,
                  items: _shifts,
                  isDark: isDark,
                  onChanged: (val) => setState(() => _selectedShift = val),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
          ),
          // Search + Filter Tabs Row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim();
                    });
                  },
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search by name, phone or seat...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 13,
                      color: isDark
                          ? const Color(0xFF64748B)
                          : const Color(0xFF9CA3AF),
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: isDark
                          ? const Color(0xFF64748B)
                          : const Color(0xFF9CA3AF),
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: isDark
                                  ? const Color(0xFF64748B)
                                  : const Color(0xFF9CA3AF),
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Color(0xFF4F46E5),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Filter Tabs
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filterTabs.map((tab) {
                      final isActive = _activeFilter == tab;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () => setState(() => _activeFilter = tab),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.transparent
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isActive
                                    ? const Color(0xFF4F46E5)
                                    : Colors.transparent,
                                width: isActive ? 1.5 : 1,
                              ),
                            ),
                            child: Text(
                              tab,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: isActive
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: isActive
                                    ? const Color(0xFF4F46E5)
                                    : (isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF6B7280)),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
          ),
          // Horizontally scrollable table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: MediaQuery.of(context).size.width - 32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTableHeader(isDark),
                  Divider(
                    height: 1,
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFF1F5F9),
                  ),
                  filtered.isEmpty
                      ? _buildEmptyState(isDark)
                      : Column(
                          children: filtered.map((record) {
                            return _buildRecordRow(record, isDark);
                          }).toList(),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(bool isDark) {
    final headerStyle = GoogleFonts.inter(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(width: 160, child: Text('Name', style: headerStyle)),
          SizedBox(width: 140, child: Text('Phone', style: headerStyle)),
          SizedBox(width: 80, child: Text('Seat', style: headerStyle)),
          SizedBox(width: 100, child: Text('Shift', style: headerStyle)),
          SizedBox(width: 100, child: Text('Time', style: headerStyle)),
          SizedBox(width: 100, child: Text('Source', style: headerStyle)),
          SizedBox(width: 180, child: Text('Actions', style: headerStyle)),
        ],
      ),
    );
  }

  Widget _buildRecordRow(_AttendanceRecord record, bool isDark) {
    Color statusColor;
    Color statusBg;
    switch (record.status) {
      case 'Present':
        statusColor = const Color(0xFF16A34A);
        statusBg = const Color(0xFFDCFCE7);
        break;
      case 'Absent':
        statusColor = const Color(0xFFDC2626);
        statusBg = const Color(0xFFFEE2E2);
        break;
      default:
        statusColor = const Color(0xFFD97706);
        statusBg = const Color(0xFFFEF3C7);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Name
              SizedBox(
                width: 160,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: const Color(0xFFEEF2FF),
                      child: Text(
                        record.name.isNotEmpty
                            ? record.name[0].toUpperCase()
                            : '?',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        record.name,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF111827),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // Phone
              SizedBox(
                width: 140,
                child: Text(
                  record.phone,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF374151),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Seat
              SizedBox(
                width: 80,
                child: Text(
                  record.seat,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
              ),
              // Shift
              SizedBox(
                width: 100,
                child: Text(
                  record.shift,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF374151),
                  ),
                ),
              ),
              // Time
              SizedBox(
                width: 100,
                child: Text(
                  record.time,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF374151),
                  ),
                ),
              ),
              // Source
              SizedBox(
                width: 100,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    record.source,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF6B7280),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              // Actions - Present / Absent buttons
              SizedBox(
                width: 180,
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => _markAttendance(record, 'Present'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: record.status == 'Present'
                              ? const Color(0xFF16A34A)
                              : (isDark
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFFF0FDF4)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: record.status == 'Present'
                                ? const Color(0xFF16A34A)
                                : const Color(0xFF16A34A).withAlpha(80),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_rounded,
                              size: 12,
                              color: record.status == 'Present'
                                  ? Colors.white
                                  : const Color(0xFF16A34A),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Present',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: record.status == 'Present'
                                    ? Colors.white
                                    : const Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _markAttendance(record, 'Absent'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: record.status == 'Absent'
                              ? const Color(0xFFDC2626)
                              : (isDark
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFFFFF5F5)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: record.status == 'Absent'
                                ? const Color(0xFFDC2626)
                                : const Color(0xFFDC2626).withAlpha(80),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.close_rounded,
                              size: 12,
                              color: record.status == 'Absent'
                                  ? Colors.white
                                  : const Color(0xFFDC2626),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Absent',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: record.status == 'Absent'
                                    ? Colors.white
                                    : const Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          indent: 16,
          endIndent: 16,
          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 40,
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
            const SizedBox(height: 12),
            Text(
              'No attendance records found',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? const Color(0xFF64748B)
                    : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try adjusting your search or filters.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isDark
                    ? const Color(0xFF475569)
                    : const Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatData {
  final String label;
  final int count;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final Color countColor;

  const _StatData({
    required this.label,
    required this.count,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.countColor,
  });
}

class _StatCard extends StatelessWidget {
  final _StatData stat;
  final bool isDark;

  const _StatCard({required this.stat, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
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
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: stat.iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(stat.icon, size: 18, color: stat.iconColor),
          ),
          const SizedBox(height: 8),
          Text(
            '${stat.count}',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: stat.countColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            stat.label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

class _ShiftDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final bool isDark;
  final ValueChanged<String> onChanged;

  const _ShiftDropdown({
    required this.value,
    required this.items,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        borderRadius: BorderRadius.circular(8),
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 16,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
          ),
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF374151),
          ),
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          items: items.map((item) {
            return DropdownMenuItem<String>(value: item, child: Text(item));
          }).toList(),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ),
    );
  }
}

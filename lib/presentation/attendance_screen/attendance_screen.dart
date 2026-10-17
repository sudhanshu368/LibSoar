import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/app_drawer.dart';
import '../../core/services/dashboard_service.dart';
import '../../core/utils/storage_helper.dart';

class AttendanceRecord {
  final String id;
  final String name;
  final String phone;
  final String seat;
  final String shift;
  String time;
  final String source;
  String status; // Present, Absent, Pending
  final String date;
  final String day;
  final String subject;

  AttendanceRecord({
    required this.id,
    required this.name,
    required this.phone,
    required this.seat,
    required this.shift,
    required this.time,
    required this.source,
    required this.status,
    required this.date,
    required this.day,
    required this.subject,
  });
}

typedef _AttendanceRecord = AttendanceRecord;

class AttendanceScreen extends StatefulWidget {
  final bool embedded;
  final bool fromBottomNav;
  final String? branchId;
  final List<AttendanceRecord>? initialRecords;
  final Future<bool> Function(String studentId, String status)? onMarkAttendance;

  const AttendanceScreen({
    super.key,
    this.embedded = false,
    this.fromBottomNav = false,
    this.branchId,
    this.initialRecords,
    this.onMarkAttendance,
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
    if (widget.initialRecords != null) {
      _allRecords = List.from(widget.initialRecords!);
      _isLoading = false;
    } else {
      _loadAttendance();
    }
  }

  @override
  void didUpdateWidget(covariant AttendanceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialRecords != null) {
      _allRecords = List.from(widget.initialRecords!);
    } else if (oldWidget.branchId != widget.branchId) {
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
        debugPrint("Failed to load branches in AttendanceScreen: $e");
      }
    }

    if (currentBranchId == null) {
      final formattedDate =
          '${_formatShortDate(_selectedDate)} ${_selectedDate.year}';
      final dayName = _dayOfWeek(_selectedDate);
      setState(() {
        _allRecords = [
          _AttendanceRecord(
            id: 'demo_1',
            name: 'Rahul Kumar',
            phone: '9876543210',
            seat: 'A-12',
            shift: 'Morning',
            time: '09:15 AM',
            source: 'Manual',
            status: 'Pending',
            date: formattedDate,
            day: dayName,
            subject: 'General',
          ),
          _AttendanceRecord(
            id: 'demo_2',
            name: 'Shivani Singh',
            phone: '9123456780',
            seat: 'B-04',
            shift: 'Morning',
            time: '08:45 AM',
            source: 'System',
            status: 'Present',
            date: formattedDate,
            day: dayName,
            subject: 'General',
          ),
          _AttendanceRecord(
            id: 'demo_3',
            name: 'Amit Patel',
            phone: '9012345678',
            seat: 'C-08',
            shift: 'Morning',
            time: '--:--',
            source: 'Manual',
            status: 'Absent',
            date: formattedDate,
            day: dayName,
            subject: 'General',
          ),
        ];
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

        final rawDate = item['date']?.toString();
        DateTime recordDate = _selectedDate;
        if (rawDate != null && rawDate.isNotEmpty) {
          final parsed = DateTime.tryParse(rawDate);
          if (parsed != null) recordDate = parsed;
        }
        final formattedDate =
            '${_formatShortDate(recordDate)} ${recordDate.year}';
        final dayName = _dayOfWeek(recordDate);
        final subjectName = item['subject']?.toString() ??
            item['course']?.toString() ??
            item['branchName']?.toString() ??
            'General';

        return _AttendanceRecord(
          id: item['id']?.toString() ?? '',
          name: item['name']?.toString() ?? '',
          phone: item['phone']?.toString() ?? '',
          seat: item['seat']?.toString() ?? '-',
          shift: mappedShift,
          time: item['checkInTime']?.toString() ?? '--:--',
          source: markedBy == 'null' || markedBy.isEmpty ? 'System' : markedBy,
          status: uiStatus,
          date: formattedDate,
          day: dayName,
          subject: subjectName.isEmpty ? 'General' : subjectName,
        );
      }).toList();

      if (mapped.isEmpty) {
        final formattedDate =
            '${_formatShortDate(_selectedDate)} ${_selectedDate.year}';
        final dayName = _dayOfWeek(_selectedDate);
        mapped.addAll([
          _AttendanceRecord(
            id: 'demo_1',
            name: 'Rahul Kumar',
            phone: '9876543210',
            seat: 'A-12',
            shift: 'Morning',
            time: '09:15 AM',
            source: 'Manual',
            status: 'Pending',
            date: formattedDate,
            day: dayName,
            subject: 'General',
          ),
          _AttendanceRecord(
            id: 'demo_2',
            name: 'Shivani Singh',
            phone: '9123456780',
            seat: 'B-04',
            shift: 'Morning',
            time: '08:45 AM',
            source: 'System',
            status: 'Present',
            date: formattedDate,
            day: dayName,
            subject: 'General',
          ),
          _AttendanceRecord(
            id: 'demo_3',
            name: 'Amit Patel',
            phone: '9012345678',
            seat: 'C-08',
            shift: 'Morning',
            time: '--:--',
            source: 'Manual',
            status: 'Absent',
            date: formattedDate,
            day: dayName,
            subject: 'General',
          ),
        ]);
      }

      setState(() {
        _shifts = tempShifts;
        if (!_shifts.contains(_selectedShift)) {
          _selectedShift = 'All Shifts';
        }
        _allRecords = mapped;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Attendance load error: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAttendance(_AttendanceRecord record, String status) async {
    final oldStatus = record.status;
    setState(() {
      record.status = status;
    });

    try {
      if (widget.onMarkAttendance != null) {
        await widget.onMarkAttendance!(record.id, status);
      } else if (!record.id.startsWith('demo_')) {
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
      }
      
      if (!mounted) return;
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
      if (!mounted) return;
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

  String _dayOfWeek(DateTime date) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[date.weekday - 1];
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
          Expanded(
            child: Text(
              'Attendance Management',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attendance',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Dashboard / Attendance',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withAlpha(204),
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
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Text(
                  _formatDate(_selectedDate),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
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
          // Responsive Attendance Grid / Cards
          _buildAttendanceCards(isDark, filtered),
        ],
      ),
    );
  }

  Widget _buildAttendanceCards(bool isDark, List<_AttendanceRecord> filtered) {
    if (filtered.isEmpty) {
      return _buildEmptyState(isDark);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 650;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isWide ? 2 : 1,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 114,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            return _buildAttendanceCard(filtered[index], isDark);
          },
        );
      },
    );
  }

  Widget _buildAttendanceCard(_AttendanceRecord record, bool isDark) {
    final normStatus = record.status.trim().toLowerCase();
    final isPresent = normStatus == 'present';
    final isAbsent = normStatus == 'absent';
    Color statusColor;
    Color statusBg;
    Color cardBg;
    Color borderColor;
    String displayStatus;

    if (normStatus == 'present') {
      displayStatus = 'Present';
      statusColor = const Color(0xFF16A34A);
      statusBg = const Color(0xFFDCFCE7);
      cardBg = isDark
          ? const Color(0xFF064E3B).withValues(alpha: 0.35)
          : const Color(0xFFECFDF5);
      borderColor = isDark
          ? const Color(0xFF059669).withValues(alpha: 0.4)
          : const Color(0xFFA7F3D0);
    } else if (normStatus == 'absent') {
      displayStatus = 'Absent';
      statusColor = const Color(0xFFDC2626);
      statusBg = const Color(0xFFFEE2E2);
      cardBg = isDark
          ? const Color(0xFF7F1D1D).withValues(alpha: 0.35)
          : const Color(0xFFFEF2F2);
      borderColor = isDark
          ? const Color(0xFFDC2626).withValues(alpha: 0.4)
          : const Color(0xFFFECACA);
    } else {
      displayStatus = record.status.trim().isEmpty ? 'Pending' : record.status;
      statusColor = const Color(0xFFD97706);
      statusBg = const Color(0xFFFEF3C7);
      cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
      borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    }

    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final textSubtle =
        isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

    final initial = record.name.trim().isNotEmpty
        ? record.name.trim()[0].toUpperCase()
        : 'U';

    final avatarThemes = [
      (const Color(0xFFFFE4E6), const Color(0xFFE11D48)), // Rose / Pink (e.g. Rahul R)
      (const Color(0xFFEDE9FE), const Color(0xFF7C3AED)), // Purple / Violet (e.g. Shivani S)
      (const Color(0xFFE0E7FF), const Color(0xFF4F46E5)), // Indigo (e.g. Amit A)
      (const Color(0xFFDCFCE7), const Color(0xFF16A34A)), // Emerald
      (const Color(0xFFFEF3C7), const Color(0xFFD97706)), // Amber
      (const Color(0xFFE0F2FE), const Color(0xFF0284C7)), // Sky
    ];
    final avatarTheme =
        avatarThemes[record.name.hashCode.abs() % avatarThemes.length];

    return AnimatedContainer(
      key: ValueKey('attendance_card_${record.id}'),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ΓöÇΓöÇΓöÇ Left: Student Avatar Initial ΓöÇΓöÇΓöÇ
          CircleAvatar(
            radius: 20,
            backgroundColor: avatarTheme.$1,
            child: Text(
              initial,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: avatarTheme.$2,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // ΓöÇΓöÇΓöÇ Center: 4-Line Student Info ΓöÇΓöÇΓöÇ
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Line 1: Name + Status Pill
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        record.name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        displayStatus,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),

                // Line 2: Phone
                Text(
                  record.phone,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),

                // Line 3: Subject | Seat
                Text(
                  '${record.subject}  |  Seat ${record.seat}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: textSubtle,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),

                // Line 4: Shift | Time | Source
                Text(
                  'Shift: ${record.shift}  |  ${record.time}  |  ${record.source}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: textSubtle,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // ΓöÇΓöÇΓöÇ Right: Circular Present (Γ£ô) & Absent (├ù) Actions ΓöÇΓöÇΓöÇ
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Present (Γ£ô) Action Button (Solid Emerald when Present, Outlined when unselected)
              Semantics(
                button: true,
                label: 'Mark Present for ${record.name}',
                child: InkWell(
                  onTap: () => _markAttendance(record, 'Present'),
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    key: ValueKey('present_btn_${record.id}'),
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isPresent
                          ? const Color(0xFF10B981)
                          : (isDark ? const Color(0xFF1E293B) : Colors.white),
                      shape: BoxShape.circle,
                      border: isPresent
                          ? Border.all(color: const Color(0xFF10B981), width: 1.2)
                          : Border.all(
                              color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.6 : 0.45),
                              width: 1.2,
                            ),
                      boxShadow: isPresent
                          ? [
                              BoxShadow(
                                color: const Color(0xFF10B981).withAlpha(45),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.check_rounded,
                      color: isPresent ? Colors.white : const Color(0xFF10B981),
                      size: 19,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Absent (├ù) Action Button (Solid Red when Absent, Outlined when unselected)
              Semantics(
                button: true,
                label: 'Mark Absent for ${record.name}',
                child: InkWell(
                  onTap: () => _markAttendance(record, 'Absent'),
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    key: ValueKey('absent_btn_${record.id}'),
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isAbsent
                          ? const Color(0xFFEF4444)
                          : (isDark ? const Color(0xFF1E293B) : Colors.white),
                      shape: BoxShape.circle,
                      border: isAbsent
                          ? Border.all(color: const Color(0xFFEF4444), width: 1.2)
                          : Border.all(
                              color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.6 : 0.45),
                              width: 1.2,
                            ),
                      boxShadow: isAbsent
                          ? [
                              BoxShadow(
                                color: const Color(0xFFEF4444).withAlpha(45),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.close_rounded,
                      color: isAbsent ? Colors.white : const Color(0xFFEF4444),
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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

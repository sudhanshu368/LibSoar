import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/app_drawer.dart';
import '../../core/services/dashboard_service.dart';
import '../../core/utils/storage_helper.dart';

// ─── Models ──────────────────────────────────────────────────────────────────

class StudentModel {
  final String id;
  final String name;
  final String phone;

  const StudentModel({
    required this.id,
    required this.name,
    required this.phone,
  });
}

class ShiftBooking {
  final String shiftId;
  final String? bookingId;
  final String shiftName;
  final String date;
  bool isBooked;
  StudentModel? student;

  ShiftBooking({
    this.shiftId = '',
    this.bookingId,
    required this.shiftName,
    required this.date,
    this.isBooked = false,
    this.student,
  });
}

class SeatModel {
  final String id;
  final String floor;
  final int number;
  final String type;
  final double price;
  List<ShiftBooking> shifts;

  SeatModel({
    required this.id,
    required this.floor,
    required this.number,
    this.type = 'Regular',
    this.price = 0,
    required this.shifts,
  });

  bool get hasAnyBooked => shifts.isNotEmpty && shifts.any((s) => s.isBooked);
  bool get allBooked => shifts.isNotEmpty && shifts.every((s) => s.isBooked);

  String get label => '$floor-$number';
  String get seatNumber => '$floor-$number';
}


// ─── Mock Data ────────────────────────────────────────────────────────────────

// final List<StudentModel> _mockStudents = [
//   StudentModel(id: 's1', name: 'Rahul Sharma', phone: '9876543210'),
//   StudentModel(id: 's2', name: 'Priya Patel', phone: '9123456789'),
//   StudentModel(id: 's3', name: 'Amit Kumar', phone: '9988776655'),
//   StudentModel(id: 's4', name: 'Sneha Verma', phone: '9765432109'),
//   StudentModel(id: 's5', name: 'Rohan Gupta', phone: '9654321098'),
//   StudentModel(id: 's6', name: 'Anjali Singh', phone: '9543210987'),
//   StudentModel(id: 's7', name: 'Vikram Yadav', phone: '9432109876'),
//   StudentModel(id: 's8', name: 'Pooja Mehta', phone: '9321098765'),
//   StudentModel(id: 's9', name: 'Karan Joshi', phone: '9210987654'),
//   StudentModel(id: 's10', name: 'Divya Nair', phone: '9109876543'),
// ];

// List<SeatModel> _generateSeats() {
//   final date = '2026-03-24';
//   final shifts = ['Morning', 'Full Day', 'Afternoon'];
//   final List<SeatModel> seats = [];

//   for (int i = 1; i <= 50; i++) {
//     final shiftList = shifts.map((s) {
//       bool booked = false;
//       StudentModel? student;
//       if (i == 3 && s == 'Morning') {
//         booked = true;
//         student = _mockStudents[0];
//       } else if (i == 7 && s == 'Full Day') {
//         booked = true;
//         student = _mockStudents[1];
//       } else if (i == 12 && s == 'Morning') {
//         booked = true;
//         student = _mockStudents[3];
//       } else if (i == 12 && s == 'Afternoon') {
//         booked = true;
//         student = _mockStudents[4];
//       } else if (i == 18 && s == 'Full Day') {
//         booked = true;
//         student = _mockStudents[5];
//       } else if (i == 25 && s == 'Morning') {
//         booked = true;
//         student = _mockStudents[6];
//       } else if (i == 31 && s == 'Afternoon') {
//         booked = true;
//         student = _mockStudents[7];
//       }
//       return ShiftBooking(
//         shiftName: s,
//         date: date,
//         isBooked: booked,
//         student: student,
//       );
//     }).toList();

//     seats.add(
//       SeatModel(
//         id: 'A$i',
//         floor: 'A',
//         number: i,
//         type: 'Regular',
//         price: 0,
//         shifts: shiftList,
//       ),
//     );
//   }
//   return seats;
// }

// ─── Screen ───────────────────────────────────────────────────────────────────

class SeatManagementScreen extends StatefulWidget {
  final bool fromBottomNav;
  final String? branchId;
  const SeatManagementScreen({super.key, this.fromBottomNav = false, this.branchId});

  @override
  State<SeatManagementScreen> createState() => _SeatManagementScreenState();
}

class _SeatManagementScreenState extends State<SeatManagementScreen> {
  String _activeShift = 'All';
  String _selectedFloor = 'All Floors';
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';


  // late final List<SeatModel> _seats = _generateSeats();
  List<SeatModel> _seats = [];
  bool _loading = true;
  List<Map<String, dynamic>> _branches = [];
  String? _currentBranchId;
  final List<String> _shiftTabs = ['All', 'Morning', 'Full Day', 'Afternoon'];
  final Map<String, Color> _shiftColors = {
    'All': const Color(0xFF4F46E5),
    'Morning': const Color(0xFF3B82F6),
    'Full Day': const Color(0xFF10B981),
    'Afternoon': const Color(0xFFF59E0B),
  };
  List<String> get _floors {
    final floorSet = <String>{'All Floors'};
    for (final seat in _seats) {
      floorSet.add('Floor ${seat.floor}');
    }
    return floorSet.toList();
  }

  List<SeatModel> get _filteredSeats {
    return _seats.where((seat) {
      final q = _searchQuery.toLowerCase();
      final matchesSearch =
          q.isEmpty ||
          seat.label.toLowerCase().contains(q) ||
          seat.seatNumber.toLowerCase().contains(q) ||
          seat.shifts.any(
            (s) => s.student?.name.toLowerCase().contains(q) ?? false,
          );
      final matchesFloor =
          _selectedFloor == 'All Floors' ||
          _selectedFloor == 'Floor ${seat.floor}';
      return matchesSearch && matchesFloor;
    }).toList();
  }

  String _formatDate(DateTime d) {
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
    const ordinals = ['th', 'st', 'nd', 'rd'];
    int day = d.day;
    int mod = day % 100;
    String suffix = (mod >= 11 && mod <= 13)
        ? ordinals[0]
        : (day % 10 < ordinals.length ? ordinals[day % 10] : ordinals[0]);
    return '${months[d.month - 1]} $day$suffix, ${d.year}';
  }

@override
void initState() {
  super.initState();
  loadSeats();
}

  @override
  void didUpdateWidget(covariant SeatManagementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.branchId != widget.branchId) {
      loadSeats();
    }
  }

Future<void> loadSeats() async {
    String? currentBranchId = widget.branchId ?? _currentBranchId;
    if (currentBranchId == null) {
      try {
        final savedBranchId = await StorageHelper.getBranchId();
        final branches = await DashboardService.getBranches();
        if (branches.isNotEmpty) {
           _branches = branches; // Store in state
           if (savedBranchId != null && branches.any((b) => b['id'] == savedBranchId)) {
             currentBranchId = savedBranchId;
           } else {
             currentBranchId = branches[0]['id'];
           }
        }
      } catch (e) {
          print("Failed to load branches in SeatManagementScreen: $e");
      }
    }
    
    // update state with selected branch
    if (currentBranchId != null && currentBranchId != _currentBranchId) {
       _currentBranchId = currentBranchId;
    }

    if (currentBranchId == null) {
      setState(() {
        _seats = [];
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);
  try {
      final dateStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
    final data = await DashboardService.getSeatMap(
        date: dateStr,
        branchId: currentBranchId,
    );

      final List<SeatModel> mappedSeats = [];
      for (final item in data) {
        final shiftsList = item['shiftBookings'] as List?;
        final shifts = shiftsList?.map((s) {
          return ShiftBooking(
            shiftId: s['shiftId']?.toString() ?? '',
            bookingId: s['bookingId']?.toString() ?? s['id']?.toString(),
            shiftName: s['shiftName']?.toString() ?? '',
            date: dateStr,
            isBooked: s['status'] == 'booked',
            student: s['studentName'] != null
                ? StudentModel(
                    id: s['studentId']?.toString() ?? '',
                    name: s['studentName']?.toString() ?? '',
                    phone: '',
                  )
                : null,
          );
        }).toList() ?? [];

        int seatNum = 0;
        if (item['number'] != null) {
          final match = RegExp(r'\d+').firstMatch(item['number'].toString());
          if (match != null) {
            seatNum = int.tryParse(match.group(0) ?? '0') ?? 0;
          }
        }

        mappedSeats.add(SeatModel(
          id: item['id']?.toString() ?? '',
          floor: item['floor']?.toString() ?? 'A',
          number: seatNum,
          type: item['type']?.toString() ?? 'Regular',
          shifts: shifts,
        ));
      }

    setState(() {
        _seats = mappedSeats;
      _loading = false;
    });
  } catch (e) {
    print("Seat map error: $e");
    setState(() => _loading = false);
  }
}
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF4F46E5),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      loadSeats();
    }
  }

  void _onSeatTap(SeatModel seat) {
    final isDesktop = MediaQuery.of(context).size.width > 700;
    if (isDesktop) {
      showDialog(
        context: context,
        builder: (_) => _SeatDetailsDialog(
          seat: seat,
          onUpdate: () => setState(() {}),
          allStudents: [],
          // allStudents: _mockStudents,
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _SeatDetailsSheet(
          seat: seat,
          onUpdate: () => setState(() {}),
          // allStudents: _mockStudents,
          allStudents: [],
        ),
      );
    }
  }

  void _showAddSingleSeatDialog() {
    showDialog(
      context: context,
      builder: (_) => _AddSingleSeatDialog(
        existingSeats: _seats,
        onSeatAdded: (seat) {
          setState(() => _seats.add(seat));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Seat ${seat.seatNumber} added successfully!'),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showBulkCreateDialog() {
    showDialog(
      context: context,
      builder: (_) => _BulkCreateSeatsDialog(
        existingSeats: _seats,
        onSeatsAdded: (newSeats) {
          setState(() => _seats.addAll(newSeats));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${newSeats.length} seats created successfully!'),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
   if (_loading) {
  return const Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );
}
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      drawer: widget.fromBottomNav
          ? null
          : const AppDrawer(activeItem: 'Seats'),
      body: SafeArea(
        child: Column(
          children: [
            if (!widget.fromBottomNav) _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderCard(),
                    const SizedBox(height: 16),
                    _buildShiftTabs(),
                    const SizedBox(height: 16),
                    const SizedBox(height: 16),
                    _buildSearchFilterCard(),
                    const SizedBox(height: 16),
                    _buildSeatStatusSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Builder(
            builder: (ctx) => GestureDetector(
              onTap: () => Scaffold.of(ctx).openDrawer(),
              child: const Icon(Icons.menu_rounded, color: Color(0xFF374151)),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Seat Management',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          const Spacer(),
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
                    final isSelected = _currentBranchId == b['id'];
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
                        if (_currentBranchId != b['id']) {
                          setState(() => _currentBranchId = b['id']);
                          StorageHelper.saveBranchId(b['id']);
                          loadSeats();
                        }
                      },
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    final filtered = _filteredSeats;
    final total = filtered.length;
    
    int booked = 0;
    if (_activeShift == 'All') {
      booked = filtered.where((s) => s.hasAnyBooked).length;
    } else {
      booked = filtered.where((s) {
        try {
          final shift = s.shifts.firstWhere((sh) => sh.shiftName.toLowerCase().contains(_activeShift.toLowerCase()));
          return shift.isBooked;
        } catch (_) {
          return false;
        }
      }).length;
    }
    final available = total - booked;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF3730A3), // Deep Indigo
            Color(0xFF4F46E5), // "All Shift" Color
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: const Icon(
                  Icons.event_seat_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seat Management',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Dashboard / Seats',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatChip(
                label: 'Total',
                value: '$total',
                color: Colors.white.withValues(alpha: 0.15),
                textColor: Colors.white,
              ),
              _StatChip(
                label: 'Available',
                value: '$available',
                color: const Color(0xFF10B981).withValues(alpha: 0.25),
                textColor: Colors.white,
              ),
              _StatChip(
                label: 'Booked',
                value: '$booked',
                color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                textColor: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _showAddSingleSeatDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.add_circle_rounded,
                          size: 20,
                          color: Color(0xFF4F46E5),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Add Seat',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF4F46E5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: GestureDetector(
                  onTap: _showBulkCreateDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.library_add_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Bulk Create',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
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

  Widget _buildShiftTabs() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _shiftTabs.map((tab) {
            final isActive = _activeShift == tab;
            final color = _shiftColors[tab] ?? cs.primary;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () => setState(() => _activeShift = tab),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: isActive
                        ? LinearGradient(
                            colors: [color, color.withValues(alpha: 0.8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isActive ? null : cs.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isActive ? color.withValues(alpha: 0.5) : cs.outline.withValues(alpha: 0.1),
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive ? Colors.white : color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tab == 'All' ? 'All Shifts' : '$tab Shift',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isActive ? Colors.white : cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSearchFilterCard() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: cs.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search seat or student...',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: cs.primary.withValues(alpha: 0.8),
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: cs.onSurfaceVariant,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              _FloorDropdown(
                value: _selectedFloor,
                items: _floors,
                onChanged: (v) => setState(() => _selectedFloor = v),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    cs.primary.withValues(alpha: 0.05),
                    cs.primary.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_month_rounded,
                    size: 20,
                    color: cs.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _formatDate(_selectedDate),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.edit_calendar_rounded,
                      size: 16,
                      color: cs.primary,
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

  Widget _buildSeatStatusSection() {
    final filtered = _filteredSeats;
    final Map<String, List<SeatModel>> byFloor = {};
    for (final seat in filtered) {
      byFloor.putIfAbsent('Floor ${seat.floor}', () => []).add(seat);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Seat Status — ${_formatDate(_selectedDate)}',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        _buildLegend(),
        const SizedBox(height: 16),
        if (byFloor.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'No seats found.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          ...byFloor.entries.map((e) => _buildFloorSection(e.key, e.value)),
      ],
    );
  }

  Widget _buildLegend() {
    final items = [
      {
        'label': 'Available',
        'color': Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        'text': Theme.of(context).colorScheme.onSurfaceVariant,
      },
      {
        'label': 'Partially Booked',
        'color': const Color(0xFFFEF3C7),
        'text': const Color(0xFFD97706),
      },
      {
        'label': 'Fully Booked',
        'color': const Color(0xFFFEE2E2),
        'text': const Color(0xFFDC2626),
      },
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: item['color'] as Color,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (item['text'] as Color).withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                item['label'] as String,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: item['text'] as Color,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFloorSection(String floorName, List<SeatModel> seats) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Text(
                  floorName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${seats.length} seats',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: seats
                  .map(
                    (seat) => _SeatCard(
                      seat: seat,
                      activeShift: _activeShift,
                      onTap: () => _onSeatTap(seat),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Seat Card ────────────────────────────────────────────────────────────────

class _SeatCard extends StatelessWidget {
  final SeatModel seat;
  final VoidCallback onTap;
  final String activeShift;

  const _SeatCard({required this.seat, required this.onTap, this.activeShift = 'All'});

  bool get _isShiftBooked {
    if (activeShift == 'All') return false;
    try {
      final shift = seat.shifts.firstWhere((s) => s.shiftName.toLowerCase().contains(activeShift.toLowerCase()));
      return shift.isBooked;
    } catch (_) {
      return false;
    }
  }

  Gradient _getBgGradient(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (activeShift != 'All') {
      return _isShiftBooked 
          ? const LinearGradient(colors: [Color(0xFFFEF2F2), Color(0xFFFEE2E2)], begin: Alignment.topLeft, end: Alignment.bottomRight) 
          : LinearGradient(colors: [cs.surface, cs.surfaceContainerHighest.withValues(alpha: 0.3)], begin: Alignment.topLeft, end: Alignment.bottomRight);
    }
    if (seat.allBooked) return const LinearGradient(colors: [Color(0xFFFEF2F2), Color(0xFFFEE2E2)], begin: Alignment.topLeft, end: Alignment.bottomRight);
    if (seat.hasAnyBooked) return const LinearGradient(colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)], begin: Alignment.topLeft, end: Alignment.bottomRight);
    return LinearGradient(colors: [cs.surface, cs.surfaceContainerHighest.withValues(alpha: 0.3)], begin: Alignment.topLeft, end: Alignment.bottomRight);
  }

  Color _getBorderColor(BuildContext context) {
    if (activeShift != 'All') {
      return _isShiftBooked ? const Color(0xFFDC2626).withValues(alpha: 0.3) : Theme.of(context).colorScheme.outline.withValues(alpha: 0.15);
    }
    if (seat.allBooked) return const Color(0xFFDC2626).withValues(alpha: 0.3);
    if (seat.hasAnyBooked) return const Color(0xFFD97706).withValues(alpha: 0.3);
    return Theme.of(context).colorScheme.outline.withValues(alpha: 0.15);
  }

  Color _getTextColor(BuildContext context) {
    if (activeShift != 'All') {
      return _isShiftBooked ? const Color(0xFFDC2626) : Theme.of(context).colorScheme.onSurface;
    }
    if (seat.allBooked) return const Color(0xFFDC2626);
    if (seat.hasAnyBooked) return const Color(0xFFD97706);
    return Theme.of(context).colorScheme.onSurface;
  }

  Color _getShadowColor(BuildContext context) {
    if (activeShift != 'All') {
      return _isShiftBooked ? const Color(0xFFDC2626).withValues(alpha: 0.2) : Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05);
    }
    if (seat.allBooked) return const Color(0xFFDC2626).withValues(alpha: 0.2);
    if (seat.hasAnyBooked) return const Color(0xFFD97706).withValues(alpha: 0.2);
    return Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05);
  }

  @override
  Widget build(BuildContext context) {
    final bgGradient = _getBgGradient(context);
    final borderColor = _getBorderColor(context);
    final textColor = _getTextColor(context);
    final shadowColor = _getShadowColor(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          gradient: bgGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              seat.floor,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: textColor.withValues(alpha: 0.6),
                letterSpacing: 0.5,
              ),
            ),
            Text(
              '${seat.number}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Add Single Seat Dialog ───────────────────────────────────────────────────

class _AddSingleSeatDialog extends StatefulWidget {
  final List<SeatModel> existingSeats;
  final void Function(SeatModel) onSeatAdded;

  const _AddSingleSeatDialog({
    required this.existingSeats,
    required this.onSeatAdded,
  });

  @override
  State<_AddSingleSeatDialog> createState() => _AddSingleSeatDialogState();
}

class _AddSingleSeatDialogState extends State<_AddSingleSeatDialog> {
  final _formKey = GlobalKey<FormState>();
  final _seatNumberController = TextEditingController();
  final _priceController = TextEditingController(text: '0');

  String _selectedFloor = 'A';
  String _selectedType = 'Regular';
  bool _isLoading = false;
  String? _seatNumberError;

  final List<String> _floors = ['A', 'B', 'C', 'D', 'E'];
  final List<String> _types = ['Regular', 'Premium', 'VIP'];

  @override
  void initState() {
    super.initState();
    _autoSuggestSeatNumber();
  }

  void _autoSuggestSeatNumber() {
    final existingOnFloor = widget.existingSeats
        .where((s) => s.floor == _selectedFloor)
        .map((s) => s.number)
        .toList();
    existingOnFloor.sort();
    int next = 1;
    while (existingOnFloor.contains(next)) {
      next++;
    }
    _seatNumberController.text = '$_selectedFloor-$next';
  }

  void _onFloorChanged(String? floor) {
    if (floor == null) return;
    setState(() {
      _selectedFloor = floor;
      _seatNumberError = null;
    });
    _autoSuggestSeatNumber();
  }

  bool _isSeatNumberDuplicate(String seatNum) {
    return widget.existingSeats.any(
      (s) => s.seatNumber.toLowerCase() == seatNum.toLowerCase(),
    );
  }

  Future<void> _submit() async {
    setState(() => _seatNumberError = null);

    final seatNum = _seatNumberController.text.trim();

    if (seatNum.isEmpty) {
      setState(() => _seatNumberError = 'Seat number is required');
      return;
    }

    final regex = RegExp(r'^[A-Za-z]-\d+$');
    if (!regex.hasMatch(seatNum)) {
      setState(() => _seatNumberError = 'Format must be like A-1, B-2');
      return;
    }

    if (_isSeatNumberDuplicate(seatNum)) {
      setState(() => _seatNumberError = 'Seat number already exists');
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final priceText = _priceController.text.trim();
    final price = double.tryParse(priceText) ?? 0;
    if (price < 0) {
      return;
    }

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 400));

    final parts = seatNum.split('-');
    final floor = parts[0].toUpperCase();
    final number = int.tryParse(parts[1]) ?? 1;

    final newSeat = SeatModel(
      id: '${floor}_$number\\_${DateTime.now().millisecondsSinceEpoch}',
      floor: floor,
      number: number,
      type: _selectedType,
      price: price,
      shifts: [
        ShiftBooking(shiftName: 'Morning', date: '2026-03-24'),
        ShiftBooking(shiftName: 'Full Day', date: '2026-03-24'),
        ShiftBooking(shiftName: 'Afternoon', date: '2026-03-24'),
      ],
    );

    setState(() => _isLoading = false);
    if (mounted) {
      Navigator.of(context).pop();
      widget.onSeatAdded(newSeat);
    }
  }

  @override
  void dispose() {
    _seatNumberController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.event_seat_rounded,
                          size: 18,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Add New Seat',
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF111827),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: Color(0xFF6B7280),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Floor
                  _FieldLabel(label: 'Floor', required: true),
                  const SizedBox(height: 6),
                  _StyledDropdown<String>(
                    value: _selectedFloor,
                    items: _floors,
                    itemLabel: (f) => 'Floor $f',
                    onChanged: _onFloorChanged,
                  ),
                  const SizedBox(height: 14),

                  // Seat Number
                  _FieldLabel(label: 'Seat Number', required: true),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _seatNumberController,
                    autofocus: true,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF111827),
                    ),
                    decoration: _inputDecoration(
                      hint: 'e.g. A-1',
                      error: _seatNumberError,
                    ),
                    onChanged: (_) => setState(() => _seatNumberError = null),
                  ),
                  if (_seatNumberError != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _seatNumberError!,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),

                  // Seat Type
                  _FieldLabel(label: 'Seat Type'),
                  const SizedBox(height: 6),
                  _StyledDropdown<String>(
                    value: _selectedType,
                    items: _types,
                    itemLabel: (t) => t,
                    onChanged: (v) =>
                        setState(() => _selectedType = v ?? 'Regular'),
                  ),
                  const SizedBox(height: 14),

                  // Price
                  _FieldLabel(label: 'Price (₹)'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF111827),
                    ),
                    decoration: _inputDecoration(hint: '0'),
                    validator: (v) {
                      final val = double.tryParse(v ?? '');
                      if (val == null) return 'Enter a valid price';
                      if (val < 0) return 'Price must be ≥ 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading
                              ? null
                              : () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF374151),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style:
                              ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                              ).copyWith(
                                backgroundColor: WidgetStateProperty.all(
                                  Colors.transparent,
                                ),
                              ),
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4F46E5), Color(0xFF2563EB)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'Add Seat',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
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
      ),
    );
  }
}

// ─── Bulk Create Seats Dialog ─────────────────────────────────────────────────

class _BulkCreateSeatsDialog extends StatefulWidget {
  final List<SeatModel> existingSeats;
  final void Function(List<SeatModel>) onSeatsAdded;

  const _BulkCreateSeatsDialog({
    required this.existingSeats,
    required this.onSeatsAdded,
  });

  @override
  State<_BulkCreateSeatsDialog> createState() => _BulkCreateSeatsDialogState();
}

class _BulkCreateSeatsDialogState extends State<_BulkCreateSeatsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _countController = TextEditingController();
  final _startController = TextEditingController(text: '1');
  final _priceController = TextEditingController(text: '0');

  String _selectedFloor = 'A';
  String _selectedType = 'Regular';
  bool _isLoading = false;

  final List<String> _floors = ['A', 'B', 'C', 'D', 'E'];
  final List<String> _types = ['Regular', 'Premium', 'VIP'];

  @override
  void initState() {
    super.initState();
    _autoFillStart();
    _countController.addListener(() => setState(() {}));
    _startController.addListener(() => setState(() {}));
  }

  void _autoFillStart() {
    final existingOnFloor = widget.existingSeats
        .where((s) => s.floor == _selectedFloor)
        .map((s) => s.number)
        .toList();
    existingOnFloor.sort();
    int next = 1;
    while (existingOnFloor.contains(next)) {
      next++;
    }
    _startController.text = '$next';
  }

  void _onFloorChanged(String? floor) {
    if (floor == null) return;
    setState(() => _selectedFloor = floor);
    _autoFillStart();
  }

  List<String> get _duplicates {
    final start = int.tryParse(_startController.text.trim()) ?? 1;
    final count = int.tryParse(_countController.text.trim()) ?? 0;
    final dupes = <String>[];
    for (int i = 0; i < count; i++) {
      final seatNum = '$_selectedFloor-${start + i}';
      if (widget.existingSeats.any((s) => s.seatNumber == seatNum)) {
        dupes.add(seatNum);
      }
    }
    return dupes;
  }

  String get _previewText {
    final start = int.tryParse(_startController.text.trim()) ?? 1;
    final count = int.tryParse(_countController.text.trim()) ?? 0;
    if (count <= 0) return '';
    final end = start + count - 1;
    return 'Will create seats $_selectedFloor-$start to $_selectedFloor-$end ($count seats)';
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final start = int.tryParse(_startController.text.trim()) ?? 1;
    final count = int.tryParse(_countController.text.trim()) ?? 0;
    final price = double.tryParse(_priceController.text.trim()) ?? 0;

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 600));

    final newSeats = <SeatModel>[];
    for (int i = 0; i < count; i++) {
      final num = start + i;
      final seatNum = '$_selectedFloor-$num';
      if (widget.existingSeats.any((s) => s.seatNumber == seatNum)) continue;
      newSeats.add(
        SeatModel(
          id: '${_selectedFloor}_${num}_${DateTime.now().millisecondsSinceEpoch + i}',
          floor: _selectedFloor,
          number: num,
          type: _selectedType,
          price: price,
          shifts: [
            ShiftBooking(shiftName: 'Morning', date: '2026-03-24'),
            ShiftBooking(shiftName: 'Full Day', date: '2026-03-24'),
            ShiftBooking(shiftName: 'Afternoon', date: '2026-03-24'),
          ],
        ),
      );
    }

    setState(() => _isLoading = false);
    if (mounted) {
      Navigator.of(context).pop();
      if (newSeats.isNotEmpty) widget.onSeatsAdded(newSeats);
    }
  }

  @override
  void dispose() {
    _countController.dispose();
    _startController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = _previewText;
    final dupes = _duplicates;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.library_add_rounded,
                          size: 18,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Bulk Create Seats',
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF111827),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: Color(0xFF6B7280),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Floor
                  _FieldLabel(label: 'Floor', required: true),
                  const SizedBox(height: 6),
                  _StyledDropdown<String>(
                    value: _selectedFloor,
                    items: _floors,
                    itemLabel: (f) => 'Floor $f',
                    onChanged: _onFloorChanged,
                  ),
                  const SizedBox(height: 14),

                  // Start Number & Count row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _FieldLabel(label: 'Start Number'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _startController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: const Color(0xFF111827),
                              ),
                              decoration: _inputDecoration(hint: '1'),
                              validator: (v) {
                                final val = int.tryParse(v ?? '');
                                if (val == null || val < 1) return 'Min 1';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _FieldLabel(
                              label: 'Number of Seats',
                              required: true,
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _countController,
                              autofocus: true,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: const Color(0xFF111827),
                              ),
                              decoration: _inputDecoration(hint: 'e.g. 10'),
                              validator: (v) {
                                final val = int.tryParse(v ?? '');
                                if (val == null || val <= 0) {
                                  return 'Must be > 0';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Seat Type
                  _FieldLabel(label: 'Seat Type'),
                  const SizedBox(height: 6),
                  _StyledDropdown<String>(
                    value: _selectedType,
                    items: _types,
                    itemLabel: (t) => t,
                    onChanged: (v) =>
                        setState(() => _selectedType = v ?? 'Regular'),
                  ),
                  const SizedBox(height: 14),

                  // Price
                  _FieldLabel(label: 'Price (₹)'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF111827),
                    ),
                    decoration: _inputDecoration(hint: '0'),
                    validator: (v) {
                      final val = double.tryParse(v ?? '');
                      if (val == null) return 'Enter a valid price';
                      if (val < 0) return 'Price must be ≥ 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Preview
                  if (preview.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFC7D2FE)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: Color(0xFF4F46E5),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              preview,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF4F46E5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Duplicate warning
                  if (dupes.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 16,
                            color: Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${dupes.length} duplicate(s) will be skipped: ${dupes.take(5).join(', ')}${dupes.length > 5 ? '...' : ''}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFFD97706),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  const SizedBox(height: 8),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading
                              ? null
                              : () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF374151),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                          ),
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4F46E5), Color(0xFF2563EB)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'Create Seats',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
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
      ),
    );
  }
}

// ─── Shared Helpers ───────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool required;
  const _FieldLabel({required this.label, this.required = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF374151),
          ),
        ),
        if (required) ...[
          const SizedBox(width: 3),
          const Text(
            '*',
            style: TextStyle(color: Color(0xFFEF4444), fontSize: 13),
          ),
        ],
      ],
    );
  }
}

class _StyledDropdown<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final String Function(T) itemLabel;
  final void Function(T?)? onChanged;

  const _StyledDropdown({
    required this.value,
    required this.items,
    required this.itemLabel,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: Color(0xFF6B7280),
          ),
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF111827),
          ),
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(itemLabel(item)),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration({String? hint, String? error}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF9CA3AF)),
    filled: true,
    fillColor: const Color(0xFFF8FAFC),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color: error != null
            ? const Color(0xFFEF4444)
            : const Color(0xFFE2E8F0),
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color: error != null
            ? const Color(0xFFEF4444)
            : const Color(0xFFE2E8F0),
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFEF4444)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
    ),
    errorStyle: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFEF4444)),
  );
}

// ─── Seat Details Bottom Sheet ────────────────────────────────────────────────

class _SeatDetailsSheet extends StatefulWidget {
  final SeatModel seat;
  final VoidCallback onUpdate;
  final List<StudentModel> allStudents;

  const _SeatDetailsSheet({
    required this.seat,
    required this.onUpdate,
    required this.allStudents,
  });

  @override
  State<_SeatDetailsSheet> createState() => _SeatDetailsSheetState();
}

class _SeatDetailsSheetState extends State<_SeatDetailsSheet> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _SeatDetailsContent(
        seat: widget.seat,
        onUpdate: () {
          widget.onUpdate();
          setState(() {});
        },
        allStudents: widget.allStudents,
      ),
    );
  }
}

// ─── Seat Details Dialog ──────────────────────────────────────────────────────

class _SeatDetailsDialog extends StatefulWidget {
  final SeatModel seat;
  final VoidCallback onUpdate;
  final List<StudentModel> allStudents;

  const _SeatDetailsDialog({
    required this.seat,
    required this.onUpdate,
    required this.allStudents,
  });

  @override
  State<_SeatDetailsDialog> createState() => _SeatDetailsDialogState();
}

class _SeatDetailsDialogState extends State<_SeatDetailsDialog> {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: _SeatDetailsContent(
          seat: widget.seat,
          onUpdate: () {
            widget.onUpdate();
            setState(() {});
          },
          allStudents: widget.allStudents,
        ),
      ),
    );
  }
}

// ─── Seat Details Content ─────────────────────────────────────────────────────

class _SeatDetailsContent extends StatefulWidget {
  final SeatModel seat;
  final VoidCallback onUpdate;
  final List<StudentModel> allStudents;

  const _SeatDetailsContent({
    required this.seat,
    required this.onUpdate,
    required this.allStudents,
  });

  @override
  State<_SeatDetailsContent> createState() => _SeatDetailsContentState();
}

class _SeatDetailsContentState extends State<_SeatDetailsContent> {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF3730A3), Color(0xFF4F46E5)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.event_seat_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seat ${widget.seat.seatNumber}',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Floor ${widget.seat.floor}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white.withAlpha(200),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
        // Shift list
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            itemCount: widget.seat.shifts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final shift = widget.seat.shifts[index];
              return _ShiftRow(
                shift: shift,
                seatId: widget.seat.id,
                allStudents: widget.allStudents,
                onUpdate: () {
                  widget.onUpdate();
                  setState(() {});
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Shift Row ────────────────────────────────────────────────────────────────

class _ShiftRow extends StatelessWidget {
  final ShiftBooking shift;
  final String seatId;
  final List<StudentModel> allStudents;
  final VoidCallback onUpdate;

  const _ShiftRow({
    required this.shift,
    required this.seatId,
    required this.allStudents,
    required this.onUpdate,
  });

  Color get _shiftColor {
    switch (shift.shiftName) {
      case 'Morning':
        return const Color(0xFF3B82F6);
      case 'Full Day':
        return const Color(0xFF10B981);
      case 'Afternoon':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF4F46E5);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _shiftColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shift.shiftName,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF111827),
                  ),
                ),
                if (shift.isBooked && shift.student != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    shift.student!.name,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (shift.isBooked) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Booked',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFF59E0B),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _showCancelConfirm(context),
              icon: const Icon(
                Icons.cancel_outlined,
                size: 18,
                color: Color(0xFFEF4444),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Available',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF3B82F6),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showAssignModal(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF2563EB)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Add Student',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showCancelConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Cancel Booking',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to cancel the booking for ${shift.student?.name ?? 'this student'} on ${shift.shiftName} shift?',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF6B7280),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Keep',
              style: GoogleFonts.inter(color: const Color(0xFF6B7280)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final originalStudent = shift.student;
              try {
                // Keep UI indication
                shift.isBooked = false;
                shift.student = null;
                onUpdate();

                // Call API
                await DashboardService.cancelBooking(
                  seatId: seatId,
                  bookingId: shift.bookingId,
                );

                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Booking cancelled successfully'),
                      backgroundColor: const Color(0xFF10B981),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              } catch (e) {
                // Revert UI if failed
                shift.isBooked = true;
                shift.student = originalStudent;
                onUpdate();
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to cancel booking: $e'),
                      backgroundColor: const Color(0xFFEF4444),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Cancel Booking',
              style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _showAssignModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _AssignStudentDialog(
        shift: shift,
        seatId: seatId,
        allStudents: allStudents,
        onAssigned: onUpdate,
      ),
    );
  }
}

// ─── Assign Student Dialog ────────────────────────────────────────────────────

class _AssignStudentDialog extends StatefulWidget {
  final ShiftBooking shift;
  final String seatId;
  final List<StudentModel> allStudents;
  final VoidCallback onAssigned;

  const _AssignStudentDialog({
    required this.shift,
    required this.seatId,
    required this.allStudents,
    required this.onAssigned,
  });

  @override
  State<_AssignStudentDialog> createState() => _AssignStudentDialogState();
}

class _AssignStudentDialogState extends State<_AssignStudentDialog> {
  final _searchController = TextEditingController();
  String _query = '';
  StudentModel? _selected;
  bool _isLoading = false;
  bool _isSearching = false;
  Timer? _debounce;
  List<StudentModel> _apiStudents = [];

  List<StudentModel> get _filtered {
    if (_query.isEmpty) return widget.allStudents;
    return _apiStudents;
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() => _query = v.trim());
      _fetchStudents(_query);
    });
  }

  Future<void> _fetchStudents(String query) async {
    if (query.isEmpty) {
      if (mounted) setState(() => _apiStudents = []);
      return;
    }
    if (mounted) setState(() => _isSearching = true);
    
    final results = await DashboardService.searchActiveStudents(query: query);
    final parsed = results.map((e) => StudentModel(
      id: e['id']?.toString() ?? '',
      name: e['name']?.toString() ?? 'Unknown',
      phone: e['phone']?.toString() ?? '',
    )).toList();
    
    if (mounted) {
      setState(() {
        _apiStudents = parsed;
        _isSearching = false;
      });
    }
  }

  Future<void> _assign() async {
    if (_selected == null) return;
    setState(() => _isLoading = true);
    
    try {
      await DashboardService.bookSeat(
        seatId: widget.seatId,
        shiftId: widget.shift.shiftId,
        studentId: _selected!.id,
        date: widget.shift.date,
      );
      
      widget.shift.isBooked = true;
      widget.shift.student = _selected;
      
      if (mounted) {
        Navigator.of(context).pop();
        widget.onAssigned();
      }
    } catch (e) {
      print("Booking failed: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assign Student',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        Text(
                          '${widget.shift.shiftName} · ${widget.shift.date}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: Color(0xFF6B7280),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: _onSearch,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF111827),
                ),
                decoration: InputDecoration(
                  hintText: 'Search by name or phone...',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF9CA3AF),
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: Color(0xFF9CA3AF),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
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
            ),
            // Student list
            Flexible(
              child: filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _query.isEmpty
                            ? 'Type a name or phone number'
                            : 'No students found',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF9CA3AF),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final student = filtered[i];
                        final isSelected = _selected?.id == student.id;
                        return GestureDetector(
                          onTap: () => setState(() => _selected = student),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 6),
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
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: isSelected
                                      ? const Color(0xFF4F46E5)
                                      : const Color(0xFFE2E8F0),
                                  child: Text(
                                    student.name[0].toUpperCase(),
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF374151),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        student.name,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF111827),
                                        ),
                                      ),
                                      Text(
                                        student.phone,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: const Color(0xFF6B7280),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    size: 18,
                                    color: Color(0xFF4F46E5),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            // Assign button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_selected == null || _isLoading) ? null : _assign,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    disabledBackgroundColor: const Color(0xFFE2E8F0),
                  ),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: _selected != null
                          ? const LinearGradient(
                              colors: [Color(0xFF4F46E5), Color(0xFF2563EB)],
                            )
                          : null,
                      color: _selected == null ? const Color(0xFFE2E8F0) : null,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      child: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Assign Student',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _selected != null
                                    ? Colors.white
                                    : const Color(0xFF9CA3AF),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Floor Dropdown ───────────────────────────────────────────────────────────

class _FloorDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final void Function(String) onChanged;

  const _FloorDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 16,
            color: Color(0xFF6B7280),
          ),
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF374151),
          ),
          items: items.map((item) {
            return DropdownMenuItem<String>(value: item, child: Text(item));
          }).toList(),
          onChanged: (v) => v != null ? onChanged(v) : null,
        ),
      ),
    );
  }
}

// ─── Stat Chip ────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color? textColor;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final tColor = textColor ?? Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: tColor.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: tColor,
            ),
          ),
        ],
      ),
    );
  }
}
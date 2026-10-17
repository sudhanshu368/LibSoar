import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/app_drawer.dart';
import '../../core/utils/storage_helper.dart';
import '../../core/services/api_service.dart';

class ShiftManagementScreen extends StatefulWidget {
  const ShiftManagementScreen({super.key});

  @override
  State<ShiftManagementScreen> createState() => _ShiftManagementScreenState();
}

class _ShiftManagementScreenState extends State<ShiftManagementScreen> {
  List<_ShiftData> _shifts = [];
  bool _isLoading = true;
  String? _selectedBranchId;

  @override
  void initState() {
    super.initState();
    _fetchShifts();
  }

  Future<void> _fetchShifts() async {
    setState(() => _isLoading = true);
    try {
      final token = await StorageHelper.getToken();
      _selectedBranchId = await StorageHelper.getBranchId();
      if (_selectedBranchId == null || token == null) {
        setState(() => _isLoading = false);
        return;
      }
      final res = await ApiService.get(
        '/shifts?includeInactive=true&branchId=$_selectedBranchId',
        token,
      );
      if (res['success'] == true && res['data'] != null) {
        final List<dynamic> rawList = res['data'];
        setState(() {
          _shifts = rawList.map((e) => _ShiftData.fromJson(e)).toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching shifts: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _toTailwindColor(Color c) {
    if (c == const Color(0xFF10B981)) return 'bg-emerald-400';
    if (c == const Color(0xFF3B82F6)) return 'bg-primary';
    if (c == const Color(0xFFF59E0B)) return 'bg-warning';
    if (c == const Color(0xFFEC4899)) return 'bg-pink-400';
    if (c == const Color(0xFF8B5CF6)) return 'bg-purple-500';
    if (c == const Color(0xFFEF4444)) return 'bg-red-500';
    return 'bg-blue-500';
  }

  Future<void> _toggleShift(int index) async {
    final shift = _shifts[index];
    final newValue = !shift.isActive;
    
    // Optimistic UI update
    setState(() {
      _shifts[index] = shift.copyWith(isActive: newValue);
    });

    try {
      final token = await StorageHelper.getToken();
      await ApiService.patch('/shifts/${shift.id}', {"isActive": newValue}, token: token);
    } catch (e) {
      // Revert if error
      setState(() {
        _shifts[index] = shift.copyWith(isActive: shift.isActive);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update status', style: GoogleFonts.plusJakartaSans()), backgroundColor: Colors.red));
      }
    }
  }

  void _showAddShiftDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _AddShiftDialog(
        onAdd: (shift) async {
          setState(() => _isLoading = true);
          try {
             final token = await StorageHelper.getToken();
             final payload = {
                "name": shift.name,
                "timing": shift.timeRange,
                "startTime": shift.timeRange.split(' - ').first,
                "endTime": shift.timeRange.split(' - ').last,
                "fee": shift.fixedPrice,
                "floatingPrice": shift.floatingPrice,
                "seatLimit": 10,
                "isActive": shift.isActive,
                "color": _toTailwindColor(shift.dotColor),
                "branchId": _selectedBranchId,
             };
             final res = await ApiService.post('/shifts', payload, token: token);
             if (res != null && res['success'] == true && res['data'] is List) {
                 setState(() {
                     _shifts = (res['data'] as List).map((e) => _ShiftData.fromJson(e)).toList();
                     _isLoading = false;
                 });
             } else {
                 _fetchShifts();
                 if (mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                     content: Text(res?['message'] ?? 'Failed to add shift', style: GoogleFonts.plusJakartaSans()),
                     backgroundColor: Colors.red,
                   ));
                 }
             }
          } catch(e) {
             if(mounted) {
               setState(() => _isLoading = false);
               ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                 content: Text('Error: $e', style: GoogleFonts.plusJakartaSans()),
                 backgroundColor: Colors.red,
               ));
             }
             debugPrint('Error: $e');
          }
        },
      ),
    );
  }

  void _showEditShiftDialog(int index) {
    showDialog(
      context: context,
      builder: (ctx) => _AddShiftDialog(
        existingShift: _shifts[index],
        onAdd: (shift) async {
          setState(() => _isLoading = true);
          try {
             final token = await StorageHelper.getToken();
             final payload = {
                "name": shift.name,
                "timing": shift.timeRange,
                "startTime": shift.timeRange.split(' - ').first,
                "endTime": shift.timeRange.split(' - ').last,
                "fee": shift.fixedPrice,
                "floatingPrice": shift.floatingPrice,
                "isActive": shift.isActive,
                "color": _toTailwindColor(shift.dotColor),
             };
             final res = await ApiService.patch('/shifts/${shift.id}', payload, token: token);
             if (res != null && res['success'] == true && res['data'] is List) {
                 setState(() {
                     _shifts = (res['data'] as List).map((e) => _ShiftData.fromJson(e)).toList();
                     _isLoading = false;
                 });
             } else {
                 _fetchShifts();
             }
          } catch(e) {
             if(mounted) setState(() => _isLoading = false);
          }
        },
      ),
    );
  }

  void _deleteShift(int index) {
    final shift = _shifts[index];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Shift',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: const Color(0xFF0F172A),
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${shift.name}"?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: const Color(0xFF64748B),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              try {
                final token = await StorageHelper.getToken();
                final res = await ApiService.delete('/shifts/${shift.id}', token: token);
                if (res != null && res['success'] == true && res['data'] is List) {
                    setState(() {
                        _shifts = (res['data'] as List).map((e) => _ShiftData.fromJson(e)).toList();
                        _isLoading = false;
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Delete successful', style: GoogleFonts.plusJakartaSans()),
                        backgroundColor: Colors.green,
                      ));
                    }
                } else {
                    _fetchShifts();
                }
              } catch (e) {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: Text(
              'Delete',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const AppDrawer(activeItem: 'Shifts'),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: Color(0xFF0F172A)),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Text(
          'Shift Management',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE2E8F0)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gradient Header Banner
            _buildGradientHeader(),
            const SizedBox(height: 24),
            // Shifts Grid
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                   child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
                ),
              )
            else if (_shifts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                   child: Text("No shifts available in this branch.", style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth > 700
                      ? 3
                      : (constraints.maxWidth > 450 ? 2 : 1);
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: crossAxisCount == 1
                          ? 1.45
                          : (crossAxisCount == 2 ? 1.0 : 0.95),
                    ),
                    itemCount: _shifts.length,
                    itemBuilder: (context, index) => _ShiftCard(
                      shift: _shifts[index],
                      onToggle: () => _toggleShift(index),
                      onEdit: () => _showEditShiftDialog(index),
                      onDelete: () => _deleteShift(index),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3730A3), Color(0xFF4F46E5), Color(0xFF6366F1)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withAlpha(89),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(38),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.schedule_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'Shift Management',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Dashboard',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: Colors.white.withAlpha(191),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        '/',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: Colors.white.withAlpha(128),
                        ),
                      ),
                    ),
                    Text(
                      'Shifts',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _showAddShiftDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(31),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.add_rounded,
                    size: 18,
                    color: Color(0xFF4F46E5),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Add Shift',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF4F46E5),
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
}

// ─── Shift Card ────────────────────────────────────────────────────────────────

class _ShiftCard extends StatelessWidget {
  final _ShiftData shift;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ShiftCard({
    required this.shift,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: name + dot + toggle + edit + delete
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        shift.name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: shift.dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: shift.isActive,
                    onChanged: (_) => onToggle(),
                    activeThumbColor: Colors.white,
                    activeTrackColor: const Color(0xFF4F46E5),
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: const Color(0xFFCBD5E1),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 2),
                InkWell(
                  onTap: onEdit,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.edit_outlined,
                      size: 17,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                InkWell(
                  onTap: onDelete,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 17,
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Time range
            _InfoRow(
              icon: Icons.access_time_rounded,
              iconColor: const Color(0xFF6366F1),
              text: shift.timeRange,
            ),
            const SizedBox(height: 8),
            // Price
            _PriceRow(
              fixedPrice: shift.fixedPrice,
              floatingPrice: shift.floatingPrice,
            ),
            const SizedBox(height: 8),
            // Seat Limit & Occupancy
            _InfoRow(
              icon: Icons.chair_alt_rounded,
              iconColor: const Color(0xFF6366F1),
              text: 'Occupancy: ${shift.occupancy} / ${shift.seatLimit} seats',
            ),
            const Spacer(),
            // Divider + occupancy
            Container(height: 1, color: const Color(0xFFF1F5F9)),
            const SizedBox(height: 8),
            Text(
              '${shift.occupancyPercent}% occupied',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF334155),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  final int fixedPrice;
  final int floatingPrice;

  const _PriceRow({required this.fixedPrice, required this.floatingPrice});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.currency_rupee_rounded,
            size: 15,
            color: Color(0xFF6366F1),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '₹$fixedPrice / month (Fixed)',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '₹$floatingPrice / month (Floating)',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Add/Edit Shift Dialog ─────────────────────────────────────────────────────

class _AddShiftDialog extends StatefulWidget {
  final _ShiftData? existingShift;
  final void Function(_ShiftData) onAdd;

  const _AddShiftDialog({this.existingShift, required this.onAdd});

  @override
  State<_AddShiftDialog> createState() => _AddShiftDialogState();
}

class _AddShiftDialogState extends State<_AddShiftDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _fixedCtrl;
  late TextEditingController _floatingCtrl;
  
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  Color _selectedColor = const Color(0xFF4F46E5);

  final List<Color> _dotColors = [
    const Color(0xFF8B5CF6),
    const Color(0xFF3B82F6),
    const Color(0xFF10B981),
    const Color(0xFFF59E0B),
    const Color(0xFFEC4899),
    const Color(0xFFEF4444),
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.existingShift;
    _nameCtrl = TextEditingController(text: s?.name ?? '');
    _fixedCtrl = TextEditingController(
      text: s != null ? '${s.fixedPrice}' : '',
    );
    _floatingCtrl = TextEditingController(
      text: s != null ? '${s.floatingPrice}' : '0',
    );
    _selectedColor = s?.dotColor ?? _dotColors[0];
    
    if (s != null && s.timeRange.contains(' - ')) {
       final parts = s.timeRange.split(' - ');
       _startTime = _parseTime(parts.first);
       _endTime = _parseTime(parts.last);
    }
  }

  TimeOfDay? _parseTime(String timeStr) {
    try {
      if (timeStr.contains(':')) {
        final parts = timeStr.split(':');
        int hour = int.parse(parts[0].replaceAll(RegExp(r'[^0-9]'), ''));
        int min = int.parse(parts[1].replaceAll(RegExp(r'[^0-9]'), ''));
        if (timeStr.toLowerCase().contains('pm') && hour < 12) hour += 12;
        if (timeStr.toLowerCase().contains('am') && hour == 12) hour = 0;
        return TimeOfDay(hour: hour, minute: min);
      }
    } catch (_) {
      // Ignored: fallback to null if time format cannot be parsed
    }
    return null;
  }

  String _format24(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2,'0')}:${time.minute.toString().padLeft(2,'0')}';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _fixedCtrl.dispose();
    _floatingCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_nameCtrl.text.trim().isEmpty || _startTime == null || _endTime == null) return;
    
    final formattedTime = '${_format24(_startTime!)} - ${_format24(_endTime!)}';

    widget.onAdd(
      _ShiftData(
        id: widget.existingShift?.id ?? '',
        name: _nameCtrl.text.trim(),
        dotColor: _selectedColor,
        isActive: widget.existingShift?.isActive ?? true,
        timeRange: formattedTime,
        fixedPrice: int.tryParse(_fixedCtrl.text) ?? 0,
        floatingPrice: int.tryParse(_floatingCtrl.text) ?? 0,
        occupancyPercent: widget.existingShift?.occupancyPercent ?? 0,
        seatLimit: widget.existingShift?.seatLimit ?? 0,
        occupancy: widget.existingShift?.occupancy ?? 0,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingShift != null;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 420,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Fixed header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 16, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.schedule_rounded,
                      color: Color(0xFF4F46E5),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEdit ? 'Edit Shift' : 'Add New Shift',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF64748B),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Divider(height: 1, color: const Color(0xFFE2E8F0)),
            // Scrollable body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildField('Shift Name', _nameCtrl, 'e.g. Morning Shift'),
                    const SizedBox(height: 12),
                    Row(
                       children: [
                          Expanded(child: _buildTimePicker('Start Time', _startTime, (t) => setState(() => _startTime = t))),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTimePicker('End Time', _endTime, (t) => setState(() => _endTime = t))),
                       ]
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildField(
                            'Fixed Price (₹)',
                            _fixedCtrl,
                            '0',
                            isNumber: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildField(
                            'Floating Price (₹)',
                            _floatingCtrl,
                            '0',
                            isNumber: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Shift Color',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _dotColors
                          .map(
                            (c) => GestureDetector(
                              onTap: () => setState(() => _selectedColor = c),
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                  border: _selectedColor == c
                                      ? Border.all(
                                          color: const Color(0xFF0F172A),
                                          width: 2.5,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            // Fixed footer buttons
            Divider(height: 1, color: const Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        isEdit ? 'Save Changes' : 'Add Shift',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController ctrl,
    String hint, {
    bool isNumber = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: const Color(0xFF94A3B8),
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
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
      ],
    );
  }

  Widget _buildTimePicker(String label, TimeOfDay? time, ValueChanged<TimeOfDay?> onChange) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () async {
             final t = await showTimePicker(context: context, initialTime: time ?? TimeOfDay.now());
             if (t != null) onChange(t);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                  Text(
                     time != null ? time.format(context) : 'Select',
                     style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: time != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                     )
                  ),
                  const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF64748B))
               ],
            )
          )
        )
      ]
    );
  }
}

// ─── Data Model ────────────────────────────────────────────────────────────────

class _ShiftData {
  final String id;
  final String name;
  final Color dotColor;
  final bool isActive;
  final String timeRange;
  final int fixedPrice;
  final int floatingPrice;
  final int occupancyPercent;
  final int seatLimit;
  final int occupancy;

  const _ShiftData({
    this.id = '',
    required this.name,
    required this.dotColor,
    required this.isActive,
    required this.timeRange,
    required this.fixedPrice,
    required this.floatingPrice,
    required this.occupancyPercent,
    required this.seatLimit,
    required this.occupancy,
  });

  factory _ShiftData.fromJson(Map<String, dynamic> json) {
    int seatLimit = json['seatLimit'] ?? 0;
    int occ = json['occupancy'] ?? 0;
    int safeLimit = seatLimit > 0 ? seatLimit : 1;
    int percent = ((occ / safeLimit) * 100).round();
    
    // Parse Color
    String colorStr = json['color'] ?? 'bg-blue-500';
    Color parsedColor = const Color(0xFF3B82F6);
    if (colorStr.contains('emerald')) parsedColor = const Color(0xFF10B981);
    if (colorStr.contains('warning') || colorStr.contains('amber') || colorStr.contains('yellow')) parsedColor = const Color(0xFFF59E0B);
    if (colorStr.contains('pink')) parsedColor = const Color(0xFFEC4899);
    if (colorStr.contains('purple')) parsedColor = const Color(0xFF8B5CF6);
    if (colorStr.contains('red')) parsedColor = const Color(0xFFEF4444);

    return _ShiftData(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      dotColor: parsedColor,
      isActive: json['isActive'] ?? true,
      timeRange: json['timing'] ?? '${json['startTime']} - ${json['endTime']}',
      fixedPrice: json['fee'] ?? 0,
      floatingPrice: json['floatingPrice'] ?? 0,
      occupancyPercent: percent,
      seatLimit: seatLimit,
      occupancy: occ,
    );
  }

  _ShiftData copyWith({
    String? id,
    String? name,
    Color? dotColor,
    bool? isActive,
    String? timeRange,
    int? fixedPrice,
    int? floatingPrice,
    int? occupancyPercent,
    int? seatLimit,
    int? occupancy,
  }) {
    return _ShiftData(
      id: id ?? this.id,
      name: name ?? this.name,
      dotColor: dotColor ?? this.dotColor,
      isActive: isActive ?? this.isActive,
      timeRange: timeRange ?? this.timeRange,
      fixedPrice: fixedPrice ?? this.fixedPrice,
      floatingPrice: floatingPrice ?? this.floatingPrice,
      occupancyPercent: occupancyPercent ?? this.occupancyPercent,
      seatLimit: seatLimit ?? this.seatLimit,
      occupancy: occupancy ?? this.occupancy,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/storage_helper.dart';
import '../../../data/models/dropdown_models.dart';

class RenewMembershipDialog extends StatefulWidget {
  final Map<String, dynamic> subscription;
  final String branchId;
  final VoidCallback onRenewed;

  const RenewMembershipDialog({
    super.key,
    required this.subscription,
    required this.branchId,
    required this.onRenewed,
  });

  @override
  State<RenewMembershipDialog> createState() => _RenewMembershipDialogState();
}

class _RenewMembershipDialogState extends State<RenewMembershipDialog> {
  DateTime? _startDate;
  DateTime? _endDate;
  final _feeController = TextEditingController();
  final _dueController = TextEditingController(text: '0');

  List<ApiShiftModel> _shifts = [];
  bool _isLoadingShifts = true;
  String? _selectedShiftId;

  List<ApiSeatModel> _seats = [];
  bool _isLoadingSeats = false;
  String? _selectedSeatId;

  String _seatType = 'Fixed Seat'; // 'Fixed Seat' or 'Floating Seat'
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

    // ── Date pre-fill ─────────────────────────────────────────────────────
    final oldEndDateStr = widget.subscription['endDate'];
    if (oldEndDateStr != null && oldEndDateStr.toString().isNotEmpty) {
      try {
        final parsed = DateTime.parse(oldEndDateStr);
        _startDate = parsed.add(const Duration(days: 1));
      } catch (_) {
        _startDate = DateTime.now();
      }
    } else {
      _startDate = DateTime.now();
    }
    _endDate = _startDate!.add(const Duration(days: 30));

    // ── Seat type pre-fill ────────────────────────────────────────────────
    final oldSeatType = widget.subscription['seatType']
        ?? widget.subscription['student']?['seatType'];
    if (oldSeatType != null &&
        oldSeatType.toString().trim().toUpperCase() == 'FLOATING') {
      _seatType = 'Floating Seat';
    } else {
      _seatType = 'Fixed Seat';
    }

    // ── Fetch shifts (which then fetches seats) ───────────────────────────
    _fetchShifts();
  }

  @override
  void dispose() {
    _feeController.dispose();
    _dueController.dispose();
    super.dispose();
  }

  /// Extract seat ID from all possible paths the API might return.
  String? _extractCurrentSeatId() {
    final s = widget.subscription;
    final student = s['student'] is Map ? Map<String, dynamic>.from(s['student'] as Map) : <String, dynamic>{};
    final seat = s['seat'] is Map ? Map<String, dynamic>.from(s['seat'] as Map) : <String, dynamic>{};

    return s['seatId']?.toString()
        ?? s['seat_id']?.toString()
        ?? seat['id']?.toString()
        ?? seat['_id']?.toString()
        ?? student['seatId']?.toString()
        ?? student['seat_id']?.toString()
        ?? (student['seat'] is Map ? (student['seat'] as Map)['id']?.toString() : null)
        ?? (student['seat'] is Map ? (student['seat'] as Map)['_id']?.toString() : null);
  }

  /// Extract shift ID from all possible paths.
  String? _extractCurrentShiftId() {
    final s = widget.subscription;
    final student = s['student'] is Map ? Map<String, dynamic>.from(s['student'] as Map) : <String, dynamic>{};
    final shift = s['shift'] is Map ? Map<String, dynamic>.from(s['shift'] as Map) : <String, dynamic>{};

    // If 'shift' is a plain string it is the ID itself
    final shiftRaw = s['shift'];
    final shiftStr = (shiftRaw is String && shiftRaw.isNotEmpty) ? shiftRaw : null;

    return s['shiftId']?.toString()
        ?? shiftStr
        ?? shift['id']?.toString()
        ?? shift['_id']?.toString()
        ?? student['shiftId']?.toString()
        ?? student['shift_id']?.toString();
  }

  Future<void> _fetchShifts() async {
    try {
      final token = await StorageHelper.getToken();
      final res = await ApiService.get('/shifts?branchId=${widget.branchId}', token ?? '');
      if (res['success'] == true && mounted) {
        final List data = res['data'] ?? [];
        final currentShiftId = _extractCurrentShiftId();

        setState(() {
          _shifts = data.map((e) => ApiShiftModel.fromJson(e)).toList();
          _isLoadingShifts = false;

          // ✅ Pre-select shift from existing subscription
          if (currentShiftId != null && _shifts.any((s) => s.id == currentShiftId)) {
            _selectedShiftId = currentShiftId;
            // Auto-fill fee based on pre-selected shift
            _updateFeeHint();
          }
        });

        // Fetch seats after shift is pre-selected
        _fetchSeats();
      } else {
        if (mounted) setState(() => _isLoadingShifts = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingShifts = false);
    }
  }

  Future<void> _fetchSeats() async {
    if (_selectedShiftId == null) {
      setState(() {
        _seats = [];
        _selectedSeatId = null;
      });
      return;
    }

    setState(() => _isLoadingSeats = true);
    try {
      final token = await StorageHelper.getToken();
      final sd = DateFormat('yyyy-MM-dd').format(_startDate!);
      final ed = DateFormat('yyyy-MM-dd').format(_endDate!);

      final url =
          '/seats?branchId=${widget.branchId}&shiftId=$_selectedShiftId&startDate=$sd&endDate=$ed';
      final res = await ApiService.get(url, token ?? '');

      if (res['success'] == true && mounted) {
        final List data = res['data'] ?? [];

        // ✅ Try all possible paths to find the student's current seat ID
        final currentSeatId = _extractCurrentSeatId();

        final available = <ApiSeatModel>[];
        bool currentSeatIncluded = false;

        for (var item in data) {
          // Include AVAILABLE seats OR the student's own (possibly OCCUPIED) seat
          final itemId = item['id']?.toString() ?? item['_id']?.toString();
          final isCurrentSeat = currentSeatId != null && itemId == currentSeatId;
          if (item['status'] == 'AVAILABLE' || isCurrentSeat) {
            available.add(ApiSeatModel.fromJson(item));
            if (isCurrentSeat) currentSeatIncluded = true;
          }
        }

        // If current seat wasn't in the API response at all (e.g. different shift page),
        // try to build a minimal entry from subscription data so the dropdown shows it.
        if (!currentSeatIncluded && currentSeatId != null) {
          final student = widget.subscription['student'] is Map
              ? Map<String, dynamic>.from(widget.subscription['student'] as Map)
              : <String, dynamic>{};
          final seatNum = student['seatNumber']?.toString()
              ?? widget.subscription['seatNumber']?.toString()
              ?? widget.subscription['seat']?['seatNumber']?.toString()
              ?? 'Current Seat';
          available.insert(
            0,
            ApiSeatModel(id: currentSeatId, seatNumber: seatNum),
          );
          currentSeatIncluded = true;
        }

        setState(() {
          _seats = available;
          _isLoadingSeats = false;

          // ✅ Auto-select the student's existing seat
          if (currentSeatId != null && _seats.any((s) => s.id == currentSeatId)) {
            _selectedSeatId = currentSeatId;
          } else {
            _selectedSeatId = null;
          }
        });
      } else {
        if (mounted) setState(() => _isLoadingSeats = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingSeats = false);
    }
  }

  void _updateFeeHint() {
    if (_selectedShiftId != null) {
      final shift = _shifts.firstWhere((s) => s.id == _selectedShiftId);
      final fee = _seatType == 'Fixed Seat' ? shift.fee : shift.floatingPrice;
      _feeController.text = fee.toString();
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF4F46E5)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
      _fetchSeats();
    }
  }

  Future<void> _submit() async {
    if (_selectedShiftId == null) {
      _showError('Please select a shift');
      return;
    }
    if (_seatType == 'Fixed Seat' && _selectedSeatId == null) {
      _showError('Please select a seat number from available seats');
      return;
    }
    if (_feeController.text.trim().isEmpty) {
      _showError('Please enter total fee');
      return;
    }

    setState(() => _isSubmitting = true);
    
    try {
      final token = await StorageHelper.getToken();
      final fee = double.tryParse(_feeController.text) ?? 0;
      final due = double.tryParse(_dueController.text) ?? 0;
      final paid = fee - due;

      String formatDate(DateTime dt) {
         return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
      }

      final studentData = widget.subscription['student'] ?? {};

      final body = {
        "studentId": widget.subscription['studentId'] ?? studentData['id'],
        "startDate": formatDate(_startDate!),
        "endDate": formatDate(_endDate!),
        "shift": _selectedShiftId,
        "seatType": _seatType == 'Fixed Seat' ? 'FIXED' : 'FLOATING',
        if (_seatType == 'Fixed Seat') "seatId": _selectedSeatId,
        "totalFee": fee.toInt(),
        "dueAmount": due.toInt(),
        "paidAmount": paid.toInt(),
        "paymentMode": "CASH", // Or make it a dropdown if needed
      };

      final res = await ApiService.post('/subscriptions/renew', body, token: token ?? '');
      
      if (res['success'] == true) {
        if (mounted) Navigator.pop(context);
        widget.onRenewed();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Membership renewed successfully!'),
          backgroundColor: Color(0xFF10B981),
        ));
      } else {
        _showError(res['message'] ?? 'Failed to renew');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(horizontal: isDesktop ? size.width * 0.2 : 16, vertical: 24),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMemberInfo(),
                        const SizedBox(height: 20),
                        _buildDateRow(),
                        const SizedBox(height: 16),
                        _buildShiftDropdown(),
                        const SizedBox(height: 16),
                        _buildSeatSection(),
                        const SizedBox(height: 16),
                        _buildFeeSection(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildButtons(),
              ],
            ),
          ),
          if (_isSubmitting)
            Positioned.fill(
               child: Container(
                 decoration: BoxDecoration(
                   color: Colors.white.withAlpha(150),
                   borderRadius: BorderRadius.circular(16),
                 ),
                 child: const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))),
               ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF64748B)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Renew membership',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _buildMemberInfo() {
    final student = widget.subscription['student'] ?? {};
    final memId = student['memberId'] ?? 'N/A';
    final name = student['name'] ?? 'Unknown';
    final phone = student['phone'] ?? 'N/A';
    final oldStart = widget.subscription['startDate']?.toString().split('T').first ?? '';
    final oldEnd = widget.subscription['endDate']?.toString().split('T').first ?? '';
    final period = oldStart.isNotEmpty ? '$oldStart to $oldEnd' : 'N/A';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 12,
        children: [
          _infoItem('Member ID', memId, isBold: true),
          _infoItem('Name', name),
          _infoItem('Phone', phone),
          _infoItem('Last Period', period),
        ],
      ),
    );
  }

  Widget _infoItem(String label, String value, {bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF64748B)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: const Color(0xFF111827),
          ),
        ),
      ],
    );
  }

  Widget _buildDateRow() {
    return Row(
      children: [
        Expanded(
          child: _buildDateField('Start Date', _startDate, true),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildDateField('End Date', _endDate, false),
        ),
      ],
    );
  }

  Widget _buildDateField(String label, DateTime? date, bool isStart) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF374151))),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => _pickDate(isStart),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFD1D5DB)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  date != null ? DateFormat('dd-MM-yyyy').format(date) : 'Select date',
                  style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF111827)),
                ),
                const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF6B7280)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShiftDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Shift *', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF374151))),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFD1D5DB)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: _isLoadingShifts
            ? const Padding(padding: EdgeInsets.all(12), child: Text('Loading shifts...'))
            : DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedShiftId,
                  hint: Text('Select Shift', style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF6B7280))),
                  items: _shifts.map((s) => DropdownMenuItem(
                    value: s.id, 
                    child: Text(s.name, style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF111827)))
                  )).toList(),
                  onChanged: (v) {
                    setState(() {
                      _selectedShiftId = v;
                      _updateFeeHint();
                    });
                    _fetchSeats();
                  },
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildSeatSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Seat Type', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF374151))),
        const SizedBox(height: 6),
        Row(
          children: [
            _buildRadio('Fixed Seat'),
            const SizedBox(width: 24),
            _buildRadio('Floating Seat'),
          ],
        ),
        if (_seatType == 'Fixed Seat') ...[
          const SizedBox(height: 16),
          Text('Seat Number *', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF374151))),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFD1D5DB)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: _isLoadingSeats
              ? const Padding(padding: EdgeInsets.all(12), child: Text('Loading seats...'))
              : DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedSeatId,
                    hint: Text('Select Seat', style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF6B7280))),
                    items: _seats.map((s) => DropdownMenuItem(
                      value: s.id, 
                      child: Text(s.seatNumber, style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF111827)))
                    )).toList(),
                    onChanged: (v) => setState(() => _selectedSeatId = v),
                  ),
                ),
          ),
        ],
      ],
    );
  }

  Widget _buildRadio(String val) {
    return GestureDetector(
      onTap: () => setState(() {
        _seatType = val;
        _updateFeeHint();
      }),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20, height: 20,
            child: Radio<String>(
              value: val,
              groupValue: _seatType,
              activeColor: const Color(0xFF4F46E5),
              onChanged: (v) {
                if (v != null) {
                  setState(() { _seatType = v; _updateFeeHint(); });
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          Text(val, style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF111827))),
        ],
      ),
    );
  }

  Widget _buildFeeSection() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Fee', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF374151))),
              const SizedBox(height: 6),
              TextField(
                controller: _feeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'e.g. 1000',
                  hintStyle: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF9CA3AF)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF4F46E5))),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Fee Due', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF374151))),
              const SizedBox(height: 6),
              TextField(
                controller: _dueController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  fillColor: const Color(0xFFFFFFFF),
                  filled: true,
                  hintText: 'e.g. 0',
                  hintStyle: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF9CA3AF)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF4F46E5))),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFD1D5DB)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: Text('Cancel', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF374151))),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            elevation: 0,
          ),
          child: Text('Renew Membership', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
        ),
      ],
    );
  }
}

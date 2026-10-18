import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/services/api_service.dart';
import '../../core/utils/storage_helper.dart';
import '../../widgets/app_drawer.dart';

// ─── Data Models ─────────────────────────────────────────────────────────────

class FloorModel {
  String name;
  int capacity;
  FloorModel({required this.name, required this.capacity});
  FloorModel copyWith({String? name, int? capacity}) =>
      FloorModel(name: name ?? this.name, capacity: capacity ?? this.capacity);
}

class ShiftModel {
  String id;
  String name;
  String startTime;
  String endTime;
  double fixedPrice;
  double floatingPrice;
  int totalSeats;
  int occupiedSeats;
  bool enabled;
  Color color;
  IconData icon;

  ShiftModel({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.fixedPrice,
    required this.floatingPrice,
    required this.totalSeats,
    required this.occupiedSeats,
    required this.enabled,
    required this.color,
    required this.icon,
  });

  ShiftModel copyWith({
    String? name,
    String? startTime,
    String? endTime,
    double? fixedPrice,
    double? floatingPrice,
    int? totalSeats,
    int? occupiedSeats,
    bool? enabled,
  }) => ShiftModel(
    id: id,
    name: name ?? this.name,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    fixedPrice: fixedPrice ?? this.fixedPrice,
    floatingPrice: floatingPrice ?? this.floatingPrice,
    totalSeats: totalSeats ?? this.totalSeats,
    occupiedSeats: occupiedSeats ?? this.occupiedSeats,
    enabled: enabled ?? this.enabled,
    color: color,
    icon: icon,
  );
}

// ─── Main Screen ─────────────────────────────────────────────────────────────

class LibraryDetailsScreen extends StatefulWidget {
  const LibraryDetailsScreen({super.key});

  @override
  State<LibraryDetailsScreen> createState() => _LibraryDetailsScreenState();
}

class _LibraryDetailsScreenState extends State<LibraryDetailsScreen> {
  // ── Basic Details State ──
  bool _isEditingBasic = false;
  bool _isSavingBasic = false;

  final _nameCtrl = TextEditingController(text: 'Sudhanshu Library');
  final _emailCtrl = TextEditingController(text: 'info@sudhanshulib.com');
  final _contactCtrl = TextEditingController(text: '8228958397');
  final _addressCtrl = TextEditingController(text: 'Chhajan');
  final _cityCtrl = TextEditingController(text: 'Muzaffarpur');
  final _stateCtrl = TextEditingController(text: 'Bihar');
  final _pincodeCtrl = TextEditingController(text: '844127');

  // Temp controllers for edit mode
  final _tNameCtrl = TextEditingController();
  final _tEmailCtrl = TextEditingController();
  final _tContactCtrl = TextEditingController();
  final _tAddressCtrl = TextEditingController();
  final _tCityCtrl = TextEditingController();
  final _tStateCtrl = TextEditingController();
  final _tPincodeCtrl = TextEditingController();

  final _basicFormKey = GlobalKey<FormState>();

  // ── Facilities State ──
  bool _isEditingFacilities = false;
  bool _isSavingFacilities = false;
  int _bufferDays = 2;
  final _bufferCtrl = TextEditingController(text: '2');

  final List<String> _allFacilities = [
    'Wi-Fi',
    'AC',
    'CCTV',
    'Locker',
    'Cafeteria',
    'Parking',
    'Printer',
    'Fans',
    'RO',
    'Library',
    'News Paper'
        'Reading Lamp',
    'Power Backup',
    'Water Cooler',
  ];
  final List<String> _selectedFacilities = ['Wi-Fi', 'AC', 'CCTV', 'Locker'];

  List<FloorModel> _floors = [
    FloorModel(name: 'A', capacity: 10),
    FloorModel(name: 'B', capacity: 15),
    FloorModel(name: 'C', capacity: 8),
  ];
  List<FloorModel> _tempFloors = [];

  // ── Shifts State ──
  final List<ShiftModel> _shifts = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final token = await StorageHelper.getToken();
      final branchId = await StorageHelper.getBranchId();
      if (token == null || branchId == null) return;

      final libRes = await ApiService.get(
        '/settings/library?branchId=$branchId',
        token,
      );
      if (libRes != null && libRes['success'] == true) {
        final data = libRes['data'];
        if (data['basic'] != null) {
          _nameCtrl.text = data['basic']['name']?.toString() ?? '';
          _emailCtrl.text = data['basic']['email']?.toString() ?? '';
          _contactCtrl.text = data['basic']['contactNumber']?.toString() ?? '';
          _addressCtrl.text = data['basic']['address']?.toString() ?? '';
          _cityCtrl.text = data['basic']['city']?.toString() ?? '';
          _stateCtrl.text = data['basic']['state']?.toString() ?? '';
          _pincodeCtrl.text = data['basic']['pincode']?.toString() ?? '';
        }
        if (data['facilities'] != null) {
          _bufferDays = data['facilities']['bufferDays'] as int? ?? 2;
          _bufferCtrl.text = _bufferDays.toString();

          if (data['facilities']['facilities'] != null) {
            _selectedFacilities.clear();
            for (var str in data['facilities']['facilities']) {
              _selectedFacilities.add(str.toString());
            }
          }
          if (data['facilities']['floors'] != null) {
            final List f = data['facilities']['floors'];
            _floors = f
                .map(
                  (e) => FloorModel(
                    name: e['name'].toString(),
                    capacity: e['seats'] as int,
                  ),
                )
                .toList();
          }
        }
      }

      final shiftRes = await ApiService.get(
        '/shifts?includeInactive=true&branchId=$branchId',
        token,
      );
      if (shiftRes != null &&
          shiftRes['success'] == true &&
          shiftRes['data'] is List) {
        final List s = shiftRes['data'];
        _shifts.clear();
        for (var e in s) {
          _shifts.add(
            ShiftModel(
              id: e['id']?.toString() ?? '',
              name: e['name']?.toString() ?? '',
              startTime: e['startTime']?.toString() ?? '',
              endTime: e['endTime']?.toString() ?? '',
              fixedPrice: (e['fee'] ?? 0).toDouble(),
              floatingPrice: (e['floatingPrice'] ?? 0).toDouble(),
              totalSeats: e['seatLimit'] as int? ?? 10,
              occupiedSeats: e['occupancy'] as int? ?? 0,
              enabled: e['isActive'] as bool? ?? false,
              color: _parseTailwindColor(e['color']?.toString() ?? ''),
              icon: _getIconForShift(e['name']?.toString() ?? ''),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error fetching lib data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _parseTailwindColor(String tw) {
    if (tw.contains('emerald')) return const Color(0xFF10B981);
    if (tw.contains('primary') || tw.contains('blue')) {
      return const Color(0xFF3B82F6);
    }
    if (tw.contains('warning') ||
        tw.contains('yellow') ||
        tw.contains('amber')) {
      return const Color(0xFFF59E0B);
    }
    if (tw.contains('pink')) return const Color(0xFFEC4899);
    if (tw.contains('purple')) return const Color(0xFF8B5CF6);
    if (tw.contains('red')) return const Color(0xFFEF4444);
    return const Color(0xFF4F46E5);
  }

  IconData _getIconForShift(String name) {
    final lowered = name.toLowerCase();
    if (lowered.contains('morning') || lowered.contains('day')) {
      return Icons.wb_sunny_rounded;
    }
    if (lowered.contains('afternoon')) return Icons.wb_cloudy_rounded;
    if (lowered.contains('evening') || lowered.contains('night')) {
      return Icons.nights_stay_rounded;
    }
    return Icons.schedule_rounded;
  }

  String _toTailwindColor(Color c) {
    if (c == const Color(0xFF10B981)) return 'bg-emerald-400';
    if (c == const Color(0xFF3B82F6)) return 'bg-primary';
    if (c == const Color(0xFFF59E0B)) return 'bg-warning';
    if (c == const Color(0xFFEC4899)) return 'bg-pink-400';
    if (c == const Color(0xFF8B5CF6)) return 'bg-purple-500';
    if (c == const Color(0xFFEF4444)) return 'bg-red-500';
    return 'bg-primary';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _contactCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pincodeCtrl.dispose();
    _tNameCtrl.dispose();
    _tEmailCtrl.dispose();
    _tContactCtrl.dispose();
    _tAddressCtrl.dispose();
    _tCityCtrl.dispose();
    _tStateCtrl.dispose();
    _tPincodeCtrl.dispose();
    _bufferCtrl.dispose();
    super.dispose();
  }

  // ── Basic Details Actions ──
  void _startEditBasic() {
    _tNameCtrl.text = _nameCtrl.text;
    _tEmailCtrl.text = _emailCtrl.text;
    _tContactCtrl.text = _contactCtrl.text;
    _tAddressCtrl.text = _addressCtrl.text;
    _tCityCtrl.text = _cityCtrl.text;
    _tStateCtrl.text = _stateCtrl.text;
    _tPincodeCtrl.text = _pincodeCtrl.text;
    setState(() => _isEditingBasic = true);
  }

  void _cancelEditBasic() => setState(() => _isEditingBasic = false);

  Future<void> _saveBasic() async {
    if (!(_basicFormKey.currentState?.validate() ?? false)) return;
    setState(() => _isSavingBasic = true);

    try {
      final token = await StorageHelper.getToken();
      final branchId = await StorageHelper.getBranchId();

      final payload = {
        "name": _tNameCtrl.text.trim(),
        "email": _tEmailCtrl.text.trim(),
        "phone": _tContactCtrl.text.trim(),
        "contactNumber": _tContactCtrl.text.trim(),
        "address": _tAddressCtrl.text.trim(),
        "city": _tCityCtrl.text.trim(),
        "state": _tStateCtrl.text.trim(),
        "pincode": _tPincodeCtrl.text.trim(),
        "branchId": branchId,
      };

      final res = await ApiService.patch(
        '/settings/library/basic',
        payload,
        token: token,
      );
      if (res != null && res['success'] == true) {
        setState(() {
          _nameCtrl.text = _tNameCtrl.text.trim();
          _emailCtrl.text = _tEmailCtrl.text.trim();
          _contactCtrl.text = _tContactCtrl.text.trim();
          _addressCtrl.text = _tAddressCtrl.text.trim();
          _cityCtrl.text = _tCityCtrl.text.trim();
          _stateCtrl.text = _tStateCtrl.text.trim();
          _pincodeCtrl.text = _tPincodeCtrl.text.trim();
          _isEditingBasic = false;
        });
        _showSnackbar(
          res['message'] ?? 'Library details updated successfully',
          isError: false,
        );
      } else {
        _showSnackbar(
          res?['message'] ?? 'Failed to update details',
          isError: true,
        );
      }
    } catch (e) {
      _showSnackbar('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSavingBasic = false);
    }
  }

  // ── Facilities Actions ──
  void _startEditFacilities() {
    _tempFloors = _floors
        .map((f) => FloorModel(name: f.name, capacity: f.capacity))
        .toList();
    _bufferCtrl.text = _bufferDays.toString();
    setState(() => _isEditingFacilities = true);
  }

  void _cancelEditFacilities() => setState(() => _isEditingFacilities = false);

  Future<void> _saveFacilities() async {
    final buf = int.tryParse(_bufferCtrl.text.trim()) ?? 0;
    if (_tempFloors.isEmpty) {
      _showSnackbar('At least 1 floor is required', isError: true);
      return;
    }
    for (final f in _tempFloors) {
      if (f.capacity <= 0) {
        _showSnackbar('Floor capacity must be greater than 0', isError: true);
        return;
      }
    }
    setState(() => _isSavingFacilities = true);

    try {
      final token = await StorageHelper.getToken();
      final branchId = await StorageHelper.getBranchId();
      final payload = {
        "bufferDays": buf,
        "facilities": _selectedFacilities,
        "floors": _tempFloors
            .map(
              (f) => {
                "id": f.name,
                "name": f.name,
                "seats": f.capacity.toString(),
              },
            )
            .toList(),
      };

      final res = await ApiService.patch(
        '/settings/library/facilities?branchId=$branchId',
        payload,
        token: token,
      );
      if (res != null && res['success'] == true) {
        setState(() {
          _bufferDays = buf;
          _floors = List.from(_tempFloors);
          _isEditingFacilities = false;
        });
        _showSnackbar(
          res['message'] ?? 'Facilities updated successfully',
          isError: false,
        );
      } else {
        _showSnackbar(
          res?['message'] ?? 'Failed to update facilities',
          isError: true,
        );
      }
    } catch (e) {
      _showSnackbar('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSavingFacilities = false);
    }
  }

  // ── Shift Actions ──
  void _toggleShift(ShiftModel shift) async {
    final newValue = !shift.enabled;
    setState(() {
      final idx = _shifts.indexWhere((s) => s.id == shift.id);
      if (idx != -1) {
        _shifts[idx] = shift.copyWith(enabled: newValue);
      }
    });

    try {
      final token = await StorageHelper.getToken();
      final res = await ApiService.patch('/shifts/${shift.id}', {
        "isActive": newValue,
      }, token: token);
      if (res != null && res['success'] == true) {
        _showSnackbar(
          '${shift.name} shift ${newValue ? "enabled" : "disabled"}',
          isError: false,
        );
      } else {
        throw Exception(res?['message'] ?? "API error");
      }
    } catch (e) {
      setState(() {
        final idx = _shifts.indexWhere((s) => s.id == shift.id);
        if (idx != -1) {
          _shifts[idx] = shift.copyWith(enabled: !newValue);
        }
      });
      _showSnackbar('Failed to update status: $e', isError: true);
    }
  }

  void _deleteShift(ShiftModel shift) async {
    final confirmed = await _showDeleteConfirmation(shift.name);
    if (confirmed == true) {
      try {
        final token = await StorageHelper.getToken();
        final res = await ApiService.delete(
          '/shifts/${shift.id}',
          token: token,
        );
        if (res != null && res['success'] == true) {
          setState(() => _shifts.removeWhere((s) => s.id == shift.id));
          _showSnackbar('${shift.name} shift deleted', isError: false);
        } else {
          _showSnackbar(
            res?['message'] ?? 'Failed to delete shift',
            isError: true,
          );
        }
      } catch (e) {
        _showSnackbar('Error: $e', isError: true);
      }
    }
  }

  void _editShift(ShiftModel shift) async {
    final result = await _showShiftEditModal(shift);
    if (result != null) {
      setState(() {
        final idx = _shifts.indexWhere((s) => s.id == shift.id);
        if (idx != -1) _shifts[idx] = result;
      });
      _showSnackbar('${result.name} shift updated', isError: false);
    }
  }

  // ── Helpers ──
  void _showSnackbar(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.white),
        ),
        backgroundColor: isError
            ? const Color(0xFFEF4444)
            : const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<bool?> _showDeleteConfirmation(String shiftName) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Shift',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "$shiftName" shift? This action cannot be undone.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: const Color(0xFF64748B),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<ShiftModel?> _showShiftEditModal(ShiftModel shift) {
    final nameCtrl = TextEditingController(text: shift.name);
    final startCtrl = TextEditingController(text: shift.startTime);
    final endCtrl = TextEditingController(text: shift.endTime);
    final fixedCtrl = TextEditingController(
      text: shift.fixedPrice.toStringAsFixed(0),
    );
    final floatingCtrl = TextEditingController(
      text: shift.floatingPrice.toStringAsFixed(0),
    );
    final seatsCtrl = TextEditingController(text: shift.totalSeats.toString());
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    return showDialog<ShiftModel>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: shift.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(shift.icon, color: shift.color, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Edit Shift',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _modalField(
                    'Shift Name',
                    nameCtrl,
                    validator: (v) =>
                        (v?.trim().isEmpty ?? true) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _modalTimeField(ctx, 'Start Time', startCtrl),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _modalTimeField(ctx, 'End Time', endCtrl),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _modalField(
                          'Fixed Price (₹)',
                          fixedCtrl,
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            final n = double.tryParse(v ?? '');
                            if (n == null || n <= 0) return 'Price > 0';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _modalField(
                          'Floating Price (₹)',
                          floatingCtrl,
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            final n = double.tryParse(v ?? '');
                            if (n == null || n <= 0) return 'Price > 0';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _modalField(
                    'Total Seats',
                    seatsCtrl,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n <= 0) return 'Seats > 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (!(formKey.currentState?.validate() ??
                                      false)) {
                                    return;
                                  }
                                  setModalState(() => isSaving = true);

                                  try {
                                    final token =
                                        await StorageHelper.getToken();
                                    final payload = {
                                      "name": nameCtrl.text.trim(),
                                      "timing":
                                          "${startCtrl.text.trim()} - ${endCtrl.text.trim()}",
                                      "startTime": startCtrl.text.trim(),
                                      "endTime": endCtrl.text.trim(),
                                      "fee":
                                          int.tryParse(fixedCtrl.text) ??
                                          shift.fixedPrice.toInt(),
                                      "floatingPrice":
                                          int.tryParse(floatingCtrl.text) ??
                                          shift.floatingPrice.toInt(),
                                      "seatLimit":
                                          int.tryParse(seatsCtrl.text) ??
                                          shift.totalSeats,
                                      "isActive": shift.enabled,
                                      "color": _toTailwindColor(shift.color),
                                    };

                                    final res = await ApiService.patch(
                                      '/shifts/${shift.id}',
                                      payload,
                                      token: token,
                                    );
                                    if (res != null && res['success'] == true) {
                                      if (ctx.mounted) {
                                        Navigator.pop(
                                          ctx,
                                          shift.copyWith(
                                            name: payload['name'] as String,
                                            startTime:
                                                payload['startTime'] as String,
                                            endTime:
                                                payload['endTime'] as String,
                                            fixedPrice: (payload['fee'] as num)
                                                .toDouble(),
                                            floatingPrice:
                                                (payload['floatingPrice']
                                                        as num)
                                                    .toDouble(),
                                            totalSeats:
                                                payload['seatLimit'] as int,
                                          ),
                                        );
                                      }
                                    } else {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              res?['message'] ??
                                                  'Failed to update shift',
                                              style:
                                                  GoogleFonts.plusJakartaSans(),
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                      setModalState(() => isSaving = false);
                                    }
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Error: $e',
                                            style:
                                                GoogleFonts.plusJakartaSans(),
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                    setModalState(() => isSaving = false);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Save',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
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

  Widget _modalField(
    String label,
    TextEditingController ctrl, {
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          validator: validator,
          style: GoogleFonts.plusJakartaSans(fontSize: 13),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
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
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFFEF4444),
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _modalTimeField(
    BuildContext ctx,
    String label,
    TextEditingController ctrl,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () async {
            TimeOfDay initial = TimeOfDay.now();
            try {
              if (ctrl.text.isNotEmpty && ctrl.text.contains(':')) {
                final parts = ctrl.text.split(':');
                initial = TimeOfDay(
                  hour: int.parse(parts[0]),
                  minute: int.parse(parts[1]),
                );
              }
            } catch (_) {}

            final picked = await showTimePicker(
              context: ctx,
              initialTime: initial,
              builder: (context, child) {
                return MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(alwaysUse24HourFormat: true),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              final h = picked.hour.toString().padLeft(2, '0');
              final m = picked.minute.toString().padLeft(2, '0');
              ctrl.text = '$h:$m';
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 16,
                  color: Color(0xFF4F46E5),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ctrl.text,
                    style: GoogleFonts.plusJakartaSans(fontSize: 13),
                  ),
                ),
                const Icon(
                  Icons.edit_outlined,
                  size: 14,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final shiftCols = isDesktop ? 3 : (isTablet ? 2 : 1);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: isDesktop ? null : const AppDrawer(activeItem: 'Library Details'),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
            )
          : Row(
              children: [
                if (isDesktop) const AppDrawer(activeItem: 'Library Details'),
                Expanded(
                  child: Column(
                    children: [
                      // ── Gradient Header ──
                      SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: Card(
                            elevation: 4,
                            shadowColor: const Color(
                              0xFF4F46E5,
                            ).withValues(alpha: 0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF4F46E5),
                                    Color(0xFF2563EB),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  20,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.business_rounded,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Library Details',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                          Text(
                                            'Dashboard / Settings / Library Details',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              color: Colors.white.withValues(
                                                alpha: 0.75,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // ── Scrollable Content ──
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _buildBasicDetailsSection(),
                            const SizedBox(height: 16),
                            _buildFacilitiesSection(),
                            const SizedBox(height: 16),
                            _buildShiftsSection(shiftCols),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // ─── Section 1: Basic Details ─────────────────────────────────────────────

  Widget _buildBasicDetailsSection() {
    return _SectionCard(
      title: 'Library Basic Details',
      icon: Icons.info_outline_rounded,
      iconColor: const Color(0xFF4F46E5),
      iconBg: const Color(0xFFEEF2FF),
      trailing: _isEditingBasic ? null : _EditButton(onTap: _startEditBasic),
      child: _isEditingBasic ? _buildBasicEditForm() : _buildBasicViewMode(),
    );
  }

  Widget _buildBasicViewMode() {
    return Column(
      children: [
        _InfoRow(
          icon: Icons.business_outlined,
          label: 'Library Name',
          value: _nameCtrl.text,
        ),
        _InfoRow(
          icon: Icons.email_outlined,
          label: 'Email',
          value: _emailCtrl.text,
        ),
        _InfoRow(
          icon: Icons.phone_outlined,
          label: 'Contact Number',
          value: _contactCtrl.text,
        ),
        _InfoRow(
          icon: Icons.home_outlined,
          label: 'Address',
          value: _addressCtrl.text,
        ),
        _InfoRow(
          icon: Icons.location_on_outlined,
          label: 'Location',
          value: '${_cityCtrl.text}, ${_stateCtrl.text} - ${_pincodeCtrl.text}',
        ),
      ],
    );
  }

  Widget _buildBasicEditForm() {
    return Form(
      key: _basicFormKey,
      child: Column(
        children: [
          _FormField(
            label: 'Library Name',
            controller: _tNameCtrl,
            icon: Icons.business_outlined,
            validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          _FormField(
            label: 'Email',
            controller: _tEmailCtrl,
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v?.trim().isEmpty ?? true) return 'Required';
              if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w+$').hasMatch(v!.trim())) {
                return 'Invalid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          _FormField(
            label: 'Contact Number',
            controller: _tContactCtrl,
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            validator: (v) {
              if (v?.trim().isEmpty ?? true) return 'Required';
              if ((v?.trim().length ?? 0) != 10) return 'Must be 10 digits';
              return null;
            },
          ),
          const SizedBox(height: 12),
          _FormField(
            label: 'Address',
            controller: _tAddressCtrl,
            icon: Icons.home_outlined,
            validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _FormField(
                  label: 'City',
                  controller: _tCityCtrl,
                  icon: Icons.location_city_outlined,
                  validator: (v) =>
                      (v?.trim().isEmpty ?? true) ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FormField(
                  label: 'State',
                  controller: _tStateCtrl,
                  icon: Icons.map_outlined,
                  validator: (v) =>
                      (v?.trim().isEmpty ?? true) ? 'Required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _FormField(
            label: 'Pincode',
            controller: _tPincodeCtrl,
            icon: Icons.pin_drop_outlined,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            validator: (v) {
              if (v?.trim().isEmpty ?? true) return 'Required';
              if ((v?.trim().length ?? 0) != 6) return 'Must be 6 digits';
              return null;
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSavingBasic ? null : _cancelEditBasic,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSavingBasic ? null : _saveBasic,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isSavingBasic
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Save',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
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

  // ─── Section 2: Facilities ────────────────────────────────────────────────

  Widget _buildFacilitiesSection() {
    return _SectionCard(
      title: 'Library Facilities',
      icon: Icons.apartment_rounded,
      iconColor: const Color(0xFF059669),
      iconBg: const Color(0xFFECFDF5),
      trailing: _isEditingFacilities
          ? null
          : _EditButton(onTap: _startEditFacilities),
      child: _isEditingFacilities
          ? _buildFacilitiesEditMode()
          : _buildFacilitiesViewMode(),
    );
  }

  Widget _buildFacilitiesViewMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Policy & Buffer
        _SubSectionHeader(
          title: 'Policy & Buffer',
          icon: Icons.policy_outlined,
          color: const Color(0xFF4F46E5),
        ),
        const SizedBox(height: 8),
        _InfoRow(
          icon: Icons.hourglass_empty_rounded,
          label: 'Buffer Days',
          value: _bufferDays > 0 ? '$_bufferDays days' : 'Not set',
        ),
        const SizedBox(height: 16),
        // Facilities
        _SubSectionHeader(
          title: 'Available Facilities',
          icon: Icons.check_circle_outline_rounded,
          color: const Color(0xFF059669),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _selectedFacilities
              .map((f) => _FacilityChip(label: f))
              .toList(),
        ),
        const SizedBox(height: 16),
        // Floor Details
        _SubSectionHeader(
          title: 'Floor Details',
          icon: Icons.layers_outlined,
          color: const Color(0xFFF97316),
        ),
        const SizedBox(height: 10),
        ..._floors.map((f) => _FloorRow(floor: f)),
      ],
    );
  }

  Widget _buildFacilitiesEditMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Policy & Buffer
        _SubSectionHeader(
          title: 'Policy & Buffer',
          icon: Icons.policy_outlined,
          color: const Color(0xFF4F46E5),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Buffer Days (optional)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _bufferCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: GoogleFonts.plusJakartaSans(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'e.g. 2',
                      prefixIcon: const Icon(
                        Icons.hourglass_empty_rounded,
                        size: 16,
                        color: Color(0xFF4F46E5),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
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
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Number of days before subscription expires',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Facilities multi-select
        _SubSectionHeader(
          title: 'Select Facilities',
          icon: Icons.check_circle_outline_rounded,
          color: const Color(0xFF059669),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _allFacilities.map((f) {
            final selected = _selectedFacilities.contains(f);
            return GestureDetector(
              onTap: () => setState(() {
                if (selected) {
                  _selectedFacilities.remove(f);
                } else {
                  _selectedFacilities.add(f);
                }
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF059669)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF059669)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selected) ...[
                      const Icon(
                        Icons.check_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      f,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: selected
                            ? Colors.white
                            : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        // Floor Details Edit
        Row(
          children: [
            _SubSectionHeader(
              title: 'Floor Details',
              icon: Icons.layers_outlined,
              color: const Color(0xFFF97316),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(
                () => _tempFloors.add(FloorModel(name: 'New', capacity: 10)),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.add_rounded,
                      size: 14,
                      color: Color(0xFF4F46E5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Add Floor',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF4F46E5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...List.generate(_tempFloors.length, (i) {
          final floor = _tempFloors[i];
          final nameCtrl = TextEditingController(text: floor.name);
          final capCtrl = TextEditingController(
            text: floor.capacity.toString(),
          );
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: nameCtrl,
                    onChanged: (v) =>
                        _tempFloors[i] = _tempFloors[i].copyWith(name: v),
                    style: GoogleFonts.plusJakartaSans(fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Floor Name',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
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
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: capCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (v) => _tempFloors[i] = _tempFloors[i].copyWith(
                      capacity: int.tryParse(v) ?? 0,
                    ),
                    style: GoogleFonts.plusJakartaSans(fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Capacity',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
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
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _tempFloors.removeAt(i)),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSavingFacilities ? null : _cancelEditFacilities,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _isSavingFacilities ? null : _saveFacilities,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isSavingFacilities
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Save',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Section 3: Shifts ────────────────────────────────────────────────────

  Widget _buildShiftsSection(int cols) {
    return _SectionCard(
      title: 'Shift Details',
      icon: Icons.schedule_rounded,
      iconColor: const Color(0xFF8B5CF6),
      iconBg: const Color(0xFFEDE9FE),
      child: _shifts.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No shifts configured',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ),
            )
          : _buildShiftGrid(cols),
    );
  }

  Widget _buildShiftGrid(int cols) {
    final rows = <Widget>[];
    for (int i = 0; i < _shifts.length; i += cols) {
      final rowItems = _shifts.sublist(i, (i + cols).clamp(0, _shifts.length));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children:
                [
                    ...rowItems.asMap().entries.map((e) {
                      return Expanded(
                        child: _ShiftCard(
                          shift: e.value,
                          onToggle: () => _toggleShift(e.value),
                          onEdit: () => _editShift(e.value),
                          onDelete: () => _deleteShift(e.value),
                        ),
                      );
                    }),
                    if (rowItems.length < cols)
                      ...List.generate(
                        cols - rowItems.length,
                        (_) => const Expanded(child: SizedBox()),
                      ),
                  ].expand((w) sync* {
                    yield w;
                    if (w !=
                        (cols > 1 ? const Expanded(child: SizedBox()) : null)) {
                      yield const SizedBox(width: 12);
                    }
                  }).toList()
                  ..removeLast(),
          ),
        ),
      );
      if (i + cols < _shifts.length) rows.add(const SizedBox(height: 12));
    }
    return Column(children: rows);
  }
}

// ─── Shift Card ───────────────────────────────────────────────────────────────

class _ShiftCard extends StatelessWidget {
  final ShiftModel shift;
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
    final pct = shift.totalSeats > 0
        ? shift.occupiedSeats / shift.totalSeats
        : 0.0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: shift.enabled
              ? shift.color.withValues(alpha: 0.3)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: shift.enabled
                ? shift.color.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: shift.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(shift.icon, color: shift.color, size: 17),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  shift.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: onToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 40,
                  height: 22,
                  decoration: BoxDecoration(
                    color: shift.enabled
                        ? shift.color
                        : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 200),
                    alignment: shift.enabled
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: 18,
                      height: 18,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Time
          Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 13,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(width: 4),
              Text(
                '${shift.startTime} – ${shift.endTime}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Pricing
          Row(
            children: [
              _PriceTag(
                label: 'Fixed',
                value: '₹${shift.fixedPrice.toStringAsFixed(0)}',
                color: const Color(0xFF4F46E5),
              ),
              const SizedBox(width: 6),
              _PriceTag(
                label: 'Float',
                value: '₹${shift.floatingPrice.toStringAsFixed(0)}/day',
                color: const Color(0xFF059669),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Seat usage
          Row(
            children: [
              const Icon(
                Icons.event_seat_rounded,
                size: 13,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(width: 4),
              Text(
                '${shift.occupiedSeats} / ${shift.totalSeats} seats',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF475569),
                ),
              ),
              const Spacer(),
              Text(
                '${(pct * 100).toStringAsFixed(0)}%',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: shift.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(shift.color),
            ),
          ),
          const SizedBox(height: 10),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.edit_outlined,
                          size: 13,
                          color: Color(0xFF4F46E5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Edit',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF4F46E5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    size: 14,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Reusable Widgets ─────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final Widget? trailing;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                if (trailing != null) ...[const Spacer(), trailing!],
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.5, color: Color(0xFFE2E8F0)),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}

class _EditButton extends StatelessWidget {
  final VoidCallback onTap;
  const _EditButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFEEF2FF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFC7D2FE)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.edit_outlined, size: 13, color: Color(0xFF4F46E5)),
            const SizedBox(width: 5),
            Text(
              'Edit',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF4F46E5),
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
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: const Color(0xFF4F46E5)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? '—' : value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  const _FormField({
    required this.label,
    required this.controller,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.validator,
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
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          style: GoogleFonts.plusJakartaSans(fontSize: 13),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 16, color: const Color(0xFF4F46E5)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
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
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFFEF4444),
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _SubSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _SubSectionHeader({
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _FacilityChip extends StatelessWidget {
  final String label;
  const _FacilityChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF6EE7B7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 12,
            color: Color(0xFF059669),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF059669),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloorRow extends StatelessWidget {
  final FloorModel floor;
  const _FloorRow({required this.floor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFED7AA)),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFF97316),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  floor.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Floor ${floor.name}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F172A),
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.event_seat_rounded,
              size: 14,
              color: Color(0xFFF97316),
            ),
            const SizedBox(width: 4),
            Text(
              '${floor.capacity} seats',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceTag extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _PriceTag({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: $value',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

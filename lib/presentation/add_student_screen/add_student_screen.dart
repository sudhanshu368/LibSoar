import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../widgets/app_drawer.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/storage_helper.dart';
import '../../data/models/form_config_model.dart';
import '../../data/models/dropdown_models.dart';
import '../../core/services/auth_service.dart';

class AddStudentScreen extends StatefulWidget {
  final bool fromBottomNav;
  const AddStudentScreen({super.key, this.fromBottomNav = false});

  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Section expand states
  bool _personalExpanded = true;
  bool _subscriptionExpanded = true;
  bool _paymentExpanded = true;
  bool _academicExpanded = true;
  bool _documentsExpanded = true;

  List<FormFieldConfig> _formFields = [];
  bool _isLoadingConfig = true;

  List<ApiBranchModel> _apiBranches = [];
  bool _isLoadingBranches = false;

  List<ApiShiftModel> _apiShifts = [];
  bool _isLoadingShifts = false;

  List<ApiSeatModel> _apiSeats = [];
  bool _isLoadingSeats = false;

  String? _selectedBranchId;
  String? _selectedShiftId;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchFormConfig();
    _fetchBranches();
  }

  Future<void> _refreshData() async {
    setState(() => _isLoadingConfig = true);
    await Future.wait([
      _fetchFormConfig(),
      _fetchBranches(),
    ]);
  }

  Future<void> _fetchBranches() async {
    setState(() => _isLoadingBranches = true);
    try {
      final token = await StorageHelper.getToken();
      if (token == null) return;
      final response = await ApiService.get('/branches', token);
      if (response['success'] == true && mounted) {
        final List data = response['data'] ?? [];
        setState(() {
          _apiBranches = data.map((e) => ApiBranchModel.fromJson(e)).toList();
          _isLoadingBranches = false;
          if (_apiBranches.isNotEmpty) {
            final defaultBranch = _apiBranches.firstWhere((b) => b.isDefault, orElse: () => _apiBranches.first);
            _selectedBranchId = defaultBranch.id;
            _fetchShifts(defaultBranch.id);
          }
        });
      } else {
        if (mounted) setState(() => _isLoadingBranches = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingBranches = false);
    }
  }

  Future<void> _fetchShifts(String branchId) async {
    setState(() => _isLoadingShifts = true);
    try {
      final token = await StorageHelper.getToken();
      if (token == null) return;
      final response = await ApiService.get('/shifts', token, queryParams: {'branchId': branchId});
      if (response['success'] == true && mounted) {
        final List data = response['data'] ?? [];
        setState(() {
          _apiShifts = data.map((e) => ApiShiftModel.fromJson(e)).toList();
          _isLoadingShifts = false;
          _selectedShiftId = null; // reset shift selection
        });
        _calculateFee();
      } else {
        if (mounted) setState(() => _isLoadingShifts = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingShifts = false);
    }
  }

  void _calculateFee() {
    if (_selectedShiftId == null) {
      _totalFeeController.clear();
      return;
    }
    try {
      final shift = _apiShifts.firstWhere((s) => s.id == _selectedShiftId);
      int fee = _selectedSeatType == 'Fixed Seat' ? shift.fee : shift.floatingPrice;
      _totalFeeController.text = fee.toString();
    } catch (e) {
      _totalFeeController.clear();
    }
  }

  Future<void> _fetchSeats() async {
    if (_selectedBranchId == null || _selectedShiftId == null) {
      setState(() => _apiSeats = []);
      return;
    }

    setState(() => _isLoadingSeats = true);
    try {
      final token = await StorageHelper.getToken();
      if (token == null) return;
      
      final startDate = _startDate ?? DateTime.now();
      final startDateStr = "${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}";
      
      final endDate = _endDate ?? _startDate?.add(const Duration(days: 30)) ?? DateTime.now().add(const Duration(days: 30));
      final endDateStr = "${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}";
      
      final url = '/seats?branchId=$_selectedBranchId&shiftId=$_selectedShiftId&startDate=$startDateStr&endDate=$endDateStr';
      final response = await ApiService.get(url, token);

      if (mounted && response['success'] == true) {
        final List<ApiSeatModel> availableSeats = [];
        final data = response['data'] as List?;
        
        if (data != null) {
          for (final item in data) {
            if (item['status'] == 'AVAILABLE') {
               availableSeats.add(ApiSeatModel.fromJson(item));
            }
          }
        }
        
        setState(() {
          _apiSeats = availableSeats;
          _isLoadingSeats = false;
          if (_selectedSeatNumber != null && !availableSeats.any((s) => s.id == _selectedSeatNumber)) {
            _selectedSeatNumber = null;
          }
        });
      } else {
        if (mounted) setState(() => _isLoadingSeats = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingSeats = false);
    }
  }

  Future<void> _fetchFormConfig() async {
    try {
      final token = await StorageHelper.getToken();
      if (token == null) throw Exception("No token found");

      final response = await ApiService.get('/settings/form-config', token);
      if (response['success'] == true) {
        final List fieldsList = response['data']['fields'] ?? [];
        if (mounted) {
          setState(() {
            _formFields = fieldsList.map((f) => FormFieldConfig.fromJson(f)).toList();
            _isLoadingConfig = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingConfig = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingConfig = false;
        });
      }
    }
  }

  FormFieldConfig? _getFieldConfig(String key) {
    try {
      return _formFields.firstWhere((f) => f.key == key);
    } catch (e) {
      return null;
    }
  }

  bool _isFieldEnabled(String key) {
    if (_formFields.isEmpty) return true;
    return _getFieldConfig(key)?.enabled ?? true;
  }

  bool _isFieldRequired(String key) {
    if (_formFields.isEmpty) return false;
    return _getFieldConfig(key)?.required ?? false;
  }

  Widget _buildOptionalField(String key, Widget child, {double bottomPadding = 14}) {
    if (!_isFieldEnabled(key)) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: child,
    );
  }

  // Personal Info
final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  bool _sameAsPhone = false;
  String _selectedGender = 'Male';
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  DateTime? _dateOfBirth;
  final _fatherNameController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _aadhaarNumberController = TextEditingController();
  final _remarksController = TextEditingController();
  String? _aadhaarDocumentPath;

  // Subscription
  DateTime? _startDate;
  DateTime? _endDate;
String _selectedSeatType = 'Fixed Seat';
  String? _selectedSeatNumber;

  // Payment
  final _totalFeeController = TextEditingController();
  final _feeDueController = TextEditingController();
  String? _selectedPaymentMode;

  // Academic
  final _qualificationController = TextEditingController();
  final _goalController = TextEditingController();

  // Document
  String? _profileImagePath;


  final List<String> _paymentModes = [
    'Cash',
    'UPI',
    'Card',
    'Net Banking',
  ];

  static const Map<String, String> _paymentModeApiValues = {
    'Cash': 'cash',
    'UPI': 'upi',
    'Card': 'card',
    'Net Banking': 'bank',
  };

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _totalFeeController.dispose();
    _feeDueController.dispose();
    _qualificationController.dispose();
    _goalController.dispose();
    _fatherNameController.dispose();
    _emergencyContactController.dispose();
    _aadhaarNumberController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart 
          ? (_startDate ?? DateTime.now()) 
          : (_endDate ?? (_startDate?.add(const Duration(days: 30)) ?? DateTime.now())),
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
          _endDate ??= _startDate!.add(const Duration(days: 30));
        } else {
          _endDate = picked;
        }
      });
      _fetchSeats();
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _profileImagePath = pickedFile.name;
        });
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  Future<void> _pickAadhaarDocument() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'png', 'pdf'],
      );

      if (result != null) {
        setState(() {
          _aadhaarDocumentPath = result.files.single.name;
        });
      }
    } catch (e) {
      _showError('Failed to pick document: $e');
    }
  }

  Future<void> _pickDateOfBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF4F46E5)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Select Date';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  /// Normalizes a phone number to E.164 format: +91XXXXXXXXXX
  /// Returns null if the input is empty.
  String? _normalizePhone(String raw) {
    String p = raw.trim().replaceAll(' ', '');
    if (p.isEmpty) return null;
    if (p.startsWith('+91')) {
      p = p.substring(3);
    } else if (p.startsWith('91') && p.length > 10) {
      p = p.substring(2);
    }
    return '+91$p';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.plusJakartaSans(color: Colors.white),
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!(_formKey.currentState?.validate() ?? true)) return;

    // Essential fields that the backend MUST have to create a student and subscription.
    if (_selectedBranchId == null || _selectedShiftId == null || _startDate == null || _endDate == null) {
      _showError('Please select Branch, Shift, and Dates');
      return;
    }

    if (_selectedSeatType == 'Fixed Seat' && _selectedSeatNumber == null) {
      _showError('Please select a seat number');
      return;
    }

    if (_selectedPaymentMode == null) {
      _showError('Please select a payment mode');
      return;
    }

    setState(() => _isSubmitting = true);

      try {
        await AuthService.refreshToken();
        final token = await StorageHelper.getToken();
        if (token == null) throw Exception("Authentication needed");

        // Fetch libraryId saved at login
        String? libraryId = await StorageHelper.getLibraryId();

        // Fallback: fetch from profile if not cached
        if (libraryId == null || libraryId.isEmpty) {
          final profile = await AuthService.getProfile();
          libraryId = profile?.library?.id;
          if (libraryId != null && libraryId.isNotEmpty) {
            await StorageHelper.saveLibraryId(libraryId);
          }
        }

        if (libraryId == null || libraryId.isEmpty) {
          throw Exception('Library ID not found. Please re-login.');
        }

        final int totalFee = (double.tryParse(_totalFeeController.text) ?? 0).toInt();
        final int feeDue = (double.tryParse(_feeDueController.text) ?? 0).toInt();

        if (totalFee <= 0) {
          _showError('Total fee must be greater than zero');
          setState(() => _isSubmitting = false);
          return;
        }

        // Normalize phone — use phone as fallback for whatsapp if empty
        final String? phoneNorm = _normalizePhone(_phoneController.text);
        final String? whatsappNorm = _normalizePhone(
          _whatsappController.text.trim().isEmpty
              ? _phoneController.text
              : _whatsappController.text,
        );

        final Map<String, dynamic> body = {
          "branchId": _selectedBranchId,
          "name": _nameController.text.trim(),
          "phone": phoneNorm,
          "whatsappNumber": whatsappNorm,
          "email": _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
          "gender": _selectedGender.toLowerCase(),
          "address": _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
          "fatherName": _fatherNameController.text.trim().isEmpty ? null : _fatherNameController.text.trim(),
          "emergencyContact": _emergencyContactController.text.trim().isEmpty
              ? null
              : _normalizePhone(_emergencyContactController.text),
          "aadharNumber": _aadhaarNumberController.text.trim().isEmpty ? null : _aadhaarNumberController.text.trim(),
          "qualification": _qualificationController.text.trim().isEmpty ? null : _qualificationController.text.trim(),
          "goal": _goalController.text.trim().isEmpty ? null : _goalController.text.trim(),
          "remarks": _remarksController.text.trim().isEmpty ? null : _remarksController.text.trim(),
          "dob": _dateOfBirth?.toUtc().toIso8601String(),
          "status": "ACTIVE",
          "seatType": _selectedSeatType == 'Fixed Seat' ? 'FIXED' : 'FLOATING',
          "seatNumber": _selectedSeatNumber,
          "subscriptionStartDate": _startDate?.toUtc().toIso8601String(),
          "subscriptionEndDate": _endDate?.toUtc().toIso8601String(),
          "shift": _selectedShiftId,
          "totalFee": totalFee,
          "feeDue": feeDue,
          "paymentMode": _paymentModeApiValues[_selectedPaymentMode] ?? 'cash',
        };

        // Strip null values — Zod .optional() expects field absent (undefined), not null
        body.removeWhere((_, v) => v == null);

        debugPrint("DEBUG PAYLOAD: $body");

        final response = await ApiService.post('/students', body, token: token);
        if (!mounted) return;

        if (response['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Student added successfully!',
                style: GoogleFonts.plusJakartaSans(color: Colors.white),
              ),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          if (mounted) {
            if (widget.fromBottomNav) {
              _formKey.currentState?.reset();
              _nameController.clear();
              _phoneController.clear();
              _whatsappController.clear();
              _emailController.clear();
              _addressController.clear();
              _fatherNameController.clear();
              _emergencyContactController.clear();
              _aadhaarNumberController.clear();
              _remarksController.clear();
              _totalFeeController.clear();
              _feeDueController.clear();
              _qualificationController.clear();
              _goalController.clear();
              setState(() {
                _sameAsPhone = false;
                _selectedGender = 'Male';
                _dateOfBirth = null;
                _aadhaarDocumentPath = null;
                _startDate = null;
                _endDate = null;
                _selectedSeatType = 'Fixed Seat';
                _selectedSeatNumber = null;
                _selectedPaymentMode = null;
                _profileImagePath = null;
              });
              _fetchSeats();
            } else {
              Navigator.pop(context, true);
            }
          }
        } else {
          _showError(response['message'] ?? 'Failed to add student');
        }
      } catch (e) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        _showError(msg);
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: widget.fromBottomNav ? null : const AppDrawer(activeItem: 'Add Student'),
      appBar: widget.fromBottomNav ? null : AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Color(0xFF0F172A)),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(
          'Add Student',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFF1F5F9)),
        ),
      ),
      body: _isLoadingConfig
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
          : Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFF4F46E5),
                onRefresh: _refreshData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGradientHeader(),
                    const SizedBox(height: 16),
                    _buildInfoBanner(),
                    const SizedBox(height: 16),
                    _buildPersonalInfoSection(),
                    const SizedBox(height: 12),
                    _buildSubscriptionSection(),
                    const SizedBox(height: 12),
                    _buildPaymentSection(),
                    const SizedBox(height: 12),
                    _buildAcademicSection(),
                    const SizedBox(height: 12),
                    _buildDocumentsSection(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
          _buildBottomActions(),
        ],
        ),
      ),
    );
  }

  Widget _buildGradientHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
              Icons.person_add_rounded,
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
                  'Add New Student',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dashboard / Students / Add Student',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withAlpha(204),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        border: Border.all(color: const Color(0xFFFCD34D), width: 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFFD97706),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "You're using the default form fields. To customise which fields appear and which are required, configure your student form settings.",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required bool isExpanded,
    required VoidCallback onToggle,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: isExpanded ? 0 : -0.25,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF64748B),
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            Container(height: 1, color: const Color(0xFFF1F5F9)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    return _buildSectionCard(
      title: 'PERSONAL INFORMATION',
      isExpanded: _personalExpanded,
      onToggle: () => setState(() => _personalExpanded = !_personalExpanded),
      children: [
        if (_isLoadingBranches)
          const Padding(padding: EdgeInsets.only(bottom: 14), child: CircularProgressIndicator())
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel('Branch'),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedBranchId,
                hint: Text('Select Branch', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF94A3B8))),
                items: _apiBranches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF0F172A))))).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedBranchId = val;
                      _apiSeats = [];
                      _selectedSeatNumber = null;
                    });
                    _fetchShifts(val);
                  }
                },
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF94A3B8)),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
                ),
              ),
            ],
          ),
        const SizedBox(height: 14),
        _buildOptionalField('name', _buildTextField(
          label: _getFieldConfig('name')?.label ?? 'Name',
          hint: 'Enter full name',
          controller: _nameController,
          isRequired: _isFieldRequired('name'),
          validator: (v) =>
              (_isFieldRequired('name') && (v == null || v.isEmpty)) ? 'Name is required' : null,
        )),
        _buildOptionalField('dob', _buildDateField(
          label: _getFieldConfig('dob')?.label ?? 'Date of Birth',
          value: _formatDate(_dateOfBirth),
          onTap: _pickDateOfBirth,
        )),
        _buildOptionalField('fatherName', _buildTextField(
          label: _getFieldConfig('fatherName')?.label ?? "Father's Name",
          hint: "Enter father's name",
          controller: _fatherNameController,
          isRequired: _isFieldRequired('fatherName'),
          validator: (v) =>
              (_isFieldRequired('fatherName') && (v == null || v.isEmpty)) ? "Father's name is required" : null,
        )),
        _buildOptionalField('phone', _buildTextField(
          label: _getFieldConfig('phone')?.label ?? 'Phone Number',
          hint: 'Enter phone number',
          controller: _phoneController,
          isRequired: _isFieldRequired('phone'),
          keyboardType: TextInputType.phone,
          validator: (v) =>
              (_isFieldRequired('phone') && (v == null || v.isEmpty)) ? 'Phone number is required' : null,
          onChanged: (v) {
            if (_sameAsPhone) {
              setState(() => _whatsappController.text = v);
            }
          },
        )),
        _buildOptionalField('emergencyContact', _buildTextField(
          label: _getFieldConfig('emergencyContact')?.label ?? 'Emergency Contact',
          hint: 'Enter emergency contact number',
          controller: _emergencyContactController,
          isRequired: _isFieldRequired('emergencyContact'),
          keyboardType: TextInputType.phone,
          validator: (v) =>
              (_isFieldRequired('emergencyContact') && (v == null || v.isEmpty)) ? 'Emergency contact is required' : null,
        )),
        _buildOptionalField('whatsappNumber', Column(
          children: [
            _buildTextField(
              label: _getFieldConfig('whatsappNumber')?.label ?? 'WhatsApp Number',
              hint: 'Enter WhatsApp number',
              controller: _whatsappController,
              isRequired: _isFieldRequired('whatsappNumber'),
              keyboardType: TextInputType.phone,
              validator: (v) =>
                  (_isFieldRequired('whatsappNumber') && (v == null || v.isEmpty)) ? 'WhatsApp number is required' : null,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: _sameAsPhone,
                    onChanged: (v) {
                      setState(() {
                        _sameAsPhone = v ?? false;
                        if (_sameAsPhone) {
                          _whatsappController.text = _phoneController.text;
                        }
                      });
                    },
                    activeColor: const Color(0xFF4F46E5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Same as Phone Number',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ],
        )),
        _buildOptionalField('gender', Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel(_getFieldConfig('gender')?.label ?? 'Gender', isRequired: _isFieldRequired('gender')),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: _selectedGender,
              onChanged: (v) {
                if (v != null) {
                  setState(() => _selectedGender = v);
                }
              },
              child: Row(
                children: ['Male', 'Female', 'Others']
                    .map(
                      (g) => Padding(
                        padding: const EdgeInsets.only(right: 20),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: Radio<String>(
                                value: g,
                                activeColor: const Color(0xFF4F46E5),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              g,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        )),
        _buildOptionalField('email', _buildTextField(
          label: _getFieldConfig('email')?.label ?? 'Email',
          hint: 'Enter email address',
          controller: _emailController,
          isRequired: _isFieldRequired('email'),
          keyboardType: TextInputType.emailAddress,
          validator: (v) =>
              (_isFieldRequired('email') && (v == null || v.isEmpty)) ? 'Email is required' : null,
        )),
        _buildOptionalField('address', _buildTextField(
          label: _getFieldConfig('address')?.label ?? 'Address',
          hint: 'Enter full address',
          controller: _addressController,
          isRequired: _isFieldRequired('address'),
          maxLines: 3,
          validator: (v) =>
              (_isFieldRequired('address') && (v == null || v.isEmpty)) ? 'Address is required' : null,
        )),
        _buildOptionalField('aadharNumber', _buildTextField(
          label: _getFieldConfig('aadharNumber')?.label ?? 'Aadhaar Number',
          hint: 'Enter 12-digit Aadhaar number',
          controller: _aadhaarNumberController,
          isRequired: _isFieldRequired('aadharNumber'),
          keyboardType: TextInputType.number,
          validator: (v) =>
              (_isFieldRequired('aadharNumber') && (v == null || v.isEmpty)) ? 'Aadhaar Number is required' : null,
        )),
        _buildOptionalField('remarks', _buildTextField(
          label: _getFieldConfig('remarks')?.label ?? 'Remarks',
          hint: 'Enter any remarks or notes',
          controller: _remarksController,
          isRequired: _isFieldRequired('remarks'),
          maxLines: 3,
          validator: (v) =>
              (_isFieldRequired('remarks') && (v == null || v.isEmpty)) ? 'Remarks are required' : null,
        )),
      ],
    );
  }

  Widget _buildSubscriptionSection() {
    return _buildSectionCard(
      title: 'SUBSCRIPTION DETAILS',
      isExpanded: _subscriptionExpanded,
      onToggle: () =>
          setState(() => _subscriptionExpanded = !_subscriptionExpanded),
      children: [
        Row(
          children: [
            Expanded(
              child: _buildDateField(
                label: 'Start Date',
                value: _formatDate(_startDate),
                onTap: () => _pickDate(true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDateField(
                label: 'End Date',
                value: _formatDate(_endDate),
                onTap: () => _pickDate(false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_isLoadingShifts)
          const Padding(padding: EdgeInsets.only(bottom: 14), child: CircularProgressIndicator())
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel('Shift'),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedShiftId,
                hint: Text('Select Shift', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF94A3B8))),
                items: _apiShifts.map((s) => DropdownMenuItem(value: s.id, child: Text("${s.name} (${s.timing})", style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF0F172A))))).toList(),
                onChanged: (val) {
                  setState(() => _selectedShiftId = val);
                  _calculateFee();
                  if (val != null) _fetchSeats();
                },
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF94A3B8)),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
                ),
              ),
            ],
          ),
        const SizedBox(height: 14),
        _buildLabel('Seat Type'),
        const SizedBox(height: 8),
        RadioGroup<String>(
          groupValue: _selectedSeatType,
          onChanged: (v) {
            if (v != null) {
              setState(() => _selectedSeatType = v);
              _calculateFee();
            }
          },
          child: Row(
            children: ['Fixed Seat', 'Floating Seat']
                .map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(right: 24),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Radio<String>(
                            value: s,
                            activeColor: const Color(0xFF4F46E5),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          s,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 14),
        if (_isLoadingSeats)
          const Padding(padding: EdgeInsets.only(bottom: 14), child: CircularProgressIndicator())
        else if (_selectedShiftId == null)
          const Padding(padding: EdgeInsets.only(bottom: 14), child: Text("Please select a branch and shift to view available seats.", style: TextStyle(color: Colors.grey, fontSize: 13)))
        else if (_apiSeats.isEmpty)
          const Padding(padding: EdgeInsets.only(bottom: 14), child: Text("No available seats for this shift", style: TextStyle(color: Colors.red, fontSize: 13)))
        else
          Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               _buildLabel('Seat Number'),
               const SizedBox(height: 6),
               DropdownButtonFormField<String>(
                 initialValue: _selectedSeatNumber,
                 hint: Text('Select Seat Number', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF94A3B8))),
                 items: _apiSeats.map((s) => DropdownMenuItem(value: s.id, child: Text(s.seatNumber, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF0F172A))))).toList(),
                 onChanged: (val) => setState(() => _selectedSeatNumber = val),
                 icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF94A3B8)),
                 decoration: InputDecoration(
                   filled: true,
                   fillColor: const Color(0xFFF8FAFC),
                   contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                   enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                   focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
                 ),
               ),
             ]
          ),
      ],
    );
  }

  Widget _buildPaymentSection() {
    return _buildSectionCard(
      title: 'PAYMENT DETAILS',
      isExpanded: _paymentExpanded,
      onToggle: () => setState(() => _paymentExpanded = !_paymentExpanded),
      children: [
        _buildTextField(
          label: 'Total Fee',
          hint: 'Enter total fee amount',
          controller: _totalFeeController,
          keyboardType: TextInputType.number,
          prefixText: '₹',
        ),
        const SizedBox(height: 14),
        _buildTextField(
          label: 'Fee Due',
          hint: 'Enter fee due amount',
          controller: _feeDueController,
          keyboardType: TextInputType.number,
          prefixText: '₹',
        ),
        const SizedBox(height: 14),
        _buildDropdownField(
          label: 'Payment Mode',
          hint: 'Select Payment Mode',
          value: _selectedPaymentMode,
          items: _paymentModes,
          onChanged: (v) => setState(() => _selectedPaymentMode = v),
        ),
      ],
    );
  }

  Widget _buildAcademicSection() {
    if (!_isFieldEnabled('qualification') && !_isFieldEnabled('goal')) {
      return const SizedBox.shrink();
    }
    return _buildSectionCard(
      title: 'ACADEMIC DETAILS',
      isExpanded: _academicExpanded,
      onToggle: () => setState(() => _academicExpanded = !_academicExpanded),
      children: [
        _buildOptionalField('qualification', _buildTextField(
          label: _getFieldConfig('qualification')?.label ?? 'Qualification',
          hint: 'e.g. B.Tech, MBA, 12th Grade',
          controller: _qualificationController,
          isRequired: _isFieldRequired('qualification'),
          validator: (v) =>
              (_isFieldRequired('qualification') && (v == null || v.isEmpty)) ? 'Qualification is required' : null,
        )),
        _buildOptionalField('goal', _buildTextField(
          label: _getFieldConfig('goal')?.label ?? 'Goal',
          hint: 'e.g. UPSC, JEE, NEET, CA',
          controller: _goalController,
          isRequired: _isFieldRequired('goal'),
          validator: (v) =>
              (_isFieldRequired('goal') && (v == null || v.isEmpty)) ? 'Goal is required' : null,
        )),
      ],
    );
  }

  Widget _buildDocumentsSection() {
    if (!_isFieldEnabled('profilePicture') && !_isFieldEnabled('aadharDocument')) {
      return const SizedBox.shrink();
    }
    return _buildSectionCard(
      title: 'DOCUMENTS',
      isExpanded: _documentsExpanded,
      onToggle: () => setState(() => _documentsExpanded = !_documentsExpanded),
      children: [
        _buildOptionalField('profilePicture', Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel(_getFieldConfig('profilePicture')?.label ?? 'Profile Picture', isRequired: _isFieldRequired('profilePicture')),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _pickProfileImage,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  border: Border.all(
                    color: const Color(0xFF4F46E5).withAlpha(102),
                    width: 1.5,
                    style: BorderStyle.solid,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withAlpha(26),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.cloud_upload_outlined,
                        color: Color(0xFF4F46E5),
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Drag & drop or click to upload',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF4F46E5),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Supports JPG, PNG (max 5MB)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_profileImagePath != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF10B981),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _profileImagePath!,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF475569),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        )),
        _buildOptionalField('aadharDocument', Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel(_getFieldConfig('aadharDocument')?.label ?? 'Aadhaar Document', isRequired: _isFieldRequired('aadharDocument')),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _pickAadhaarDocument,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  border: Border.all(
                    color: const Color(0xFF4F46E5).withAlpha(102),
                    width: 1.5,
                    style: BorderStyle.solid,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withAlpha(26),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.upload_file_outlined,
                        color: Color(0xFF4F46E5),
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Upload Aadhaar Document',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF4F46E5),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Supports JPG, PNG, PDF (max 5MB)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_aadhaarDocumentPath != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF10B981),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _aadhaarDocumentPath!,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF475569),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        )),
      ],
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: const Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Cancel',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF475569),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF2563EB)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  disabledForegroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.person_add_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Add Student',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
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
    );
  }

  Widget _buildLabel(String label, {bool isRequired = false}) {
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF374151),
          ),
        ),
        if (isRequired) ...[
          const SizedBox(width: 3),
          const Text(
            '*',
            style: TextStyle(color: Color(0xFFEF4444), fontSize: 13),
          ),
        ],
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    bool isRequired = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? prefixText,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label, isRequired: isRequired),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          onChanged: onChanged,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefixText,
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
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String hint,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          hint: Text(
            hint,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: const Color(0xFF94A3B8),
            ),
          ),
          items: items
              .map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Text(
                    item,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF94A3B8),
          ),
          decoration: InputDecoration(
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

  Widget _buildDateField({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: value == 'Select Date'
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                const Icon(
                  Icons.calendar_today_rounded,
                  color: Color(0xFF94A3B8),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

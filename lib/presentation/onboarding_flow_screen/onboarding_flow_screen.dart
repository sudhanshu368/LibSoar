import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../routes/app_routes.dart';
import '../../core/services/auth_service.dart';

// ─── Data Models ────────────────────────────────────────────────────────────

class FloorDetail {
  String name;
  String capacity;
  FloorDetail({this.name = '', this.capacity = ''});
}

class ShiftData {
  final String label;
  final IconData icon;
  bool enabled;
  TimeOfDay startTime;
  TimeOfDay endTime;
  String fee;

  ShiftData({
    required this.label,
    required this.icon,
    this.enabled = false,
    required this.startTime,
    required this.endTime,
    this.fee = '',
  });
}

// ─── Main Screen ─────────────────────────────────────────────────────────────

class OnboardingFlowScreen extends StatefulWidget {
  const OnboardingFlowScreen({super.key});

  @override
  State<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends State<OnboardingFlowScreen> {
  int _currentStep = 0;
  bool _isLoading = false;
  final PageController _pageController = PageController();

  // Step 1 – Personal Details
  final _step1Key = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  bool _sameAsMobile = false;

  // Step 2 – Library Info
  final _step2Key = GlobalKey<FormState>();
  int _libraryTypeIndex = 0;
  final _libNameCtrl = TextEditingController();
  final _libEmailCtrl = TextEditingController();
  final _libContactCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _landmarkCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  String? _selectedState;

  // Step 3 – Facilities
  final Set<String> _selectedAmenities = {};
  final List<FloorDetail> _floors = [FloorDetail()];
  final _customAmenityCtrl = TextEditingController();
  final _bufferDaysCtrl = TextEditingController();

  // Step 4 – Shifts
  final List<ShiftData> _shifts = [
    ShiftData(
      label: 'Morning',
      icon: Icons.wb_sunny_outlined,
      enabled: false,
      startTime: const TimeOfDay(hour: 6, minute: 0),
      endTime: const TimeOfDay(hour: 12, minute: 0),
    ),
    ShiftData(
      label: 'Afternoon',
      icon: Icons.wb_cloudy_outlined,
      enabled: false,
      startTime: const TimeOfDay(hour: 12, minute: 0),
      endTime: const TimeOfDay(hour: 17, minute: 0),
    ),
    ShiftData(
      label: 'Evening',
      icon: Icons.nights_stay_outlined,
      enabled: false,
      startTime: const TimeOfDay(hour: 17, minute: 0),
      endTime: const TimeOfDay(hour: 21, minute: 0),
    ),
    ShiftData(
      label: 'Night',
      icon: Icons.dark_mode_outlined,
      enabled: false,
      startTime: const TimeOfDay(hour: 21, minute: 0),
      endTime: const TimeOfDay(hour: 6, minute: 0),
    ),
    ShiftData(
      label: 'Full Day',
      icon: Icons.light_mode_outlined,
      enabled: false,
      startTime: const TimeOfDay(hour: 6, minute: 0),
      endTime: const TimeOfDay(hour: 22, minute: 0),
    ),
    ShiftData(
      label: '24 Hours',
      icon: Icons.access_time_filled_rounded,
      enabled: false,
      startTime: const TimeOfDay(hour: 0, minute: 0),
      endTime: const TimeOfDay(hour: 0, minute: 0),
    ),
  ];

  static const List<String> _states = [
    'Andhra Pradesh',
    'Arunachal Pradesh',
    'Assam',
    'Bihar',
    'Chhattisgarh',
    'Goa',
    'Gujarat',
    'Haryana',
    'Himachal Pradesh',
    'Jharkhand',
    'Karnataka',
    'Kerala',
    'Madhya Pradesh',
    'Maharashtra',
    'Manipur',
    'Meghalaya',
    'Mizoram',
    'Nagaland',
    'Odisha',
    'Punjab',
    'Rajasthan',
    'Sikkim',
    'Tamil Nadu',
    'Telangana',
    'Tripura',
    'Uttar Pradesh',
    'Uttarakhand',
    'West Bengal',
    'Delhi',
    'Jammu & Kashmir',
    'Ladakh',
  ];

  static const List<String> _libraryTypes = [
    'Individual Owner',
    'Organization',
    'College',
    'Public Library',
  ];

  static const List<String> _defaultAmenities = [
    'WiFi',
    'AC',
    'CCTV',
    'Water Cooler',
    'Cafeteria',
    'Locker',
    'Power Backup',
  ];

  static const List<String> _stepLabels = [
    'Personal Details',
    'Library Info',
    'Facilities',
    'Shifts & Timings',
    'Review & Launch',
  ];

  static const List<IconData> _stepIcons = [
    Icons.person_outline_rounded,
    Icons.business_outlined,
    Icons.apartment_outlined,
    Icons.schedule_outlined,
    Icons.rocket_launch_outlined,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  Future<void> _initializeData() async {
    // 1. Check for arguments (usually from signup or profile)
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is String && args.isNotEmpty) {
      final cleanPhone = args.replaceAll('+91', '').trim();
      _mobileCtrl.text = cleanPhone;
      if (_sameAsMobile) _whatsappCtrl.text = cleanPhone;
    }

    // 2. Fetch full profile to fill other fields if possible
    try {
      final user = await AuthService.getProfile();
      if (user != null) {
        setState(() {
          if (_fullNameCtrl.text.isEmpty) _fullNameCtrl.text = user.name ?? '';
          if (_emailCtrl.text.isEmpty) _emailCtrl.text = user.email ?? '';
          if (_mobileCtrl.text.isEmpty) {
             final p = (user.phone ?? '').replaceAll('+91', '').trim();
             _mobileCtrl.text = p;
             if (_sameAsMobile) _whatsappCtrl.text = p;
          }
        });
      }
    } catch (e) {
      debugPrint("Pre-fill fetch failed: $e");
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _mobileCtrl.dispose();
    _whatsappCtrl.dispose();
    _libNameCtrl.dispose();
    _libEmailCtrl.dispose();
    _libContactCtrl.dispose();
    _addressCtrl.dispose();
    _landmarkCtrl.dispose();
    _pincodeCtrl.dispose();
    _cityCtrl.dispose();
    _customAmenityCtrl.dispose();
    _bufferDaysCtrl.dispose();
    super.dispose();
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _step1Key.currentState?.validate() ?? false;
      case 1:
        return _step2Key.currentState?.validate() ?? false;
      case 2:
        if (_floors.isEmpty) return false;
        for (final f in _floors) {
          if (f.name.trim().isEmpty || f.capacity.trim().isEmpty) return false;
          final cap = int.tryParse(f.capacity);
          if (cap == null || cap <= 0) return false;
        }
        return true;
      case 3:
        return _shifts.any((s) => s.enabled);
      default:
        return true;
    }
  }

  void _goNext() {
    if (!_validateCurrentStep()) {
      _showValidationError();
      return;
    }
    if (_currentStep < 4) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _submitOnboarding();
    }
  }

  void _submitOnboarding() async {
    setState(() => _isLoading = true);
    try {
      final payload = {
        "user": {
          "fullName": _fullNameCtrl.text.trim(),
          "email": _emailCtrl.text.trim(),
          "mobile": _mobileCtrl.text.trim(),
          "whatsapp": _whatsappCtrl.text.trim(),
        },
        // Flattened and remapped library fields
        "libraryName": _libNameCtrl.text.trim(),
        "libraryType": {
          'Individual Owner': 'individual',
          'Organization': 'organization',
          'College': 'university',
          'Public Library': 'public',
        }[_libraryTypes[_libraryTypeIndex]] ?? 'individual',
        "libraryEmail": _libEmailCtrl.text.trim(),
        "libraryContact": _libContactCtrl.text.trim(),
        "address": _addressCtrl.text.trim(),
        "landmark": _landmarkCtrl.text.trim(),
        "pincode": _pincodeCtrl.text.trim(),
        "city": _cityCtrl.text.trim(),
        "state": _selectedState ?? "",
        "bufferDays": _bufferDaysCtrl.text.trim(),
        
        "facilities": _selectedAmenities.toList(),
        "floors": _floors.map((f) => {
          "id": f.name.trim(), // Added 'id' back as required by backend
          "name": f.name.trim(),
          "seats": f.capacity.trim(),
        }).toList(),
        "shifts": _shifts.where((s) => s.enabled).map((s) => {
          "name": s.label,
          "startTime": "${s.startTime.hour.toString().padLeft(2, '0')}:${s.startTime.minute.toString().padLeft(2, '0')}",
          "endTime": "${s.endTime.hour.toString().padLeft(2, '0')}:${s.endTime.minute.toString().padLeft(2, '0')}",
          "fee": s.fee.trim(), // Server expects string
          "enabled": true,
        }).toList(),
      };

      await AuthService.completeOnboarding(payload);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.homeScreen);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll("Exception: ", "")),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goBack() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showValidationError() {
    String msg;
    switch (_currentStep) {
      case 0:
        msg = 'Please fill all required fields correctly.';
        break;
      case 1:
        msg = 'Please complete all required library information.';
        break;
      case 2:
        msg = 'Add at least one floor with valid name and capacity > 0.';
        break;
      case 3:
        msg = 'Please enable at least one shift.';
        break;
      default:
        msg = 'Please complete all required fields.';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.white),
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: isWide ? _buildWideLayout() : _buildNarrowLayout(),
    );
  }

  // ─── Wide Layout (Sidebar + Content) ──────────────────────────────────────

  Widget _buildWideLayout() {
    return Row(
      children: [
        _buildSidebar(),
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4F46E5), Color(0xFF2563EB)],
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.local_library_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'LibSoar',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Setup your library',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: Colors.white.withAlpha(179),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            // Progress bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progress',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withAlpha(179),
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        '${((_currentStep + 1) / 5 * 100).round()}%',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (_currentStep + 1) / 5,
                      backgroundColor: Colors.white.withAlpha(40),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _stepLabels.length,
                itemBuilder: (context, i) => _buildSidebarStep(i),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withAlpha(40)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your data is encrypted\nand secure',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: Colors.white.withAlpha(204),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarStep(int index) {
    final isDone = index < _currentStep;
    final isActive = index == _currentStep;
    return GestureDetector(
      onTap: index < _currentStep
          ? () {
              setState(() => _currentStep = index);
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
              );
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withAlpha(30) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isActive
              ? Border.all(color: Colors.white.withAlpha(60))
              : null,
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isDone
                    ? Colors.white
                    : (isActive ? Colors.white : Colors.white.withAlpha(30)),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isDone
                    ? const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: Color(0xFF4F46E5),
                      )
                    : Icon(
                        _stepIcons[index],
                        size: 16,
                        color: isActive
                            ? const Color(0xFF4F46E5)
                            : Colors.white.withAlpha(179),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Step ${index + 1}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withAlpha(153),
                      letterSpacing: 0.4,
                    ),
                  ),
                  Text(
                    _stepLabels[index],
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive
                          ? Colors.white
                          : Colors.white.withAlpha(179),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Narrow Layout (Mobile Stepper) ───────────────────────────────────────

  Widget _buildNarrowLayout() {
    return SafeArea(
      child: Column(
        children: [
          _buildMobileStepper(),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildMobileStepper() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF2563EB)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_library_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'LibSoar Setup',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Text(
                '${_currentStep + 1}/5',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withAlpha(204),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(5, (i) {
              final isDone = i < _currentStep;
              final isActive = i == _currentStep;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < 4 ? 4 : 0),
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDone || isActive
                        ? Colors.white
                        : Colors.white.withAlpha(60),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            _stepLabels[_currentStep],
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Content Area ──────────────────────────────────────────────────────────

  Widget _buildContent() {
    return Column(
      children: [
        Expanded(
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildStep1(),
              _buildStep2(),
              _buildStep3(),
              _buildStep4(),
              _buildStep5(),
            ],
          ),
        ),
        _buildBottomBar(),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: const Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _goBack,
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: Text(
                  'Back',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4F46E5),
                  side: const BorderSide(color: Color(0xFF4F46E5)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF2563EB)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withAlpha(80),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _goNext,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _currentStep == 4
                            ? Icons.rocket_launch_rounded
                            : Icons.arrow_forward_rounded,
                        size: 16,
                      ),
                label: Text(
                  _currentStep == 4 ? 'Start Free Trial' : 'Next Step',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Step Header ──────────────────────────────────────────────────────────

  Widget _buildStepHeader(String title, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4F46E5), Color(0xFF2563EB)],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
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

  Widget _buildCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF0F172A),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool required = false,
    bool readOnly = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int maxLines = 1,
    Widget? suffix,
    void Function(String)? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        onChanged: onChanged,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          color: const Color(0xFF0F172A),
        ),
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          hintText: hint,
          suffixIcon: suffix,
          filled: true,
          fillColor: readOnly
              ? const Color(0xFFF8FAFC)
              : const Color(0xFFF1F5F9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFEF4444)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
          ),
          labelStyle: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: const Color(0xFF64748B),
          ),
          hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: const Color(0xFF94A3B8),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
        validator:
            validator ??
            (required
                ? (v) => (v == null || v.trim().isEmpty)
                      ? '$label is required'
                      : null
                : null),
      ),
    );
  }

  // ─── STEP 1: Personal Details ─────────────────────────────────────────────

  Widget _buildStep1() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            'Personal Details',
            'Tell us about yourself',
            Icons.person_outline_rounded,
          ),
          const SizedBox(height: 8),
          Form(
            key: _step1Key,
            child: _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Basic Information'),
                  _buildField(
                    controller: _fullNameCtrl,
                    label: 'Full Name',
                    hint: 'Enter your full name',
                    required: true,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Full name is required';
                      }
                      if (v.trim().length < 2) {
                        return 'Name must be at least 2 characters';
                      }
                      return null;
                    },
                  ),
                  _buildField(
                    controller: _emailCtrl,
                    label: 'Email Address',
                    hint: 'your@email.com',
                    required: true,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Email is required';
                      }
                      if (!RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      ).hasMatch(v.trim())) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                  _buildField(
                    controller: _mobileCtrl,
                    label: 'Mobile Number',
                    hint: '10-digit mobile number',
                    required: true,
                    readOnly: true,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Mobile number is required';
                      }
                      if (v.trim().length != 10) {
                        return 'Enter a valid 10-digit number';
                      }
                      return null;
                    },
                    onChanged: (val) {
                      if (_sameAsMobile) {
                        setState(() => _whatsappCtrl.text = val);
                      }
                    },
                  ),
                  Row(
                    children: [
                      Checkbox(
                        value: _sameAsMobile,
                        onChanged: (val) {
                          setState(() {
                            _sameAsMobile = val ?? false;
                            if (_sameAsMobile) {
                              _whatsappCtrl.text = _mobileCtrl.text;
                            } else {
                              _whatsappCtrl.clear();
                            }
                          });
                        },
                        activeColor: const Color(0xFF4F46E5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Text(
                        'WhatsApp same as mobile',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildField(
                    controller: _whatsappCtrl,
                    label: 'WhatsApp Number',
                    hint: '10-digit WhatsApp number',
                    readOnly: _sameAsMobile,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─── STEP 2: Library Info ─────────────────────────────────────────────────

  Widget _buildStep2() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            'Library Info',
            'Details about your library',
            Icons.business_outlined,
          ),
          const SizedBox(height: 8),
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('Library Type'),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: List.generate(_libraryTypes.length, (i) {
                    final selected = _libraryTypeIndex == i;
                    return GestureDetector(
                      onTap: () => setState(() => _libraryTypeIndex = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFF4F46E5)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected
                                ? const Color(0xFF4F46E5)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Text(
                          _libraryTypes[i],
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? Colors.white
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          Form(
            key: _step2Key,
            child: _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Library Details'),
                  _buildField(
                    controller: _libNameCtrl,
                    label: 'Library Name',
                    hint: 'Enter library name',
                    required: true,
                  ),
                  _buildField(
                    controller: _libEmailCtrl,
                    label: 'Official Email',
                    hint: 'library@email.com',
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v != null &&
                          v.isNotEmpty &&
                          !RegExp(
                            r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                          ).hasMatch(v.trim())) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                  _buildField(
                    controller: _libContactCtrl,
                    label: 'Contact Number',
                    hint: '10-digit number',
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                  ),
                  _buildField(
                    controller: _addressCtrl,
                    label: 'Address',
                    hint: 'Street address',
                    required: true,
                    maxLines: 2,
                  ),
                  _buildField(
                    controller: _landmarkCtrl,
                    label: 'Landmark',
                    hint: 'Near landmark (optional)',
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildField(
                          controller: _pincodeCtrl,
                          label: 'Pincode',
                          hint: '6-digit pincode',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          validator: (v) {
                            if (v != null && v.isNotEmpty && v.length != 6) {
                              return 'Enter valid 6-digit pincode';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildField(
                          controller: _cityCtrl,
                          label: 'City',
                          hint: 'City name',
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedState,
                      decoration: InputDecoration(
                        labelText: 'State',
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF4F46E5),
                            width: 1.5,
                          ),
                        ),
                        labelStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                      ),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: const Color(0xFF0F172A),
                      ),
                      items: _states
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedState = v),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─── STEP 3: Facilities ───────────────────────────────────────────────────

  Widget _buildStep3() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            'Facilities',
            'Amenities and floor details',
            Icons.apartment_outlined,
          ),
          const SizedBox(height: 8),
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('Amenities'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._defaultAmenities.map((a) => _buildAmenityChip(a)),
                    ..._selectedAmenities
                        .where((a) => !_defaultAmenities.contains(a))
                        .map((a) => _buildAmenityChip(a, isCustom: true)),
                    _buildAddCustomChip(),
                  ],
                ),
              ],
            ),
          ),
          // Policy & Buffer section
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('Policy & Buffer'),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                    controller: _bufferDaysCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      labelText: 'Buffer Days (optional)',
                      hintText: 'e.g. 3',
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      suffixIcon: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'days',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF4F46E5),
                          width: 1.5,
                        ),
                      ),
                      labelStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF94A3B8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
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
                          'Buffer days allow extra time between seat bookings for preparation.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: const Color(0xFF4F46E5),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionTitle('Floor Details'),
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => _floors.add(FloorDetail())),
                      icon: const Icon(
                        Icons.add_rounded,
                        size: 16,
                        color: Color(0xFF4F46E5),
                      ),
                      label: Text(
                        'Add Floor',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF4F46E5),
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                    ),
                  ],
                ),
                ...List.generate(_floors.length, (i) => _buildFloorRow(i)),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildAmenityChip(String label, {bool isCustom = false}) {
    final selected = _selectedAmenities.contains(label);
    return GestureDetector(
      onTap: () => setState(() {
        if (selected) {
          _selectedAmenities.remove(label);
        } else {
          _selectedAmenities.add(label);
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEEF2FF) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(
                Icons.check_rounded,
                size: 14,
                color: Color(0xFF4F46E5),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected
                    ? const Color(0xFF4F46E5)
                    : const Color(0xFF64748B),
              ),
            ),
            if (isCustom) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => setState(() => _selectedAmenities.remove(label)),
                child: const Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAddCustomChip() {
    return GestureDetector(
      onTap: () => _showAddCustomAmenityDialog(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFE2E8F0),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, size: 14, color: Color(0xFF64748B)),
            const SizedBox(width: 4),
            Text(
              'Add Custom',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCustomAmenityDialog() {
    _customAmenityCtrl.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Add Custom Amenity',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: TextField(
          controller: _customAmenityCtrl,
          autofocus: true,
          style: GoogleFonts.plusJakartaSans(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'e.g. Parking, Printer',
            hintStyle: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: const Color(0xFF94A3B8),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFF4F46E5),
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final val = _customAmenityCtrl.text.trim();
              if (val.isNotEmpty) setState(() => _selectedAmenities.add(val));
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Add',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloorRow(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Floor ${index + 1}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF4F46E5),
                ),
              ),
              if (_floors.length > 1)
                GestureDetector(
                  onTap: () => setState(() => _floors.removeAt(index)),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: Color(0xFFEF4444),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: _floors[index].name,
                  style: GoogleFonts.plusJakartaSans(fontSize: 13),
                  onChanged: (v) => _floors[index].name = v,
                  decoration: InputDecoration(
                    labelText: 'Floor Name *',
                    hintText: 'e.g. Ground Floor',
                    filled: true,
                    fillColor: Colors.white,
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
                    labelStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                    ),
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: const Color(0xFF94A3B8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  initialValue: _floors[index].capacity,
                  style: GoogleFonts.plusJakartaSans(fontSize: 13),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (v) => _floors[index].capacity = v,
                  decoration: InputDecoration(
                    labelText: 'Capacity *',
                    hintText: '0',
                    filled: true,
                    fillColor: Colors.white,
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
                    labelStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                    ),
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: const Color(0xFF94A3B8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
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

  // ─── STEP 4: Shifts & Timings ─────────────────────────────────────────────

  Widget _buildStep4() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            'Shifts & Timings',
            'Configure your library shifts',
            Icons.schedule_outlined,
          ),
          const SizedBox(height: 8),
          _buildCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16, left: 4),
                  child: Text(
                    'Select and configure shifts',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
                ...List.generate(_shifts.length, (i) => _buildShiftCard(i)),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildShiftCard(int index) {
    final shift = _shifts[index];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: shift.enabled
            ? const Color(0xFFEEF2FF)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: shift.enabled
              ? const Color(0xFF4F46E5)
              : const Color(0xFFE2E8F0),
          width: shift.enabled ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: shift.enabled
                        ? const Color(0xFF4F46E5)
                        : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    shift.icon,
                    size: 20,
                    color: shift.enabled
                        ? Colors.white
                        : const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shift.label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      if (shift.enabled)
                        Text(
                          '${shift.startTime.format(context)} – ${shift.endTime.format(context)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: const Color(0xFF4F46E5),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                Switch(
                  value: shift.enabled,
                  onChanged: (v) => setState(() => shift.enabled = v),
                  activeThumbColor: const Color(0xFF4F46E5),
                  activeTrackColor: const Color(0xFFEEF2FF),
                ),
              ],
            ),
          ),
          if (shift.enabled)
            Container(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTimePicker(
                      'Start Time',
                      shift.startTime,
                      (t) => setState(() => shift.startTime = t),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildTimePicker(
                      'End Time',
                      shift.endTime,
                      (t) => setState(() => shift.endTime = t),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextFormField(
                      initialValue: shift.fee,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (v) => shift.fee = v,
                      style: GoogleFonts.plusJakartaSans(fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Monthly Fee',
                        prefixText: '₹ ',
                        prefixStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: const Color(0xFF4F46E5),
                          fontWeight: FontWeight.w600,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFF4F46E5),
                            width: 1.5,
                          ),
                        ),
                        labelStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimePicker(
    String label,
    TimeOfDay time,
    void Function(TimeOfDay) onPicked,
  ) {
    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
        );
        if (picked != null) onPicked(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 14,
                  color: Color(0xFF4F46E5),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    time.format(context),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── STEP 5: Review & Launch ──────────────────────────────────────────────

  Widget _buildStep5() {
    final totalSeats = _floors.fold<int>(
      0,
      (sum, f) => sum + (int.tryParse(f.capacity) ?? 0),
    );
    final activeShifts = _shifts.where((s) => s.enabled).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            'Review & Launch',
            'Everything looks good? Let\'s go!',
            Icons.rocket_launch_outlined,
          ),
          const SizedBox(height: 8),
          // Summary stats
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF2563EB)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _buildStatBadge('${_floors.length}', 'Floors'),
                _buildStatDivider(),
                _buildStatBadge('$totalSeats', 'Seats'),
                _buildStatDivider(),
                _buildStatBadge('${activeShifts.length}', 'Shifts'),
                _buildStatDivider(),
                _buildStatBadge('${_selectedAmenities.length}', 'Amenities'),
              ],
            ),
          ),
          // Owner Info
          _buildReviewCard(
            icon: Icons.person_outline_rounded,
            title: 'Owner Information',
            items: [
              _ReviewItem(
                'Full Name',
                _fullNameCtrl.text.isEmpty ? '—' : _fullNameCtrl.text,
              ),
              _ReviewItem(
                'Email',
                _emailCtrl.text.isEmpty ? '—' : _emailCtrl.text,
              ),
              _ReviewItem(
                'Mobile',
                _mobileCtrl.text.isEmpty ? '—' : _mobileCtrl.text,
              ),
              _ReviewItem(
                'WhatsApp',
                _sameAsMobile
                    ? _mobileCtrl.text
                    : (_whatsappCtrl.text.isEmpty ? '—' : _whatsappCtrl.text),
              ),
            ],
          ),
          // Library Info
          _buildReviewCard(
            icon: Icons.business_outlined,
            title: 'Library Information',
            items: [
              _ReviewItem('Type', _libraryTypes[_libraryTypeIndex]),
              _ReviewItem(
                'Name',
                _libNameCtrl.text.isEmpty ? '—' : _libNameCtrl.text,
              ),
              _ReviewItem(
                'Address',
                _addressCtrl.text.isEmpty ? '—' : _addressCtrl.text,
              ),
              _ReviewItem(
                'City',
                _cityCtrl.text.isEmpty ? '—' : _cityCtrl.text,
              ),
              _ReviewItem('State', _selectedState ?? '—'),
              _ReviewItem(
                'Pincode',
                _pincodeCtrl.text.isEmpty ? '—' : _pincodeCtrl.text,
              ),
            ],
          ),
          // Amenities
          if (_selectedAmenities.isNotEmpty)
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.apartment_outlined,
                          size: 16,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Amenities',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedAmenities
                        .map(
                          (a) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF4F46E5).withAlpha(80),
                              ),
                            ),
                            child: Text(
                              a,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF4F46E5),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          // Capacity
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.chair_outlined,
                        size: 16,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Capacity',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ..._floors.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          f.name.isEmpty ? 'Unnamed Floor' : f.name,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          '${f.capacity.isEmpty ? 0 : f.capacity} seats',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Shift Pricing
          if (activeShifts.isNotEmpty)
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.schedule_outlined,
                          size: 16,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Shift Pricing',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ...activeShifts.map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              s.icon,
                              size: 16,
                              color: const Color(0xFF4F46E5),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.label,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  '${s.startTime.format(context)} – ${s.endTime.format(context)}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            s.fee.isEmpty ? '₹ —' : '₹ ${s.fee}/mo',
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
            ),
          // Trial banner
          Container(
            margin: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF10B981).withAlpha(80)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.verified_outlined,
                    color: Color(0xFF10B981),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '14-Day Free Trial',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF065F46),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'No credit card required. Full access to all features.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: const Color(0xFF047857),
                        ),
                      ),
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

  Widget _buildStatBadge(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: Colors.white.withAlpha(204),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(width: 1, height: 36, color: Colors.white.withAlpha(60));
  }

  Widget _buildReviewCard({
    required IconData icon,
    required String title,
    required List<_ReviewItem> items,
  }) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: const Color(0xFF4F46E5)),
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
            ],
          ),
          const SizedBox(height: 14),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      item.label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.value,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
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

class _ReviewItem {
  final String label;
  final String value;
  const _ReviewItem(this.label, this.value);
}

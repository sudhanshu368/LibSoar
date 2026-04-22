import re

file_path = 'd:/libsoar/lib/presentation/add_student_screen/add_student_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update imports
if "'../../data/models/dropdown_models.dart'" not in content:
    content = content.replace("import '../../data/models/form_config_model.dart';",
                              "import '../../data/models/form_config_model.dart';\nimport '../../data/models/dropdown_models.dart';")

# 2. Add API branch and shift variables, replace old branch/shift variables
vars_to_replace = '''  List<FormFieldConfig> _formFields = [];
  bool _isLoadingConfig = true;'''
new_vars = '''  List<FormFieldConfig> _formFields = [];
  bool _isLoadingConfig = true;

  List<ApiBranchModel> _apiBranches = [];
  bool _isLoadingBranches = false;

  List<ApiShiftModel> _apiShifts = [];
  bool _isLoadingShifts = false;

  String? _selectedBranchId;
  String? _selectedShiftId;'''
if "_apiBranches" not in content:
    content = content.replace(vars_to_replace, new_vars)

# Remove old branch and shift static strings
content = re.sub(r"  String\? _selectedBranch;\s*", "", content)
content = re.sub(r"  String\? _selectedShift;\s*", "", content)
content = re.sub(r"  final List<String> _branches = \[.*?\];\n", "", content, flags=re.DOTALL)
content = re.sub(r"  final List<String> _shifts = \[.*?\];\n", "", content, flags=re.DOTALL)

# 3. Add fetch functions inside _AddStudentScreenState
fetch_funcs = '''  Future<void> _fetchBranches() async {
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

  Future<void> _fetchFormConfig() async {'''

if "_fetchBranches()" not in content:
    content = content.replace("  Future<void> _fetchFormConfig() async {", fetch_funcs)

# Update initState to call _fetchBranches
new_init = '''  @override
  void initState() {
    super.initState();
    _fetchFormConfig();
    _fetchBranches();
  }'''
content = re.sub(r'  @override\s*void initState\(\) \{\s*super\.initState\(\);\s*_fetchFormConfig\(\);\s*\}', new_init, content)

# 4. Modify Branch Dropdown inside _buildPersonalInfoSection
old_branch_dropdown = '''        _buildDropdownField(
          label: 'Branch',
          hint: 'Select Branch',
          value: _selectedBranch,
          items: _branches,
          onChanged: (v) => setState(() => _selectedBranch = v),
        ),'''
new_branch_dropdown = '''        if (_isLoadingBranches)
          const Padding(padding: EdgeInsets.only(bottom: 14), child: CircularProgressIndicator())
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel('Branch'),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedBranchId,
                hint: Text('Select Branch', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF94A3B8))),
                items: _apiBranches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF0F172A))))).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedBranchId = val);
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
          ),'''
if "_isLoadingBranches)" not in content:
    content = content.replace(old_branch_dropdown, new_branch_dropdown)

# 5. Modify Shift Dropdown and Seat Type Radio inside _buildSubscriptionSection
# Wait, seat type radio also needs to call _calculateFee!
# Let's target _buildSubscriptionSection directly.
old_sub_section_part = '''        _buildDropdownField(
          label: 'Shift',
          hint: 'Select Shift',
          value: _selectedShift,
          items: _shifts,
          onChanged: (v) => setState(() => _selectedShift = v),
        ),
        const SizedBox(height: 14),
        _buildLabel('Seat Type'),
        const SizedBox(height: 8),
        Row(
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
                          groupValue: _selectedSeatType,
                          onChanged: (v) =>
                              setState(() => _selectedSeatType = v!),
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
        ),'''

new_sub_section_part = '''        if (_isLoadingShifts)
          const Padding(padding: EdgeInsets.only(bottom: 14), child: CircularProgressIndicator())
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel('Shift'),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedShiftId,
                hint: Text('Select Shift', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF94A3B8))),
                items: _apiShifts.map((s) => DropdownMenuItem(value: s.id, child: Text("${s.name} (${s.timing})", style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF0F172A))))).toList(),
                onChanged: (val) {
                  setState(() => _selectedShiftId = val);
                  _calculateFee();
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
        Row(
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
                          groupValue: _selectedSeatType,
                          onChanged: (v) {
                              setState(() => _selectedSeatType = v!);
                              _calculateFee();
                          },
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
        ),'''
if "if (_isLoadingShifts)" not in content:
    content = content.replace(old_sub_section_part, new_sub_section_part)


with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

#print("Update script completed successfully!")

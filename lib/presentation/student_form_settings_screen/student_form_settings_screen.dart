import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/services/api_service.dart';
import '../../core/utils/storage_helper.dart';

class StudentFormSettingsScreen extends StatefulWidget {
  const StudentFormSettingsScreen({super.key});

  @override
  State<StudentFormSettingsScreen> createState() =>
      _StudentFormSettingsScreenState();
}

class _StudentFormSettingsScreenState extends State<StudentFormSettingsScreen> {
  // Field model: enabled, required
  final Map<String, Map<String, bool>> _fields = {
    // Personal Information
    'Name': {'enabled': true, 'required': true, 'core': true},
    'Phone': {'enabled': true, 'required': true, 'core': true},
    'Gender': {'enabled': true, 'required': true, 'core': true},
    'WhatsApp Number': {'enabled': true, 'required': false, 'core': false},
    'Email': {'enabled': true, 'required': false, 'core': false},
    'Address': {'enabled': true, 'required': false, 'core': false},
    'Date of Birth': {'enabled': false, 'required': false, 'core': false},
    'Father Name': {'enabled': false, 'required': false, 'core': false},
    'Emergency Contact': {'enabled': false, 'required': false, 'core': false},
    // Documents
    'Profile Picture': {
      'enabled': true,
      'required': false,
      'core': false,
      'fileUpload': true,
    },
    'Aadhaar Document': {
      'enabled': false,
      'required': false,
      'core': false,
      'fileUpload': true,
    },
    'Aadhaar Number': {
      'enabled': false,
      'required': false,
      'core': false,
      'fileUpload': false,
    },
    // Academic Details
    'Qualification': {'enabled': true, 'required': false, 'core': false},
    'Goal': {'enabled': true, 'required': false, 'core': false},
    // Other Details
    'Remarks': {'enabled': false, 'required': false, 'core': false},
  };

  bool _editMode = false;
  bool _isLoading = false;
  bool _isFetching = true;

  @override
  void initState() {
    super.initState();
    _fetchFormConfig();
  }

  Future<void> _fetchFormConfig() async {
    try {
      final token = await StorageHelper.getToken();
      if (token == null) return;
      final res = await ApiService.get('/settings/form-config', token);
      if (res != null && res['success'] == true && res['data'] != null) {
        final List<dynamic> fieldsData = res['data']['fields'];
        setState(() {
          for (var fieldData in fieldsData) {
            final apiReqKey = fieldData['key'];
            // Find corresponding UI key
            final uiKey = _apiKeysMap.entries.firstWhere(
               (entry) => entry.value == apiReqKey, 
               orElse: () => const MapEntry('', '')
            ).key;
            
            if (uiKey.isNotEmpty && _fields.containsKey(uiKey)) {
              _fields[uiKey]!['enabled'] = fieldData['enabled'] ?? false;
              _fields[uiKey]!['required'] = fieldData['required'] ?? false;
            }
          }
          _isFetching = false;
        });
      } else {
        setState(() => _isFetching = false);
      }
    } catch (e) {
      debugPrint('Error fetching form config: $e');
      if (mounted) setState(() => _isFetching = false);
    }
  }

  final Map<String, String> _apiKeysMap = {
    'Name': 'name',
    'Phone': 'phone',
    'Gender': 'gender',
    'WhatsApp Number': 'whatsappNumber',
    'Email': 'email',
    'Address': 'address',
    'Date of Birth': 'dob',
    'Father Name': 'fatherName',
    'Emergency Contact': 'emergencyContact',
    'Profile Picture': 'profilePicture',
    'Aadhaar Document': 'aadharDocument',
    'Aadhaar Number': 'aadharNumber',
    'Qualification': 'qualification',
    'Goal': 'goal',
    'Remarks': 'remarks',
  };

  static const List<String> _personalFields = [
    'Name',
    'Phone',
    'Gender',
    'WhatsApp Number',
    'Email',
    'Address',
    'Date of Birth',
    'Father Name',
    'Emergency Contact',
  ];

  static const List<String> _documentFields = [
    'Profile Picture',
    'Aadhaar Document',
    'Aadhaar Number',
  ];

  static const List<String> _academicFields = ['Qualification', 'Goal'];

  static const List<String> _otherFields = ['Remarks'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: _isFetching 
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderCard(),
                    const SizedBox(height: 16),
                    _buildMainCard(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.assignment_outlined,
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
                  'Student Form Settings',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dashboard / Settings / Student Form',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Student Registration Form',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    if (_editMode) {
                      setState(() => _isLoading = true);
                      try {
                        final token = await StorageHelper.getToken();
                        final fieldsPayload = _apiKeysMap.entries.map((e) {
                          final currentField = _fields[e.key]!;
                          return {
                             "key": e.value,
                             "label": e.key,
                             "required": currentField['required'],
                             "enabled": currentField['enabled']
                          };
                        }).toList();
                        
                        final res = await ApiService.put('/settings/form-config', {"fields": fieldsPayload}, token: token);
                        if (res != null && res['success'] == true) {
                           setState(() {
                              _editMode = false;
                           });
                           if (mounted) {
                             ScaffoldMessenger.of(context).showSnackBar(
                               SnackBar(
                                 content: Text(
                                   'Form settings saved successfully',
                                   style: GoogleFonts.plusJakartaSans(fontSize: 13),
                                 ),
                                 backgroundColor: Colors.green,
                                 behavior: SnackBarBehavior.floating,
                                 shape: RoundedRectangleBorder(
                                   borderRadius: BorderRadius.circular(10),
                                 ),
                               ),
                             );
                           }
                        } else {
                           if (mounted) {
                             ScaffoldMessenger.of(context).showSnackBar(
                               SnackBar(
                                 content: Text(res?['message'] ?? 'Failed to update', style: GoogleFonts.plusJakartaSans()),
                                 backgroundColor: Colors.red,
                               )
                             );
                           }
                        }
                      } catch(e) {
                        if (mounted) {
                           ScaffoldMessenger.of(context).showSnackBar(
                             SnackBar(
                               content: Text('Error: $e', style: GoogleFonts.plusJakartaSans()),
                               backgroundColor: Colors.red,
                             )
                           );
                        }
                      } finally {
                        if (mounted) setState(() => _isLoading = false);
                      }
                    } else {
                      setState(() => _editMode = true);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: _editMode
                          ? const LinearGradient(
                              colors: [Color(0xFF059669), Color(0xFF10B981)],
                            )
                          : const LinearGradient(
                              colors: [Color(0xFF4F46E5), Color(0xFF2563EB)],
                            ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isLoading)
                           const SizedBox(
                             width: 14, height: 14, 
                             child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                           )
                        else
                           Icon(
                             _editMode ? Icons.check_rounded : Icons.edit_outlined,
                             size: 14,
                             color: Colors.white,
                           ),
                        const SizedBox(width: 6),
                        Text(
                          _editMode ? 'Save' : 'Edit',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: const Color(0xFFF1F5F9)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSection('Personal Information', _personalFields),
                const SizedBox(height: 20),
                _buildSection('Documents', _documentFields),
                const SizedBox(height: 20),
                _buildSection('Academic Details', _academicFields),
                const SizedBox(height: 20),
                _buildSection('Other Details', _otherFields),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<String> fieldKeys) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 500 ? 3 : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.05,
              ),
              itemCount: fieldKeys.length,
              itemBuilder: (context, index) {
                return _buildFieldCard(fieldKeys[index]);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildFieldCard(String fieldKey) {
    final field = _fields[fieldKey]!;
    final bool isEnabled = field['enabled']!;
    final bool isRequired = field['required']!;
    final bool isCore = field['core'] ?? false;
    final bool isFileUpload = field['fileUpload'] ?? false;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isEnabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEnabled
              ? const Color(0xFF4F46E5).withValues(alpha: 0.2)
              : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Field name + core badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  fieldKey,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isEnabled
                        ? const Color(0xFF1E293B)
                        : const Color(0xFF94A3B8),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Tags row
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              if (isCore)
                _buildTag(
                  'Core Field',
                  const Color(0xFFEEF2FF),
                  const Color(0xFF4F46E5),
                ),
              if (isFileUpload)
                _buildTag(
                  'File Upload',
                  const Color(0xFFF0F9FF),
                  const Color(0xFF0284C7),
                ),
            ],
          ),
          const Spacer(),
          // Enabled toggle
          _buildToggleRow(
            label: isEnabled ? 'Enabled' : 'Disabled',
            value: isEnabled,
            onChanged: _editMode
                ? (val) {
                    setState(() {
                      _fields[fieldKey]!['enabled'] = val;
                      if (!val) _fields[fieldKey]!['required'] = false;
                    });
                  }
                : null,
          ),
          const SizedBox(height: 6),
          // Required toggle
          _buildToggleRow(
            label: isRequired ? 'Required' : 'Optional',
            value: isRequired,
            onChanged: (_editMode && isEnabled)
                ? (val) {
                    setState(() => _fields[fieldKey]!['required'] = val);
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String label, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildToggleRow({
    required String label,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: value ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8),
            ),
          ),
        ),
        SizedBox(
          width: 36,
          height: 20,
          child: Transform.scale(
            scale: 0.75,
            alignment: Alignment.centerRight,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: const Color(0xFF4F46E5),
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFFCBD5E1),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ],
    );
  }
}

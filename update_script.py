import re

file_path = 'd:/libsoar/lib/presentation/add_student_screen/add_student_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Imports
imports = '''import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/app_drawer.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/storage_helper.dart';
import '../../data/models/form_config_model.dart';'''
content = re.sub(r"import 'package:flutter/material\.dart';\s*import 'package:google_fonts/google_fonts\.dart';\s*import '\.\./\.\./widgets/app_drawer\.dart';", imports, content)

# 2. State variables
state_vars = '''  List<FormFieldConfig> _formFields = [];
  bool _isLoadingConfig = true;

  @override
  void initState() {
    super.initState();
    _fetchFormConfig();
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
  String? _selectedBranch;'''

content = content.replace('  // Personal Info\n  String? _selectedBranch;', state_vars)

# 3. Form builder loading
form_builder = '''      body: _isLoadingConfig
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
          : Form(
        key: _formKey,
        child: Column('''
content = content.replace('      body: Form(\n        key: _formKey,\n        child: Column(', form_builder)

# Find and replace sections using regex to match entire function bodies
personal_info_replacement = '''  Widget _buildPersonalInfoSection() {
    return _buildSectionCard(
      title: 'PERSONAL INFORMATION',
      isExpanded: _personalExpanded,
      onToggle: () => setState(() => _personalExpanded = !_personalExpanded),
      children: [
        _buildDropdownField(
          label: 'Branch',
          hint: 'Select Branch',
          value: _selectedBranch,
          items: _branches,
          onChanged: (v) => setState(() => _selectedBranch = v),
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
            Row(
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
                              groupValue: _selectedGender,
                              onChanged: (v) =>
                                  setState(() => _selectedGender = v!),
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
  }'''
content = re.sub(r'  Widget _buildPersonalInfoSection\(\) \{.*?(?=  Widget _buildSubscriptionSection\(\) \{)', personal_info_replacement + '\n\n', content, flags=re.DOTALL)

academic_replacement = '''  Widget _buildAcademicSection() {
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
  }'''
content = re.sub(r'  Widget _buildAcademicSection\(\) \{.*?(?=  Widget _buildDocumentsSection\(\) \{)', academic_replacement + '\n\n', content, flags=re.DOTALL)

documents_replacement = '''  Widget _buildDocumentsSection() {
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
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Image picker would open here',
                      style: GoogleFonts.plusJakartaSans(color: Colors.white),
                    ),
                    backgroundColor: const Color(0xFF4F46E5),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              },
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
              onTap: () {
                setState(() => _aadhaarDocumentPath = 'aadhaar_document.pdf');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'File picker would open here',
                      style: GoogleFonts.plusJakartaSans(color: Colors.white),
                    ),
                    backgroundColor: const Color(0xFF4F46E5),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              },
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
  }'''
content = re.sub(r'  Widget _buildDocumentsSection\(\) \{.*?(?=  Widget _buildBottomActions\(\) \{)', documents_replacement + '\n\n', content, flags=re.DOTALL)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

#print("File updated successfully!")

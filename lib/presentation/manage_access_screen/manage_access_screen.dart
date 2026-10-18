import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/services/api_service.dart';
import '../../core/services/dashboard_service.dart';
import '../../core/utils/storage_helper.dart';

class ManageAccessScreen extends StatefulWidget {
  const ManageAccessScreen({super.key});

  @override
  State<ManageAccessScreen> createState() => _ManageAccessScreenState();
}

class _ManageAccessScreenState extends State<ManageAccessScreen> {
  final List<_StaffUser> _users = [];
  bool _isLoading = true;
  List<Map<String, dynamic>> _branches = [];
  final Map<String, String> _branchMap = {};

  @override
  void initState() {
    super.initState();
    _fetchStaff();
  }

  Future<void> _fetchStaff() async {
    try {
      final token = await StorageHelper.getToken();
      if (token == null) return;

      final branchesRes = await DashboardService.getBranches();
      if (branchesRes.isNotEmpty) {
        _branches = branchesRes;
        for (var b in _branches) {
          _branchMap[b['id'].toString()] = b['name'].toString();
        }
      }

      final res = await ApiService.get('/staff', token);
      if (res != null && res['success'] == true && res['data'] is List) {
        final List s = res['data'];
        setState(() {
          _users.clear();
          for (var e in s) {
            String bName = '';
            if (e['branch'] is Map) {
              bName = e['branch']['name']?.toString() ?? '';
            } else if (e['branch'] != null) {
              String bId = e['branch'].toString();
              bName = _branchMap[bId] ?? bId;
            }

            _users.add(
              _StaffUser(
                id: e['id']?.toString() ?? '',
                name: e['name']?.toString() ?? '',
                role: e['role']?.toString() ?? 'staff',
                email: e['email']?.toString() ?? '',
                phone: e['phone']?.toString() ?? '',
                branch: bName,
                isActive: (e['status']?.toString().toLowerCase() == 'active'),
                isOwner: e['isOwner'] == true,
              ),
            );
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching staff: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddStaffSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddStaffSheetWidget(
        branches: _branches,
        onAdd: (staff) {
          setState(() {
            _users.add(staff);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Staff member added successfully',
                style: GoogleFonts.plusJakartaSans(fontSize: 13),
              ),
              backgroundColor: const Color(0xFF059669),
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

  void _showDeleteDialog(int index) {
    final user = _users[index];
    bool isDeleting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Remove Member',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
            ),
          ),
          content: Text(
            'Are you sure you want to remove ${user.name}?',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: const Color(0xFF64748B),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isDeleting ? null : () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDeleting ? Colors.grey : const Color(0xFF64748B),
                ),
              ),
            ),
            FilledButton(
              onPressed: isDeleting
                  ? null
                  : () async {
                      setDialogState(() => isDeleting = true);
                      try {
                        final token = await StorageHelper.getToken();
                        if (token == null) {
                          setDialogState(() => isDeleting = false);
                          return;
                        }

                        final res = await ApiService.delete(
                          '/staff/${user.id}',
                          token: token,
                        );

                        if (ctx.mounted && mounted) {
                          setDialogState(() => isDeleting = false);
                          if (res != null && res['success'] == true) {
                            setState(() => _users.removeAt(index));
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Member removed',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                  ),
                                ),
                                backgroundColor: const Color(0xFFEF4444),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  res?['message'] ?? 'Failed to remove member',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                  ),
                                ),
                                backgroundColor: const Color(0xFFEF4444),
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        if (ctx.mounted && mounted) {
                          setDialogState(() => isDeleting = false);

                          String errMsg = e.toString().replaceAll(
                            'Exception: ',
                            '',
                          );
                          if (errMsg.contains('error: {') &&
                              errMsg.contains('message:')) {
                            final match = RegExp(
                              r'message:\s*([^,}]+)',
                            ).firstMatch(errMsg);
                            if (match != null) {
                              errMsg = match.group(1)?.trim() ?? errMsg;
                            }
                          }

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                errMsg,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                ),
                              ),
                              backgroundColor: const Color(0xFFEF4444),
                            ),
                          );
                        }
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                disabledBackgroundColor: const Color(0xFFFCA5A5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: isDeleting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Remove',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleStatus(int index) async {
    final user = _users[index];
    final newStatus = user.isActive ? 'INACTIVE' : 'ACTIVE';
    // Optimistic UI update
    setState(() {
      _users[index] = _StaffUser(
        id: user.id,
        name: user.name,
        role: user.role,
        email: user.email,
        phone: user.phone,
        branch: user.branch,
        isActive: !user.isActive,
        isOwner: user.isOwner,
      );
    });
    try {
      final token = await StorageHelper.getToken();
      if (token == null) return;
      final res = await ApiService.patch('/staff/${user.id}', {
        'status': newStatus,
      }, token: token);
      if (res == null || res['success'] != true) {
        // Rollback on failure
        setState(() {
          _users[index] = user;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                res?['message'] ?? 'Failed to update status',
                style: GoogleFonts.plusJakartaSans(fontSize: 13),
              ),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } else {
        final data = res['data'];
        final updatedStatus =
            data['status']?.toString().toUpperCase() == 'ACTIVE';
        setState(() {
          _users[index] = _StaffUser(
            id: user.id,
            name: user.name,
            role: user.role,
            email: user.email,
            phone: user.phone,
            branch: user.branch,
            isActive: updatedStatus,
            isOwner: user.isOwner,
          );
        });
      }
    } catch (e) {
      // Rollback
      if (mounted) {
        setState(() {
          _users[index] = user;
        });
      }
      String errMsg = e.toString().replaceAll('Exception: ', '');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errMsg,
              style: GoogleFonts.plusJakartaSans(fontSize: 13),
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _toggleRole(int index) async {
    final user = _users[index];
    final isCurrentlyAdmin =
        user.role.toUpperCase() == 'LIBRARY_ADMIN' ||
        user.role.toUpperCase() == 'ADMIN';
    final newRole = isCurrentlyAdmin ? 'STAFF' : 'LIBRARY_ADMIN';
    final newRoleLabel = isCurrentlyAdmin ? 'Staff' : 'Admin';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Change Role',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        content: Text(
          'Change ${user.name}\'s role to $newRoleLabel?',
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
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Confirm',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final token = await StorageHelper.getToken();
      if (token == null) return;
      final res = await ApiService.patch('/staff/${user.id}', {
        'role': newRole,
      }, token: token);
      if (res != null && res['success'] == true) {
        final data = res['data'];
        if (mounted) {
          setState(() {
            _users[index] = _StaffUser(
              id: user.id,
              name: user.name,
              role: data['role']?.toString() ?? newRole,
              email: user.email,
              phone: user.phone,
              branch: user.branch,
              isActive: user.isActive,
              isOwner: user.isOwner,
            );
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Role changed to $newRoleLabel',
                style: GoogleFonts.plusJakartaSans(fontSize: 13),
              ),
              backgroundColor: const Color(0xFF059669),
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
              content: Text(
                res?['message'] ?? 'Failed to change role',
                style: GoogleFonts.plusJakartaSans(fontSize: 13),
              ),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    } catch (e) {
      String errMsg = e.toString().replaceAll('Exception: ', '');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errMsg,
              style: GoogleFonts.plusJakartaSans(fontSize: 13),
            ),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _showEditSheet(int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditStaffSheetWidget(
        branches: _branches,
        user: _users[index],
        onEdit: (updatedUser) {
          setState(() {
            _users[index] = updatedUser;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Gradient Header Card ──
                    Container(
                      width: double.infinity,
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
                            color: const Color(
                              0xFF4F46E5,
                            ).withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
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
                              Icons.group_outlined,
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
                                  'Manage Access',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Dashboard / Settings / Manage Access',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Access Permissions Card ──
                    Container(
                      width: double.infinity,
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
                          // Card Header Row
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                            child: Row(
                              children: [
                                Text(
                                  'Access Permissions',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: _showAddStaffSheet,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF4F46E5),
                                          Color(0xFF2563EB),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(
                                            0xFF4F46E5,
                                          ).withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.add_rounded,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Add Staff / Admin',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
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
                          Divider(
                            height: 1,
                            thickness: 0.5,
                            color: Colors.grey.shade100,
                          ),

                          // User List
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _users.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              thickness: 0.5,
                              color: Colors.grey.shade100,
                              indent: 16,
                              endIndent: 16,
                            ),
                            itemBuilder: (context, index) {
                              final user = _users[index];
                              return _buildUserCard(user, index);
                            },
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildUserCard(_StaffUser user, int index) {
    final isAdmin =
        user.isOwner ||
        user.role.toLowerCase() == 'library_admin' ||
        user.role.toLowerCase() == 'admin';
    final avatarColor = isAdmin
        ? const Color(0xFF7C3AED)
        : const Color(0xFF2563EB);
    final roleBgColor = isAdmin
        ? const Color(0xFFF3E8FF)
        : const Color(0xFFEFF6FF);
    final roleTextColor = isAdmin
        ? const Color(0xFF7C3AED)
        : const Color(0xFF2563EB);
    final statusBgColor = user.isActive
        ? const Color(0xFFDCFCE7)
        : const Color(0xFFFEE2E2);
    final statusTextColor = user.isActive
        ? const Color(0xFF059669)
        : const Color(0xFFEF4444);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Circular Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: avatarColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name, Email, Badges
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (user.phone.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      user.phone,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (!user.isOwner)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(
                      user.branch.trim().isEmpty ? 'All Branches' : user.branch,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    // Role Badge (tappable for role change)
                    GestureDetector(
                      onTap: !user.isOwner ? () => _toggleRole(index) : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: roleBgColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              user.isOwner
                                  ? 'Owner'
                                  : (isAdmin ? 'Admin' : 'Staff'),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: roleTextColor,
                              ),
                            ),
                            if (!user.isOwner) ...[
                              const SizedBox(width: 3),
                              Icon(
                                Icons.swap_horiz_rounded,
                                size: 10,
                                color: roleTextColor,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusBgColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        user.isActive ? 'Active' : 'Inactive',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: statusTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Edit & Delete Icons
          if (!user.isOwner)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: 0.75,
                  child: Switch(
                    value: user.isActive,
                    activeTrackColor: const Color(0xFFDCFCE7),
                    activeThumbColor: const Color(0xFF059669),
                    onChanged: (val) => _toggleStatus(index),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _showEditSheet(index),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _showDeleteDialog(index),
                  child: Container(
                    width: 34,
                    height: 34,
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
        ],
      ),
    );
  }
}

class _AddStaffSheetWidget extends StatefulWidget {
  final List<Map<String, dynamic>> branches;
  final Function(_StaffUser) onAdd;

  const _AddStaffSheetWidget({required this.branches, required this.onAdd});

  @override
  State<_AddStaffSheetWidget> createState() => _AddStaffSheetWidgetState();
}

class _AddStaffSheetWidgetState extends State<_AddStaffSheetWidget> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();

  bool _isWhatsAppSameAsPhone = false;
  bool _isAdmin = false;
  String? _selectedBranchId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _phoneCtrl.addListener(() {
      if (_isWhatsAppSameAsPhone) {
        _whatsappCtrl.text = _phoneCtrl.text;
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);

      try {
        final token = await StorageHelper.getToken();
        if (token == null) {
          setState(() => _isSubmitting = false);
          return;
        }

        final Map<String, dynamic> payload = {
          "name": _nameCtrl.text.trim(),
          "email": _emailCtrl.text.trim(),
          "phone": _phoneCtrl.text.trim(),
          if (_whatsappCtrl.text.trim().isNotEmpty)
            "whatsapp": _whatsappCtrl.text.trim(),
          "role": _isAdmin ? "LIBRARY_ADMIN" : "STAFF",
        };

        if (!_isAdmin && _selectedBranchId != null) {
          payload["branchId"] = _selectedBranchId;
        }

        final res = await ApiService.post('/staff', payload, token: token);

        if (mounted) {
          setState(() => _isSubmitting = false);
          if (res != null && res['success'] == true) {
            final data = res['data'];

            String bName = '';
            if (data['branch'] != null) {
              if (data['branch'] is Map) {
                bName = data['branch']['name']?.toString() ?? '';
              } else {
                String bId = data['branch'].toString();
                var match = widget.branches.where(
                  (b) => b['id'].toString() == bId,
                );
                bName = match.isNotEmpty ? match.first['name'].toString() : bId;
              }
            } else if (data['staffOfBranchId'] == null && !_isAdmin) {
              bName = 'All Branches';
            }

            widget.onAdd(
              _StaffUser(
                id: data['id']?.toString() ?? '',
                name: data['name']?.toString() ?? '',
                role:
                    data['role']?.toString() ??
                    (_isAdmin ? 'LIBRARY_ADMIN' : 'STAFF'),
                email: data['email']?.toString() ?? '',
                phone: data['phone']?.toString() ?? '',
                branch: bName,
                isActive: true,
                isOwner: false,
              ),
            );
            Navigator.pop(context);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  res?['message'] ?? 'Failed to add staff',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13),
                ),
                backgroundColor: const Color(0xFFEF4444),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSubmitting = false);

          String errMsg = e.toString().replaceAll('Exception: ', '');
          if (errMsg.contains('error: {') && errMsg.contains('message:')) {
            final match = RegExp(r'message:\s*([^,}]+)').firstMatch(errMsg);
            if (match != null) errMsg = match.group(1)?.trim() ?? errMsg;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errMsg,
                style: GoogleFonts.plusJakartaSans(fontSize: 13),
              ),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    }
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
    String? prefixText,
    String? Function(String?)? validator,
    Color labelColor = const Color(0xFF1E293B),
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: labelColor,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLength: maxLength,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: const Color(0xFF1E293B),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: const Color(0xFF94A3B8),
            ),
            prefixText: prefixText != null ? '$prefixText ' : null,
            prefixStyle: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: const Color(0xFF1E293B),
              fontWeight: FontWeight.w600,
            ),
            counterText: "",
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
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
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: validator,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Color(0xFF1E293B),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Add Staff / Admin',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildTextField(
                label: 'Name',
                controller: _nameCtrl,
                hint: 'Enter name',
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Name is required'
                    : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                label: 'Email',
                controller: _emailCtrl,
                hint: 'Enter email',
                keyboardType: TextInputType.emailAddress,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Email is required';
                  }
                  final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                  if (!emailRegex.hasMatch(val)) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                label: 'Phone Number',
                controller: _phoneCtrl,
                hint: '10-digit phone number',
                prefixText: '+91',
                keyboardType: TextInputType.phone,
                maxLength: 10,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Phone number is required';
                  }
                  if (val.length != 10) return 'Must be 10 digits';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _isWhatsAppSameAsPhone,
                      onChanged: (val) {
                        setState(() {
                          _isWhatsAppSameAsPhone = val ?? false;
                          if (_isWhatsAppSameAsPhone) {
                            _whatsappCtrl.text = _phoneCtrl.text;
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
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Same as Phone Number',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF4F46E5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(
                label: 'WhatsApp Number',
                controller: _whatsappCtrl,
                hint: '10-digit phone number',
                prefixText: '+91',
                keyboardType: TextInputType.phone,
                maxLength: 10,
                labelColor: const Color(0xFFEF4444),
                validator: (val) {
                  if (val != null && val.isNotEmpty && val.length != 10) {
                    return 'Must be 10 digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              RadioGroup<bool>(
                groupValue: _isAdmin,
                onChanged: (val) {
                  setState(() {
                    _isAdmin = val ?? false;
                    if (_isAdmin) _selectedBranchId = null;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Radio<bool>(
                        value: true,
                        activeColor: Color(0xFF4F46E5),
                        visualDensity: VisualDensity(
                          horizontal: -4,
                          vertical: -4,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Make this person an Admin',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '👉 Admins have access to all branches and can manage staff.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!_isAdmin) ...[
                const SizedBox(height: 20),
                Text(
                  'Assign to Branch',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  initialValue: _selectedBranchId,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
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
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: const Color(0xFF1E293B),
                  ),
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF64748B),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All Branches'),
                    ),
                    ...widget.branches.map(
                      (b) => DropdownMenuItem<String?>(
                        value: b['id'].toString(),
                        child: Text(b['name'].toString()),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedBranchId = val;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  "👉 Leave as 'All Branches' to allow access to all branches.",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Add Staff',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_forward,
                              color: Colors.white,
                              size: 18,
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditStaffSheetWidget extends StatefulWidget {
  final List<Map<String, dynamic>> branches;
  final _StaffUser user;
  final Function(_StaffUser) onEdit;

  const _EditStaffSheetWidget({
    required this.branches,
    required this.user,
    required this.onEdit,
  });

  @override
  State<_EditStaffSheetWidget> createState() => _EditStaffSheetWidgetState();
}

class _EditStaffSheetWidgetState extends State<_EditStaffSheetWidget> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _whatsappCtrl;

  bool _isWhatsAppSameAsPhone = true;
  String? _selectedBranchId;
  bool _isSubmitting = false;
  late bool _isAdmin;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user.name);
    _emailCtrl = TextEditingController(text: widget.user.email);

    String phoneVal = widget.user.phone.startsWith('+91')
        ? widget.user.phone.substring(3)
        : widget.user.phone;
    _phoneCtrl = TextEditingController(text: phoneVal);
    _whatsappCtrl = TextEditingController(text: phoneVal);

    _isAdmin =
        widget.user.isOwner ||
        widget.user.role.toUpperCase() == 'LIBRARY_ADMIN' ||
        widget.user.role.toUpperCase() == 'ADMIN';

    if (!_isAdmin &&
        widget.user.branch.isNotEmpty &&
        widget.user.branch != 'All Branches') {
      try {
        _selectedBranchId = widget.branches
            .firstWhere((b) => b['name'].toString() == widget.user.branch)['id']
            .toString();
      } catch (e) {
        _selectedBranchId = null;
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);

      try {
        final token = await StorageHelper.getToken();
        if (token == null) {
          setState(() => _isSubmitting = false);
          return;
        }

        final Map<String, dynamic> payload = {
          if (_nameCtrl.text.trim().isNotEmpty) "name": _nameCtrl.text.trim(),
          if (_emailCtrl.text.trim().isNotEmpty)
            "email": _emailCtrl.text.trim(),
          if (_whatsappCtrl.text.trim().isNotEmpty)
            "whatsapp": _whatsappCtrl.text.trim(),
          if (!_isAdmin) "branchId": _selectedBranchId,
        };

        final res = await ApiService.patch(
          '/staff/${widget.user.id}',
          payload,
          token: token,
        );

        if (mounted) {
          setState(() => _isSubmitting = false);
          if (res != null && res['success'] == true) {
            final data = res['data'];

            String bName = '';
            if (data['branch'] != null) {
              if (data['branch'] is Map) {
                bName = data['branch']['name']?.toString() ?? '';
              } else {
                String bId = data['branch'].toString();
                var match = widget.branches.where(
                  (b) => b['id'].toString() == bId,
                );
                bName = match.isNotEmpty ? match.first['name'].toString() : bId;
              }
            } else if (data['staffOfBranchId'] == null && !_isAdmin) {
              bName = 'All Branches';
            }

            widget.onEdit(
              _StaffUser(
                id: widget.user.id,
                name: data['name']?.toString() ?? widget.user.name,
                role: data['role']?.toString() ?? widget.user.role,
                email: data['email']?.toString() ?? widget.user.email,
                phone: data['phone']?.toString() ?? widget.user.phone,
                branch: bName.isNotEmpty ? bName : widget.user.branch,
                isActive: (data['status']?.toString().toUpperCase() == 'ACTIVE')
                    ? true
                    : widget.user.isActive,
                isOwner: widget.user.isOwner,
              ),
            );

            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Staff updated successfully',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13),
                ),
                backgroundColor: const Color(0xFF059669),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  res?['message'] ?? 'Failed to update staff',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13),
                ),
                backgroundColor: const Color(0xFFEF4444),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSubmitting = false);

          String errMsg = e.toString().replaceAll('Exception: ', '');
          if (errMsg.contains('error: {') && errMsg.contains('message:')) {
            final match = RegExp(r'message:\s*([^,}]+)').firstMatch(errMsg);
            if (match != null) errMsg = match.group(1)?.trim() ?? errMsg;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errMsg,
                style: GoogleFonts.plusJakartaSans(fontSize: 13),
              ),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    'Edit Staff Details',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Text(
                'Name',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  hintText: 'Enter name',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF94A3B8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
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
                  filled: true,
                  fillColor: Colors.white,
                ),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: const Color(0xFF1E293B),
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Name is required'
                    : null,
              ),
              const SizedBox(height: 16),

              Text(
                'Email',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'Enter email',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF94A3B8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
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
                  filled: true,
                  fillColor: Colors.white,
                ),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: const Color(0xFF1E293B),
                ),
                validator: (val) {
                  if (val != null && val.trim().isNotEmpty) {
                    if (!RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(val)) {
                      return 'Enter a valid email address';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              Text(
                'Phone Number',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                readOnly: true,
                decoration: InputDecoration(
                  hintText: '10-digit phone number',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF94A3B8),
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '+91',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 0,
                    minHeight: 0,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                ),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: const Color(0xFF64748B),
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: _isWhatsAppSameAsPhone,
                      onChanged: (val) {
                        setState(() {
                          _isWhatsAppSameAsPhone = val ?? false;
                          if (_isWhatsAppSameAsPhone) {
                            _whatsappCtrl.text = _phoneCtrl.text;
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
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Text(
                'WhatsApp Number',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFEF4444),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _whatsappCtrl,
                keyboardType: TextInputType.phone,
                readOnly: _isWhatsAppSameAsPhone,
                decoration: InputDecoration(
                  hintText: '10-digit phone number',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF94A3B8),
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '+91',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 0,
                    minHeight: 0,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
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
                  filled: true,
                  fillColor: _isWhatsAppSameAsPhone
                      ? const Color(0xFFF8FAFC)
                      : Colors.white,
                ),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: const Color(0xFF1E293B),
                ),
                validator: (val) {
                  if (val != null &&
                      val.trim().isNotEmpty &&
                      val.trim().length != 10) {
                    return 'Must be 10 digits';
                  }
                  return null;
                },
                onChanged: (_) {
                  if (_isWhatsAppSameAsPhone) {
                    setState(() {
                      _isWhatsAppSameAsPhone = false;
                    });
                  }
                },
              ),

              if (!_isAdmin) ...[
                const SizedBox(height: 20),
                Text(
                  'Assign to Branch',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  initialValue: _selectedBranchId,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
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
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: const Color(0xFF1E293B),
                  ),
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF64748B),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All Branches'),
                    ),
                    ...widget.branches.map(
                      (b) => DropdownMenuItem<String?>(
                        value: b['id'].toString(),
                        child: Text(b['name'].toString()),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedBranchId = val;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  "👉 Leave as 'All Branches' to allow access to all branches.",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],

              const SizedBox(height: 32),

              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Save Changes →',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
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
      ),
    );
  }
}

class _StaffUser {
  final String id;
  final String name;
  final String role;
  final String email;
  final String phone;
  final String branch;
  final bool isActive;
  final bool isOwner;

  const _StaffUser({
    required this.id,
    required this.name,
    required this.role,
    required this.email,
    required this.phone,
    required this.branch,
    required this.isActive,
    required this.isOwner,
  });
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../routes/app_routes.dart';
import '../core/services/dashboard_service.dart';
import '../core/services/auth_service.dart';
import '../data/models/profile_model.dart';
import 'custom_image_widget.dart';

class AppDrawer extends StatefulWidget {
  final String activeItem;
  const AppDrawer({super.key, this.activeItem = 'Dashboard'});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  bool _studentsExpanded = false;
  bool _reportsExpanded = false;
  String _activeItem = 'Dashboard';
  String? _pendingCount;
  UserModel? _profile;

  @override
  void initState() {
    super.initState();
    _activeItem = widget.activeItem;
    _fetchPendingCount();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final profile = await AuthService.getProfile();
      if (mounted && profile != null) {
        setState(() {
          _profile = profile;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchPendingCount() async {
    try {
      final branches = await DashboardService.getBranches();
      if (branches.isNotEmpty && mounted) {
        final branchId = branches[0]['id'];
        final res = await DashboardService.getPendingStudentRequests(branchId, 1, 1);
        final total = (res['total'] is num) ? (res['total'] as num).toInt() : 0;
        if (mounted && total > 0) {
          setState(() {
            _pendingCount = total > 99 ? '99+' : total.toString();
          });
        }
      }
    } catch (_) {}
  }

  void _setActive(String item) {
    setState(() => _activeItem = item);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      backgroundColor: theme.colorScheme.surface,
      width: 280,
      child: SafeArea(
        child: Column(
          children: [
            // Profile Section
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF2563EB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: _profile?.profileImage != null && _profile!.profileImage!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: CustomImageWidget(
                              imageUrl: _profile!.profileImage,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Center(
                            child: Text(
                              _profile?.library?.name != null && _profile!.library!.name.isNotEmpty
                                  ? _profile!.library!.name[0].toUpperCase()
                                  : (_profile?.name.isNotEmpty == true
                                      ? _profile!.name[0].toUpperCase()
                                      : 'L'),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _profile?.library?.name ?? (_profile == null ? 'Loading...' : 'My Library'),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _profile?.name ?? '',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: theme.colorScheme.outlineVariant),
            // Menu Items
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dashboard
                    _DrawerItem(
                      icon: Icons.dashboard_rounded,
                      label: 'Dashboard',
                      isActive: _activeItem == 'Dashboard',
                      onTap: () {
                        _setActive('Dashboard');
                        Navigator.pushNamed(context, AppRoutes.homeScreen);
                      },
                    ),
                    const SizedBox(height: 8),
                    // MODULES Section
                    _SectionLabel(label: 'MODULES'),
                    const SizedBox(height: 4),
                    _DrawerItem(
                      icon: Icons.how_to_reg_rounded,
                      label: 'Attendance',
                      isActive: _activeItem == 'Attendance',
                      onTap: () {
                        _setActive('Attendance');
                        Navigator.pushNamed(
                          context,
                          AppRoutes.attendanceScreen,
                        );
                      },
                    ),
                    // Students Expandable
                    _ExpandableDrawerItem(
                      icon: Icons.people_rounded,
                      label: 'Students',
                      isExpanded: _studentsExpanded,
                      isActive:
                          _activeItem == 'Students' ||
                          _activeItem == 'Student List' ||
                          _activeItem == 'Add Student' ||
                          _activeItem == 'Pending Students',
                      onTap: () => setState(
                        () => _studentsExpanded = !_studentsExpanded,
                      ),
                      children: [
                        _SubItem(
                          label: 'Student List',
                          isActive: _activeItem == 'Student List',
                          onTap: () {
                            _setActive('Student List');
                            Navigator.pushNamed(
                              context,
                              AppRoutes.studentManagementScreen,
                            );
                          },
                        ),
                        _SubItem(
                          label: 'Add Student',
                          isActive: _activeItem == 'Add Student',
                          onTap: () {
                            _setActive('Add Student');
                            Navigator.pushNamed(
                              context,
                              AppRoutes.addStudentScreen,
                            );
                          },
                        ),
                        _SubItem(
                          label: 'Pending Students',
                          isActive: _activeItem == 'Pending Students',
                          onTap: () {
                            _setActive('Pending Students');
                            Navigator.pushNamed(
                              context,
                              AppRoutes.pendingStudentsScreen,
                            );
                          },
                          badge: _pendingCount,
                        ),
                      ],
                    ),
                    _DrawerItem(
                      icon: Icons.event_seat_rounded,
                      label: 'Seats',
                      isActive: _activeItem == 'Seats',
                      onTap: () {
                        _setActive('Seats');
                        Navigator.pushNamed(
                          context,
                          AppRoutes.seatManagementScreen,
                        );
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.schedule_rounded,
                      label: 'Shifts',
                      isActive: _activeItem == 'Shifts',
                      onTap: () {
                        _setActive('Shifts');
                        Navigator.pushNamed(
                          context,
                          AppRoutes.shiftManagementScreen,
                        );
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.card_membership_rounded,
                      label: 'Student Memberships',
                      isActive: _activeItem == 'Subscriptions',
                      onTap: () {
                        _setActive('Subscriptions');
                        Navigator.pushNamed(
                          context,
                          AppRoutes.subscriptionsScreen,
                        );
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.currency_rupee_rounded,
                      label: 'Revenue',
                      isActive: _activeItem == 'Revenue',
                      onTap: () {
                        _setActive('Revenue');
                        Navigator.pushNamed(context, AppRoutes.paymentsScreen);
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.pending_actions_rounded,
                      label: 'Due Payments',
                      isActive: _activeItem == 'Due Payments',
                      onTap: () {
                        _setActive('Due Payments');
                        Navigator.pushNamed(context, AppRoutes.duePaymentsScreen);
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.account_balance_rounded,
                      label: 'Branch',
                      isActive: _activeItem == 'Branch',
                      onTap: () {
                        _setActive('Branch');
                        Navigator.pushNamed(context, AppRoutes.branchScreen);
                      },
                    ),
                    // Reports Expandable
                    _ExpandableDrawerItem(
                      icon: Icons.bar_chart_rounded,
                      label: 'Reports',
                      isExpanded: _reportsExpanded,
                      isActive:
                          _activeItem == 'Reports' ||
                          _activeItem == 'Overview' ||
                          _activeItem == 'Attendance Report' ||
                          _activeItem == 'Revenue Report',
                      onTap: () =>
                          setState(() => _reportsExpanded = !_reportsExpanded),
                      children: [
                        _SubItem(
                          label: 'Overview',
                          isActive: _activeItem == 'Overview',
                          onTap: () {
                            _setActive('Overview');
                            Navigator.pushNamed(
                              context,
                              AppRoutes.libraryReportsScreen,
                            );
                          },
                        ),
                        _SubItem(
                          label: 'Attendance Report',
                          isActive: _activeItem == 'Attendance Report',
                          onTap: () {
                            _setActive('Attendance Report');
                            Navigator.pushNamed(
                              context,
                              AppRoutes.attendanceReportScreen,
                            );
                          },
                        ),
                        _SubItem(
                          label: 'Revenue Report',
                          isActive: _activeItem == 'Revenue Report',
                          onTap: () {
                            _setActive('Revenue Report');
                            Navigator.pushNamed(
                              context,
                              AppRoutes.revenueReportScreen,
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Logout
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 2,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              AppRoutes.loginScreen,
                              (route) => false,
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.logout_rounded,
                                  size: 20,
                                  color: const Color(0xFFEF4444),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Logout',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFFEF4444),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: isActive ? theme.colorScheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      color: isActive
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpandableDrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isExpanded;
  final bool isActive;
  final VoidCallback onTap;
  final List<Widget> children;

  const _ExpandableDrawerItem({
    required this.icon,
    required this.label,
    required this.isExpanded,
    required this.isActive,
    required this.onTap,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Material(
            color: isActive && !isExpanded
                ? theme.colorScheme.primaryContainer
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: isActive
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isActive
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: isActive
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Column(children: children),
          crossFadeState: isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
          sizeCurve: Curves.easeInOut,
        ),
      ],
    );
  }
}

class _SubItem extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final String? badge;

  const _SubItem({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 12, top: 1, bottom: 1),
      child: Material(
        color: isActive ? theme.colorScheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge!,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/dashboard_service.dart';
import '../../../core/utils/storage_helper.dart';
import '../../qr_registration_screen/qr_registration_dialog.dart';

class HomeHeaderWidget extends StatefulWidget {
  final Function(String branchId, String branchName)? onBranchSelected;
  final List<Map<String, dynamic>> branches;
  final String? selectedBranchId;
  const HomeHeaderWidget({
    super.key,
    this.onBranchSelected,
    required this.branches,
    this.selectedBranchId,
  });

  @override
  State<HomeHeaderWidget> createState() => _HomeHeaderWidgetState();
}

class _HomeHeaderWidgetState extends State<HomeHeaderWidget> {
  String selectedBranch = "Loading...";
  String selectedBranchId = "";
  String selectedBranchCode = ""; // code field used in QR URL
  int notificationCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeFromProps();
    loadNotifications();
  }

  void _initializeFromProps() {
    if (widget.branches.isNotEmpty) {
      final selected = widget.branches.firstWhere(
        (b) => b["id"] == widget.selectedBranchId,
        orElse: () => widget.branches[0],
      );
      selectedBranch = selected["name"] ?? "Main Branch";
      selectedBranchId = selected["id"] ?? "";
      selectedBranchCode = selected["code"]?.toString() ?? selectedBranchId;
    } else {
      selectedBranch = "No Branches Available";
      selectedBranchId = "";
      selectedBranchCode = "";
    }
  }

  @override
  void didUpdateWidget(HomeHeaderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.branches != oldWidget.branches || widget.selectedBranchId != oldWidget.selectedBranchId) {
      _initializeFromProps();
    }
  }

  List<dynamic> _notifications = [];

  // 🚀 LOAD NOTIFICATIONS ONLY
  Future<void> loadNotifications() async {
    try {
      final notif = await DashboardService.getNotifications();
      setState(() {
        _notifications = notif;
        notificationCount = notif.length;
      });
    } catch (e) {
      ////print("Notifications error: $e");
    }
  }

  Future<String> _getToken() async {
    return await StorageHelper.getToken() ?? "";
  }

  void _showNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Notifications",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  )
                ],
              ),
              const Divider(),
              Expanded(
                child: _notifications.isEmpty
                    ? Center(
                        child: Text(
                          "No new notifications",
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final notif = _notifications[index];
                          final title = notif["title"] ?? "Notification";
                          final message = notif["message"] ?? notif["body"] ?? "";
                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.notifications,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                            title: Text(
                              title.toString(),
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(message.toString()),
                          );
                        },
                      ),
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          /// ☰ MENU
          _headerAction(Icons.menu_rounded, () => Scaffold.of(context).openDrawer(), colorScheme),

          const SizedBox(width: 12),

          /// 🏷 LOGO
          Text(
            "LibSoar",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: colorScheme.primary,
            ),
          ),

          const Spacer(),

          /// 🏢 BRANCH (Pill Selector)
          Flexible(
            child: GestureDetector(
              onTap: () => showBranch(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colorScheme.primary.withValues(alpha: 0.1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.business_rounded, size: 14, color: colorScheme.primary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        selectedBranch,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: colorScheme.primary),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          /// 📷 QR
          _headerAction(Icons.qr_code_scanner_rounded, () => _openQrDialog(context), colorScheme),

          const SizedBox(width: 8),

          /// 🔔 NOTIFICATION
          Stack(
            clipBehavior: Clip.none,
            children: [
              _headerAction(Icons.notifications_none_rounded, () => _showNotifications(context), colorScheme),
              if (notificationCount > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colorScheme.error,
                      shape: BoxShape.circle,
                      border: Border.all(color: colorScheme.surface, width: 2),
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Center(
                      child: Text(
                        "$notificationCount",
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onError,
                        ),
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

  /// 🔘 HEADER ACTION BUTTON
  Widget _headerAction(IconData icon, VoidCallback onTap, ColorScheme colorScheme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }

  /// 📷 Open QR Registration Dialog
  Future<void> _openQrDialog(BuildContext context) async {
    final scaffoldCtx = context;
    String libCode = '';
    String libName = 'My Library';

    try {
      final profile = await AuthService.getProfile();
      if (profile != null && profile.library != null) {
        libName = profile.library!.name.trim();
        libCode = profile.library!.code.trim();
        if (libName.isEmpty) libName = 'My Library';
      }
    } catch (e) {
      // fallback on error
    }

    // Fallback just in case
    if (libCode.isEmpty) libCode = 'LIB262205';

    // Branch code — prefer the code field, fall back to selectedBranchId
    final bCode = selectedBranchCode.isNotEmpty
        ? selectedBranchCode
        : selectedBranchId;

    if (!scaffoldCtx.mounted) return;
    showQrRegistrationDialog(
      scaffoldCtx,
      libraryCode: libCode,
      libraryName: libName,
      branchCode: bCode,
      branchName: selectedBranch,
    );
  }

  /// 🏢 BRANCH SELECTOR
  void showBranch(BuildContext context) {
    if (widget.branches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No branches available")),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: widget.branches.map((b) {
          return ListTile(
            title: Text(b["name"] ?? ""),
            onTap: () {
              setState(() {
                selectedBranch = b["name"] ?? "";
                selectedBranchId = b["id"] ?? "";
                selectedBranchCode = b["code"]?.toString() ?? selectedBranchId;
              });
              widget.onBranchSelected?.call(selectedBranchId, selectedBranch);
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }
}
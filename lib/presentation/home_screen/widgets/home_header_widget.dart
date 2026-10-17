import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/dashboard_service.dart';
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
      Map<String, dynamic>? selected;
      for (final b in widget.branches) {
        if (b["id"] == widget.selectedBranchId) {
          selected = b;
          break;
        }
      }
      selected ??= widget.branches.first;
      selectedBranch = selected["name"]?.toString() ?? "Main Branch";
      selectedBranchId = selected["id"]?.toString() ?? "";
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
                                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;

        // Breakpoints
        final bool isNarrow = maxWidth < 360;
        final bool isCompact = maxWidth >= 360 && maxWidth < 480;
        final bool isPhablet = maxWidth >= 480 && maxWidth < 600;

        // Responsive spacing & sizing
        final double padH = isNarrow
            ? 6.0
            : (isCompact ? 10.0 : (isPhablet ? 12.0 : 16.0));
        final double padV = isNarrow
            ? 8.0
            : (isCompact ? 10.0 : 12.0);
        final double actionPad = isNarrow
            ? 5.5
            : (isCompact ? 7.0 : (isPhablet ? 8.0 : 9.0));
        final double actionIconSize = isNarrow
            ? 17.0
            : (isCompact ? 18.0 : (isPhablet ? 19.0 : 20.0));
        final double actionGap = isNarrow
            ? 4.0
            : (isCompact ? 5.5 : (isPhablet ? 6.5 : 8.0));
        final double menuBrandGap = isNarrow
            ? 4.0
            : (isCompact ? 6.0 : (isPhablet ? 8.0 : 10.0));

        final double logoHeight = isNarrow
            ? 20.0
            : (isCompact ? 22.0 : (isPhablet ? 24.0 : 26.0));
        final double logoGap = isNarrow
            ? 4.0
            : (isCompact ? 5.0 : (isPhablet ? 6.0 : 8.0));
        final double brandFontSize = isNarrow
            ? 15.0
            : (isCompact ? 17.0 : (isPhablet ? 18.5 : 20.0));

        final double pillPadH = isNarrow
            ? 5.5
            : (isCompact ? 7.5 : (isPhablet ? 8.5 : 10.0));
        final double pillPadV = isNarrow ? 5.0 : 6.0;
        final double pillIconSize = isNarrow
            ? 13.5
            : (isCompact ? 14.5 : (isPhablet ? 15.0 : 16.0));
        final double pillChevronSize = isNarrow
            ? 14.0
            : (isCompact ? 15.5 : (isPhablet ? 16.5 : 18.0));
        final double branchFontSize = isNarrow
            ? 11.0
            : (isCompact ? 11.5 : 12.0);

        // Maximum width cap for branch pill selector based on screen size
        final double maxBranchPillWidth = maxWidth >= 600
            ? 180.0
            : (maxWidth >= 480 ? 140.0 : 115.0);

        // For narrow (<360px), selector collapses to icon + chevron while retaining full tap behavior.
        // For medium & wide (>=360px), branch text is visible and shrinks with ellipsis if needed.
        final bool canShowBranchText = !isNarrow &&
            selectedBranch.isNotEmpty &&
            selectedBranch != "Loading...";

        return Container(
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(
                color: Color(0xFFF1F5F9),
                width: 1.2,
              ),
            ),
          ),
          child: Row(
            children: [
              /// ☰ LEFT GROUP: MENU + BRANDING
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _headerAction(
                    Icons.menu_rounded,
                    () => Scaffold.of(context).openDrawer(),
                    padding: actionPad,
                    iconSize: actionIconSize,
                  ),
                  SizedBox(width: menuBrandGap),
                  Image.asset(
                    "assets/images/logo_bars.png",
                    height: logoHeight,
                  ),
                  SizedBox(width: logoGap),
                  Text(
                    "LibSoar",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: brandFontSize,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: const Color(0xFF4F46E5),
                    ),
                  ),
                ],
              ),

              /// 🔹 EXPANDED RIGHT GROUP (Pushes controls right and flex-contains branch pill)
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    /// 🏢 BRANCH (Pill Selector)
                    Flexible(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxBranchPillWidth),
                        child: GestureDetector(
                          onTap: () => showBranch(context),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: pillPadH,
                              vertical: pillPadV,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.apartment_rounded,
                                  size: pillIconSize,
                                  color: const Color(0xFF4F46E5),
                                ),
                                if (canShowBranchText) ...[
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      selectedBranch,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: branchFontSize,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF4F46E5),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                                const SizedBox(width: 2),
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: pillChevronSize,
                                  color: const Color(0xFF4F46E5),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(width: actionGap),

                    /// 📷 QR
                    _headerAction(
                      Icons.qr_code_scanner_rounded,
                      () => _openQrDialog(context),
                      padding: actionPad,
                      iconSize: actionIconSize,
                    ),

                    SizedBox(width: actionGap),

                    /// 🔔 NOTIFICATION
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _headerAction(
                          Icons.notifications_none_rounded,
                          () => _showNotifications(context),
                          padding: actionPad,
                          iconSize: actionIconSize,
                        ),
                        if (notificationCount > 0)
                          Positioned(
                            right: -1,
                            top: -1,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                              child: Center(
                                child: Text(
                                  "$notificationCount",
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 🔘 HEADER ACTION BUTTON
  Widget _headerAction(
    IconData icon,
    VoidCallback onTap, {
    double padding = 9.0,
    double iconSize = 20.0,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, size: iconSize, color: const Color(0xFF64748B)),
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
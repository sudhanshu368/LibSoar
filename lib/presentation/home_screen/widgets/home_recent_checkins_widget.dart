import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/dashboard_service.dart';
import '../../../widgets/custom_image_widget.dart';

class HomeRecentCheckInsWidget extends StatefulWidget {
  final String? branchId;
  final int refreshToken;
  const HomeRecentCheckInsWidget({
    super.key,
    this.branchId,
    this.refreshToken = 0,
  });

  @override
  State<HomeRecentCheckInsWidget> createState() =>
      _HomeRecentCheckInsWidgetState();
}

class _HomeRecentCheckInsWidgetState extends State<HomeRecentCheckInsWidget> {
  List<dynamic> checkIns = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadCheckIns();
  }

  @override
  void didUpdateWidget(covariant HomeRecentCheckInsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.branchId != widget.branchId ||
        oldWidget.refreshToken != widget.refreshToken) {
      loadCheckIns();
    }
  }

  /// Parses ISO datetime or HH:mm string → "hh:mm AM/PM"
  String _formatTime(dynamic raw) {
    if (raw == null) return '';
    final str = raw.toString().trim();
    if (str.isEmpty) return '';
    try {
      // Full ISO datetime
      final dt = DateTime.parse(str).toLocal();
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$h:$m $period';
    } catch (_) {}

    // Try plain HH:mm or HH:mm:ss
    final parts = str.split(':');
    if (parts.length >= 2) {
      final hh = int.tryParse(parts[0]);
      final mm = int.tryParse(parts[1]);
      if (hh != null && mm != null) {
        final h = hh % 12 == 0 ? 12 : hh % 12;
        final m = mm.toString().padLeft(2, '0');
        final period = hh >= 12 ? 'PM' : 'AM';
        return '$h:$m $period';
      }
    }
    return str;
  }

  // 🚀 FETCH DATA
  Future<void> loadCheckIns() async {
    String? currentBranchId = widget.branchId;
    if (currentBranchId == null) {
      try {
        final branches = await DashboardService.getBranches();
        if (branches.isNotEmpty) {
          currentBranchId = branches[0]['id'];
        }
      } catch (e) {
        //print('Failed to load branches in HomeRecentCheckInsWidget: $e');
      }
    }

    if (currentBranchId == null) {
      if (mounted) {
        setState(() {
          checkIns = [];
          isLoading = false;
        });
      }
      return;
    }

    try {
      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final attendanceRes = await DashboardService.getAttendance(
        date: dateStr,
        branchId: currentBranchId,
      );
      final data = attendanceRes['data'] as List? ?? [];

      // Only keep entries that have a real checkInTime
      final checkInList = data
          .where(
            (c) =>
                c is Map &&
                (c['checkInTime'] != null &&
                    c['checkInTime'].toString().isNotEmpty),
          )
          .map((c) {
            final mapped = Map<String, dynamic>.from(c as Map);
            mapped['_formattedTime'] = _formatTime(mapped['checkInTime']);
            return mapped;
          })
          .toList();

      if (mounted) {
        setState(() {
          checkIns = checkInList;
          isLoading = false;
        });
      }
    } catch (e) {
      //print('❌ Check-in error: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surface,
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
          ],
        ),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// 🔹 HEADER
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.how_to_reg_rounded,
                  size: 18,
                  color: Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Recent Check-ins',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          /// 🔹 EMPTY STATE
          if (checkIns.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Text(
                  'No check-ins yet today',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),

          /// 🔹 LIST — only students with a checkInTime
          ...checkIns.map((c) {
            final timeLabel = c['_formattedTime']?.toString() ?? '';
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                children: [
                  /// Avatar
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: CustomImageWidget(
                        imageUrl:
                            c['avatar'] ??
                            'https://ui-avatars.com/api/?name=${Uri.encodeComponent(c['name'] ?? '')}',
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  /// Name + Seat
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c['name'] ?? '',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if ((c['seat'] ?? '').toString().isNotEmpty)
                          Text(
                            "Seat: ${c['seat']}",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),

                  /// ⏱ Check-in time
                  if (timeLabel.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 12,
                            color: Color(0xFF10B981),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            timeLabel,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

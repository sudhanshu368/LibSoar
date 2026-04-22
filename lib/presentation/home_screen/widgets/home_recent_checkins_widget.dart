import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/dashboard_service.dart';
import '../../../widgets/custom_image_widget.dart';

class HomeRecentCheckInsWidget extends StatefulWidget {
  final String? branchId;
  final int refreshToken;
  const HomeRecentCheckInsWidget({super.key, this.branchId, this.refreshToken = 0});

  @override
  State<HomeRecentCheckInsWidget> createState() =>
      _HomeRecentCheckInsWidgetState();
}

class _HomeRecentCheckInsWidgetState
    extends State<HomeRecentCheckInsWidget> {
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
      if (mounted) setState(() { checkIns = []; isLoading = false; });
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
          .where((c) =>
              c is Map &&
              (c['checkInTime'] != null &&
                  c['checkInTime'].toString().isNotEmpty))
          .map((c) {
        final mapped = Map<String, dynamic>.from(c as Map);
        mapped['_formattedTime'] = _formatTime(mapped['checkInTime']);
        return mapped;
      }).toList();

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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// 🔹 HEADER
          Row(
            children: [
              const Icon(Icons.how_to_reg, size: 16),
              const SizedBox(width: 6),
              Text(
                'Recent Check-ins',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

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
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  /// Avatar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: CustomImageWidget(
                      imageUrl: c['avatar'] ??
                          'https://ui-avatars.com/api/?name=${Uri.encodeComponent(c['name'] ?? '')}',
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),

                  /// Name + Seat
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c['name'] ?? '',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if ((c['seat'] ?? '').toString().isNotEmpty)
                          Text(
                            c['seat'].toString(),
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 13,
                          color: const Color(0xFF10B981),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          timeLabel,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ],
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
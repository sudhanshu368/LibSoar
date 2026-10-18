import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/dashboard_service.dart';

class HomeStudentRequestsWidget extends StatefulWidget {
  final String? branchId;
  final int refreshToken;

  const HomeStudentRequestsWidget({
    super.key,
    this.branchId,
    this.refreshToken = 0,
  });

  @override
  State<HomeStudentRequestsWidget> createState() =>
      _HomeStudentRequestsWidgetState();
}

class _HomeStudentRequestsWidgetState extends State<HomeStudentRequestsWidget> {
  List<Map<String, dynamic>> _requests = [];
  int _totalCount = 0;
  bool _loading = true;
  String? _actionId;

  @override
  void initState() {
    super.initState();
    loadRequests();
  }

  @override
  void didUpdateWidget(covariant HomeStudentRequestsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.branchId != widget.branchId ||
        oldWidget.refreshToken != widget.refreshToken) {
      Future.microtask(() => loadRequests());
    }
  }

  Future<void> loadRequests() async {
    setState(() => _loading = true);
    try {
      final res = await DashboardService.getPendingStudentRequests(
        widget.branchId,
      );
      if (!mounted) return;
      final raw = res["list"];
      final list = raw is List
          ? raw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];
      setState(() {
        _requests = list;
        _totalCount = (res["total"] is num)
            ? (res["total"] as num).toInt()
            : list.length;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _requests = [];
        _totalCount = 0;
        _loading = false;
      });
    }
  }

  String _seatLabel(Map<String, dynamic> r) {
    final seat = r["seat"];
    if (seat is Map) {
      final n = seat["number"] ?? seat["label"];
      if (n != null) return n.toString();
    }
    return r["seatNumber"]?.toString() ?? "—";
  }

  Future<void> _confirm(String id) async {
    setState(() => _actionId = id);
    try {
      await DashboardService.approveStudent(id);
      if (!mounted) return;
      setState(() {
        _requests.removeWhere((e) => e["id"] == id);
        _totalCount = (_totalCount - 1).clamp(0, 1 << 30);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Request confirmed")));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Could not confirm: $e")));
      }
    } finally {
      if (mounted) setState(() => _actionId = null);
    }
  }

  // Reject method removed based on request

  void _view(Map<String, dynamic> r) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final sub = r["subscription"];
        final subs = r["subscriptions"];
        Map<String, dynamic>? subMap;
        if (sub is Map) {
          subMap = Map<String, dynamic>.from(sub);
        } else if (subs is List && subs.isNotEmpty && subs[0] is Map) {
          subMap = Map<String, dynamic>.from(subs[0] as Map);
        }
        final shiftName = subMap?["shiftData"] is Map
            ? (subMap!["shiftData"] as Map)["name"]?.toString()
            : subMap?["shift"]?.toString();
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewPadding.bottom + 20,
            top: 8,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  r["name"]?.toString() ?? "Student",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                _detailRow("Phone", r["phone"]?.toString() ?? "—"),
                _detailRow("Seat", _seatLabel(r)),
                _detailRow("Status", r["status"]?.toString() ?? "—"),
                _detailRow("Gender", r["gender"]?.toString() ?? "—"),
                if (shiftName != null) _detailRow("Shift", shiftName),
                if (subMap != null) ...[
                  if (subMap["totalFee"] != null)
                    _detailRow("Fee", "₹${subMap["totalFee"]}"),
                  if (subMap["startDate"] != null)
                    _detailRow("Start", subMap["startDate"].toString()),
                  if (subMap["endDate"] != null)
                    _detailRow("End", subMap["endDate"].toString()),
                ],
                if (r["createdAt"] != null)
                  _detailRow("Requested", r["createdAt"].toString()),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (widget.branchId == null || widget.branchId!.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outline, width: 0.8),
        ),
        child: Text(
          "Select a branch to see new student requests.",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: cs.onSurfaceVariant,
          ),
        ),
      );
    }

    if (_loading) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outline, width: 0.8),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.surface,
            cs.surfaceContainerHighest.withValues(alpha: 0.45),
          ],
        ),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.person_add_rounded,
                  color: cs.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Student Requests",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const Spacer(),
              if (_totalCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "$_totalCount",
                    style: TextStyle(
                      color: cs.onPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (_requests.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  "No pending requests",
                  style: GoogleFonts.plusJakartaSans(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else ...[
            ...List.generate(_requests.length, (i) {
              final r = _requests[i];
              final id = r["id"]?.toString() ?? "";
              final busy = _actionId == id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _RequestRow(
                  index: i + 1,
                  name: r["name"]?.toString() ?? "—",
                  seat: _seatLabel(r),
                  busy: busy,
                  onView: () => _view(r),
                  onConfirm: id.isEmpty ? null : () => _confirm(id),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  final int index;
  final String name;
  final String seat;
  final bool busy;
  final VoidCallback? onView;
  final VoidCallback? onConfirm;

  const _RequestRow({
    required this.index,
    required this.name,
    required this.seat,
    required this.busy,
    this.onView,
    this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: cs.surface,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                "$index",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
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
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                Text(
                  "Seat: $seat",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (busy)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          else
            Row(
              children: [
                _actionBtn(
                  icon: Icons.visibility_outlined,
                  color: cs.primary,
                  onTap: onView,
                ),
                const SizedBox(width: 8),
                _actionBtn(
                  icon: Icons.check_circle_rounded,
                  color: const Color(0xFF10B981),
                  onTap: onConfirm,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

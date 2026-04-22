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
      final res = await DashboardService.getPendingStudentRequests(widget.branchId);
      if (!mounted) return;
      final raw = res["list"];
      final list = raw is List
          ? raw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];
      setState(() {
        _requests = list;
        _totalCount = (res["total"] is num) ? (res["total"] as num).toInt() : list.length;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Request confirmed")),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not confirm: $e")),
        );
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "New Student Requests",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "$_totalCount",
                  style: TextStyle(color: cs.onPrimary, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
            _TableHeader(cs: cs),
            const SizedBox(height: 8),
            ...List.generate(_requests.length, (i) {
              final r = _requests[i];
              final id = r["id"]?.toString() ?? "";
              final busy = _actionId == id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
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

class _TableHeader extends StatelessWidget {
  final ColorScheme cs;

  const _TableHeader({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 28,
          child: Text(
            "#",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            "Name",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        SizedBox(
          width: 52,
          child: Text(
            "Seat",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        SizedBox(
          width: 112,
          child: Text(
            "Actions",
            textAlign: TextAlign.end,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      ],
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
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 28,
              child: Text(
                "$index",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(
              width: 52,
              child: Text(
                seat,
                style: GoogleFonts.plusJakartaSans(fontSize: 12),
              ),
            ),
            SizedBox(
              width: 112,
              child: busy
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          tooltip: "View",
                          onPressed: onView,
                          icon: Icon(
                            Icons.visibility_outlined,
                            size: 20,
                            color: cs.primary,
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          tooltip: "Confirm",
                          onPressed: onConfirm,
                          icon: const Icon(
                            Icons.check_circle_outline,
                            size: 20,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

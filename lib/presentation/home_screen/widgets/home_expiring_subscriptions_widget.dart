import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../routes/app_routes.dart';
import '../../subscriptions_screen/widgets/renew_membership_dialog.dart';

enum ExpireTab { oneDay, threeDays, buffer, expired }

class HomeExpiringSubscriptionsWidget extends StatefulWidget {
  final List<dynamic> data;
  final int totalCount;
  final String? branchId;
  final int bufferDays;
  final VoidCallback? onRefresh;

  const HomeExpiringSubscriptionsWidget({
    super.key,
    required this.data,
    this.totalCount = 0,
    this.branchId,
    this.bufferDays = 0,
    this.onRefresh,
  });

  @override
  State<HomeExpiringSubscriptionsWidget> createState() => _HomeExpiringSubscriptionsWidgetState();
}

class _HomeExpiringSubscriptionsWidgetState extends State<HomeExpiringSubscriptionsWidget> {
  ExpireTab _selectedTab = ExpireTab.expired;


  Map<String, dynamic> _asMap(dynamic e) {
    if (e is Map<String, dynamic>) return e;
    if (e is Map) return Map<String, dynamic>.from(e);
    return {};
  }

  // Group data directly in build
  Map<ExpireTab, List<dynamic>> _groupData() {
    final Map<ExpireTab, List<dynamic>> grouped = {
      ExpireTab.oneDay: [],
      ExpireTab.threeDays: [],
      ExpireTab.buffer: [],
      ExpireTab.expired: [],
    };

    for (final raw in widget.data) {
      final row = _asMap(raw);
      final daysLeftVal = row["daysLeft"];
      if (daysLeftVal == null) continue;

      try {
        final daysLeft = int.parse(daysLeftVal.toString());

        if (daysLeft <= 0) {
          grouped[ExpireTab.expired]!.add(row);
        } else if (daysLeft == 1) {
          grouped[ExpireTab.oneDay]!.add(row);
        } else if (widget.bufferDays > 0 && daysLeft == widget.bufferDays) {
          // Priority to specifically configured buffer day
          grouped[ExpireTab.buffer]!.add(row);
        } else if (daysLeft >= 2 && daysLeft <= 3) {
          grouped[ExpireTab.threeDays]!.add(row);
        } else {
          // Anything else (e.g. if bufferDays is 10, then 4-9 fall here)
          grouped[ExpireTab.buffer]!.add(row);
        }
      } catch (_) {}
    }

    return grouped;
  }

  void _showRenewPopup(BuildContext context, Map<String, dynamic> row) {
    showDialog(
      context: context,
      builder: (ctx) => RenewMembershipDialog(
        subscription: row,
        branchId: widget.branchId ?? '',
        onRenewed: () {
          if (widget.onRefresh != null) {
            widget.onRefresh!();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final groupedData = _groupData();
    final currentList = groupedData[_selectedTab] ?? [];

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
        border: Border.all(
          color: cs.outline.withValues(alpha: 0.2),
        ),
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
          // 1. Title Row & View All
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEA580C).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.access_time_filled_rounded, size: 18, color: Color(0xFFEA580C)),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Expiring Memberships",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.subscriptionsScreen);
                },
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text(
                    "VIEW ALL",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 2. Filter Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterTabWidget(
                  label: "1 Day Left",
                  count: groupedData[ExpireTab.oneDay]!.length,
                  isSelected: _selectedTab == ExpireTab.oneDay,
                  onTap: () => setState(() => _selectedTab = ExpireTab.oneDay),
                ),
                const SizedBox(width: 8),
                _FilterTabWidget(
                  label: "3 Days Left",
                  count: groupedData[ExpireTab.threeDays]!.length,
                  isSelected: _selectedTab == ExpireTab.threeDays,
                  onTap: () => setState(() => _selectedTab = ExpireTab.threeDays),
                ),
                const SizedBox(width: 8),
                _FilterTabWidget(
                  label: widget.bufferDays > 0 ? "${widget.bufferDays} Day${widget.bufferDays > 1 ? 's' : ''} Left" : "Buffer Day",
                  count: groupedData[ExpireTab.buffer]!.length,
                  isSelected: _selectedTab == ExpireTab.buffer,
                  onTap: () => setState(() => _selectedTab = ExpireTab.buffer),
                ),
                const SizedBox(width: 8),
                _FilterTabWidget(
                  label: "Expired",
                  count: groupedData[ExpireTab.expired]!.length,
                  isSelected: _selectedTab == ExpireTab.expired,
                  onTap: () => setState(() => _selectedTab = ExpireTab.expired),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Table UI
          if (currentList.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  "No memberships found in this category",
                  style: GoogleFonts.plusJakartaSans(
                    color: cs.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else ...[
            ...List.generate(currentList.length, (i) {
              final row = _asMap(currentList[i]);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _StudentRowWidget(
                  index: i + 1,
                  row: row,
                  onRenew: () => _showRenewPopup(context, row),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _FilterTabWidget extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterTabWidget({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF2563EB); // Modern Blue

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withValues(alpha: 0.1) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryColor.withValues(alpha: 0.3) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? primaryColor : const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? primaryColor : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentRowWidget extends StatelessWidget {
  final int index;
  final Map<String, dynamic> row;
  final VoidCallback onRenew;

  const _StudentRowWidget({
    required this.index,
    required this.row,
    required this.onRenew,
  });

  String _formatDate(dynamic dateVal) {
    if (dateVal == null || dateVal.toString().isEmpty) return '-';
    try {
      final dtStr = dateVal.toString();
      final dt = DateTime.parse(dtStr).toLocal();
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
    } catch (e) {
      return dateVal.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = row["name"]?.toString() ?? "—";
    final expiry = _formatDate(row["endDate"]);
    final seat = row["seatNo"]?.toString().isNotEmpty == true 
        ? row["seatNo"].toString() 
        : "—";
    final shift = row["shift"]?.toString() ?? "";

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    
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
                index.toString(),
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
                  "Expires: $expiry • Seat: $seat${shift.isNotEmpty ? ' • $shift' : ''}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 32,
            child: ElevatedButton(
              onPressed: onRenew,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                "Renew",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

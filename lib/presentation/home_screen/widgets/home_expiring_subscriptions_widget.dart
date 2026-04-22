import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../routes/app_routes.dart';
import '../../subscriptions_screen/widgets/renew_membership_dialog.dart';

enum ExpireTab { oneDay, threeDays, buffer, expired }

class HomeExpiringSubscriptionsWidget extends StatefulWidget {
  final List<dynamic> data;
  final int totalCount;
  final String? branchId;
  final VoidCallback? onRefresh;

  const HomeExpiringSubscriptionsWidget({
    super.key,
    required this.data,
    this.totalCount = 0,
    this.branchId,
    this.onRefresh,
  });

  @override
  State<HomeExpiringSubscriptionsWidget> createState() => _HomeExpiringSubscriptionsWidgetState();
}

class _HomeExpiringSubscriptionsWidgetState extends State<HomeExpiringSubscriptionsWidget> {
  ExpireTab _selectedTab = ExpireTab.expired;

  int _daysBetween(DateTime from, DateTime to) {
    from = DateTime(from.year, from.month, from.day);
    to = DateTime(to.year, to.month, to.day);
    return to.difference(from).inDays;
  }

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

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final raw in widget.data) {
      final row = _asMap(raw);
      final endDateStr = row["endDate"];
      if (endDateStr == null) continue;

      try {
        final endDate = DateTime.parse(endDateStr.toString());
        final endDay = DateTime(endDate.year, endDate.month, endDate.day);
        final diff = endDay.difference(today).inDays;

        // All records are status=expired from the API so ALL go to Expired tab
        grouped[ExpireTab.expired]!.add(row);

        // Additionally categorise by endDate proximity (grace period / warning tabs)
        if (diff >= 1 && diff <= 1) {
          // exactly 1 day left
          grouped[ExpireTab.oneDay]!.add(row);
        }
        if (diff >= 2 && diff <= 3) {
          // 2-3 days left
          grouped[ExpireTab.threeDays]!.add(row);
        }
        if (diff == 0) {
          // expires today — buffer
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                  const Icon(Icons.access_time_filled_rounded, size: 18, color: Color(0xFFEA580C)),
                  const SizedBox(width: 8),
                  Text(
                    "Expiring student memberships",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    "View all",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2563EB), // Primary Blue
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
                  label: "Buffer Day",
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
            _TableHeader(cs: cs),
            const SizedBox(height: 8),
            ...List.generate(currentList.length, (i) {
              final row = _asMap(currentList[i]);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
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

class _TableHeader extends StatelessWidget {
  final ColorScheme cs;

  const _TableHeader({required this.cs});

  @override
  Widget build(BuildContext context) {
    final t = GoogleFonts.plusJakartaSans(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: cs.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          SizedBox(width: 26, child: Text("#", style: t)),
          Expanded(flex: 2, child: Text("Name", style: t)),
          Expanded(flex: 2, child: Text("Expiry", style: t)),
          SizedBox(width: 44, child: Text("Seat", style: t)),
          SizedBox(
            width: 70,
            child: Text("Action", textAlign: TextAlign.right, style: t),
          ),
        ],
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

  Map<String, dynamic> _asMap(dynamic e) {
    if (e is Map<String, dynamic>) return e;
    if (e is Map) return Map<String, dynamic>.from(e);
    return {};
  }

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
    final s = _asMap(row["student"]);
    final name = s["name"]?.toString() ?? "—";
    final expiry = _formatDate(row["endDate"]);
    final seat = s["seatNumber"]?.toString().isNotEmpty == true 
        ? s["seatNumber"].toString() 
        : "—";

    final cs = Theme.of(context).colorScheme;
    
    return Material(
      color: const Color(0xFFF8FAFC), // Light grey background per req
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Text(
                index.toString(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                name,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                expiry,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: 44,
              child: Text(
                seat,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ),
            SizedBox(
              width: 70,
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  height: 28,
                  child: ElevatedButton(
                    onPressed: onRenew,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB), // Primary Blue
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

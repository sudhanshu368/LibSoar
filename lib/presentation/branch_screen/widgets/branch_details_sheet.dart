import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/services/dashboard_service.dart';
import '../branch_screen.dart';

class BranchDetailsSheetWidget extends StatefulWidget {
  final BranchModel branch;

  const BranchDetailsSheetWidget({super.key, required this.branch});

  @override
  State<BranchDetailsSheetWidget> createState() => _BranchDetailsSheetWidgetState();
}

class _BranchDetailsSheetWidgetState extends State<BranchDetailsSheetWidget> {
  bool _isLoading = true;
  List<dynamic> _floorStats = [];
  List<dynamic> _shiftOccupancy = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final results = await Future.wait<dynamic>([
        DashboardService.getFloorStats(widget.branch.id),
        DashboardService.getShifts(widget.branch.id, true),
      ]);
      if (!mounted) return;
      setState(() {
        _floorStats = results[0];
        _shiftOccupancy = results[1];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatCurrency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Center(
            child: Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Branch Details',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Complete information about this branch',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 24),
          
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // SECTION 1: BASIC INFO
                  _buildSectionTitle('BASIC INFO'),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildInfoRow(Icons.business_outlined, 'Name', widget.branch.name),
                          const Divider(height: 24),
                          _buildInfoRow(Icons.location_on_outlined, 'Address', widget.branch.address),
                          const Divider(height: 24),
                          _buildInfoRow(Icons.phone_outlined, 'Phone', widget.branch.phone),
                          const Divider(height: 24),
                          _buildInfoRow(Icons.email_outlined, 'Email', widget.branch.email),
                          const Divider(height: 24),
                          _buildInfoRow(
                            widget.branch.isActive ? Icons.check_circle_outline : Icons.cancel_outlined, 
                            'Status', 
                            widget.branch.isActive ? 'Active' : 'Inactive',
                            iconColor: widget.branch.isActive ? Colors.green : Colors.red,
                            valueColor: widget.branch.isActive ? Colors.green : Colors.red,
                          ),
                          const Divider(height: 24),
                          _buildInfoRow(Icons.calendar_today_outlined, 'Created Date', '10 April, 2026'), // Dummy date
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // SECTION 2: STATISTICS (GRID 2x2)
                  _buildSectionTitle('STATISTICS'),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: [
                      _buildStatCard('Total Students', widget.branch.totalStudents.toString(), Icons.people_outline, Colors.blue),
                      _buildStatCard('Active Students', widget.branch.activeStudents.toString(), Icons.how_to_reg_outlined, Colors.purple),
                      _buildStatCard('Staff', widget.branch.staff.toString(), Icons.badge_outlined, Colors.orange),
                      _buildStatCard('Total Seats', widget.branch.totalSeats.toString(), Icons.chair_outlined, Colors.teal),
                      _buildStatCard('Booked Seats', widget.branch.bookedSeats.toString(), Icons.event_seat_outlined, Colors.redAccent),
                      Card(
                        elevation: 0,
                        color: const Color(0xFF4F46E5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.account_balance_wallet_outlined, color: Colors.white70, size: 24),
                              const Spacer(),
                              Text(
                                formatCurrency.format(widget.branch.revenue),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Revenue',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // SECTION 3: FLOOR BREAKDOWN
                  _buildSectionTitle('FLOOR BREAKDOWN'),
                  const SizedBox(height: 12),
                  if (_isLoading) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                  else if (_floorStats.isEmpty) Card(
                    elevation: 0, color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('No floor data available', style: GoogleFonts.plusJakartaSans(color: Colors.grey)),
                    ),
                  )
                  else Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: _floorStats.asMap().entries.map((e) {
                        final index = e.key;
                        final stat = e.value;
                        final floorName = 'Floor ${stat['floor']?.toString() ?? ''}'.trim();
                        final available = stat['available']?.toString() ?? '0';
                        final total = stat['total']?.toString() ?? '0';
                        return Column(
                          children: [
                            if (index > 0) const Divider(height: 1),
                            _buildListTile(floorName, '$available / $total available'),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // SECTION 4: SHIFT OCCUPANCY
                  _buildSectionTitle('SHIFT OCCUPANCY'),
                  const SizedBox(height: 12),
                  if (_isLoading) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                  else if (_shiftOccupancy.isEmpty) Card(
                    elevation: 0, color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('No shift data available', style: GoogleFonts.plusJakartaSans(color: Colors.grey)),
                    ),
                  )
                  else Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: _shiftOccupancy.asMap().entries.map((e) {
                          final index = e.key;
                          final shift = e.value;
                          final name = shift['name']?.toString() ?? 'Shift';
                          
                          String time = shift['timing']?.toString() ?? '';
                          if (time.isEmpty) {
                            time = '${shift['startTime'] ?? ''} - ${shift['endTime'] ?? ''}';
                          }

                          // Safety check for integers resolving as doubles magically
                          final occupancyDynamic = shift['occupancy'];
                          final int booked = occupancyDynamic is num ? occupancyDynamic.toInt() : int.tryParse(occupancyDynamic?.toString() ?? '0') ?? 0;
                          
                          final seatLimitDynamic = shift['seatLimit'];
                          final int total = seatLimitDynamic is num ? seatLimitDynamic.toInt() : int.tryParse(seatLimitDynamic?.toString() ?? '0') ?? 0;

                          Color shiftColor = Colors.blue;
                          final colorStr = shift['color']?.toString() ?? '';
                          if (colorStr.contains('emerald') || colorStr.contains('success')) {
                            shiftColor = Colors.green;
                          } else if (colorStr.contains('pink')) {
                            shiftColor = Colors.pink;
                          } else if (colorStr.contains('warning')) {
                            shiftColor = Colors.orange;
                          } else if (colorStr.contains('destructive') || colorStr.contains('danger')) {
                            shiftColor = Colors.red;
                          } else if (colorStr.contains('primary')) {
                            shiftColor = Colors.blue;
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (index > 0) const SizedBox(height: 16),
                              _buildShiftRow(name, time, booked, total, shiftColor),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: const Color(0xFF64748B),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? iconColor, Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: iconColor ?? const Color(0xFF94A3B8)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value.isEmpty ? 'N/A' : value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const Spacer(),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile(String title, String subtitle) {
    return ListTile(
      title: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1E293B),
        ),
      ),
      trailing: Text(
        subtitle,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildShiftRow(String name, String time, int booked, int total, Color color) {
    final double progress = (total > 0) ? booked / total : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                Text(
                  time,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            Text(
              '$booked / $total booked',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF334155),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade100,
            color: color,
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

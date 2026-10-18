import 'package:flutter_svg/flutter_svg.dart';
import '../../../data/models/due_payment_model.dart';
import '../../../core/app_export.dart';

class DuePaymentsTableWidget extends StatelessWidget {
  final List<DuePaymentModel> data;
  final bool isLoading;
  final Function(DuePaymentModel) onCollect;
  final Function(DuePaymentModel) onRemind;

  const DuePaymentsTableWidget({
    super.key,
    required this.data,
    required this.isLoading,
    required this.onCollect,
    required this.onRemind,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (data.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.search_off_rounded,
        title: 'No due payments found',
        description:
            'All subscriptions for this branch are fully paid or no results match your filter.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 800) {
          return _buildDesktopTable(context);
        }
        return _buildMobileList(context);
      },
    );
  }

  BadgeStatus _getBadgeStatus(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return BadgeStatus.active;
      case 'expired':
        return BadgeStatus.expired;
      case 'warning':
        return BadgeStatus.warning;
      case 'pending':
        return BadgeStatus.pending;
      default:
        return BadgeStatus.info;
    }
  }

  Widget _buildDesktopTable(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
          dataRowMinHeight: 70,
          dataRowMaxHeight: 70,
          horizontalMargin: 20,
          columnSpacing: 24,
          columns: [
            DataColumn(label: _headerText('Student Name')),
            DataColumn(label: _headerText('Seat & Shift')),
            DataColumn(label: _headerText('Amount Info')),
            DataColumn(label: _headerText('Status')),
            DataColumn(label: Center(child: _headerText('Actions'))),
          ],
          rows: data.map((item) => _buildDataRow(context, item)).toList(),
        ),
      ),
    );
  }

  DataRow _buildDataRow(BuildContext context, DuePaymentModel item) {
    return DataRow(
      cells: [
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.student.name,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: const Color(0xFF1E293B),
                ),
              ),
              Text(
                item.student.phone,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.event_seat_rounded,
                    size: 14,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    item.student.seatNumber ?? 'No Seat',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 14,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    item.shiftData.name,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Due: ₹${item.dueAmount.toStringAsFixed(0)}',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: const Color(0xFFEF4444),
                ),
              ),
              Text(
                'Paid: ₹${item.paidAmount.toStringAsFixed(0)} / ₹${item.totalFee.toStringAsFixed(0)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        DataCell(
          StatusBadgeWidget(
            label: item.status.toUpperCase(),
            status: _getBadgeStatus(item.status),
          ),
        ),
        DataCell(
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ActionButton(
                icon: Icons.payments_rounded,
                label: 'Collect',
                color: const Color(0xFF10B981),
                onTap: () => onCollect(item),
              ),
              const SizedBox(width: 8),
              _ActionButton(
                iconWidget: SvgPicture.string(
                  '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><path fill="white" d="M12.03 2c-5.52 0-10 4.48-10 10 0 1.76.46 3.41 1.26 4.85l-1.35 4.93 5.06-1.33c1.4.75 2.99 1.18 4.67 1.18 5.52 0 10-4.48 10-10S17.55 2 12.03 2zm0 18.23c-1.55 0-3.01-.41-4.28-1.12l-.3-.17-3.18.84.85-3.1-.19-.3c-.8-1.29-1.24-2.8-1.24-4.38 0-4.41 3.59-8 8-8s8 3.59 8 8-3.59 8-8 8zm4.56-6.14c-.25-.12-1.47-.73-1.7-.81-.23-.08-.39-.12-.55.12-.16.24-.63.81-.77.97-.14.16-.28.18-.53.06-.25-.12-1.05-.39-1.99-1.23-.74-.66-1.23-1.47-1.38-1.72-.15-.25-.02-.38.11-.5.11-.11.25-.29.37-.43.12-.14.16-.24.24-.41.08-.17.04-.32-.02-.45-.06-.13-.55-1.32-.75-1.81-.2-.48-.4-.41-.55-.42h-.47c-.16 0-.41.06-.63.29-.22.23-.85.83-.85 2.03s.87 2.35.99 2.51c.12.16 1.71 2.61 4.14 3.66.58.25 1.03.4 1.38.51.58.18 1.11.16 1.53.1.47-.07 1.47-.6 1.67-1.18.2-.58.2-1.08.14-1.18-.06-.1-.22-.16-.47-.28z"/></svg>',
                  width: 16,
                  height: 16,
                ),
                label: 'WhatsApp',
                color: const Color(0xFF25D366), // WhatsApp Green
                onTap: () => onRemind(item),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileList(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: data.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = data[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.student.name,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          item.student.phone,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusBadgeWidget(
                    label: item.status.toUpperCase(),
                    status: _getBadgeStatus(item.status),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _infoItem(
                    Icons.event_seat_rounded,
                    item.student.seatNumber ?? 'No Seat',
                  ),
                  const SizedBox(width: 16),
                  _infoItem(Icons.schedule_rounded, item.shiftData.name),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Due Amount',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: const Color(0xFF991B1B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '₹${item.dueAmount.toStringAsFixed(0)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            color: const Color(0xFFB91C1C),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Paid Amount',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          '₹${item.paidAmount.toStringAsFixed(0)} / ₹${item.totalFee.toStringAsFixed(0)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: const Color(0xFF475569),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _MobileActionButton(
                      icon: Icons.payments_rounded,
                      label: 'Collect Payment',
                      color: const Color(0xFF10B981),
                      onTap: () => onCollect(item),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MobileActionButton(
                      iconWidget: SvgPicture.string(
                        '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><path fill="white" d="M12.03 2c-5.52 0-10 4.48-10 10 0 1.76.46 3.41 1.26 4.85l-1.35 4.93 5.06-1.33c1.4.75 2.99 1.18 4.67 1.18 5.52 0 10-4.48 10-10S17.55 2 12.03 2zm0 18.23c-1.55 0-3.01-.41-4.28-1.12l-.3-.17-3.18.84.85-3.1-.19-.3c-.8-1.29-1.24-2.8-1.24-4.38 0-4.41 3.59-8 8-8s8 3.59 8 8-3.59 8-8 8zm4.56-6.14c-.25-.12-1.47-.73-1.7-.81-.23-.08-.39-.12-.55.12-.16.24-.63.81-.77.97-.14.16-.28.18-.53.06-.25-.12-1.05-.39-1.99-1.23-.74-.66-1.23-1.47-1.38-1.72-.15-.25-.02-.38.11-.5.11-.11.25-.29.37-.43.12-.14.16-.24.24-.41.08-.17.04-.32-.02-.45-.06-.13-.55-1.32-.75-1.81-.2-.48-.4-.41-.55-.42h-.47c-.16 0-.41.06-.63.29-.22.23-.85.83-.85 2.03s.87 2.35.99 2.51c.12.16 1.71 2.61 4.14 3.66.58.25 1.03.4 1.38.51.58.18 1.11.16 1.53.1.47-.07 1.47-.6 1.67-1.18.2-.58.2-1.08.14-1.18-.06-.1-.22-.16-.47-.28z"/></svg>',
                        width: 18,
                        height: 18,
                      ),
                      label: 'WhatsApp',
                      color: const Color(0xFF25D366), // WhatsApp Green
                      onTap: () => onRemind(item),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _headerText(String label) {
    return Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w700,
        fontSize: 12,
        color: const Color(0xFF64748B),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _infoItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF64748B)),
        const SizedBox(width: 6),
        Text(
          text,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: const Color(0xFF475569),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData? icon;
  final Widget? iconWidget;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    this.icon,
    this.iconWidget,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (iconWidget != null)
                iconWidget!
              else if (icon != null)
                Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileActionButton extends StatelessWidget {
  final IconData? icon;
  final Widget? iconWidget;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MobileActionButton({
    this.icon,
    this.iconWidget,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: iconWidget ?? Icon(icon, size: 16),
      label: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

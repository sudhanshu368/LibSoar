import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DuePaymentsFilterWidget extends StatelessWidget {
  final TextEditingController searchController;
  final String? selectedShift;
  final List<Map<String, dynamic>> shifts;
  final Function(String?) onShiftChanged;
  final VoidCallback onSearchChanged;

  const DuePaymentsFilterWidget({
    super.key,
    required this.searchController,
    required this.selectedShift,
    required this.shifts,
    required this.onShiftChanged,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 600) {
                return Row(
                  children: [
                    Expanded(flex: 3, child: _buildSearchField()),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: _buildShiftDropdown()),
                  ],
                );
              }
              return Column(
                children: [
                  _buildSearchField(),
                  const SizedBox(height: 12),
                  _buildShiftDropdown(),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextField(
        controller: searchController,
        onChanged: (_) => onSearchChanged(),
        style: GoogleFonts.plusJakartaSans(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search student or mobile...',
          hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: const Color(0xFF94A3B8),
          ),
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildShiftDropdown() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedShift,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
          hint: Text(
            'All Shifts',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: const Color(0xFF94A3B8),
            ),
          ),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('All Shifts'),
            ),
            ...shifts.map((shift) {
              return DropdownMenuItem<String>(
                value: shift['id'],
                child: Text(shift['name'] ?? 'Unknown'),
              );
            }),
          ],
          onChanged: onShiftChanged,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

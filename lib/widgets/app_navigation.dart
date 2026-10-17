import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

class AppNavigation extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  static const List<_NavItem> _items = [
    _NavItem(
      icon: Icons.grid_view_rounded,
      selectedIcon: Icons.grid_view_rounded,
      label: 'Home',
    ),
    _NavItem(
      icon: Icons.chair_outlined,
      selectedIcon: Icons.chair_rounded,
      label: 'Seat',
    ),
    _NavItem(
      icon: Icons.person_add_alt_1_outlined,
      selectedIcon: Icons.person_add_rounded,
      label: 'Add Student',
    ),
    _NavItem(
      icon: Icons.credit_card_rounded,
      selectedIcon: Icons.credit_card_rounded,
      label: 'Payment',
    ),
    _NavItem(
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  const AppNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;

    if (isTablet) {
      return NavigationRail(
        selectedIndex: currentIndex,
        onDestinationSelected: onTap,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFEEF2FF),
        labelType: NavigationRailLabelType.all,
        selectedLabelTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF4F46E5),
        ),
        unselectedLabelTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF64748B),
        ),
        destinations: _items.map((item) {
          return NavigationRailDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.selectedIcon, color: const Color(0xFF4F46E5)),
            label: Text(item.label),
          );
        }).toList(),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Color(0xFFF1F5F9),
            width: 1.2,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (index) {
              final isSelected = currentIndex == index;
              final item = _items[index];
              return Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onTap(index),
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          width: isSelected ? 58 : 36,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFEEF2FF)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            isSelected ? item.selectedIcon : item.icon,
                            size: 20,
                            color: isSelected
                                ? const Color(0xFF4F46E5)
                                : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.label,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? const Color(0xFF4F46E5)
                                : const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class AppColors {
  static const Color primary = Color(0xFF4F46E5);
}

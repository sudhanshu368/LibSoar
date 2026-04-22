import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../data/models/profile_model.dart';

class ProfilePersonalInfoWidget extends StatelessWidget {
  final UserModel? user;

  const ProfilePersonalInfoWidget({super.key, this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                const Icon(
                  Icons.person_outline_rounded,
                  size: 20,
                  color: Color(0xFF5B4FCF),
                ),
                const SizedBox(width: 8),
                Text(
                  'Personal Information',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: theme.colorScheme.outline.withValues(alpha: 0.5),
          ),
          // Email row
          _InfoRow(
            icon: Icons.email_outlined,
            label: 'Email',
            value: user?.email ?? 'N/A',
            theme: theme,
          ),
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: theme.colorScheme.outline.withValues(alpha: 0.4),
          ),
          // Phone row
          _InfoRow(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: user?.phone ?? 'N/A',
            theme: theme,
          ),
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: theme.colorScheme.outline.withValues(alpha: 0.4),
          ),
          // WhatsApp row
          _InfoRow(
            icon: Icons.message_outlined,
            label: 'WhatsApp',
            value: (user?.whatsappNumber?.isNotEmpty ?? false) ? user!.whatsappNumber : 'N/A',
            theme: theme,
          ),
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: theme.colorScheme.outline.withValues(alpha: 0.4),
          ),
          // Address row
          _InfoRow(
            icon: Icons.location_on_outlined,
            label: 'Address',
            value: user?.address ?? 'N/A',
            theme: theme,
          ),
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: theme.colorScheme.outline.withValues(alpha: 0.4),
          ),
          // Bio row
          _InfoRow(
            icon: Icons.info_outline_rounded,
            label: 'Bio',
            value: user?.bio ?? 'No bio available',
            theme: theme,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ThemeData theme;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF5B4FCF)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

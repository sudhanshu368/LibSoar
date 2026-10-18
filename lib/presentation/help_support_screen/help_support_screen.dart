import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/services/api_service.dart';
import '../../core/utils/storage_helper.dart';

// ── Model ────────────────────────────────────────────────────────────────────

class SupportTicket {
  final String id;
  final String ticketId;
  final int ticketNumber;
  final String subject;
  final String category;
  final String priority;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  SupportTicket({
    required this.id,
    required this.ticketId,
    required this.ticketNumber,
    required this.subject,
    required this.category,
    required this.priority,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> j) => SupportTicket(
    id: j['id']?.toString() ?? '',
    ticketId: j['ticketId']?.toString() ?? '',
    ticketNumber: (j['ticketNumber'] as num?)?.toInt() ?? 0,
    subject: j['subject']?.toString() ?? '',
    category: j['category']?.toString() ?? '',
    priority: j['priority']?.toString() ?? '',
    status: j['status']?.toString() ?? '',
    createdAt:
        DateTime.tryParse(j['createdAt']?.toString() ?? '') ?? DateTime.now(),
    updatedAt:
        DateTime.tryParse(j['updatedAt']?.toString() ?? '') ?? DateTime.now(),
  );
}

// ── Screen ───────────────────────────────────────────────────────────────────

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  // State
  bool _isLoading = true;
  List<SupportTicket> _tickets = [];
  String _searchQuery = '';
  int _expandedFaqIndex = -1;
  final TextEditingController _searchController = TextEditingController();

  // Stats derived from tickets
  int get _total => _tickets.length;
  int get _openCount =>
      _tickets.where((t) => t.status.toLowerCase() == 'open').length;
  int get _inProgressCount => _tickets
      .where(
        (t) =>
            t.status.toLowerCase() == 'in_progress' ||
            t.status.toLowerCase() == 'inprogress',
      )
      .length;
  int get _resolvedCount => _tickets
      .where(
        (t) =>
            t.status.toLowerCase() == 'resolved' ||
            t.status.toLowerCase() == 'closed',
      )
      .length;

  List<SupportTicket> get _filteredTickets {
    if (_searchQuery.isEmpty) return _tickets;
    final q = _searchQuery.toLowerCase();
    return _tickets
        .where(
          (t) =>
              t.subject.toLowerCase().contains(q) ||
              t.ticketId.toLowerCase().contains(q) ||
              t.category.toLowerCase().contains(q) ||
              t.status.toLowerCase().contains(q),
        )
        .toList();
  }

  // ── FAQ data ─────────────────────────────────────────────────────────────────
  final List<Map<String, String>> _faqs = [
    {
      'q': 'How do I add a new student to the system?',
      'a':
          'Go to Students > Add Student (or click Add Student in the header). Fill in the required details such as name, contact number, seat preference, and subscription plan. Once submitted, the student will appear in your active student list.',
    },
    {
      'q': 'How does the attendance system work?',
      'a':
          'The attendance system tracks daily check-ins and check-outs for each student. Students can be marked present manually or via QR code scan. You can view attendance reports filtered by date range, student, or shift from the Attendance Report section.',
    },
    {
      'q': 'Can I manage multiple library branches?',
      'a':
          'Yes! LibSoar supports multi-branch management. Navigate to the Branch section from the sidebar to add, edit, or remove branches. Each branch has its own seat layout, shifts, and student assignments.',
    },
    {
      'q': 'How do subscription renewals work?',
      'a':
          'Subscriptions can be renewed from the Subscriptions screen. You will see a list of active and expiring subscriptions. Click Renew on any subscription to extend it. The system also shows expiring subscriptions on the Home dashboard for quick action.',
    },
    {
      'q': 'How can I generate reports?',
      'a':
          'Reports are available under the Library Reports section. You can generate attendance reports, revenue reports, and student activity summaries. All reports support date range filtering and can be exported for further analysis.',
    },
    {
      'q': 'What payment modes are supported?',
      'a':
          'LibSoar supports multiple payment modes including Cash, UPI, Bank Transfer, and Card payments. You can record payments from the Payments screen and track revenue by payment method in the Revenue Report.',
    },
  ];

  final List<Map<String, dynamic>> _resources = [
    {
      'icon': Icons.menu_book_outlined,
      'title': 'User Guide',
      'color': const Color(0xFF4F46E5),
      'bg': const Color(0xFFEEF2FF),
    },
    {
      'icon': Icons.play_circle_outline_rounded,
      'title': 'Video Tutorials',
      'color': const Color(0xFFDC2626),
      'bg': const Color(0xFFFEE2E2),
    },
    {
      'icon': Icons.code_rounded,
      'title': 'API Documentation',
      'color': const Color(0xFF0284C7),
      'bg': const Color(0xFFE0F2FE),
    },
    {
      'icon': Icons.new_releases_outlined,
      'title': 'Release Notes',
      'color': const Color(0xFF059669),
      'bg': const Color(0xFFD1FAE5),
    },
  ];

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _fetchTickets();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── API: Fetch tickets ────────────────────────────────────────────────────────

  Future<void> _fetchTickets() async {
    setState(() => _isLoading = true);
    try {
      final token = await StorageHelper.getToken();
      if (token == null) return;

      final res = await ApiService.get('/support?page=1&limit=50', token);
      if (res != null && res['success'] == true && res['data'] is List) {
        final List raw = res['data'] as List;
        setState(() {
          _tickets = raw
              .map((e) => SupportTicket.fromJson(e as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Support fetch error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── API: Create ticket ────────────────────────────────────────────────────────

  Future<void> _createTicket({
    required String subject,
    required String category,
    required String priority,
    required String description,
    required VoidCallback onSuccess,
    required Function(String) onError,
    required VoidCallback setLoading,
    required VoidCallback clearLoading,
  }) async {
    setLoading();
    try {
      final token = await StorageHelper.getToken();
      final body = {
        'subject': subject.trim(),
        'category': category,
        'priority': priority.toUpperCase(),
        if (description.trim().isNotEmpty) 'description': description.trim(),
      };

      final res = await ApiService.post('/support', body, token: token);
      if (res != null && res['success'] == true) {
        final newTicket = SupportTicket.fromJson(
          res['data'] as Map<String, dynamic>,
        );
        setState(() => _tickets.insert(0, newTicket));
        onSuccess();
      } else {
        onError(res?['message'] ?? 'Failed to create ticket');
      }
    } catch (e) {
      onError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      clearLoading();
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.plusJakartaSans(fontSize: 13)),
        backgroundColor: isError
            ? const Color(0xFFEF4444)
            : const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      if (diff.inHours == 0) return '${diff.inMinutes}m ago';
      return '${diff.inHours}h ago';
    }
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  // ── Status / Priority helpers ─────────────────────────────────────────────────

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return const Color(0xFFD97706);
      case 'in_progress':
      case 'inprogress':
        return const Color(0xFF0284C7);
      case 'resolved':
      case 'closed':
        return const Color(0xFF059669);
      default:
        return const Color(0xFF64748B);
    }
  }

  Color _statusBg(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return const Color(0xFFFEF3C7);
      case 'in_progress':
      case 'inprogress':
        return const Color(0xFFE0F2FE);
      case 'resolved':
      case 'closed':
        return const Color(0xFFD1FAE5);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  Color _priorityColor(String p) {
    switch (p.toLowerCase()) {
      case 'high':
        return const Color(0xFFDC2626);
      case 'medium':
        return const Color(0xFFD97706);
      case 'low':
        return const Color(0xFF059669);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _displayStatus(String s) {
    switch (s.toLowerCase()) {
      case 'open':
        return 'Open';
      case 'in_progress':
      case 'inprogress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      case 'closed':
        return 'Closed';
      default:
        return s;
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchTickets,
          color: const Color(0xFF4F46E5),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 800;
                final leftSection = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildStatsRow(),
                    const SizedBox(height: 16),
                    _buildTicketsCard(),
                    const SizedBox(height: 16),
                    _buildFaqSection(),
                  ],
                );
                final rightSection = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildContactSupportCard(),
                    const SizedBox(height: 16),
                    _buildResourcesCard(),
                    const SizedBox(height: 16),
                    _buildSystemStatusCard(),
                  ],
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGradientHeader(context),
                    const SizedBox(height: 20),
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: leftSection),
                          const SizedBox(width: 16),
                          Expanded(flex: 1, child: rightSection),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          leftSection,
                          const SizedBox(height: 16),
                          rightSection,
                        ],
                      ),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ── Gradient Header ───────────────────────────────────────────────────────────

  Widget _buildGradientHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF2563EB)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.help_outline_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Help & Support',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Dashboard / Help & Support',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showNewTicketSheet(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.add_rounded,
                    size: 16,
                    color: Color(0xFF4F46E5),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'New Ticket',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF4F46E5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Stats Row ────────────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    final stats = [
      {
        'label': 'Total Tickets',
        'value': '$_total',
        'icon': Icons.confirmation_number_outlined,
        'iconBg': const Color(0xFFEEF2FF),
        'iconColor': const Color(0xFF4F46E5),
      },
      {
        'label': 'Open',
        'value': '$_openCount',
        'icon': Icons.folder_open_outlined,
        'iconBg': const Color(0xFFFEF3C7),
        'iconColor': const Color(0xFFD97706),
      },
      {
        'label': 'In Progress',
        'value': '$_inProgressCount',
        'icon': Icons.autorenew_rounded,
        'iconBg': const Color(0xFFE0F2FE),
        'iconColor': const Color(0xFF0284C7),
      },
      {
        'label': 'Resolved',
        'value': '$_resolvedCount',
        'icon': Icons.check_circle_outline_rounded,
        'iconBg': const Color(0xFFD1FAE5),
        'iconColor': const Color(0xFF059669),
      },
    ];

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: stats.map((s) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: s['iconBg'] as Color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  s['icon'] as IconData,
                  size: 20,
                  color: s['iconColor'] as Color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _isLoading
                        ? Container(
                            width: 28,
                            height: 20,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          )
                        : Text(
                            s['value'] as String,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                    const SizedBox(height: 2),
                    Text(
                      s['label'] as String,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Tickets Card ─────────────────────────────────────────────────────────────

  Widget _buildTicketsCard() {
    final filtered = _filteredTickets;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Your Support Tickets',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
                SizedBox(
                  width: 180,
                  height: 36,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search tickets...',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF94A3B8),
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 16,
                        color: Color(0xFF94A3B8),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 0,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Color(0xFF4F46E5),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Table header
          Container(
            color: const Color(0xFFF8FAFC),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _tableHeader('Ticket ID', flex: 2),
                _tableHeader('Subject', flex: 3),
                _tableHeader('Category', flex: 2),
                _tableHeader('Priority', flex: 2),
                _tableHeader('Status', flex: 2),
                _tableHeader('Updated', flex: 2),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.5, color: Color(0xFFE2E8F0)),

          // Content
          if (_isLoading)
            _buildLoadingState()
          else if (filtered.isEmpty)
            _buildEmptyState()
          else
            ...List.generate(filtered.length, (i) {
              final t = filtered[i];
              return Column(
                children: [
                  _buildTicketRow(t),
                  if (i < filtered.length - 1)
                    const Divider(
                      height: 1,
                      thickness: 0.4,
                      color: Color(0xFFE2E8F0),
                      indent: 16,
                    ),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _tableHeader(String label, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF64748B),
          letterSpacing: 0.3,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildTicketRow(SupportTicket t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Ticket ID
          Expanded(
            flex: 2,
            child: Text(
              '#${t.ticketId}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF4F46E5),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Subject
          Expanded(
            flex: 3,
            child: Text(
              t.subject,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF0F172A),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          // Category
          Expanded(
            flex: 2,
            child: Text(
              t.category,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: const Color(0xFF64748B),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Priority badge
          Expanded(
            flex: 2,
            child: _badge(
              t.priority.isEmpty
                  ? '-'
                  : t.priority[0].toUpperCase() +
                        t.priority.substring(1).toLowerCase(),
              _priorityColor(t.priority),
              _priorityColor(t.priority).withValues(alpha: 0.1),
            ),
          ),
          // Status badge
          Expanded(
            flex: 2,
            child: _badge(
              _displayStatus(t.status),
              _statusColor(t.status),
              _statusBg(t.status),
            ),
          ),
          // Updated
          Expanded(
            flex: 2,
            child: Text(
              _formatDate(t.updatedAt),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: const Color(0xFF94A3B8),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF4F46E5),
              strokeWidth: 2.5,
            ),
            const SizedBox(height: 14),
            Text(
              'Loading tickets...',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.inbox_outlined,
                size: 32,
                color: Color(0xFF4F46E5),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No tickets found',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isEmpty
                  ? "You haven't submitted any support tickets yet."
                  : 'No tickets match your search.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _showNewTicketSheet(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF2563EB)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Create your first ticket',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── FAQ ───────────────────────────────────────────────────────────────────────

  Widget _buildFaqSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.quiz_outlined,
                    size: 16,
                    color: Color(0xFF4F46E5),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Frequently Asked Questions',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.5, color: Color(0xFFE2E8F0)),
          ...List.generate(_faqs.length, (i) {
            final isExpanded = _expandedFaqIndex == i;
            final isLast = i == _faqs.length - 1;
            return Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isExpanded
                        ? const Color(0xFFF5F3FF)
                        : Colors.transparent,
                    borderRadius: isLast
                        ? const BorderRadius.only(
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          )
                        : BorderRadius.zero,
                  ),
                  child: InkWell(
                    onTap: () =>
                        setState(() => _expandedFaqIndex = isExpanded ? -1 : i),
                    borderRadius: isLast
                        ? const BorderRadius.only(
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          )
                        : BorderRadius.zero,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _faqs[i]['q']!,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isExpanded
                                        ? const Color(0xFF4F46E5)
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              AnimatedRotation(
                                turns: isExpanded ? 0.5 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 20,
                                  color: isExpanded
                                      ? const Color(0xFF4F46E5)
                                      : const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                          AnimatedCrossFade(
                            firstChild: const SizedBox.shrink(),
                            secondChild: Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(
                                _faqs[i]['a']!,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: const Color(0xFF475569),
                                  height: 1.6,
                                ),
                              ),
                            ),
                            crossFadeState: isExpanded
                                ? CrossFadeState.showSecond
                                : CrossFadeState.showFirst,
                            duration: const Duration(milliseconds: 200),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  const Divider(
                    height: 1,
                    thickness: 0.5,
                    color: Color(0xFFE2E8F0),
                    indent: 14,
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ── Contact Support ───────────────────────────────────────────────────────────

  Widget _buildContactSupportCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Text(
              'Contact Support',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
          const Divider(height: 1, thickness: 0.5, color: Color(0xFFE2E8F0)),
          _buildContactItem(
            icon: Icons.email_outlined,
            iconBg: const Color(0xFFEEF2FF),
            iconColor: const Color(0xFF4F46E5),
            title: 'Email Support',
            subtitle: 'contact@codesoar.io',
            note: 'Response within 24 hours',
          ),
          const Divider(
            height: 1,
            thickness: 0.5,
            color: Color(0xFFE2E8F0),
            indent: 14,
          ),
          _buildContactItem(
            icon: Icons.phone_outlined,
            iconBg: const Color(0xFFD1FAE5),
            iconColor: const Color(0xFF059669),
            title: 'Phone Support',
            subtitle: '+91 90600 33540',
            note: 'Mon-Sat, 9 AM - 6 PM',
          ),
          const Divider(
            height: 1,
            thickness: 0.5,
            color: Color(0xFFE2E8F0),
            indent: 14,
          ),
          _buildContactItem(
            icon: Icons.chat_bubble_outline_rounded,
            iconBg: const Color(0xFFDCFCE7),
            iconColor: const Color(0xFF16A34A),
            title: 'WhatsApp',
            subtitle: 'Chat with us',
            note: 'Quick responses',
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String note,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: () {},
      borderRadius: isLast
          ? const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            )
          : BorderRadius.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: const Color(0xFF4F46E5),
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    note,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }

  // ── Resources ─────────────────────────────────────────────────────────────────

  Widget _buildResourcesCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Text(
              'Resources',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
          const Divider(height: 1, thickness: 0.5, color: Color(0xFFE2E8F0)),
          ...List.generate(_resources.length, (i) {
            final r = _resources[i];
            final isLast = i == _resources.length - 1;
            return Column(
              children: [
                InkWell(
                  onTap: () {},
                  borderRadius: isLast
                      ? const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        )
                      : BorderRadius.zero,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: r['bg'] as Color,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            r['icon'] as IconData,
                            size: 16,
                            color: r['color'] as Color,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            r['title'] as String,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.open_in_new_rounded,
                          size: 14,
                          color: Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!isLast)
                  const Divider(
                    height: 1,
                    thickness: 0.5,
                    color: Color(0xFFE2E8F0),
                    indent: 14,
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ── System Status ─────────────────────────────────────────────────────────────

  Widget _buildSystemStatusCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Status',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF86EFAC), width: 0.8),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFF22C55E),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'All Systems Operational',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF15803D),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Last checked: Just now',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          color: const Color(0xFF4ADE80),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── New Ticket Bottom Sheet ───────────────────────────────────────────────────

  void _showNewTicketSheet(BuildContext context) {
    final subjectCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedCategory = 'Technical Issue';
    String selectedPriority = 'Medium';
    bool isSubmitting = false;

    final categories = [
      'Technical Issue',
      'Billing',
      'Feature Request',
      'Account',
      'Other',
    ];
    final priorities = ['Low', 'Medium', 'High'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title row
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Create New Ticket',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 22,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Fill in the details below and our team will respond shortly.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 20),

                // Subject
                _sheetLabel('Subject *'),
                const SizedBox(height: 6),
                TextField(
                  controller: subjectCtrl,
                  enabled: !isSubmitting,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: const Color(0xFF0F172A),
                  ),
                  decoration: _sheetInputDecoration(
                    'e.g. Cannot access admin panel',
                  ),
                ),
                const SizedBox(height: 14),

                // Category & Priority in a row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sheetLabel('Category'),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: selectedCategory,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: const Color(0xFF0F172A),
                            ),
                            decoration: _sheetInputDecoration(''),
                            items: categories
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ),
                                )
                                .toList(),
                            onChanged: isSubmitting
                                ? null
                                : (v) => setSheet(
                                    () => selectedCategory =
                                        v ?? selectedCategory,
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sheetLabel('Priority'),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: selectedPriority,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: const Color(0xFF0F172A),
                            ),
                            decoration: _sheetInputDecoration(''),
                            items: priorities
                                .map(
                                  (p) => DropdownMenuItem(
                                    value: p,
                                    child: Text(p),
                                  ),
                                )
                                .toList(),
                            onChanged: isSubmitting
                                ? null
                                : (v) => setSheet(
                                    () => selectedPriority =
                                        v ?? selectedPriority,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Description
                _sheetLabel('Description (Optional)'),
                const SizedBox(height: 6),
                TextField(
                  controller: descCtrl,
                  maxLines: 4,
                  enabled: !isSubmitting,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: const Color(0xFF0F172A),
                  ),
                  decoration: _sheetInputDecoration(
                    'Describe your issue in detail...',
                  ),
                ),
                const SizedBox(height: 20),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isSubmitting
                            ? [const Color(0xFF94A3B8), const Color(0xFF94A3B8)]
                            : [
                                const Color(0xFF4F46E5),
                                const Color(0xFF2563EB),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () {
                              if (subjectCtrl.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Please enter a subject',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                      ),
                                    ),
                                    backgroundColor: const Color(0xFFEF4444),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    margin: const EdgeInsets.all(16),
                                  ),
                                );
                                return;
                              }

                              _createTicket(
                                subject: subjectCtrl.text,
                                category: selectedCategory,
                                priority: selectedPriority,
                                description: descCtrl.text,
                                setLoading: () =>
                                    setSheet(() => isSubmitting = true),
                                clearLoading: () {
                                  if (ctx.mounted) {
                                    setSheet(() => isSubmitting = false);
                                  }
                                },
                                onSuccess: () {
                                  Navigator.pop(ctx);
                                  _showSnack(
                                    'Ticket submitted successfully! 🎟️',
                                  );
                                },
                                onError: (msg) =>
                                    _showSnack(msg, isError: true),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Submit Ticket',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Sheet helpers ─────────────────────────────────────────────────────────────

  Widget _sheetLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF475569),
      ),
    );
  }

  InputDecoration _sheetInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        color: const Color(0xFF94A3B8),
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
      ),
    );
  }
}

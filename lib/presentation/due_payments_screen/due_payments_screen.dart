import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/dashboard_service.dart';
import '../../core/utils/storage_helper.dart';
import '../../data/models/due_payment_model.dart';
import '../../widgets/app_drawer.dart';
import 'package:url_launcher/url_launcher.dart';
import './widgets/due_payments_header_widget.dart';
import './widgets/due_payments_filter_widget.dart';
import './widgets/due_payments_table_widget.dart';
import './widgets/collect_payment_modal.dart';

class DuePaymentsScreen extends StatefulWidget {
  const DuePaymentsScreen({super.key});

  @override
  State<DuePaymentsScreen> createState() => _DuePaymentsScreenState();
}

class _DuePaymentsScreenState extends State<DuePaymentsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedShiftId;
  List<Map<String, dynamic>> _shifts = [];
  List<DuePaymentModel> _duePayments = [];
  bool _isLoading = true;
  String? _branchId;
  Timer? _debounce;

  // Pagination
  int _currentPage = 1;
  bool _hasMore = false;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _initData() async {
    _branchId = await StorageHelper.getBranchId();
    if (_branchId != null) {
      await Future.wait([_loadShifts(), _loadDuePayments()]);
    }
  }

  Future<void> _loadShifts() async {
    try {
      final shifts = await DashboardService.getShifts(_branchId);
      setState(() {
        _shifts = shifts
            .map(
              (e) => {'id': e['id'].toString(), 'name': e['name'].toString()},
            )
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading shifts: $e');
    }
  }

  Future<void> _loadDuePayments({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _isLoading = true;
      });
    }

    try {
      final res = await DashboardService.getDetailedDuePayments(
        branchId: _branchId!,
        page: _currentPage,
        search: _searchController.text.trim(),
        shiftId: _selectedShiftId,
      );

      if (res['success'] == true) {
        final List data = res['data'] ?? [];
        final meta = res['meta']?['pagination'] ?? {};

        setState(() {
          final newItems = data
              .map((e) => DuePaymentModel.fromJson(e))
              .toList();
          if (refresh) {
            _duePayments = newItems;
          } else {
            _duePayments.addAll(newItems);
          }
          _hasMore = meta['hasMore'] ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading due payments: $e');
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _loadDuePayments(refresh: true);
    });
  }

  void _onShiftChanged(String? val) {
    setState(() => _selectedShiftId = val);
    _loadDuePayments(refresh: true);
  }

  void _onCollectPayment(DuePaymentModel item) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (context) => Center(
          child: Material(
            color: Colors.transparent,
            child: CollectPaymentModal(
              item: item,
              onPaymentRecorded: () => _loadDuePayments(refresh: true),
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => CollectPaymentModal(
          item: item,
          onPaymentRecorded: () => _loadDuePayments(refresh: true),
        ),
      );
    }
  }

  Future<void> _onSendReminder(DuePaymentModel item) async {
    final name = item.student.name;
    final due = item.dueAmount.toStringAsFixed(0);
    final phone = item.student.phone.replaceAll(RegExp(r'[^0-9+]'), '');

    final message =
        "Hi $name, this is a reminder that you have a pending due of value ₹$due for your library subscription. Kindly clear your dues at the earliest. Thank you!";

    final whatsappUrl = Uri.parse(
      "https://wa.me/$phone?text=${Uri.encodeComponent(message)}",
    );

    try {
      // First try standard wa.me link
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        // Fallback for some systems where canLaunchUrl might return false but launchUrl still works
        final bool launched = await launchUrl(
          whatsappUrl,
          mode: LaunchMode.externalApplication,
        ).catchError((_) => false);

        if (!launched && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not launch WhatsApp. Please check if it is installed or try again.',
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const AppDrawer(activeItem: 'Due Payments'),
      body: SafeArea(
        child: Column(
          children: [
            // AppBar replacement
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Builder(
                    builder: (ctx) => GestureDetector(
                      onTap: () => Scaffold.of(ctx).openDrawer(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.menu_rounded,
                          size: 20,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Due Payments',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _loadDuePayments(refresh: true),
                color: const Color(0xFF4F46E5),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      DuePaymentsHeaderWidget(
                        onRefresh: () => _loadDuePayments(refresh: true),
                      ),
                      const SizedBox(height: 16),
                      DuePaymentsFilterWidget(
                        searchController: _searchController,
                        selectedShift: _selectedShiftId,
                        shifts: _shifts,
                        onShiftChanged: _onShiftChanged,
                        onSearchChanged: _onSearchChanged,
                      ),
                      const SizedBox(height: 16),
                      DuePaymentsTableWidget(
                        data: _duePayments,
                        isLoading: _isLoading,
                        onCollect: _onCollectPayment,
                        onRemind: _onSendReminder,
                      ),
                      if (_hasMore)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: TextButton(
                            onPressed: () {
                              setState(() => _currentPage++);
                              _loadDuePayments();
                            },
                            child: Text(
                              'Load More Results',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF4F46E5),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 40),
                    ],
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

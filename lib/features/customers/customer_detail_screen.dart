import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'customers_provider.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_state.dart';
import '../../core/locale/locale_provider.dart';
import '../../core/locale/app_strings.dart';
import '../../core/models/booking.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/app_error.dart';
import '../../shared/widgets/shimmer_widgets.dart';

class CustomerDetailScreen extends ConsumerStatefulWidget {
  final int id;
  const CustomerDetailScreen({super.key, required this.id});

  @override
  ConsumerState<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen> {
  final List<Booking> _bookings = [];
  bool _loadingBookings = true;
  int _bookingPage = 1;
  int _bookingTotal = 0;
  int _bookingLastPage = 1;

  @override
  void initState() {
    super.initState();
    _fetchBookings(1);
  }

  Future<void> _fetchBookings(int page) async {
    setState(() => _loadingBookings = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/bookings/customer/${widget.id}', params: {'page': page, 'size': 10});
      final data = res.data as Map<String, dynamic>;
      final list = (data['data'] as List<dynamic>? ?? [])
          .map((e) => Booking.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() {
          _bookings.clear();
          _bookings.addAll(list);
          _bookingPage = page;
          _bookingTotal = (data['total'] as int?) ?? list.length;
          _bookingLastPage = (data['last_page'] as int?) ?? page;
          _loadingBookings = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingBookings = false);
    }
  }

  void _refreshAll() {
    ref.invalidate(customerDetailProvider(widget.id));
    _fetchBookings(1);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final detailAsync = ref.watch(customerDetailProvider(widget.id));
    return detailAsync.when(
      loading: () => const Scaffold(body: ShimmerCustomerDetail()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: AppError(
          message: 'Failed to load customer',
          onRetry: () => ref.invalidate(customerDetailProvider(widget.id)),
        ),
      ),
      data: (data) => _buildContent(data),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────
  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  String _str(Map<String, dynamic> d, List<String> keys) {
    for (final k in keys) {
      final v = d[k];
      if (v is String && v.isNotEmpty) return v;
    }
    return '';
  }

  // ─── Main content ─────────────────────────────────────────────────
  Widget _buildContent(Map<String, dynamic> data) {
    final firstName = _str(data, ['first_name', 'firstName']);
    final lastName  = _str(data, ['last_name', 'lastName']);
    final rawName   = '$firstName $lastName'.trim();
    final phone     = _str(data, ['phone_number', 'phoneNumber']);
    final altPhone  = (data['alt_phone_number'] ?? data['altPhoneNumber']) as String?;
    final notes     = data['notes'] as String?;
    final createdAt = (data['created_at'] ?? data['createdAt']) as String?;
    final isBlacklisted  = (data['isBlacklisted'] ?? data['is_blacklisted'] ?? data['blacklisted'] ?? false) as bool;
    final blacklistReason = (data['blacklist_reason'] ?? data['blacklistReason']) as String?;
    final blacklistedAt  = (data['blacklisted_at'] ?? data['blacklistedAt']) as String?;

    final stats = (data['stats'] as Map<String, dynamic>?) ?? {};
    final totalBookings = stats['totalBookings'] ?? stats['total_bookings'] ?? _bookingTotal;
    final totalSpent    = _d(stats['totalSpent'] ?? stats['total_spent']);
    final totalPaid     = _d(stats['totalPaid'] ?? stats['total_paid']);
    final outstanding   = _d(stats['totalOutstanding'] ?? stats['outstanding_balance']);
    final lastBookingDate = stats['lastBookingDate'] ?? stats['last_booking_date'];

    final initials = rawName.split(' ').where((p) => p.isNotEmpty).take(2).map((p) => p[0].toUpperCase()).join();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: () async => _refreshAll(),
        child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 190,
            pinned: true,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF0F172A),
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: 'Edit',
                onPressed: () => _showEditSheet(data),
              ),
              if (!isBlacklisted)
                IconButton(
                  icon: const Icon(Icons.block_rounded, size: 20),
                  color: const Color(0xFFEF4444),
                  tooltip: 'Blacklist',
                  onPressed: () => _showBlacklistDialog(rawName),
                )
              else
                IconButton(
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  color: const Color(0xFF10B981),
                  tooltip: 'Remove from Blacklist',
                  onPressed: () => _doUnblacklist(rawName),
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                color: const Color(0xFFEF4444),
                tooltip: 'Delete',
                onPressed: () => _showDeleteDialog(rawName),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _Header(
                initials: initials,
                name: rawName,
                phone: phone,
                isBlacklisted: isBlacklisted,
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Blacklist banner
                if (isBlacklisted)
                  _BlacklistBanner(
                    reason: blacklistReason,
                    since: blacklistedAt,
                  ),

                // Stats
                _StatsGrid(
                  totalBookings: totalBookings,
                  totalSpent: totalSpent,
                  totalPaid: totalPaid,
                  outstanding: outstanding,
                ),
                const SizedBox(height: 12),

                // Info
                _InfoCard(
                  phone: phone,
                  altPhone: altPhone,
                  createdAt: createdAt,
                  lastBookingDate: lastBookingDate?.toString(),
                  notes: notes,
                ),
                const SizedBox(height: 12),

                _BookingHistoryCard(
                  bookings: _bookings,
                  isLoading: _loadingBookings,
                  total: _bookingTotal,
                  currentPage: _bookingPage,
                  lastPage: _bookingLastPage,
                  onPageChange: _fetchBookings,
                ),
              ]),
            ),
          ),
        ],
      ),
      ),
    );
  }

  // ─── Edit ────────────────────────────────────────────────────────
  void _showEditSheet(Map<String, dynamic> data) {
    final fnCtrl = TextEditingController(text: _str(data, ['first_name', 'firstName']));
    final lnCtrl = TextEditingController(text: _str(data, ['last_name', 'lastName']));
    final phCtrl = TextEditingController(text: _str(data, ['phone_number', 'phoneNumber']));
    final apCtrl = TextEditingController(text: (data['alt_phone_number'] ?? data['altPhoneNumber'] ?? '') as String);
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditSheet(
        fnCtrl: fnCtrl,
        lnCtrl: lnCtrl,
        phCtrl: phCtrl,
        apCtrl: apCtrl,
        formKey: formKey,
        onSave: () async {
          final api = ref.read(apiClientProvider);
          await api.put('/customers/${widget.id}', data: {
            'firstName': fnCtrl.text.trim(),
            'lastName': lnCtrl.text.trim(),
            'phoneNumber': phCtrl.text.trim(),
            'altPhoneNumber': apCtrl.text.trim().isEmpty ? null : apCtrl.text.trim(),
          });
          _refreshAll();
          ref.read(customersProvider.notifier).load();
        },
      ),
    );
  }

  // ─── Blacklist ────────────────────────────────────────────────────
  void _showBlacklistDialog(String name) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => _BlacklistDialog(
        name: name,
        reasonCtrl: reasonCtrl,
        onConfirm: () async {
          final api = ref.read(apiClientProvider);
          await api.post('/customers/${widget.id}/blacklist', data: {'reason': reasonCtrl.text.trim()});
          _refreshAll();
          ref.read(customersProvider.notifier).load();
        },
      ),
    );
  }

  Future<void> _doUnblacklist(String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDialog(
        icon: Icons.check_circle_outline,
        iconColor: const Color(0xFF10B981),
        title: S.customers.removeBlacklist,
        message: S.customers.confirmRemove,
        confirmLabel: S.common.confirm,
        confirmColor: const Color(0xFF10B981),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/customers/${widget.id}/unblacklist');
      _refreshAll();
      ref.read(customersProvider.notifier).load();
    } catch (_) {}
  }

  // ─── Delete ───────────────────────────────────────────────────────
  void _showDeleteDialog(String name) {
    showDialog(
      context: context,
      builder: (ctx) => _DeleteDialog(
        name: name,
        onConfirm: () async {
          final api = ref.read(apiClientProvider);
          await api.delete('/customers/${widget.id}');
          if (mounted) {
            ref.read(customersProvider.notifier).load();
            context.go('/customers');
          }
        },
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String initials, name, phone;
  final bool isBlacklisted;
  const _Header({required this.initials, required this.name, required this.phone, required this.isBlacklisted});

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF5F3FF), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 44),
              Stack(
                children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: isBlacklisted
                          ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                          : const Color(0xFF7C3AED).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Center(
                      child: Text(
                        initials.isNotEmpty ? initials : '?',
                        style: TextStyle(
                          color: isBlacklisted ? const Color(0xFFEF4444) : const Color(0xFF7C3AED),
                          fontSize: 22, fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  if (isBlacklisted)
                    Positioned(
                      right: 0, bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                        child: const Icon(Icons.block_rounded, size: 10, color: Colors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
              const SizedBox(height: 2),
              Text(phone, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: isBlacklisted ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isBlacklisted ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0)),
                ),
                child: Text(
                  isBlacklisted ? S.customers.blacklisted : S.customers.active,
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: isBlacklisted ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

// ─── Blacklist Banner ─────────────────────────────────────────────────────────

class _BlacklistBanner extends StatelessWidget {
  final String? reason, since;
  const _BlacklistBanner({this.reason, this.since});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.block_rounded, color: Color(0xFFEF4444), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(S.customers.blacklistedCustomer,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFEF4444))),
                  if (reason?.isNotEmpty == true) ...[
                    const SizedBox(height: 3),
                    Text(reason!, style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D))),
                  ],
                  if (since?.isNotEmpty == true) ...[
                    const SizedBox(height: 2),
                    Text('${S.customers.since} ${formatDate(since!)}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
}

// ─── Stats Grid ───────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final dynamic totalBookings;
  final double totalSpent, totalPaid, outstanding;

  const _StatsGrid({
    required this.totalBookings,
    required this.totalSpent,
    required this.totalPaid,
    required this.outstanding,
  });

  @override
  Widget build(BuildContext context) {
    final count = totalBookings is int
        ? totalBookings
        : (int.tryParse(totalBookings.toString()) ?? 0);
    final hasStats = totalSpent > 0 || totalPaid > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Expanded(child: _StatTile(icon: Icons.receipt_long_outlined, label: S.customers.totalBookings, value: '$count', color: const Color(0xFF7C3AED))),
          if (hasStats) ...[
            _VDivider(),
            Expanded(child: _StatTile(icon: Icons.handshake_outlined, label: S.customers.totalSpent, value: formatCurrency(totalSpent), color: const Color(0xFFD97706))),
            _VDivider(),
            Expanded(child: _StatTile(icon: Icons.check_circle_outline_rounded, label: S.customers.totalPaid, value: formatCurrency(totalPaid), color: const Color(0xFF10B981))),
            _VDivider(),
            Expanded(child: _StatTile(
              icon: Icons.access_time_rounded,
              label: S.customers.outstanding,
              value: formatCurrency(outstanding),
              color: outstanding > 0 ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
            )),
          ],
        ],
      ),
    );
  }
}

class _VDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1, height: 40, color: const Color(0xFFF1F5F9),
        margin: const EdgeInsets.symmetric(horizontal: 4),
      );
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _StatTile({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 5),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
              textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)), textAlign: TextAlign.center),
        ],
      );
}

// ─── Info Card ───────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final String phone;
  final String? altPhone, createdAt, lastBookingDate, notes;

  const _InfoCard({required this.phone, this.altPhone, this.createdAt, this.lastBookingDate, this.notes});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF7C3AED)),
              const SizedBox(width: 6),
              Text(S.customers.customerInfo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
            ]),
            const SizedBox(height: 12),
            _InfoRow(icon: Icons.phone_outlined, label: S.newBooking.labelPhone, value: phone),
            if (altPhone?.isNotEmpty == true)
              _InfoRow(icon: Icons.phone_forwarded_outlined, label: S.newBooking.labelAltPhone, value: altPhone!),
            if (createdAt?.isNotEmpty == true)
              _InfoRow(icon: Icons.calendar_today_outlined, label: S.customers.memberSince, value: formatDate(createdAt!)),
            if (lastBookingDate?.isNotEmpty == true)
              _InfoRow(icon: Icons.event_available_outlined, label: S.customers.lastBooking, value: formatDate(lastBookingDate!)),
            if (notes?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes_rounded, size: 14, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(notes!,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontStyle: FontStyle.italic)),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
            const SizedBox(width: 10),
            SizedBox(
              width: 100,
              child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
            ),
          ],
        ),
      );
}

// ─── Booking History Card (paginated) ────────────────────────────────────────

class _BookingHistoryCard extends StatelessWidget {
  final List<Booking> bookings;
  final bool isLoading;
  final int total, currentPage, lastPage;
  final void Function(int) onPageChange;

  const _BookingHistoryCard({
    required this.bookings,
    required this.isLoading,
    required this.total,
    required this.currentPage,
    required this.lastPage,
    required this.onPageChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.receipt_long_outlined, size: 14, color: Color(0xFF7C3AED)),
            const SizedBox(width: 6),
            Text(S.customers.bookingHistory,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(6)),
              child: Text('$total',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF7C3AED))),
            ),
          ]),
          const SizedBox(height: 12),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (bookings.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Column(children: [
                const Icon(Icons.receipt_long_outlined, size: 32, color: Color(0xFFCBD5E1)),
                const SizedBox(height: 8),
                Text(S.customers.noBookings, style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
              ])),
            )
          else ...[
            ...bookings.map((b) => _BookingTile(booking: b)),
            if (lastPage > 1) ...[
              const SizedBox(height: 4),
              _PaginationBar(
                current: currentPage,
                last: lastPage,
                total: total,
                isLoading: isLoading,
                onPage: onPageChange,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  final int current, last, total;
  final bool isLoading;
  final void Function(int) onPage;

  const _PaginationBar({
    required this.current, required this.last, required this.total,
    required this.isLoading, required this.onPage,
  });

  @override
  Widget build(BuildContext context) {
    final start = (current - 1) * 10 + 1;
    final end = (current * 10).clamp(0, total);
    return Row(
      children: [
        Text('$start–$end of $total',
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        const Spacer(),
        _PageBtn(
          icon: Icons.chevron_left_rounded,
          enabled: current > 1 && !isLoading,
          onTap: () => onPage(current - 1),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(8),
          ),
          child: Text('$current / $last',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF7C3AED))),
        ),
        const SizedBox(width: 6),
        _PageBtn(
          icon: Icons.chevron_right_rounded,
          enabled: current < last && !isLoading,
          onTap: () => onPage(current + 1),
        ),
      ],
    );
  }
}

class _PageBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _PageBtn({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: enabled ? const Color(0xFFEDE9FE) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 18,
              color: enabled ? const Color(0xFF7C3AED) : const Color(0xFFCBD5E1)),
        ),
      );
}

class _BookingTile extends ConsumerWidget {
  final Booking booking;
  const _BookingTile({required this.booking});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = StatusColors.forStatus(booking.status);
    final statusBg    = StatusColors.backgroundForStatus(booking.status);
    final isCancelled = booking.isCancelled;
    final hasBalance  = booking.remainingBalance > 0 && !isCancelled;

    final user = ref.watch(authProvider).user;
    final isForeign = user != null
        && (user.isStaff || user.isBranchManager)
        && booking.branchId != null
        && booking.branchId != user.branchId;
    final branchChipColor = isForeign ? const Color(0xFF64748B) : const Color(0xFF7C3AED);
    final branchChipBg    = isForeign ? const Color(0xFFF1F5F9) : const Color(0xFFF3E8FF);

    return GestureDetector(
      onTap: () => context.push('/bookings/${booking.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    booking.invoiceNumber,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF7C3AED)),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    _statusLabel(booking.status),
                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(children: [
              if (booking.branchName != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: branchChipBg, borderRadius: BorderRadius.circular(5)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.account_tree_outlined, size: 10, color: branchChipColor),
                    const SizedBox(width: 3),
                    Text(
                      booking.branchName!,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: branchChipColor),
                    ),
                  ]),
                ),
                const SizedBox(width: 8),
              ],
              const Icon(Icons.date_range_outlined, size: 11, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${formatDate(booking.startDate)} → ${formatDate(booking.endDate)}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isCancelled ? '—' : formatCurrency(booking.totalAmount),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isCancelled ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                    decoration: isCancelled ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (hasBalance)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(6)),
                    child: Text('${formatCurrency(booking.remainingBalance)} ${S.customers.dueLabel}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFEF4444))),
                  )
                else if (!isCancelled)
                  Row(children: [
                    const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF10B981)),
                    const SizedBox(width: 3),
                    Text(S.customers.paidLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF10B981))),
                  ]),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String s) => S.status.forStatus(s);
}

// ─── Edit Sheet ───────────────────────────────────────────────────────────────

class _EditSheet extends StatefulWidget {
  final TextEditingController fnCtrl, lnCtrl, phCtrl, apCtrl;
  final GlobalKey<FormState> formKey;
  final Future<void> Function() onSave;

  const _EditSheet({
    required this.fnCtrl, required this.lnCtrl, required this.phCtrl, required this.apCtrl,
    required this.formKey, required this.onSave,
  });

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  bool _saving = false;
  String? _error;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          child: Form(
            key: widget.formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Row(children: [
                  const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 8),
                  Text(S.customers.editCustomer, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                ]),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
                    child: Text(_error!, style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444))),
                  ),
                ],
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _Field(ctrl: widget.fnCtrl, label: S.profile.firstName, required: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _Field(ctrl: widget.lnCtrl, label: S.profile.lastName, required: true)),
                ]),
                const SizedBox(height: 10),
                _Field(ctrl: widget.phCtrl, label: S.newBooking.labelPhone, keyboard: TextInputType.phone, required: true),
                const SizedBox(height: 10),
                _Field(ctrl: widget.apCtrl, label: '${S.newBooking.altPhone} ${S.common.optional}', keyboard: TextInputType.phone),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _saving
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(S.items.saveChanges, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Future<void> _save() async {
    if (!widget.formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      await widget.onSave();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      setState(() { _saving = false; _error = S.customers.failedToSave; });
    }
  }
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final bool required;
  final TextInputType? keyboard;

  const _Field({required this.ctrl, required this.label, this.required = false, this.keyboard});

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        validator: required ? (v) => v?.trim().isEmpty == true ? S.settings.staffRequired : null : null,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          isDense: true,
        ),
      );
}

// ─── Blacklist Dialog ────────────────────────────────────────────────────────

class _BlacklistDialog extends StatefulWidget {
  final String name;
  final TextEditingController reasonCtrl;
  final Future<void> Function() onConfirm;

  const _BlacklistDialog({required this.name, required this.reasonCtrl, required this.onConfirm});

  @override
  State<_BlacklistDialog> createState() => _BlacklistDialogState();
}

class _BlacklistDialogState extends State<_BlacklistDialog> {
  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.block_rounded, color: Color(0xFFEF4444), size: 20),
          const SizedBox(width: 8),
          Text(S.customers.blacklistCustomer, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(S.customers.blacklistWarning,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            const SizedBox(height: 14),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444))),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: widget.reasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: S.customers.blacklistReason,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(S.common.cancel)),
          ElevatedButton(
            onPressed: _loading ? null : _confirm,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: _loading
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(S.common.confirm, style: const TextStyle(color: Colors.white)),
          ),
        ],
      );

  Future<void> _confirm() async {
    setState(() { _loading = true; _error = null; });
    try {
      await widget.onConfirm();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      setState(() { _loading = false; _error = 'Failed. Please try again.'; });
    }
  }
}

// ─── Confirm Dialog ──────────────────────────────────────────────────────────

class _ConfirmDialog extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, message, confirmLabel;
  final Color confirmColor;

  const _ConfirmDialog({
    required this.icon, required this.iconColor, required this.title,
    required this.message, required this.confirmLabel, required this.confirmColor,
  });

  @override
  Widget build(BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
        content: Text(message, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(S.common.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
            child: Text(confirmLabel, style: const TextStyle(color: Colors.white)),
          ),
        ],
      );
}

// ─── Delete Dialog ───────────────────────────────────────────────────────────

class _DeleteDialog extends StatefulWidget {
  final String name;
  final Future<void> Function() onConfirm;
  const _DeleteDialog({required this.name, required this.onConfirm});

  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  bool _deleting = false;
  String? _error;

  @override
  Widget build(BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
          const SizedBox(width: 8),
          Text(S.customers.deleteCustomer, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 15),
                const SizedBox(width: 8),
                Expanded(child: Text(S.customers.cannotBeUndone, style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)))),
              ]),
            ),
            const SizedBox(height: 12),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444))),
              const SizedBox(height: 8),
            ],
            Text(S.customers.confirmDelete,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(S.common.cancel)),
          ElevatedButton(
            onPressed: _deleting ? null : _delete,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: _deleting
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(S.customers.deleteCustomer, style: const TextStyle(color: Colors.white)),
          ),
        ],
      );

  Future<void> _delete() async {
    setState(() { _deleting = true; _error = null; });
    try {
      await widget.onConfirm();
    } catch (_) {
      setState(() { _deleting = false; _error = S.customers.failedToDelete; });
    }
  }
}

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_state.dart';
import '../../core/locale/locale_provider.dart';
import '../../core/locale/app_strings.dart';
import '../../core/models/booking.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import 'package:go_router/go_router.dart';
import 'bookings_provider.dart';
import '../../shared/widgets/shimmer_widgets.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

class BookingDetailScreen extends ConsumerStatefulWidget {
  final int id;
  const BookingDetailScreen({super.key, required this.id});

  @override
  ConsumerState<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends ConsumerState<BookingDetailScreen> {
  Booking? _booking;
  bool _loading = true;
  String? _error;

  List<_ChangeEntry>? _logs;
  bool _loadingLogs = true;

  int? _returningItemId;
  final Map<String, bool> _expandedGroups = {};

  /// STAFF/BRANCH_MANAGER can only act on bookings from their own branch.
  /// SHOP_ADMIN can act on any branch. If the booking isn't loaded yet, treat
  /// as foreign so no action buttons flash before we know.
  bool get _isForeignBranch {
    final user = ref.read(authProvider).user;
    if (user == null) return true;
    if (!user.isStaff && !user.isBranchManager) return false;
    if (_booking == null) return true;
    return _booking!.branchId != user.branchId;
  }

  bool get _canWrite => !_isForeignBranch;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ref.read(apiClientProvider).get('/bookings/${widget.id}');
      setState(() {
        _booking = Booking.fromJson(res.data as Map<String, dynamic>);
        _loading = false;
      });
    } catch (_) {
      setState(() { _error = S.bookingDetail.failedToLoad; _loading = false; });
    }
    _fetchChangeLogs();
  }

  Future<void> _fetchChangeLogs() async {
    setState(() => _loadingLogs = true);
    try {
      final res = await ref.read(apiClientProvider).get('/bookings/${widget.id}/change-logs');
      final raw = res.data is List ? res.data as List : [];
      if (mounted) setState(() {
        _logs = raw.map((e) => _ChangeEntry.fromJson(e as Map<String, dynamic>)).toList();
        _loadingLogs = false;
      });
    } catch (_) {
      if (mounted) setState(() { _logs = []; _loadingLogs = false; });
    }
  }

  Future<void> _refresh() async {
    try {
      final res = await ref.read(apiClientProvider).get('/bookings/${widget.id}');
      if (mounted) {
        setState(() => _booking = Booking.fromJson(res.data as Map<String, dynamic>));
      }
      ref.invalidate(bookingsProvider);
    } catch (_) {}
  }

  Future<void> _markItemReturned(int itemId) async {
    setState(() => _returningItemId = itemId);
    try {
      await ref.read(apiClientProvider).post('/bookings/items/$itemId/return');
      await _refresh();
      _snack(S.bookingDetail.itemMarkedReturnedMsg);
    } catch (e) {
      _snack('Failed to mark as returned', color: const Color(0xFFEF4444));
    } finally {
      if (mounted) setState(() => _returningItemId = null);
    }
  }

  void _snack(String msg, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color ?? const Color(0xFF10B981),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ─── Action openers ────────────────────────────────────────────────────────

  void _openPickup() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickupSheet(booking: _booking!, api: ref.read(apiClientProvider)),
    );
    if (ok == true && mounted) {
      await _refresh();
      _snack(S.bookingDetail.pickedUpMsg);
    }
  }

  void _openReturn() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReturnSheet(booking: _booking!, api: ref.read(apiClientProvider)),
    );
    if (ok == true && mounted) {
      await _refresh();
      _snack(S.bookingDetail.returnedMsg);
    }
  }

  void _openCancel() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CancelSheet(booking: _booking!, api: ref.read(apiClientProvider)),
    );
    if (ok == true && mounted) {
      await _refresh();
      _snack(S.bookingDetail.cancelledMsg, color: const Color(0xFFEF4444));
    }
  }

  void _openPay() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaySheet(booking: _booking!, api: ref.read(apiClientProvider)),
    );
    if (ok == true && mounted) {
      await _refresh();
      _snack(S.bookingDetail.paymentRecordedMsg);
    }
  }

  void _openModify() async {
    final ok = await context.push<bool>('/bookings/${widget.id}/modify', extra: _booking!);
    if (ok == true && mounted) {
      await _refresh();
      _fetchChangeLogs();
      _snack(S.bookingDetail.bookingModifiedMsg);
    }
  }

  void _openEdit() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditSheet(booking: _booking!, api: ref.read(apiClientProvider)),
    );
    if (ok == true && mounted) {
      await _refresh();
      _snack(S.bookingDetail.bookingUpdatedMsg);
    }
  }

  void _openPdf() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PdfSheet(booking: _booking!, api: ref.read(apiClientProvider)),
    );
  }

  // ─── History loaders ───────────────────────────────────────────────────────


  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    if (_loading) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: const ShimmerBookingDetail(),
      );
    }
    if (_error != null || _booking == null) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFCBD5E1)),
              const SizedBox(height: 12),
              Text(_error ?? 'Not found', style: const TextStyle(color: Color(0xFF94A3B8))),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: Text(S.common.retry)),
            ],
          ),
        ),
      );
    }

    final b = _booking!;
    final statusColor = StatusColors.forStatus(b.status);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          _buildAppBar(b, statusColor),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 16),
                if (_isForeignBranch) _buildReadOnlyBanner(b),
                if (_isForeignBranch) const SizedBox(height: 12),
                _buildFinancials(b),
                const SizedBox(height: 12),
                _buildRentalPeriod(b),
                const SizedBox(height: 12),
                _buildCustomer(b),
                const SizedBox(height: 12),
                _buildItems(b),
                const SizedBox(height: 12),
                _buildChangeLogs(),
              ]),
            ),
          ),
        ],
      ),
      ),
      bottomNavigationBar: _buildBottomBar(b),
    );
  }

  // ─── App bar ───────────────────────────────────────────────────────────────

  Widget _buildAppBar(Booking b, Color statusColor) {
    final isTerminal = b.isCompleted || b.isCancelled;
    return SliverAppBar(
      expandedHeight: 130,
      pinned: true,
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF0F172A),
      leading: const BackButton(),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [statusColor.withValues(alpha: 0.08), Colors.white],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 52, 130, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    b.invoiceNumber,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    b.customerName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 4, top: 10, bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: StatusColors.backgroundForStatus(b.status),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _statusLabel(b.status),
            style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 3,
          onSelected: (v) {
            switch (v) {
              case 'modify':
                _openModify();
              case 'edit':
                _openEdit();
              case 'pdf':
                _openPdf();
              case 'cancel':
                _openCancel();
            }
          },
          itemBuilder: (_) => [
            if (!isTerminal) ...[
              if (b.isConfirmed)
                PopupMenuItem(
                  value: 'modify',
                  child: _MenuEntry(icon: Icons.tune_rounded, label: S.bookingDetail.modify),
                ),
              PopupMenuItem(
                value: 'edit',
                child: _MenuEntry(icon: Icons.edit_outlined, label: S.bookingDetail.edit),
              ),
              if (b.isConfirmed || b.isActive)
                PopupMenuItem(
                  value: 'cancel',
                  child: _MenuEntry(
                    icon: Icons.cancel_outlined,
                    label: S.bookingDetail.cancel,
                    color: Color(0xFFEF4444),
                  ),
                ),
            ],
            PopupMenuItem(
              value: 'pdf',
              child: _MenuEntry(icon: Icons.picture_as_pdf_outlined, label: S.bookingDetail.pdf),
            ),
          ],
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ─── Financials ────────────────────────────────────────────────────────────

  Widget _buildFinancials(Booking b) {
    return b.isCancelled
        ? _buildCancellationSummary(b)
        : _buildActiveSummary(b);
  }

  Widget _buildActiveSummary(Booking b) {
    final pct = b.totalAmount > 0 ? (b.amountPaid / b.totalAmount).clamp(0.0, 1.0) : 0.0;
    final depositState = _depositState(b);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SectionTitle(icon: Icons.payments_outlined, label: S.bookingDetail.financials),
              const Spacer(),
              Text(
                '${(pct * 100).toInt()}% ${S.bookingDetail.paid}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: pct >= 1 ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation(
                pct >= 1 ? const Color(0xFF10B981) : const Color(0xFF7C3AED),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _FinTile(S.bookingDetail.totalAgreed, formatCurrency(b.totalAmount), const Color(0xFF0F172A))),
              Expanded(child: _FinTile(S.bookingDetail.paid, formatCurrency(b.amountPaid), const Color(0xFF10B981))),
              Expanded(
                child: _FinTile(
                  S.bookingDetail.balance,
                  formatCurrency(b.remainingBalance),
                  b.remainingBalance > 0 ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                ),
              ),
            ],
          ),
          if (b.deposit > 0) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            _buildDepositRow(b, depositState),
          ],
        ],
      ),
    );
  }

  Widget _buildCancellationSummary(Booking b) {
    final netKept = b.amountPaid - b.refundAmount;
    final hasRefund = b.refundAmount > 0;
    final depositState = _depositState(b);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SectionTitle(icon: Icons.cancel_outlined, label: S.bookingDetail.cancellationSummary),
              const Spacer(),
              Text(
                '${S.bookingDetail.netKept}: ${formatCurrency(netKept)}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFC62828),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _FinTile(
                  S.bookingDetail.advancePaid,
                  formatCurrency(b.amountPaid),
                  const Color(0xFF6366F1),
                ),
              ),
              Expanded(
                child: _FinTileWithNote(
                  label: S.bookingDetail.refunded,
                  value: formatCurrency(b.refundAmount),
                  color: hasRefund ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                  note: hasRefund ? null : S.bookingDetail.noRefundGiven,
                ),
              ),
              Expanded(
                child: _FinTile(
                  S.bookingDetail.netKept,
                  formatCurrency(netKept),
                  const Color(0xFFC62828),
                ),
              ),
            ],
          ),
          if (b.deposit > 0) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            _buildDepositRow(b, depositState),
          ],
        ],
      ),
    );
  }

  Widget _buildDepositRow(Booking b, ({String label, Color color}) depositState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.security_rounded, size: 14, color: depositState.color),
            const SizedBox(width: 6),
            Text(
              '${S.bookingDetail.securityDeposit}  ${formatCurrency(b.deposit)}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: depositState.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                depositState.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: depositState.color,
                ),
              ),
            ),
          ],
        ),
        if (b.depositDeduction > 0) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Text(
              '${S.bookingDetail.damageDeduction}: ${formatCurrency(b.depositDeduction)}',
              style: const TextStyle(fontSize: 11, color: Color(0xFFEF4444)),
            ),
          ),
        ],
        if (b.excessDamageCharge > 0) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Text(
              '${S.bookingDetail.excessCharge}: ${formatCurrency(b.excessDamageCharge)}',
              style: const TextStyle(fontSize: 11, color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ],
    );
  }

  // ─── Rental period ─────────────────────────────────────────────────────────

  Widget _buildRentalPeriod(Booking b) {
    final days = daysBetween(b.startDate, b.endDate);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(icon: Icons.calendar_month_outlined, label: S.bookingDetail.rentalPeriod),
          const SizedBox(height: 12),
          _InfoRow(S.bookingDetail.pickupDate, formatDateLong(b.startDate)),
          _InfoRow(S.bookingDetail.returnDate, formatDateLong(b.endDate)),
          _InfoRow(S.bookingDetail.duration, '$days ${days != 1 ? S.newBooking.rentalDaysPlural : S.newBooking.rentalDays}'),
          if (b.branchName != null) _InfoRow(S.bookingDetail.branch, b.branchName!),
          if (b.notes?.isNotEmpty == true)
            _InfoRow(b.isCancelled ? S.bookingDetail.reason : S.bookingDetail.notes, b.notes!),
        ],
      ),
    );
  }

  // ─── Customer ──────────────────────────────────────────────────────────────

  Widget _buildCustomer(Booking b) {
    final initials = b.customerName.trim().split(' ').where((p) => p.isNotEmpty).take(2).map((p) => p[0].toUpperCase()).join();
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(icon: Icons.person_outline_rounded, label: S.bookingDetail.customer),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(
                  child: Text(
                    initials.isNotEmpty ? initials : '?',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF7C3AED),
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
                      b.customerName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined, size: 13, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Text(b.phoneNumber,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                      ],
                    ),
                    if (b.altPhoneNumber?.isNotEmpty == true) ...[
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined, size: 13, color: Color(0xFFCBD5E1)),
                          const SizedBox(width: 4),
                          Text(b.altPhoneNumber!,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Items ─────────────────────────────────────────────────────────────────

  Widget _buildItems(Booking b) {
    final isPickedUp = b.status.toUpperCase() == 'PICKED_UP';

    // Group items by unique code (same as Vue's groupedBookingItems)
    final Map<String, List<BookingItem>> groups = {};
    for (final item in b.items) {
      groups.putIfAbsent(item.item.code, () => []).add(item);
    }

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Icons.inventory_2_outlined,
            label: '${b.items.length} ${b.items.length != 1 ? S.bookingDetail.items : S.bookingDetail.items}',
          ),
          const SizedBox(height: 4),
          ...groups.entries.map((entry) {
            final code = entry.key;
            final units = entry.value;
            final isExpanded = _expandedGroups[code] ?? false;
            final allReturned = units.every((u) => u.isReturned);
            final isMulti = units.length > 1;

            return Column(
              children: [
                // ── Group header row ──
                InkWell(
                  onTap: isMulti
                      ? () => setState(() =>
                          _expandedGroups[code] = !isExpanded)
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: allReturned
                                ? const Color(0xFFF0FDF4)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(
                            Icons.inventory_2_outlined,
                            size: 18,
                            color: allReturned
                                ? const Color(0xFF10B981)
                                : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                units.first.item.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                code,
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        ),
                        // Actions / chips
                        if (isMulti) ...[
                          _ItemChip('×${units.length}',
                              color: const Color(0xFF7C3AED),
                              bg: const Color(0xFFEDE9FE)),
                          const SizedBox(width: 6),
                          if (allReturned)
                            _ItemChip(S.bookingDetail.allReturned,
                                color: const Color(0xFF10B981),
                                bg: const Color(0xFFF0FDF4)),
                          Icon(
                            isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 20,
                            color: const Color(0xFF94A3B8),
                          ),
                        ] else ...[
                          if (units.first.isReturned)
                            _ItemChip(S.bookingDetail.returned,
                                color: const Color(0xFF10B981),
                                bg: const Color(0xFFF0FDF4))
                          else if (isPickedUp && _canWrite)
                            _ReturnButton(
                              loading: _returningItemId == units.first.id,
                              onPressed: () =>
                                  _markItemReturned(units.first.id),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),

                // ── Expanded unit sub-rows ──
                if (isMulti && isExpanded)
                  ...units.asMap().entries.map((e) {
                    final idx = e.key;
                    final unit = e.value;
                    final isReturning = _returningItemId == unit.id;
                    return Padding(
                      padding: const EdgeInsets.only(left: 16, bottom: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.subdirectory_arrow_right_rounded,
                              size: 14, color: Color(0xFFCBD5E1)),
                          const SizedBox(width: 8),
                          Text(
                            '${S.bookingDetail.unitLabel} ${idx + 1}',
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500),
                          ),
                          const Spacer(),
                          if (unit.isReturned)
                            _ItemChip(S.bookingDetail.returned,
                                color: const Color(0xFF10B981),
                                bg: const Color(0xFFF0FDF4))
                          else if (isPickedUp && _canWrite)
                            _ReturnButton(
                              loading: isReturning,
                              onPressed: () => _markItemReturned(unit.id),
                            ),
                        ],
                      ),
                    );
                  }),

                const Divider(height: 1),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ─── Change logs ───────────────────────────────────────────────────────────

  Widget _buildChangeLogs() {
    // Loading state
    if (_loadingLogs) {
      return _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(icon: Icons.history_rounded, label: S.bookingDetail.changeHistory),
            const SizedBox(height: 16),
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C3AED)),
              ),
            ),
          ],
        ),
      );
    }

    // Empty state — hide the card entirely
    if (_logs == null || _logs!.isEmpty) return const SizedBox.shrink();

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_rounded, size: 15, color: Color(0xFF7C3AED)),
              const SizedBox(width: 6),
              Text(S.bookingDetail.changeHistory,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('${_logs!.length}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF7C3AED))),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._logs!.asMap().entries.map((entry) {
            final idx = entry.key;
            final log = entry.value;
            final isLast = idx == _logs!.length - 1;
            return _TimelineEntry(log: log, isLast: isLast);
          }),
        ],
      ),
    );
  }

  // ─── Read-only banner (foreign branch) ────────────────────────────────────

  Widget _buildReadOnlyBanner(Booking b) {
    final locale = ref.read(localeProvider);
    final branch = b.branchName ?? '';
    final msg = locale == 'am'
        ? 'ይህ ማስያዝ የ$branch ነው። ማየት ብቻ ይችላሉ፣ ማስተካከል አይችሉም።'
        : 'This booking belongs to $branch. You can view but not edit bookings from other branches.';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.account_tree_outlined, color: Color(0xFF2563EB), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(fontSize: 13, color: Color(0xFF1E3A8A), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Bottom bar ────────────────────────────────────────────────────────────

  Widget? _buildBottomBar(Booking b) {
    final pad = MediaQuery.of(context).padding.bottom;

    // Foreign-branch users see PDF only, regardless of status.
    if (b.isCompleted || b.isCancelled || !_canWrite) {
      return Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, pad + 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
        ),
        child: OutlinedButton.icon(
          onPressed: _openPdf,
          icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
          label: Text(S.bookingDetail.pdf),
        ),
      );
    }

    if (b.isConfirmed) {
      return Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, pad + 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
        ),
        child: Row(
          children: [
            OutlinedButton(
              onPressed: _openCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                side: const BorderSide(color: Color(0xFFEF4444)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
              child: Text(S.bookingDetail.cancel),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _openPickup,
                icon: const Icon(Icons.directions_walk_rounded, size: 18),
                label: Text(S.bookingDetail.markPickedUp),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (b.isActive) {
      final hasBalance = b.remainingBalance > 0;
      return Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, pad + 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
        ),
        child: Row(
          children: [
            if (hasBalance) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: _openPay,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF3B82F6),
                    side: const BorderSide(color: Color(0xFF3B82F6)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(S.bookingDetail.collectButton, style: const TextStyle(fontSize: 11)),
                      Text(
                        formatCurrency(b.remainingBalance),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: hasBalance ? 1 : 2,
              child: ElevatedButton.icon(
                onPressed: _openReturn,
                icon: const Icon(Icons.assignment_return_outlined, size: 18),
                label: Text(S.bookingDetail.markReturned),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return null;
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  String _statusLabel(String s) => S.status.forStatus(s.toUpperCase());

  ({String label, Color color}) _depositState(Booking b) {
    if (b.isConfirmed || b.isActive) {
      return (label: S.bookingDetail.held, color: const Color(0xFF3B82F6));
    }
    if (b.depositReturned && b.depositDeduction == 0) {
      return (label: S.bookingDetail.depositReturned, color: const Color(0xFF10B981));
    }
    if (b.depositDeduction > 0 && b.depositDeduction < b.deposit) {
      return (label: S.bookingDetail.depositPartial, color: const Color(0xFFF59E0B));
    }
    if (b.depositDeduction >= b.deposit || b.excessDamageCharge > 0) {
      return (label: S.bookingDetail.depositKeptDamage, color: const Color(0xFFEF4444));
    }
    return (label: S.bookingDetail.depositPending, color: const Color(0xFF94A3B8));
  }
}

// ─── Sheet: Mark Picked Up ────────────────────────────────────────────────────

class _PickupSheet extends StatefulWidget {
  final Booking booking;
  final ApiClient api;
  const _PickupSheet({required this.booking, required this.api});

  @override
  State<_PickupSheet> createState() => _PickupSheetState();
}

class _PickupSheetState extends State<_PickupSheet> {
  late final TextEditingController _amountCtrl;
  final _depositCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.booking.remainingBalance > 0
          ? widget.booking.remainingBalance.toStringAsFixed(2)
          : '',
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _depositCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await widget.api.post(
        '/bookings/${widget.booking.id}/pickup',
        data: {
          'amount': double.tryParse(_amountCtrl.text) ?? 0,
          if (_depositCtrl.text.isNotEmpty)
            'securityDeposit': double.tryParse(_depositCtrl.text) ?? 0,
        },
      );
      nav.pop(true);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(_apiError(e)), backgroundColor: const Color(0xFFEF4444)),
      );
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    return _SheetScaffold(
      title: S.bookingDetail.markPickedUp,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetBookingRef(b),
          const SizedBox(height: 20),
          _label(S.bookingDetail.paymentCollection),
          const SizedBox(height: 8),
          if (b.remainingBalance > 0)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 8),
                  Text(
                    '${S.bookingDetail.balanceDue}: ${formatCurrency(b.remainingBalance)}',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: S.bookingDetail.amountCollected,
              hintText: '0.00',
              prefixIcon: const Icon(Icons.payments_outlined, size: 20),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _depositCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: S.bookingDetail.securityDepositOptional,
              hintText: '0.00',
              prefixIcon: const Icon(Icons.security_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _confirm,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.directions_walk_rounded, size: 18),
              label: Text(S.bookingDetail.confirmPickup),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sheet: Mark Returned ─────────────────────────────────────────────────────

class _ReturnSheet extends StatefulWidget {
  final Booking booking;
  final ApiClient api;
  const _ReturnSheet({required this.booking, required this.api});

  @override
  State<_ReturnSheet> createState() => _ReturnSheetState();
}

class _ReturnSheetState extends State<_ReturnSheet> {
  late final TextEditingController _amountCtrl;
  final _damageAmtCtrl = TextEditingController();
  final _damageReasonCtrl = TextEditingController();
  String _damageChoice = 'none'; // 'none' | 'damage'
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.booking.remainingBalance > 0
          ? widget.booking.remainingBalance.toStringAsFixed(2)
          : '',
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _damageAmtCtrl.dispose();
    _damageReasonCtrl.dispose();
    super.dispose();
  }

  double get _damageAmt => double.tryParse(_damageAmtCtrl.text) ?? 0;

  Future<void> _confirm() async {
    if (_damageChoice == 'damage' && _damageAmtCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.bookingDetail.enterDamageAmountMsg), backgroundColor: const Color(0xFFEF4444)),
      );
      return;
    }
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await widget.api.post(
        '/bookings/${widget.booking.id}/complete-return',
        data: {
          'amount': double.tryParse(_amountCtrl.text) ?? 0,
          'damageAmount': _damageChoice == 'damage' ? _damageAmt : 0,
          if (_damageChoice == 'damage' && _damageReasonCtrl.text.isNotEmpty)
            'damageReason': _damageReasonCtrl.text.trim(),
        },
      );
      nav.pop(true);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(_apiError(e)), backgroundColor: const Color(0xFFEF4444)),
      );
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final deposit = b.deposit;

    return _SheetScaffold(
      title: S.bookingDetail.markReturned,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetBookingRef(b),
          const SizedBox(height: 20),

          // Final payment
          _label(S.bookingDetail.finalPayment),
          const SizedBox(height: 8),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: S.bookingDetail.amountCollected,
              hintText: '0.00',
              prefixIcon: const Icon(Icons.payments_outlined, size: 20),
            ),
          ),

          // Damage assessment
          if (deposit > 0) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.security_rounded, size: 13, color: Color(0xFF64748B)),
                const SizedBox(width: 5),
                Text('${S.bookingDetail.securityDeposit}: ${formatCurrency(deposit)}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ],
            ),
          ],
          const SizedBox(height: 20),
          _label(S.bookingDetail.itemCondition),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _ChoiceCard(
                  selected: _damageChoice == 'none',
                  icon: Icons.check_circle_outline_rounded,
                  label: S.bookingDetail.noDamage,
                  color: const Color(0xFF10B981),
                  onTap: () => setState(() {
                    _damageChoice = 'none';
                    _damageAmtCtrl.clear();
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ChoiceCard(
                  selected: _damageChoice == 'damage',
                  icon: Icons.warning_amber_rounded,
                  label: S.bookingDetail.damageFound,
                  color: const Color(0xFFEF4444),
                  onTap: () => setState(() => _damageChoice = 'damage'),
                ),
              ),
            ],
          ),
          if (_damageChoice == 'damage') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _damageAmtCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: S.bookingDetail.totalDamageAmount,
                hintText: '0.00',
                prefixIcon: const Icon(Icons.warning_amber_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _damageReasonCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: S.bookingDetail.describeTheDamage,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 20),
                  child: Icon(Icons.notes_rounded, size: 20),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _SettlementSummary(mode: _damageChoice, damage: _damageAmt, deposit: deposit),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _confirm,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.assignment_return_outlined, size: 18),
              label: Text(S.bookingDetail.completeReturn),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sheet: Cancel ────────────────────────────────────────────────────────────

class _CancelSheet extends StatefulWidget {
  final Booking booking;
  final ApiClient api;
  const _CancelSheet({required this.booking, required this.api});

  @override
  State<_CancelSheet> createState() => _CancelSheetState();
}

class _CancelSheetState extends State<_CancelSheet> {
  String _refundMode = 'none'; // 'full' | 'none' | 'custom'
  final _customAmtCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  String _damageChoice = 'none';
  final _damageAmtCtrl = TextEditingController();
  final _damageReasonCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _customAmtCtrl.dispose();
    _reasonCtrl.dispose();
    _damageAmtCtrl.dispose();
    _damageReasonCtrl.dispose();
    super.dispose();
  }

  double get _refundAmt {
    if (_refundMode == 'full') return widget.booking.amountPaid;
    if (_refundMode == 'none') return 0;
    final parsed = double.tryParse(_customAmtCtrl.text) ?? 0;
    return parsed.clamp(0, widget.booking.amountPaid);
  }

  bool get _customExceedsMax {
    if (_refundMode != 'custom') return false;
    final parsed = double.tryParse(_customAmtCtrl.text) ?? 0;
    return parsed > widget.booking.amountPaid;
  }

  Future<void> _confirm() async {
    if (_customExceedsMax) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Refund cannot exceed advance paid (${formatCurrency(widget.booking.amountPaid)})'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      return;
    }
    final refund = _refundAmt;
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await widget.api.post(
        '/bookings/${widget.booking.id}/cancel',
        data: {
          'refundAmount': refund,
          if (_reasonCtrl.text.isNotEmpty) 'cancellationReason': _reasonCtrl.text.trim(),
          if (widget.booking.isActive) ...{
            'damageAmount': _damageChoice == 'damage' ? (double.tryParse(_damageAmtCtrl.text) ?? 0) : 0,
            if (_damageChoice == 'damage' && _damageReasonCtrl.text.isNotEmpty)
              'damageReason': _damageReasonCtrl.text.trim(),
          },
        },
      );
      nav.pop(true);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(_apiError(e)), backgroundColor: const Color(0xFFEF4444)),
      );
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final keeps = b.amountPaid - _refundAmt;

    return _SheetScaffold(
      title: S.bookingDetail.cancel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetBookingRef(b),
          const SizedBox(height: 20),

          // Refund section
          _label(S.bookingDetail.refundAmount),
          const SizedBox(height: 8),
          Text(
            '${S.bookingDetail.advancePaid}: ${formatCurrency(b.amountPaid)}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ChoiceCard(
                  selected: _refundMode == 'full',
                  icon: Icons.undo_rounded,
                  label: S.bookingDetail.fullRefund,
                  color: const Color(0xFF10B981),
                  onTap: () => setState(() => _refundMode = 'full'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ChoiceCard(
                  selected: _refundMode == 'none',
                  icon: Icons.block_rounded,
                  label: S.bookingDetail.noRefund,
                  color: const Color(0xFFEF4444),
                  onTap: () => setState(() => _refundMode = 'none'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ChoiceCard(
                  selected: _refundMode == 'custom',
                  icon: Icons.tune_rounded,
                  label: S.bookingDetail.custom,
                  color: const Color(0xFF7C3AED),
                  onTap: () => setState(() => _refundMode = 'custom'),
                ),
              ),
            ],
          ),
          if (_refundMode == 'custom') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _customAmtCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: '${S.bookingDetail.refundAmount} (max ${formatCurrency(b.amountPaid)})',
                hintText: '0.00',
                prefixIcon: const Icon(Icons.payments_outlined, size: 20),
                errorText: _customExceedsMax
                    ? 'Cannot exceed ${formatCurrency(b.amountPaid)}'
                    : null,
              ),
            ),
          ],
          // Summary
          if (b.amountPaid > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(S.bookingDetail.customerReceives, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      Text(formatCurrency(_refundAmt),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(S.bookingDetail.shopKeeps, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      Text(formatCurrency(keeps),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // Damage assessment (only if PICKED_UP)
          if (b.isActive) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                _label(S.bookingDetail.damageAssessment),
                if (b.deposit > 0) ...[
                  const Spacer(),
                  Text(
                    '${S.bookingDetail.securityDeposit}: ${formatCurrency(b.deposit)}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ],
            ),
            if (b.deposit == 0) ...[
              const SizedBox(height: 6),
              Text(
                S.bookingDetail.noDepositCollected,
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ChoiceCard(
                    selected: _damageChoice == 'none',
                    icon: Icons.check_circle_outline_rounded,
                    label: S.bookingDetail.noDamage,
                    color: const Color(0xFF10B981),
                    onTap: () => setState(() {
                      _damageChoice = 'none';
                      _damageAmtCtrl.clear();
                    }),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ChoiceCard(
                    selected: _damageChoice == 'damage',
                    icon: Icons.warning_amber_rounded,
                    label: S.bookingDetail.damageRecorded,
                    color: const Color(0xFFEF4444),
                    onTap: () => setState(() => _damageChoice = 'damage'),
                  ),
                ),
              ],
            ),
            if (_damageChoice == 'damage') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _damageAmtCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: S.bookingDetail.totalDamageAmount,
                  hintText: '0.00',
                  prefixIcon: const Icon(Icons.warning_amber_outlined, size: 20),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _damageReasonCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: S.bookingDetail.cancellationReason,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: Icon(Icons.notes_rounded, size: 20),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            _SettlementSummary(
              mode: _damageChoice,
              damage: double.tryParse(_damageAmtCtrl.text) ?? 0,
              deposit: b.deposit,
            ),
          ],

          // Reason
          const SizedBox(height: 20),
          _label(S.bookingDetail.cancellationReason),
          const SizedBox(height: 8),
          TextField(
            controller: _reasonCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: Icon(Icons.notes_rounded, size: 20),
              ),
            ),
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _confirm,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.cancel_outlined, size: 18),
              label: Text(S.bookingDetail.cancel),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sheet: Collect Payment ───────────────────────────────────────────────────

class _PaySheet extends StatefulWidget {
  final Booking booking;
  final ApiClient api;
  const _PaySheet({required this.booking, required this.api});

  @override
  State<_PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends State<_PaySheet> {
  late final TextEditingController _amountCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.booking.remainingBalance.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final amt = double.tryParse(_amountCtrl.text) ?? 0;
    if (amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.bookingDetail.enterValidAmountMsg), backgroundColor: const Color(0xFFEF4444)),
      );
      return;
    }
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await widget.api.post('/bookings/${widget.booking.id}/pay', data: {'amount': amt});
      nav.pop(true);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(_apiError(e)), backgroundColor: const Color(0xFFEF4444)),
      );
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    return _SheetScaffold(
      title: S.bookingDetail.pay,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetBookingRef(b),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(S.bookingDetail.balanceDue, style: const TextStyle(fontSize: 14, color: Color(0xFF92400E))),
                Text(
                  formatCurrency(b.remainingBalance),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFFF59E0B)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: S.bookingDetail.amountToCollect,
              prefixIcon: const Icon(Icons.payments_outlined, size: 20),
              suffixIcon: TextButton(
                onPressed: () => setState(() => _amountCtrl.text = b.remainingBalance.toStringAsFixed(2)),
                child: Text(S.bookingDetail.fillBalance, style: const TextStyle(fontSize: 12)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _confirm,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text(S.bookingDetail.pay),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sheet: Edit Booking ──────────────────────────────────────────────────────

class _EditSheet extends StatefulWidget {
  final Booking booking;
  final ApiClient api;
  const _EditSheet({required this.booking, required this.api});

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final TextEditingController _firstCtrl;
  late final TextEditingController _lastCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _altPhoneCtrl;
  late final TextEditingController _totalCtrl;
  late final TextEditingController _advanceCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final b = widget.booking;
    _firstCtrl = TextEditingController(text: b.firstName);
    _lastCtrl = TextEditingController(text: b.lastName);
    _phoneCtrl = TextEditingController(text: b.phoneNumber);
    _altPhoneCtrl = TextEditingController(text: b.altPhoneNumber ?? '');
    _totalCtrl = TextEditingController(text: b.totalAmount.toStringAsFixed(2));
    _advanceCtrl = TextEditingController(text: b.amountPaid.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _phoneCtrl.dispose();
    _altPhoneCtrl.dispose();
    _totalCtrl.dispose();
    _advanceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await widget.api.put(
        '/bookings/${widget.booking.id}',
        data: {
          'firstName': _firstCtrl.text.trim(),
          'lastName': _lastCtrl.text.trim(),
          'phoneNumber': _phoneCtrl.text.trim(),
          if (_altPhoneCtrl.text.trim().isNotEmpty) 'altPhoneNumber': _altPhoneCtrl.text.trim(),
          'totalAgreedPrice': double.tryParse(_totalCtrl.text) ?? widget.booking.totalAmount,
          'totalAdvancePayment': double.tryParse(_advanceCtrl.text) ?? widget.booking.amountPaid,
        },
      );
      nav.pop(true);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(_apiError(e)), backgroundColor: const Color(0xFFEF4444)),
      );
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: S.bookingDetail.editBooking,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(S.bookingDetail.customer),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _firstCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: S.newBooking.firstName),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _lastCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: S.newBooking.lastName),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: S.newBooking.phone,
              prefixIcon: const Icon(Icons.phone_outlined, size: 20),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _altPhoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: '${S.newBooking.altPhone} ${S.common.optional}',
              prefixIcon: const Icon(Icons.phone_outlined, size: 20),
            ),
          ),
          const SizedBox(height: 20),
          _label(S.bookingDetail.paymentSection),
          const SizedBox(height: 10),
          TextField(
            controller: _totalCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: S.bookingDetail.totalAgreedPrice,
              prefixIcon: const Icon(Icons.attach_money_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _advanceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: S.bookingDetail.totalAdvancePaid,
              prefixIcon: const Icon(Icons.payments_outlined, size: 20),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(S.bookingDetail.saveChanges),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sheet: PDF ───────────────────────────────────────────────────────────────

class _PdfSheet extends StatefulWidget {
  final Booking booking;
  final ApiClient api;
  const _PdfSheet({required this.booking, required this.api});

  @override
  State<_PdfSheet> createState() => _PdfSheetState();
}

class _PdfSheetState extends State<_PdfSheet> {
  bool _withAck = true;
  bool _loading = false;

  Future<void> _action({required bool share}) async {
    setState(() => _loading = true);
    try {
      final bytes = await widget.api.getBytes(
        '/bookings/${widget.booking.id}/invoice/pdf',
        params: {'withAck': _withAck ? 1 : 0},
      );
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/rental_${widget.booking.invoiceNumber}.pdf';
      await File(path).writeAsBytes(bytes);

      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [XFile(path, mimeType: 'application/pdf')],
        subject: share ? 'Rental Agreement ${widget.booking.invoiceNumber}' : null,
        sharePositionOrigin: box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : null,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.bookingDetail.failedToLoad), backgroundColor: const Color(0xFFEF4444)),
        );
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _SheetHandle(),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFF7C3AED), size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(S.bookingDetail.rentalAgreement,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  Text(widget.booking.invoiceNumber,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(S.bookingDetail.includeSignatureLines,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                      Text(S.bookingDetail.signatureLinesHint,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                    ],
                  ),
                ),
                Switch(
                  value: _withAck,
                  onChanged: (v) => setState(() => _withAck = v),
                  activeColor: const Color(0xFF7C3AED),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: CircularProgressIndicator(),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _action(share: false),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: Text(S.bookingDetail.saveToDevice),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _action(share: true),
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: Text(S.bookingDetail.share),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ─── Local models ─────────────────────────────────────────────────────────────

class _ChangeEntry {
  final String? notes;
  final String? added;
  final String? removed;
  final String? by;
  final String at;
  final double? oldTotal;
  final double? newTotal;
  final double? additionalPayment;

  const _ChangeEntry({
    this.notes, this.added, this.removed, this.by,
    required this.at,
    this.oldTotal, this.newTotal, this.additionalPayment,
  });

  static double? _d(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString());
  }

  factory _ChangeEntry.fromJson(Map<String, dynamic> j) => _ChangeEntry(
        notes: j['notes'] as String?,
        added: (j['added_items_summary'] ?? j['addedItemsSummary']) as String?,
        removed: (j['removed_items_summary'] ?? j['removedItemsSummary']) as String?,
        by: (j['changed_by_name'] ?? j['changedByName']) as String?,
        at: (j['changed_at'] ?? j['changedAt'] ?? j['created_at'] ?? '') as String,
        oldTotal: _d(j['old_total_price'] ?? j['oldTotalPrice']),
        newTotal: _d(j['new_total_price'] ?? j['newTotalPrice']),
        additionalPayment: _d(j['additional_payment'] ?? j['additionalPayment']),
      );
}

// ─── Shared sub-widgets ───────────────────────────────────────────────────────

class _ItemChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  const _ItemChip(this.label, {required this.color, required this.bg});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w700)),
      );
}

class _ReturnButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;
  const _ReturnButton({required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 30,
        child: loading
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF7C3AED))),
              )
            : OutlinedButton(
                onPressed: onPressed,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF7C3AED),
                  side: const BorderSide(color: Color(0xFF7C3AED)),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(S.bookingDetail.returnItem,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ),
      );
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: child,
      );
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionTitle({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 15, color: const Color(0xFF7C3AED)),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF7C3AED),
                letterSpacing: 0.2,
              )),
        ],
      );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
            ),
          ],
        ),
      );
}

class _FinTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _FinTile(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        ],
      );
}

class _FinTileWithNote extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final String? note;
  const _FinTileWithNote({required this.label, required this.value, required this.color, this.note});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
          if (note != null) ...[
            const SizedBox(height: 2),
            Text(note!, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
          ],
        ],
      );
}

class _ExpandableSection extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool expanded;
  final bool loading;
  final VoidCallback onToggle;
  final Widget? child;

  const _ExpandableSection({
    required this.icon,
    required this.label,
    required this.expanded,
    required this.loading,
    required this.onToggle,
    this.child,
  });

  @override
  Widget build(BuildContext context) => _Card(
        child: Column(
          children: [
            InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(icon, size: 15, color: const Color(0xFF7C3AED)),
                    const SizedBox(width: 6),
                    Text(label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7C3AED),
                        )),
                    const Spacer(),
                    if (loading)
                      const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      Icon(
                        expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        color: const Color(0xFF94A3B8),
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
            if (expanded && child != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              child!,
            ],
          ],
        ),
      );
}

class _TimelineEntry extends StatelessWidget {
  final _ChangeEntry log;
  final bool isLast;
  const _TimelineEntry({required this.log, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final hasPriceChange = log.oldTotal != null &&
        log.newTotal != null &&
        log.oldTotal != log.newTotal;
    final hasPayment =
        log.additionalPayment != null && log.additionalPayment != 0;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Timeline spine ──
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFEDE9FE), width: 2),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: const Color(0xFFE2E8F0),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // ── Content ──
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Who & when
                  Row(
                    children: [
                      if (log.by != null) ...[
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text(
                              log.by!.isNotEmpty ? log.by![0].toUpperCase() : '?',
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF7C3AED)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            log.by!,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ] else
                        Expanded(
                          child: Text(S.bookingDetail.staffFallback,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0F172A))),
                        ),
                      Text(
                        formatDateTime(log.at),
                        style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Items changed
                  if (log.removed?.isNotEmpty == true || log.added?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (log.removed?.isNotEmpty == true)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFECACA)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.remove_rounded, size: 10, color: Color(0xFFEF4444)),
                                  const SizedBox(width: 3),
                                  Text(log.removed!,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFFEF4444),
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          if (log.removed?.isNotEmpty == true && log.added?.isNotEmpty == true)
                            const Icon(Icons.arrow_forward_rounded,
                                size: 12, color: Color(0xFF94A3B8)),
                          if (log.added?.isNotEmpty == true)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFBBF7D0)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.add_rounded, size: 10, color: Color(0xFF10B981)),
                                  const SizedBox(width: 3),
                                  Text(log.added!,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF10B981),
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                  // Price change
                  if (hasPriceChange)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.attach_money_rounded,
                              size: 13, color: Color(0xFF94A3B8)),
                          Text(
                            formatCurrency(log.oldTotal!),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const Icon(Icons.arrow_forward_rounded,
                              size: 12, color: Color(0xFF94A3B8)),
                          Text(
                            formatCurrency(log.newTotal!),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Payment collected / refunded
                  if (hasPayment)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: log.additionalPayment! > 0
                              ? const Color(0xFFF0FDF4)
                              : const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              log.additionalPayment! > 0
                                  ? Icons.add_circle_outline_rounded
                                  : Icons.remove_circle_outline_rounded,
                              size: 12,
                              color: log.additionalPayment! > 0
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFF59E0B),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${log.additionalPayment! > 0 ? '+' : ''}${formatCurrency(log.additionalPayment!)} ${log.additionalPayment! > 0 ? S.bookingDetail.collectedLog : S.bookingDetail.refundedLog}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: log.additionalPayment! > 0
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFF59E0B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Notes
                  if (log.notes?.isNotEmpty == true)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.notes_rounded,
                            size: 12, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            log.notes!,
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                                fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuEntry extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _MenuEntry({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 18, color: color ?? const Color(0xFF64748B)),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(
                fontSize: 14,
                color: color ?? const Color(0xFF0F172A),
                fontWeight: FontWeight.w500,
              )),
        ],
      );
}

class _SheetScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  const _SheetScaffold({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SheetHandle(),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                    20, 4, 20, MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        )),
                    const SizedBox(height: 4),
                    const Divider(),
                    const SizedBox(height: 8),
                    child,
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

class _SheetBookingRef extends StatelessWidget {
  final Booking booking;
  const _SheetBookingRef(this.booking);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Text(booking.invoiceNumber,
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            const Text('·', style: TextStyle(color: Color(0xFFCBD5E1))),
            const SizedBox(width: 8),
            Text(booking.customerName,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
          ],
        ),
      );
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );
}

class _ChoiceCard extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.selected,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : const Color(0xFFE2E8F0),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? color : const Color(0xFF94A3B8), size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? color : const Color(0xFF64748B),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}

class _SettlementSummary extends StatelessWidget {
  final String mode; // 'none' | 'damage'
  final double damage;
  final double deposit;
  const _SettlementSummary({required this.mode, required this.damage, required this.deposit});

  @override
  Widget build(BuildContext context) {
    final returnAmt = deposit > 0 ? (deposit - damage).clamp(0.0, deposit) : 0.0;
    final kept = deposit > 0 ? damage.clamp(0.0, deposit) : 0.0;
    final excess = (damage - deposit).clamp(0.0, double.infinity);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Settlement Summary',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.3),
          ),
          const SizedBox(height: 10),
          if (mode == 'none') ...[
            if (deposit > 0)
              _sRow(Icons.arrow_circle_left_outlined, 'Return full deposit to customer', formatCurrency(deposit), const Color(0xFF10B981))
            else
              _sRow(Icons.check_circle_outline_rounded, 'No damage — no charges', null, const Color(0xFF10B981)),
          ],
          if (mode == 'damage') ...[
            if (damage == 0)
              Row(children: [
                const Icon(Icons.touch_app_outlined, size: 14, color: Color(0xFF94A3B8)),
                const SizedBox(width: 6),
                const Text('Enter the damage amount above', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
              ])
            else ...[
              if (deposit > 0 && returnAmt > 0)
                _sRow(Icons.arrow_circle_left_outlined, 'Return to customer', formatCurrency(returnAmt), const Color(0xFF10B981)),
              if (deposit > 0 && kept > 0)
                _sRow(Icons.account_balance_wallet_outlined, 'Deposit kept for damage', formatCurrency(kept), const Color(0xFFEF4444)),
              if (excess > 0)
                _sRow(Icons.warning_rounded, deposit > 0 ? 'Extra Damage Charge' : 'Damage Charge', formatCurrency(excess), const Color(0xFFB91C1C)),
            ],
          ],
        ],
      ),
    );
  }

  Widget _sRow(IconData icon, String label, String? value, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: color))),
            if (value != null)
              Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      );
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

Widget _label(String text) => Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Color(0xFF64748B),
        letterSpacing: 0.3,
      ),
    );


String _apiError(dynamic e) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map) return (data['message'] ?? data['error'] ?? 'Server error') as String;
  }
  return 'Something went wrong. Please try again.';
}

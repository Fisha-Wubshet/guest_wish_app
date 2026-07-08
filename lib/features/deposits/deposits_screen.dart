import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_state.dart';
import '../../core/branch/branch_provider.dart';
import '../../core/models/branch.dart';
import '../../shared/widgets/app_error.dart';
import '../../core/locale/app_strings.dart';
import '../../core/locale/locale_provider.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _depErr(dynamic e) {
  final s = e.toString();
  if (s.contains('SocketException') ||
      s.contains('Connection refused') ||
      s.contains('Failed host lookup') ||
      s.contains('Network is unreachable')) {
    return 'Cannot reach server. Check your connection.';
  }
  if (s.contains('401') || s.contains('Unauthorized')) return 'Session expired. Please log in again.';
  if (s.contains('403') || s.contains('Forbidden')) return 'You don\'t have permission to view deposits.';
  if (s.contains('DioException') || s.contains('dio')) return 'Network error. Please try again.';
  return 'Failed to load deposits. Please try again.';
}

String _fmtAmt(num? v) => '${appLocale == 'am' ? 'ብር' : 'ETB'} ${v?.toStringAsFixed(0) ?? '0'}';

// ─── Models ───────────────────────────────────────────────────────────────────

class DepositRow {
  final int bookingId;
  final String invoiceNumber;
  final String customerName;
  final String phoneNumber;
  final String bookingDate;
  final String? returnDate;
  final String depositStatus;
  final num securityDeposit;
  final num depositDeduction;
  final num excessDamageCharge;
  final String? depositDeductionReason;
  final String? branchName;

  const DepositRow({
    required this.bookingId,
    required this.invoiceNumber,
    required this.customerName,
    required this.phoneNumber,
    required this.bookingDate,
    this.returnDate,
    required this.depositStatus,
    required this.securityDeposit,
    required this.depositDeduction,
    required this.excessDamageCharge,
    this.depositDeductionReason,
    this.branchName,
  });

  factory DepositRow.fromJson(Map<String, dynamic> j) => DepositRow(
        bookingId: j['bookingId'] as int,
        invoiceNumber: (j['invoiceNumber'] as String?) ?? '',
        customerName: (j['customerName'] as String?) ?? '',
        phoneNumber: (j['phoneNumber'] as String?) ?? '',
        bookingDate: (j['bookingDate'] as String?) ?? '',
        returnDate: j['returnDate'] as String?,
        depositStatus: (j['depositStatus'] as String?) ?? '',
        securityDeposit: (j['securityDeposit'] as num?) ?? 0,
        depositDeduction: (j['depositDeduction'] as num?) ?? 0,
        excessDamageCharge: (j['excessDamageCharge'] as num?) ?? 0,
        depositDeductionReason: j['depositDeductionReason'] as String?,
        branchName: j['branchName'] as String?,
      );
}

class DepositSummary {
  final num totalHeld;
  final num totalReturnedClean;
  final num totalKeptDamage;
  final num totalExcessDamage;

  const DepositSummary({
    required this.totalHeld,
    required this.totalReturnedClean,
    required this.totalKeptDamage,
    required this.totalExcessDamage,
  });

  factory DepositSummary.fromJson(Map<String, dynamic> j) => DepositSummary(
        totalHeld: (j['totalHeld'] as num?) ?? 0,
        totalReturnedClean: (j['totalReturnedClean'] as num?) ?? 0,
        totalKeptDamage: (j['totalKeptDamage'] as num?) ?? 0,
        totalExcessDamage: (j['totalExcessDamage'] as num?) ?? 0,
      );
}

// ─── Status helpers ───────────────────────────────────────────────────────────

Color _statusColor(String status) {
  switch (status) {
    case 'HELD':
      return const Color(0xFFF59E0B);
    case 'RETURNED':
      return const Color(0xFF10B981);
    case 'PARTIAL_KEEP':
      return const Color(0xFFEA580C);
    case 'FULL_KEEP':
      return const Color(0xFFDC2626);
    case 'EXCESS_DAMAGE':
      return const Color(0xFF7F1D1D);
    default:
      return const Color(0xFF94A3B8);
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'HELD':
      return S.deposits.held;
    case 'RETURNED':
      return S.deposits.returned;
    case 'PARTIAL_KEEP':
      return S.deposits.statusPartialKeep;
    case 'FULL_KEEP':
      return S.deposits.statusFullKeep;
    case 'EXCESS_DAMAGE':
      return S.deposits.statusExcessDamage;
    default:
      return status;
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class DepositsScreen extends ConsumerStatefulWidget {
  const DepositsScreen({super.key});

  @override
  ConsumerState<DepositsScreen> createState() => _DepositsScreenState();
}

class _DepositsScreenState extends ConsumerState<DepositsScreen> {
  bool _isLoading = false;
  String? _error;
  List<DepositRow> _rows = [];
  DepositSummary? _summary;

  // Filters
  String _statusFilter = '';
  DateTime? _startDate;
  DateTime? _endDate;
  int? _selectedBranchId;

  // Branches for shop admin filter
  List<Branch> _branches = [];
  bool _branchesLoaded = false;

  List<(String, String)> get _statusOptions => [
    ('', S.deposits.all),
    ('HELD', S.deposits.held),
    ('RETURNED', S.deposits.returned),
    ('PARTIAL_KEEP', S.deposits.partialKeep),
    ('FULL_KEEP', S.deposits.fullKeep),
    ('EXCESS_DAMAGE', S.deposits.extraDamage),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final user = ref.read(authProvider).user;
      final branchScope = ref.read(branchScopeProvider);

      // Load branches for shop admin filter (once)
      if (user?.isShopAdmin == true && !_branchesLoaded) {
        _loadBranches(api);
      }

      final params = <String, dynamic>{};
      if (_statusFilter.isNotEmpty) params['status'] = _statusFilter;
      if (_startDate != null) {
        params['startDate'] =
            '${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}';
      }
      if (_endDate != null) {
        params['endDate'] =
            '${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}';
      }
      // Branch filter: shop admin can pick a specific branch; otherwise use scope or own branchId
      if (user?.isShopAdmin == true && _selectedBranchId != null) {
        params['branchId'] = _selectedBranchId;
      } else {
        final branchId = branchScope ?? user?.branchId;
        if (branchId != null) params['branchId'] = branchId;
      }

      final res = await api.get('/reports/deposits', params: params);
      final data = res.data as Map<String, dynamic>;
      final rawRows = data['rows'] as List<dynamic>? ?? [];
      final rawSummary = data['summary'] as Map<String, dynamic>? ?? {};

      setState(() {
        _rows = rawRows.map((e) => DepositRow.fromJson(e as Map<String, dynamic>)).toList();
        _summary = DepositSummary.fromJson(rawSummary);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = _depErr(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _loadBranches(ApiClient api) async {
    try {
      final res = await api.get('/branches');
      final raw = res.data as List<dynamic>;
      setState(() {
        _branches = raw.map((e) => Branch.fromJson(e as Map<String, dynamic>)).toList();
        _branchesLoaded = true;
      });
    } catch (_) {
      // Non-fatal — branch filter just won't populate
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial = isStart ? (_startDate ?? now) : (_endDate ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF7C3AED)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _statusFilter = '';
      _startDate = null;
      _endDate = null;
      _selectedBranchId = null;
    });
    _load();
  }

  void _showDetailSheet(DepositRow row) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DepositDetailSheet(row: row),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          S.nav.deposits,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Color(0xFF0F172A)),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE2E8F0)),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: const Color(0xFF7C3AED),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _buildSummaryCards(),
                  const SizedBox(height: 16),
                  _buildFilterSection(user),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED))),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: AppError(message: _error!, onRetry: _load),
              )
            else if (_rows.isEmpty)
              SliverFillRemaining(
                child: EmptyState(
                  icon: Icons.security_rounded,
                  title: S.deposits.noDepositRecords,
                  subtitle: S.deposits.tryAdjusting,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _DepositCard(
                      row: _rows[i],
                      onTap: () => _showDetailSheet(_rows[i]),
                    ),
                    childCount: _rows.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final s = _summary;
    final cards = [
      _SummaryCardData(
        label: S.deposits.currentlyHeld,
        amount: s?.totalHeld,
        color: const Color(0xFFF59E0B),
        bgColor: const Color(0xFFFFFBEB),
        icon: Icons.lock_clock_rounded,
      ),
      _SummaryCardData(
        label: S.deposits.returnedClean,
        amount: s?.totalReturnedClean,
        color: const Color(0xFF10B981),
        bgColor: const Color(0xFFECFDF5),
        icon: Icons.check_circle_rounded,
      ),
      _SummaryCardData(
        label: S.deposits.keptForDamage,
        amount: s?.totalKeptDamage,
        color: const Color(0xFFEA580C),
        bgColor: const Color(0xFFFFF7ED),
        icon: Icons.build_rounded,
      ),
      _SummaryCardData(
        label: S.deposits.extraDamage,
        amount: s?.totalExcessDamage,
        color: const Color(0xFFDC2626),
        bgColor: const Color(0xFFFEF2F2),
        icon: Icons.warning_rounded,
      ),
    ];

    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) => _SummaryCard(data: cards[i]),
      ),
    );
  }

  Widget _buildFilterSection(AppUser? user) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
          // Status dropdown
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _statusFilter,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Color(0xFF64748B)),
                style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                items: _statusOptions.map((opt) {
                  final (value, label) = opt;
                  return DropdownMenuItem(value: value, child: Text(label));
                }).toList(),
                onChanged: (v) => setState(() => _statusFilter = v ?? ''),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Date range row
          Row(
            children: [
              Expanded(
                child: _DateButton(
                  label: _startDate == null
                      ? S.deposits.fromDate
                      : '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}',
                  hasValue: _startDate != null,
                  icon: Icons.calendar_today_rounded,
                  onTap: () => _pickDate(isStart: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DateButton(
                  label: _endDate == null
                      ? S.deposits.toDate
                      : '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}',
                  hasValue: _endDate != null,
                  icon: Icons.calendar_month_rounded,
                  onTap: () => _pickDate(isStart: false),
                ),
              ),
            ],
          ),
          // Branch filter — shop admin only
          if (user?.isShopAdmin == true && _branches.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: _selectedBranchId,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Color(0xFF64748B)),
                  style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                  hint: Text(S.deposits.allBranches, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                  items: [
                    DropdownMenuItem<int?>(value: null, child: Text(S.deposits.allBranches)),
                    ..._branches.map((b) => DropdownMenuItem<int?>(value: b.id, child: Text(b.name))),
                  ],
                  onChanged: (v) => setState(() => _selectedBranchId = v),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Apply / Clear buttons
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: OutlinedButton(
                    onPressed: _clearFilters,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      foregroundColor: const Color(0xFF64748B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(S.deposits.clear, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 38,
                  child: FilledButton(
                    onPressed: _load,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(S.deposits.applyFilters, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Summary card data ────────────────────────────────────────────────────────

class _SummaryCardData {
  final String label;
  final num? amount;
  final Color color;
  final Color bgColor;
  final IconData icon;

  const _SummaryCardData({
    required this.label,
    required this.amount,
    required this.color,
    required this.bgColor,
    required this.icon,
  });
}

// ─── Summary card widget ──────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final _SummaryCardData data;
  const _SummaryCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: data.bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(data.icon, color: data.color, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _fmtAmt(data.amount),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: data.color,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                data.label,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Date picker button ───────────────────────────────────────────────────────

class _DateButton extends StatelessWidget {
  final String label;
  final bool hasValue;
  final IconData icon;
  final VoidCallback onTap;

  const _DateButton({
    required this.label,
    required this.hasValue,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: hasValue ? const Color(0xFFF5F3FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasValue ? const Color(0xFF7C3AED).withValues(alpha: 0.4) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: hasValue ? const Color(0xFF7C3AED) : const Color(0xFF94A3B8)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: hasValue ? const Color(0xFF7C3AED) : const Color(0xFF94A3B8),
                  fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Deposit list card ────────────────────────────────────────────────────────

class _DepositCard extends StatelessWidget {
  final DepositRow row;
  final VoidCallback onTap;

  const _DepositCard({required this.row, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(row.depositStatus);
    final hasDeduction = row.depositDeduction > 0;
    final hasExcess = row.excessDamageCharge > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left status bar
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                  ),
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: name + invoice badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              row.customerName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => context.push('/bookings/${row.bookingId}'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F3FF),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                row.invoiceNumber,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF7C3AED),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      // Phone
                      Text(
                        row.phoneNumber,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                      const SizedBox(height: 6),
                      // Date + branch
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFFCBD5E1)),
                          const SizedBox(width: 4),
                          Text(
                            row.bookingDate,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          ),
                          if (row.branchName != null) ...[
                            const SizedBox(width: 10),
                            const Icon(Icons.store_rounded, size: 12, color: Color(0xFFCBD5E1)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                row.branchName!,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Bottom row: amounts + status chip
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _AmountChip(
                            label: _fmtAmt(row.securityDeposit),
                            color: const Color(0xFF475569),
                            bgColor: const Color(0xFFF1F5F9),
                          ),
                          if (hasDeduction)
                            _AmountChip(
                              label: '${S.deposits.keptLabel} ${_fmtAmt(row.depositDeduction)}',
                              color: const Color(0xFFDC2626),
                              bgColor: const Color(0xFFFEF2F2),
                            ),
                          if (hasExcess)
                            _AmountChip(
                              label: '+${_fmtAmt(row.excessDamageCharge)}',
                              color: const Color(0xFF7F1D1D),
                              bgColor: const Color(0xFFFEE2E2),
                            ),
                          _StatusChip(status: row.depositStatus),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmountChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bgColor;

  const _AmountChip({required this.label, required this.color, required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    final label = _statusLabel(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

// ─── Detail bottom sheet ──────────────────────────────────────────────────────

class _DepositDetailSheet extends StatelessWidget {
  final DepositRow row;
  const _DepositDetailSheet({required this.row});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.customerName,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            row.phoneNumber,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                    _StatusChip(status: row.depositStatus),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              // Timeline
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  children: [
                    Text(
                      S.deposits.depositLifecycle,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTimeline(),
                    const SizedBox(height: 24),
                    // Open booking button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          context.push('/bookings/${row.bookingId}');
                        },
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: Text(S.deposits.openBooking, style: const TextStyle(fontWeight: FontWeight.w700)),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimeline() {
    final steps = _buildTimelineSteps();
    return Column(
      children: List.generate(steps.length, (i) {
        final step = steps[i];
        final isLast = i == steps.length - 1;
        return _TimelineStep(step: step, isLast: isLast);
      }),
    );
  }

  List<_TimelineStepData> _buildTimelineSteps() {
    final steps = <_TimelineStepData>[];

    steps.add(_TimelineStepData(
      title: S.deposits.depositCollected,
      subtitle: _fmtAmt(row.securityDeposit),
      detail: row.bookingDate,
      dotColor: const Color(0xFF3B82F6),
    ));

    if (row.depositStatus == 'HELD') {
      steps.add(_TimelineStepData(
        title: S.deposits.currentlyHeld,
        subtitle: S.deposits.awaitingReturn,
        dotColor: const Color(0xFFF59E0B),
        isPending: true,
      ));
    } else {
      steps.add(_TimelineStepData(
        title: S.deposits.itemReturned,
        subtitle: row.returnDate != null
            ? '${S.deposits.returnedOn} ${row.returnDate}'
            : S.deposits.returnDateNotRecorded,
        dotColor: const Color(0xFF10B981),
      ));

      switch (row.depositStatus) {
        case 'RETURNED':
          steps.add(_TimelineStepData(
            title: S.deposits.fullDepositReturned,
            subtitle: _fmtAmt(row.securityDeposit),
            dotColor: const Color(0xFF10B981),
          ));
          break;

        case 'PARTIAL_KEEP':
          steps.add(_TimelineStepData(
            title: S.deposits.keptForDamage,
            subtitle: _fmtAmt(row.depositDeduction),
            detail: row.depositDeductionReason,
            dotColor: const Color(0xFFDC2626),
          ));
          final remainder = row.securityDeposit - row.depositDeduction;
          if (remainder > 0) {
            steps.add(_TimelineStepData(
              title: S.deposits.remainderReturned,
              subtitle: _fmtAmt(remainder),
              dotColor: const Color(0xFF10B981),
            ));
          }
          break;

        case 'FULL_KEEP':
          steps.add(_TimelineStepData(
            title: S.deposits.fullDepositKept,
            subtitle: _fmtAmt(row.securityDeposit),
            detail: row.depositDeductionReason,
            dotColor: const Color(0xFFDC2626),
          ));
          break;

        case 'EXCESS_DAMAGE':
          steps.add(_TimelineStepData(
            title: S.deposits.keptForDamage,
            subtitle: _fmtAmt(row.depositDeduction),
            detail: row.depositDeductionReason,
            dotColor: const Color(0xFFDC2626),
          ));
          steps.add(_TimelineStepData(
            title: S.deposits.extraDamageCollected,
            subtitle: _fmtAmt(row.excessDamageCharge),
            dotColor: const Color(0xFF7F1D1D),
          ));
          break;
      }
    }

    return steps;
  }
}

class _TimelineStepData {
  final String title;
  final String subtitle;
  final String? detail;
  final Color dotColor;
  final bool isPending;

  const _TimelineStepData({
    required this.title,
    required this.subtitle,
    this.detail,
    required this.dotColor,
    this.isPending = false,
  });
}

class _TimelineStep extends StatelessWidget {
  final _TimelineStepData step;
  final bool isLast;

  const _TimelineStep({required this.step, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dot + line column
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.only(top: 3),
                  decoration: BoxDecoration(
                    color: step.isPending
                        ? Colors.transparent
                        : step.dotColor,
                    shape: BoxShape.circle,
                    border: step.isPending
                        ? Border.all(color: step.dotColor, width: 2)
                        : null,
                    boxShadow: step.isPending
                        ? null
                        : [
                            BoxShadow(
                              color: step.dotColor.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            )
                          ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: const Color(0xFFE2E8F0),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    step.subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: step.dotColor,
                    ),
                  ),
                  if (step.detail != null && step.detail!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        step.detail!,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

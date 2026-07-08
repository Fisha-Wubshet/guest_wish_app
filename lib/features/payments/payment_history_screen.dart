import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_state.dart';
import '../../core/branch/branch_provider.dart';
import '../../core/locale/app_strings.dart';
import '../../core/locale/locale_provider.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _payErr(dynamic e) {
  final msg = e.toString();
  if (msg.contains('401') || msg.contains('Unauthorized')) {
    return 'Session expired. Please log in again.';
  }
  if (msg.contains('SocketException') ||
      msg.contains('Connection refused') ||
      msg.contains('Network is unreachable') ||
      msg.contains('Failed host lookup') ||
      msg.contains('ConnectException') ||
      msg.contains('connection timed out')) {
    return 'Cannot reach server. Check your connection.';
  }
  if (msg.contains('DioException') || msg.contains('dio')) {
    return 'Network error. Please try again.';
  }
  return 'Failed to load payments. Please try again.';
}

final _currency = NumberFormat('#,##0.00', 'en_US');
final _apiDate = DateFormat('yyyy-MM-dd');
final _displayDate = DateFormat('EEE, MMM d, yyyy');
final _displayDateShort = DateFormat('MMM d, yyyy');
final _displayTime = DateFormat('HH:mm');

String _fmtCurrency(num v) => _currency.format(v);
String _fmtDateHeader(String iso) {
  try {
    return _displayDate.format(DateTime.parse(iso));
  } catch (_) {
    return iso;
  }
}

String _fmtDateShort(DateTime d) => _displayDateShort.format(d);
String _fmtTime(String iso) {
  try {
    return _displayTime.format(DateTime.parse(iso).toLocal());
  } catch (_) {
    return '';
  }
}

String _dateKey(String iso) {
  try {
    final d = DateTime.parse(iso).toLocal();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  } catch (_) {
    return iso.split('T').first;
  }
}

// ─── Payment type metadata ────────────────────────────────────────────────────

enum PaymentType {
  advance,
  additional,
  securityDeposit,
  depositReturned,
  depositDeducted,
  damageCharge,
  refund,
}

extension PaymentTypeX on PaymentType {
  String get label {
    switch (this) {
      case PaymentType.advance:
        return S.payments.initialAdvance;
      case PaymentType.additional:
        return S.payments.additionalPayment;
      case PaymentType.securityDeposit:
        return S.payments.securityDeposit;
      case PaymentType.depositReturned:
        return S.payments.depositReturned;
      case PaymentType.depositDeducted:
        return S.payments.depositKept;
      case PaymentType.damageCharge:
        return S.payments.damageCharge;
      case PaymentType.refund:
        return S.payments.refund;
    }
  }

  /// 'in' | 'out' | 'kept'
  String get direction {
    switch (this) {
      case PaymentType.advance:
      case PaymentType.additional:
      case PaymentType.securityDeposit:
      case PaymentType.damageCharge:
        return 'in';
      case PaymentType.depositReturned:
      case PaymentType.refund:
        return 'out';
      case PaymentType.depositDeducted:
        return 'kept';
    }
  }

  Color get color {
    switch (this) {
      case PaymentType.advance:
        return const Color(0xFF6366F1); // indigo
      case PaymentType.additional:
        return const Color(0xFF10B981); // green
      case PaymentType.securityDeposit:
        return const Color(0xFFF59E0B); // orange
      case PaymentType.depositReturned:
        return const Color(0xFF3B82F6); // blue
      case PaymentType.depositDeducted:
        return const Color(0xFFEF4444); // red
      case PaymentType.damageCharge:
        return const Color(0xFF991B1B); // dark red
      case PaymentType.refund:
        return const Color(0xFF3B82F6); // blue
    }
  }

  IconData get icon {
    switch (this) {
      case PaymentType.advance:
        return Icons.payments_outlined;
      case PaymentType.additional:
        return Icons.add_card_outlined;
      case PaymentType.securityDeposit:
        return Icons.security_outlined;
      case PaymentType.depositReturned:
        return Icons.undo_rounded;
      case PaymentType.depositDeducted:
        return Icons.remove_circle_outline_rounded;
      case PaymentType.damageCharge:
        return Icons.warning_amber_rounded;
      case PaymentType.refund:
        return Icons.money_off_rounded;
    }
  }
}

PaymentType? _parseType(String? raw) {
  const map = {
    'ADVANCE': PaymentType.advance,
    'ADDITIONAL': PaymentType.additional,
    'SECURITY_DEPOSIT': PaymentType.securityDeposit,
    'DEPOSIT_RETURNED': PaymentType.depositReturned,
    'DEPOSIT_DEDUCTED': PaymentType.depositDeducted,
    'DAMAGE_CHARGE': PaymentType.damageCharge,
    'REFUND': PaymentType.refund,
  };
  return map[raw];
}

// ─── Payment model ────────────────────────────────────────────────────────────

class Payment {
  final int id;
  final String type;
  final double amount;
  final String createdAt;
  final String? invoiceNumber;
  final int? bookingId;
  final String? customerName;
  final String? phoneNumber;
  final String? recordedByName;
  final String? notes;

  Payment({
    required this.id,
    required this.type,
    required this.amount,
    required this.createdAt,
    this.invoiceNumber,
    this.bookingId,
    this.customerName,
    this.phoneNumber,
    this.recordedByName,
    this.notes,
  });

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        id: j['id'] as int,
        type: j['type'] as String? ?? '',
        amount: (j['amount'] as num).toDouble(),
        createdAt: j['created_at'] as String? ?? '',
        invoiceNumber: j['invoice_number'] as String?,
        bookingId: j['booking_id'] as int?,
        customerName: j['customer_name'] as String?,
        phoneNumber: j['phone_number'] as String?,
        recordedByName: j['recorded_by_name'] as String?,
        notes: j['notes'] as String?,
      );

  PaymentType? get paymentType => _parseType(type);
}

// ─── Summary model ────────────────────────────────────────────────────────────

class PaymentSummary {
  final double totalIn;
  final double totalOut;
  final double net;

  const PaymentSummary({
    required this.totalIn,
    required this.totalOut,
    required this.net,
  });

  factory PaymentSummary.fromJson(Map<String, dynamic> j) => PaymentSummary(
        totalIn: (j['total_in'] as num?)?.toDouble() ?? 0,
        totalOut: (j['total_out'] as num?)?.toDouble() ?? 0,
        net: (j['net'] as num?)?.toDouble() ?? 0,
      );

  static const empty = PaymentSummary(totalIn: 0, totalOut: 0, net: 0);
}

// ─── Screen state ─────────────────────────────────────────────────────────────

class _PaymentHistoryState {
  final List<Payment> payments;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int currentPage;
  final int lastPage;
  final int total;
  final PaymentSummary summary;

  const _PaymentHistoryState({
    this.payments = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.currentPage = 1,
    this.lastPage = 1,
    this.total = 0,
    this.summary = PaymentSummary.empty,
  });

  bool get hasMore => currentPage < lastPage;

  _PaymentHistoryState copyWith({
    List<Payment>? payments,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    int? currentPage,
    int? lastPage,
    int? total,
    PaymentSummary? summary,
    bool clearError = false,
  }) =>
      _PaymentHistoryState(
        payments: payments ?? this.payments,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        error: clearError ? null : (error ?? this.error),
        currentPage: currentPage ?? this.currentPage,
        lastPage: lastPage ?? this.lastPage,
        total: total ?? this.total,
        summary: summary ?? this.summary,
      );
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class PaymentHistoryScreen extends ConsumerStatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  ConsumerState<PaymentHistoryScreen> createState() =>
      _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends ConsumerState<PaymentHistoryScreen> {
  // ── Controllers ─────────────────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  // ── UI state ─────────────────────────────────────────────────────────────────
  _PaymentHistoryState _state = const _PaymentHistoryState();
  String _search = '';
  DateTime? _fromDate;
  DateTime? _toDate;
  String? _typeFilter; // null = all
  Timer? _debounce;
  bool _showFilters = true;

  static const _pageSize = 25;
  static const _purple = Color(0xFF7C3AED);
  static const _bg = Color(0xFFF8FAFC);

  // ── Lifecycle ─────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Branch param ─────────────────────────────────────────────────────────────
  Map<String, dynamic> _branchParam() {
    final user = ref.read(authProvider).user;
    final scopeId = ref.read(branchScopeProvider);
    final branchId = scopeId ?? user?.branchId;
    if (branchId != null) return {'branchId': branchId};
    return {};
  }

  // ── API calls ─────────────────────────────────────────────────────────────────
  Future<void> _load({bool reset = true}) async {
    if (reset) {
      setState(() {
        _state = _state.copyWith(
          isLoading: true,
          clearError: true,
          payments: [],
          currentPage: 1,
        );
      });
    } else {
      setState(() => _state = _state.copyWith(isLoadingMore: true));
    }

    try {
      final api = ref.read(apiClientProvider);
      final page = reset ? 1 : _state.currentPage + 1;

      final params = <String, dynamic>{
        'page': page,
        'size': _pageSize,
        ..._branchParam(),
      };
      if (_search.isNotEmpty) params['search'] = _search;
      if (_fromDate != null) params['startDate'] = _apiDate.format(_fromDate!);
      if (_toDate != null) params['endDate'] = _apiDate.format(_toDate!);
      if (_typeFilter != null) params['type'] = _typeFilter;

      final res = await api.get('/payments', params: params);
      final data = res.data as Map<String, dynamic>;

      final list = (data['data'] as List<dynamic>)
          .map((e) => Payment.fromJson(e as Map<String, dynamic>))
          .toList();

      final summaryRaw = data['summary'] as Map<String, dynamic>?;
      final summary = summaryRaw != null
          ? PaymentSummary.fromJson(summaryRaw)
          : PaymentSummary.empty;

      setState(() {
        _state = _state.copyWith(
          isLoading: false,
          isLoadingMore: false,
          payments: reset ? list : [..._state.payments, ...list],
          currentPage: (data['current_page'] as int?) ?? page,
          lastPage: (data['last_page'] as int?) ?? 1,
          total: (data['total'] as int?) ?? list.length,
          summary: summary,
          clearError: true,
        );
      });
    } catch (e) {
      setState(() {
        _state = _state.copyWith(
          isLoading: false,
          isLoadingMore: false,
          error: _payErr(e),
        );
      });
    }
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 300 &&
        _state.hasMore &&
        !_state.isLoadingMore &&
        !_state.isLoading) {
      _load(reset: false);
    }
  }

  // ── Filter helpers ────────────────────────────────────────────────────────────
  void _onSearchChanged(String v) {
    _search = v;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () => _load());
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _search = '';
    _load();
  }

  Future<void> _pickFrom(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: _toDate ?? DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => _datePickerTheme(ctx, child),
    );
    if (picked != null) {
      setState(() => _fromDate = picked);
      _load();
    }
  }

  Future<void> _pickTo(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? DateTime.now(),
      firstDate: _fromDate ?? DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => _datePickerTheme(ctx, child),
    );
    if (picked != null) {
      setState(() => _toDate = picked);
      _load();
    }
  }

  Widget _datePickerTheme(BuildContext ctx, Widget? child) {
    return Theme(
      data: Theme.of(ctx).copyWith(
        colorScheme: const ColorScheme.light(
          primary: _purple,
          onPrimary: Colors.white,
        ),
      ),
      child: child!,
    );
  }

  void _setTypeFilter(String? type) {
    setState(() => _typeFilter = type);
    _load();
  }

  bool get _hasActiveFilters =>
      _search.isNotEmpty ||
      _fromDate != null ||
      _toDate != null ||
      _typeFilter != null;

  int get _activeFilterCount {
    int n = 0;
    if (_search.isNotEmpty) n++;
    if (_fromDate != null) n++;
    if (_toDate != null) n++;
    if (_typeFilter != null) n++;
    return n;
  }

  // ── Grouped list builder ──────────────────────────────────────────────────────
  /// Returns alternating [String (date key), List<Payment>] groups sorted desc.
  List<dynamic> _grouped() {
    final Map<String, List<Payment>> groups = {};
    for (final p in _state.payments) {
      final key = _dateKey(p.createdAt);
      groups.putIfAbsent(key, () => []).add(p);
    }
    final keys = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    final result = <dynamic>[];
    for (final k in keys) {
      result.add(k);
      result.add(groups[k]!);
    }
    return result;
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        color: _purple,
        onRefresh: () => _load(),
        child: CustomScrollView(
          controller: _scrollCtrl,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildSummaryStrip()),
            SliverToBoxAdapter(child: _buildFilterPanel()),
            SliverToBoxAdapter(child: _buildActiveFilterChips()),
            SliverToBoxAdapter(child: _buildTypeFilterRow()),
            _buildBody(),
            SliverToBoxAdapter(child: _buildBottomPadding()),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Text(
        S.nav.payments,
        style: const TextStyle(
          color: Color(0xFF0F172A),
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
      iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      actions: [
        // Filter toggle button
        Stack(
          alignment: Alignment.topRight,
          children: [
            IconButton(
              icon: Icon(
                _showFilters
                    ? Icons.filter_list_off_rounded
                    : Icons.filter_list_rounded,
                color: _hasActiveFilters ? _purple : const Color(0xFF64748B),
              ),
              onPressed: () => setState(() => _showFilters = !_showFilters),
              tooltip: _showFilters ? S.payments.hideFilters : S.payments.showFilters,
            ),
            if (_hasActiveFilters)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: _purple,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$_activeFilterCount',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.account_balance_wallet_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.nav.payments,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  S.payments.subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStrip() {
    final s = _state.summary;
    final netPositive = s.net >= 0;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      child: Row(
        children: [
          Expanded(
            child: _SummaryCard(
              label: S.payments.totalReceived,
              amount: s.totalIn,
              color: const Color(0xFF10B981),
              icon: Icons.arrow_downward_rounded,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SummaryCard(
              label: S.payments.totalReturned,
              amount: s.totalOut,
              color: const Color(0xFF3B82F6),
              icon: Icons.arrow_upward_rounded,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SummaryCard(
              label: S.payments.netCash,
              amount: s.net,
              color: netPositive
                  ? const Color(0xFF6366F1)
                  : const Color(0xFFEF4444),
              icon: netPositive
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPanel() {
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 200),
      crossFadeState:
          _showFilters ? CrossFadeState.showFirst : CrossFadeState.showSecond,
      firstChild: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Column(
          children: [
            // Search
            Container(
              height: 46,
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: S.payments.searchHintFull,
                  hintStyle:
                      const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: 18, color: Color(0xFF94A3B8)),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded,
                              size: 16, color: Color(0xFF94A3B8)),
                          onPressed: _clearSearch,
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Date row
            Row(
              children: [
                Expanded(
                  child: _DateButton(
                    label: _fromDate != null
                        ? _fmtDateShort(_fromDate!)
                        : S.payments.fromDate,
                    hasValue: _fromDate != null,
                    icon: Icons.calendar_today_outlined,
                    onTap: () => _pickFrom(context),
                    onClear: _fromDate != null
                        ? () {
                            setState(() => _fromDate = null);
                            _load();
                          }
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DateButton(
                    label:
                        _toDate != null ? _fmtDateShort(_toDate!) : S.payments.toDate,
                    hasValue: _toDate != null,
                    icon: Icons.event_outlined,
                    onTap: () => _pickTo(context),
                    onClear: _toDate != null
                        ? () {
                            setState(() => _toDate = null);
                            _load();
                          }
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      secondChild: const SizedBox.shrink(),
    );
  }

  Widget _buildActiveFilterChips() {
    if (!_hasActiveFilters) return const SizedBox.shrink();

    final chips = <Widget>[];

    if (_search.isNotEmpty) {
      chips.add(_FilterChip(
        label: '${S.payments.searchPrefix}: $_search',
        onRemove: _clearSearch,
      ));
    }
    if (_fromDate != null) {
      chips.add(_FilterChip(
        label: '${S.payments.fromPrefix}: ${_fmtDateShort(_fromDate!)}',
        onRemove: () {
          setState(() => _fromDate = null);
          _load();
        },
      ));
    }
    if (_toDate != null) {
      chips.add(_FilterChip(
        label: '${S.payments.toPrefix}: ${_fmtDateShort(_toDate!)}',
        onRemove: () {
          setState(() => _toDate = null);
          _load();
        },
      ));
    }
    if (_typeFilter != null) {
      final t = _parseType(_typeFilter);
      chips.add(_FilterChip(
        label: t?.label ?? _typeFilter!,
        onRemove: () => _setTypeFilter(null),
      ));
    }

    // Clear all
    if (chips.length > 1) {
      chips.add(
        GestureDetector(
          onTap: () {
            _searchCtrl.clear();
            setState(() {
              _search = '';
              _fromDate = null;
              _toDate = null;
              _typeFilter = null;
            });
            _load();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Text(
              S.payments.clearAll,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFEF4444)),
            ),
          ),
        ),
      );
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: chips,
      ),
    );
  }

  Widget _buildTypeFilterRow() {
    final types = PaymentType.values;
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: types.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                if (i == 0) {
                  final selected = _typeFilter == null;
                  return _TypeChip(
                    label: S.payments.all,
                    selected: selected,
                    color: _purple,
                    onTap: () => _setTypeFilter(null),
                  );
                }
                final t = types[i - 1];
                final selected = _typeFilter == t.name;
                return _TypeChip(
                  label: t.label,
                  selected: selected,
                  color: t.color,
                  onTap: () => _setTypeFilter(selected ? null : t.name),
                );
              },
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
        ],
      ),
    );
  }

  Widget _buildBottomPadding() => const SizedBox(height: 32);

  // ── Body (loading / error / empty / list) ────────────────────────────────────
  Widget _buildBody() {
    if (_state.isLoading) return _buildSkeletonSliver();
    if (_state.error != null && _state.payments.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _ErrorView(
          message: _state.error!,
          onRetry: () => _load(),
        ),
      );
    }
    if (_state.payments.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _EmptyView(hasFilters: _hasActiveFilters),
      );
    }
    return _buildListSliver();
  }

  SliverList _buildSkeletonSliver() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, i) => const _SkeletonRow(),
        childCount: 10,
      ),
    );
  }

  Widget _buildListSliver() {
    final grouped = _grouped();
    // Count total items: date headers + payment rows + counter + optional load more
    int itemCount = 0;
    for (int i = 0; i < grouped.length; i += 2) {
      final payments = grouped[i + 1] as List<Payment>;
      itemCount += 1 + payments.length; // header + rows
    }
    itemCount += 1; // records counter
    if (_state.hasMore) itemCount += 1;
    if (_state.isLoadingMore) itemCount += 1;

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _listItemAt(index, grouped),
        childCount: itemCount,
      ),
    );
  }

  Widget? _listItemAt(int index, List<dynamic> grouped) {
    // Build a flat index → widget mapping
    int cursor = 0;

    for (int gi = 0; gi < grouped.length; gi += 2) {
      final dateKey = grouped[gi] as String;
      final payments = grouped[gi + 1] as List<Payment>;

      // Date header
      if (index == cursor) {
        return _DateHeader(dateKey: dateKey, payments: payments);
      }
      cursor++;

      // Payment rows
      for (int pi = 0; pi < payments.length; pi++) {
        if (index == cursor) {
          return _PaymentRow(
            payment: payments[pi],
            onTap: payments[pi].bookingId != null
                ? () => context.push('/bookings/${payments[pi].bookingId}')
                : null,
          );
        }
        cursor++;
      }
    }

    // Records counter
    if (index == cursor) {
      return _RecordCounter(
        shown: _state.payments.length,
        total: _state.total,
      );
    }
    cursor++;

    // Load more / spinner
    if (_state.isLoadingMore && index == cursor) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
            child: CircularProgressIndicator(color: _purple, strokeWidth: 2)),
      );
    }
    if (_state.hasMore && !_state.isLoadingMore && index == cursor) {
      return _LoadMoreButton(onTap: () => _load(reset: false));
    }

    return const SizedBox.shrink();
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: color,
                      letterSpacing: 0.2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _fmtCurrency(amount),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final bool hasValue;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DateButton({
    required this.label,
    required this.hasValue,
    required this.icon,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: hasValue
              ? const Color(0xFF7C3AED).withValues(alpha: 0.07)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasValue
                ? const Color(0xFF7C3AED).withValues(alpha: 0.4)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 15,
                color: hasValue
                    ? const Color(0xFF7C3AED)
                    : const Color(0xFF94A3B8)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                  color: hasValue
                      ? const Color(0xFF7C3AED)
                      : const Color(0xFF94A3B8),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close_rounded,
                    size: 14, color: Color(0xFF94A3B8)),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _FilterChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF7C3AED),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded,
                size: 13, color: Color(0xFF7C3AED)),
          ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : const Color(0xFFE2E8F0),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  final String dateKey;
  final List<Payment> payments;

  const _DateHeader({required this.dateKey, required this.payments});

  @override
  Widget build(BuildContext context) {
    double dayIn = 0;
    double dayOut = 0;
    for (final p in payments) {
      final dir = p.paymentType?.direction ?? 'in';
      if (dir == 'in') {
        dayIn += p.amount;
      } else if (dir == 'out') {
        dayOut += p.amount;
      }
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month_outlined,
              size: 14, color: Color(0xFF64748B)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _fmtDateHeader(dateKey),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
          ),
          if (dayIn > 0) ...[
            const SizedBox(width: 6),
            _DayBadge(label: '+${_fmtCurrency(dayIn)}',
                color: const Color(0xFF10B981)),
          ],
          if (dayOut > 0) ...[
            const SizedBox(width: 4),
            _DayBadge(label: '−${_fmtCurrency(dayOut)}',
                color: const Color(0xFF3B82F6)),
          ],
        ],
      ),
    );
  }
}

class _DayBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _DayBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final Payment payment;
  final VoidCallback? onTap;

  const _PaymentRow({required this.payment, this.onTap});

  @override
  Widget build(BuildContext context) {
    final pt = payment.paymentType;
    final color = pt?.color ?? const Color(0xFF64748B);
    final icon = pt?.icon ?? Icons.payments_outlined;
    final label = pt?.label ?? payment.type;
    final dir = pt?.direction ?? 'in';

    final amountColor = dir == 'in'
        ? const Color(0xFF10B981)
        : dir == 'out'
            ? const Color(0xFF3B82F6)
            : const Color(0xFFEF4444);

    final amountPrefix = dir == 'in' ? '+' : dir == 'out' ? '−' : '';
    final dirIcon = dir == 'in'
        ? Icons.arrow_downward_rounded
        : dir == 'out'
            ? Icons.arrow_upward_rounded
            : Icons.horizontal_rule_rounded;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon circle
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            // Middle content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (payment.invoiceNumber != null) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: payment.bookingId != null
                              ? () => context
                                  .push('/bookings/${payment.bookingId}')
                              : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              payment.invoiceNumber!,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6366F1),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (payment.customerName != null) ...[
                        const Icon(Icons.person_outline_rounded,
                            size: 11, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            payment.customerName!,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF64748B)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      if (payment.phoneNumber != null) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.phone_outlined,
                            size: 11, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 3),
                        Text(
                          payment.phoneNumber!,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ],
                  ),
                  if (payment.recordedByName != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.badge_outlined,
                            size: 11, color: Color(0xFFCBD5E1)),
                        const SizedBox(width: 3),
                        Text(
                          payment.recordedByName!,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ],
                  if (payment.notes != null &&
                      payment.notes!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      payment.notes!,
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFCBD5E1),
                          fontStyle: FontStyle.italic),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Right: amount + time
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(dirIcon, size: 12, color: amountColor),
                    const SizedBox(width: 2),
                    Text(
                      '$amountPrefix${_fmtCurrency(payment.amount)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: amountColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  _fmtTime(payment.createdAt),
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF94A3B8)),
                ),
                if (onTap != null) ...[
                  const SizedBox(height: 3),
                  const Icon(Icons.chevron_right_rounded,
                      size: 16, color: Color(0xFFCBD5E1)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordCounter extends StatelessWidget {
  final int shown;
  final int total;

  const _RecordCounter({required this.shown, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Text(
        '$shown ${S.payments.ofLabel} $total ${S.payments.records}',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
      ),
    );
  }
}

class _LoadMoreButton extends StatelessWidget {
  final VoidCallback onTap;

  const _LoadMoreButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.expand_more_rounded,
                  size: 18, color: Color(0xFF7C3AED)),
              const SizedBox(width: 6),
              Text(
                S.payments.loadMore,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7C3AED),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonRow extends StatefulWidget {
  const _SkeletonRow();

  @override
  State<_SkeletonRow> createState() => _SkeletonRowState();
}

class _SkeletonRowState extends State<_SkeletonRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              _box(42, 42, radius: 21),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _box(12, 120),
                    const SizedBox(height: 6),
                    _box(10, 180),
                    const SizedBox(height: 4),
                    _box(10, 100),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _box(14, 70),
                  const SizedBox(height: 6),
                  _box(10, 35),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _box(double h, double w, {double radius = 6}) => Container(
        height: h,
        width: w,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.error_outline_rounded,
                  color: Color(0xFFEF4444), size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: Color(0xFF64748B), fontSize: 14),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(S.payments.tryAgain),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final bool hasFilters;

  const _EmptyView({required this.hasFilters});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.receipt_long_rounded,
                  color: Color(0xFFCBD5E1), size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              S.payments.noRecords,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hasFilters
                  ? S.payments.tryAdjusting
                  : S.payments.paymentsWillAppear,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_state.dart';
import '../../core/branch/branch_provider.dart';
import '../../core/locale/app_strings.dart';
import '../../core/locale/locale_provider.dart';
import '../../core/utils/formatters.dart';

// ─── Top-level error extractor ────────────────────────────────────────────────

String _rptErr(dynamic e) {
  try {
    final data = (e as dynamic).response?.data;
    if (data is Map) return (data['message'] ?? data['error'] ?? 'An error occurred') as String;
    if (data is String && data.isNotEmpty) return data;
  } catch (_) {}
  return 'Something went wrong. Please try again.';
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Track which tabs have been loaded at least once
  final Set<int> _loadedTabs = {};

  // ── Overview state ──────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _trendData = [];
  List<Map<String, dynamic>> _topItems = [];
  bool _overviewLoading = false;
  String? _overviewError;

  // ── Revenue tab state ───────────────────────────────────────────────────────
  // 0 = Today, 1 = This Month, 2 = Custom
  int _revenuePeriod = 0;
  int _customYear = DateTime.now().year;
  int _customMonth = DateTime.now().month;
  Map<String, dynamic>? _revenueData;
  bool _revenueLoading = false;
  String? _revenueError;

  // ── Receivables tab state ───────────────────────────────────────────────────
  Map<String, dynamic>? _agingData;
  bool _receivablesLoading = false;
  String? _receivablesError;
  int? _selectedBucket; // index into buckets list

  // ── Items tab state ─────────────────────────────────────────────────────────
  // 0 = Revenue view, 1 = Utilization view
  int _itemsView = 0;
  List<Map<String, dynamic>> _itemsRevenueList = [];
  bool _itemsLoading = false;
  String? _itemsError;

  // Utilization sub-state
  // 0 = This Month, 1 = Last Month, 2 = Custom
  int _utilPeriod = 0;
  int _utilCustomYear = DateTime.now().year;
  int _utilCustomMonth = DateTime.now().month;
  List<Map<String, dynamic>> _utilList = [];
  bool _utilLoading = false;
  String? _utilError;

  // ── Branches tab state ──────────────────────────────────────────────────────
  int _branchYear = DateTime.now().year;
  int _branchMonth = DateTime.now().month;
  Map<String, dynamic>? _branchData;
  bool _branchesLoading = false;
  String? _branchesError;

  // ── Tab config ──────────────────────────────────────────────────────────────
  bool get _isShopAdmin => ref.read(authProvider).user?.isShopAdmin == true;

  List<String> get _tabs {
    final tabs = [S.reports.tabOverview, S.reports.tabRevenue, S.reports.tabReceivables, S.reports.tabItems];
    if (_isShopAdmin) tabs.add(S.reports.tabBranches);
    return tabs;
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  Map<String, dynamic> _branchParam() {
    final user = ref.read(authProvider).user;
    final scopeId = ref.read(branchScopeProvider);
    final branchId = scopeId ?? user?.branchId;
    if (branchId != null) return {'branchId': branchId};
    return {};
  }

  String _fmtAmt(num v) => '${formatCurrency(v)} ${appLocale == 'am' ? 'ብር' : 'ETB'}';

  ApiClient get _api => ref.read(apiClientProvider);

  // ─── Data loading ────────────────────────────────────────────────────────────

  Future<void> _loadOverview({bool refresh = false}) async {
    if (_overviewLoading && !refresh) return;
    setState(() {
      _overviewLoading = true;
      _overviewError = null;
    });
    try {
      final params = {..._branchParam(), 'months': 12};
      final trendRes = await _api.get('/reports/revenue/trend', params: params);
      final trendRaw = trendRes.data as List<dynamic>? ?? [];
      final trend = trendRaw.map((e) => e as Map<String, dynamic>).toList();

      final itemRes = await _api.get('/reports/revenue/by-item', params: _branchParam());
      final itemRaw = itemRes.data as List<dynamic>? ?? [];
      final items = itemRaw.map((e) => e as Map<String, dynamic>).toList();
      items.sort((a, b) {
        final ra = (a['totalRevenue'] as num?) ?? 0;
        final rb = (b['totalRevenue'] as num?) ?? 0;
        return rb.compareTo(ra);
      });

      setState(() {
        _trendData = trend;
        _topItems = items.take(5).toList();
        _overviewLoading = false;
      });
    } catch (e) {
      setState(() {
        _overviewError = _rptErr(e);
        _overviewLoading = false;
      });
    }
  }

  Future<void> _loadRevenue() async {
    if (_revenueLoading) return;
    setState(() {
      _revenueLoading = true;
      _revenueError = null;
      _revenueData = null;
    });
    try {
      final Map<String, dynamic> params = {..._branchParam()};
      String path;
      if (_revenuePeriod == 0) {
        path = '/reports/revenue/daily';
      } else {
        path = '/reports/revenue/monthly';
        final now = DateTime.now();
        if (_revenuePeriod == 1) {
          params['year'] = now.year;
          params['month'] = now.month;
        } else {
          params['year'] = _customYear;
          params['month'] = _customMonth;
        }
      }
      final res = await _api.get(path, params: params);
      setState(() {
        _revenueData = res.data as Map<String, dynamic>;
        _revenueLoading = false;
      });
    } catch (e) {
      setState(() {
        _revenueError = _rptErr(e);
        _revenueLoading = false;
      });
    }
  }

  Future<void> _loadReceivables({bool refresh = false}) async {
    if (_receivablesLoading && !refresh) return;
    setState(() {
      _receivablesLoading = true;
      _receivablesError = null;
    });
    try {
      final res = await _api.get('/reports/receivables-aging', params: _branchParam());
      setState(() {
        _agingData = res.data as Map<String, dynamic>;
        _receivablesLoading = false;
      });
    } catch (e) {
      setState(() {
        _receivablesError = _rptErr(e);
        _receivablesLoading = false;
      });
    }
  }

  Future<void> _loadItemsRevenue({bool refresh = false}) async {
    if (_itemsLoading && !refresh) return;
    setState(() {
      _itemsLoading = true;
      _itemsError = null;
    });
    try {
      final res = await _api.get('/reports/revenue/by-item', params: _branchParam());
      final raw = res.data as List<dynamic>? ?? [];
      final items = raw.map((e) => e as Map<String, dynamic>).toList();
      items.sort((a, b) {
        final ra = (a['totalRevenue'] as num?) ?? 0;
        final rb = (b['totalRevenue'] as num?) ?? 0;
        return rb.compareTo(ra);
      });
      setState(() {
        _itemsRevenueList = items;
        _itemsLoading = false;
      });
    } catch (e) {
      setState(() {
        _itemsError = _rptErr(e);
        _itemsLoading = false;
      });
    }
  }

  Future<void> _loadUtilization() async {
    if (_utilLoading) return;
    setState(() {
      _utilLoading = true;
      _utilError = null;
      _utilList = [];
    });
    try {
      final now = DateTime.now();
      DateTime from;
      DateTime to;
      if (_utilPeriod == 0) {
        from = DateTime(now.year, now.month, 1);
        to = DateTime(now.year, now.month + 1, 0);
      } else if (_utilPeriod == 1) {
        from = DateTime(now.year, now.month - 1, 1);
        to = DateTime(now.year, now.month, 0);
      } else {
        from = DateTime(_utilCustomYear, _utilCustomMonth, 1);
        to = DateTime(_utilCustomYear, _utilCustomMonth + 1, 0);
      }
      final params = {
        ...(_branchParam()),
        'dateFrom': toApiDate(from),
        'dateTo': toApiDate(to),
      };
      final res = await _api.get('/reports/inventory-utilization', params: params);
      final raw = res.data as List<dynamic>? ?? [];
      final items = raw.map((e) => e as Map<String, dynamic>).toList();
      setState(() {
        _utilList = items;
        _utilLoading = false;
      });
    } catch (e) {
      setState(() {
        _utilError = _rptErr(e);
        _utilLoading = false;
      });
    }
  }

  Future<void> _loadBranches() async {
    if (_branchesLoading) return;
    setState(() {
      _branchesLoading = true;
      _branchesError = null;
      _branchData = null;
    });
    try {
      final res = await _api.get('/reports/branch-comparison', params: {
        'year': _branchYear,
        'month': _branchMonth,
      });
      setState(() {
        _branchData = res.data as Map<String, dynamic>;
        _branchesLoading = false;
      });
    } catch (e) {
      setState(() {
        _branchesError = _rptErr(e);
        _branchesLoading = false;
      });
    }
  }

  // ─── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    // Load overview immediately
    _loadedTabs.add(0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOverview());
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final idx = _tabController.index;
    if (_loadedTabs.contains(idx)) return;
    _loadedTabs.add(idx);
    switch (idx) {
      case 1:
        _loadRevenue();
      case 2:
        _loadReceivables();
      case 3:
        _loadItemsRevenue();
      case 4:
        if (_isShopAdmin) _loadBranches();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final tabs = _tabs;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          S.nav.reports,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: const Color(0xFF7C3AED),
              labelColor: const Color(0xFF7C3AED),
              unselectedLabelColor: const Color(0xFF94A3B8),
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelStyle:
                  const TextStyle(fontWeight: FontWeight.w400, fontSize: 13),
              tabs: tabs.map((t) => Tab(text: t)).toList(),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OverviewTab(
            trendData: _trendData,
            topItems: _topItems,
            loading: _overviewLoading,
            error: _overviewError,
            fmtAmt: _fmtAmt,
            onRefresh: () => _loadOverview(refresh: true),
          ),
          _RevenueTab(
            period: _revenuePeriod,
            customYear: _customYear,
            customMonth: _customMonth,
            data: _revenueData,
            loading: _revenueLoading,
            error: _revenueError,
            fmtAmt: _fmtAmt,
            onPeriodChanged: (p) {
              setState(() {
                _revenuePeriod = p;
                _revenueData = null;
              });
              if (p != 2) _loadRevenue();
            },
            onCustomChanged: (y, m) {
              setState(() {
                _customYear = y;
                _customMonth = m;
              });
            },
            onLoad: _loadRevenue,
          ),
          _ReceivablesTab(
            data: _agingData,
            loading: _receivablesLoading,
            error: _receivablesError,
            selectedBucket: _selectedBucket,
            fmtAmt: _fmtAmt,
            onBucketSelected: (i) => setState(() {
              _selectedBucket = _selectedBucket == i ? null : i;
            }),
            onRefresh: () => _loadReceivables(refresh: true),
          ),
          _ItemsTab(
            view: _itemsView,
            revenueList: _itemsRevenueList,
            revenueLoading: _itemsLoading,
            revenueError: _itemsError,
            utilPeriod: _utilPeriod,
            utilCustomYear: _utilCustomYear,
            utilCustomMonth: _utilCustomMonth,
            utilList: _utilList,
            utilLoading: _utilLoading,
            utilError: _utilError,
            fmtAmt: _fmtAmt,
            itemLabel: ref.read(authProvider).user?.itemLabel ?? 'Item',
            onViewChanged: (v) {
              setState(() => _itemsView = v);
              if (v == 1 && _utilList.isEmpty && !_utilLoading) {
                _loadUtilization();
              }
            },
            onRevenueRefresh: () => _loadItemsRevenue(refresh: true),
            onUtilPeriodChanged: (p) {
              setState(() {
                _utilPeriod = p;
                _utilList = [];
              });
              if (p != 2) _loadUtilization();
            },
            onUtilCustomChanged: (y, m) {
              setState(() {
                _utilCustomYear = y;
                _utilCustomMonth = m;
              });
            },
            onUtilLoad: _loadUtilization,
          ),
          if (_isShopAdmin)
            _BranchesTab(
              year: _branchYear,
              month: _branchMonth,
              data: _branchData,
              loading: _branchesLoading,
              error: _branchesError,
              fmtAmt: _fmtAmt,
              onYearChanged: (y) => setState(() => _branchYear = y),
              onMonthChanged: (m) => setState(() => _branchMonth = m),
              onLoad: _loadBranches,
            ),
        ],
      ),
    );
  }
}

// ─── Overview Tab ─────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final List<Map<String, dynamic>> trendData;
  final List<Map<String, dynamic>> topItems;
  final bool loading;
  final String? error;
  final String Function(num) fmtAmt;
  final Future<void> Function() onRefresh;

  const _OverviewTab({
    required this.trendData,
    required this.topItems,
    required this.loading,
    required this.error,
    required this.fmtAmt,
    required this.onRefresh,
  });

  num _sumField(String field) =>
      trendData.fold<num>(0, (acc, row) => acc + ((row[field] as num?) ?? 0));

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return _ErrorRetry(message: error!, onRetry: onRefresh);
    }

    final totalRevenue = _sumField('totalRevenue');
    final totalCollected = _sumField('totalCollected');
    final totalOutstanding = _sumField('totalOutstanding');
    final totalBookings = _sumField('totalBookings');

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              S.reports.last12Months,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF94A3B8),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.45,
              children: [
                _StatCard(
                  label: S.reports.totalRevenueStat,
                  value: fmtAmt(totalRevenue),
                  icon: Icons.payments_outlined,
                  color: const Color(0xFF6366F1),
                ),
                _StatCard(
                  label: S.reports.collected,
                  value: fmtAmt(totalCollected),
                  icon: Icons.check_circle_outline_rounded,
                  color: const Color(0xFF10B981),
                ),
                _StatCard(
                  label: 'Outstanding',
                  value: fmtAmt(totalOutstanding),
                  icon: Icons.pending_outlined,
                  color: const Color(0xFFF59E0B),
                ),
                _StatCard(
                  label: S.reports.bookingsStat,
                  value: totalBookings.toInt().toString(),
                  icon: Icons.receipt_long_outlined,
                  color: const Color(0xFF3B82F6),
                ),
              ],
            ),
            if (topItems.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                S.reports.topItemsByRevenue,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              ...topItems.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                final revenue = (item['totalRevenue'] as num?) ?? 0;
                final maxRevenue =
                    (topItems.first['totalRevenue'] as num?) ?? 1;
                final ratio = maxRevenue > 0 ? revenue / maxRevenue : 0.0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
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
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              fontSize: 13,
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
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    item['uniqueCode']?.toString() ?? '',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    item['itemName']?.toString() ?? '',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: ratio.toDouble(),
                                minHeight: 5,
                                backgroundColor: const Color(0xFFF1F5F9),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Color(0xFF7C3AED)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        fmtAmt(revenue),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Revenue Tab ──────────────────────────────────────────────────────────────

class _RevenueTab extends StatelessWidget {
  final int period;
  final int customYear;
  final int customMonth;
  final Map<String, dynamic>? data;
  final bool loading;
  final String? error;
  final String Function(num) fmtAmt;
  final void Function(int) onPeriodChanged;
  final void Function(int year, int month) onCustomChanged;
  final Future<void> Function() onLoad;

  const _RevenueTab({
    required this.period,
    required this.customYear,
    required this.customMonth,
    required this.data,
    required this.loading,
    required this.error,
    required this.fmtAmt,
    required this.onPeriodChanged,
    required this.onCustomChanged,
    required this.onLoad,
  });

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period picker
          Row(
            children: [
              _PillChip(label: S.reports.today, selected: period == 0, onTap: () => onPeriodChanged(0)),
              const SizedBox(width: 8),
              _PillChip(label: S.reports.thisMonth, selected: period == 1, onTap: () => onPeriodChanged(1)),
              const SizedBox(width: 8),
              _PillChip(label: S.reports.custom, selected: period == 2, onTap: () => onPeriodChanged(2)),
            ],
          ),
          if (period == 2) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _OutlinedInput(
                    label: 'Year',
                    initialValue: customYear.toString(),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final y = int.tryParse(v);
                      if (y != null && y > 2000) onCustomChanged(y, customMonth);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: customMonth,
                    decoration: InputDecoration(
                      labelText: 'Month',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                    items: List.generate(
                      12,
                      (i) => DropdownMenuItem(
                          value: i + 1, child: Text(_monthNames[i])),
                    ),
                    onChanged: (v) {
                      if (v != null) onCustomChanged(customYear, v);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: onLoad,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(S.reports.load,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          if (loading)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator()))
          else if (error != null)
            _ErrorRetry(message: error!, onRetry: onLoad)
          else if (data == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Text(
                  S.reports.selectPeriod,
                  style: const TextStyle(color: Color(0xFF94A3B8)),
                ),
              ),
            )
          else
            _buildRevenueCards(data!),
        ],
      ),
    );
  }

  Widget _buildRevenueCards(Map<String, dynamic> d) {
    final revenue = (d['totalRevenue'] as num?) ?? 0;
    final bookings = (d['totalBookings'] as num?) ?? 0;
    final outstanding = (d['totalOutstanding'] as num?) ?? 0;
    final collected = revenue - outstanding;
    final rate = revenue > 0 ? (collected / revenue).clamp(0.0, 1.0) : 0.0;

    Color rateColor;
    if (rate >= 0.8) {
      rateColor = const Color(0xFF10B981);
    } else if (rate >= 0.5) {
      rateColor = const Color(0xFFF59E0B);
    } else {
      rateColor = const Color(0xFFEF4444);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: S.reports.totalRevenueStat,
                value: fmtAmt(revenue),
                icon: Icons.payments_outlined,
                color: const Color(0xFF6366F1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                label: S.reports.bookingsStat,
                value: bookings.toInt().toString(),
                icon: Icons.receipt_long_outlined,
                color: const Color(0xFF3B82F6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _StatTile(
          label: 'Outstanding',
          value: fmtAmt(outstanding),
          icon: Icons.pending_outlined,
          color: const Color(0xFFF59E0B),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                S.reports.collectionRate,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(rate * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: rateColor,
                    ),
                  ),
                  Text(
                    '${fmtAmt(collected)} ${S.reports.collected}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: rate.toDouble(),
                  minHeight: 10,
                  backgroundColor: const Color(0xFFF1F5F9),
                  valueColor: AlwaysStoppedAnimation<Color>(rateColor),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Receivables Tab ──────────────────────────────────────────────────────────

class _ReceivablesTab extends StatelessWidget {
  final Map<String, dynamic>? data;
  final bool loading;
  final String? error;
  final int? selectedBucket;
  final String Function(num) fmtAmt;
  final void Function(int) onBucketSelected;
  final Future<void> Function() onRefresh;

  const _ReceivablesTab({
    required this.data,
    required this.loading,
    required this.error,
    required this.selectedBucket,
    required this.fmtAmt,
    required this.onBucketSelected,
    required this.onRefresh,
  });

  static const _bucketColors = [
    Color(0xFF6366F1), // 0-30d
    Color(0xFFF59E0B), // 31-60d
    Color(0xFFEA580C), // 61-90d
    Color(0xFFEF4444), // 90+d
  ];

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return _ErrorRetry(message: error!, onRetry: onRefresh);
    }
    if (data == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final buckets =
        (data!['buckets'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final bookings =
        (data!['bookings'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

    List<Map<String, dynamic>> filteredBookings;
    if (selectedBucket != null && selectedBucket! < buckets.length) {
      final bucketLabel = buckets[selectedBucket!]['label']?.toString() ?? '';
      filteredBookings = bookings
          .where((b) => _bucketForBooking(b) == bucketLabel)
          .toList();
    } else {
      filteredBookings = bookings;
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Aging bucket cards
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.5,
              children: buckets.asMap().entries.map((entry) {
                final i = entry.key;
                final bucket = entry.value;
                final color = i < _bucketColors.length
                    ? _bucketColors[i]
                    : const Color(0xFF94A3B8);
                final isSelected = selectedBucket == i;
                return GestureDetector(
                  onTap: () => onBucketSelected(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withValues(alpha: 0.12)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? color : Colors.transparent,
                        width: isSelected ? 2 : 0,
                      ),
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              bucket['label']?.toString() ?? '',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${(bucket['count'] as num?) ?? 0}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: color,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fmtAmt((bucket['total'] as num?) ?? 0),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: color,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Text(
                              'outstanding',
                              style: TextStyle(
                                  fontSize: 10, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  selectedBucket != null
                      ? '${filteredBookings.length} booking${filteredBookings.length != 1 ? 's' : ''}'
                      : S.reports.allOutstanding,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (selectedBucket != null)
                  GestureDetector(
                    onTap: () => onBucketSelected(selectedBucket!),
                    child: Text(
                      S.reports.clearFilter,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7C3AED),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (filteredBookings.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    S.reports.noOutstandingBookings,
                    style:
                        const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                  ),
                ),
              )
            else
              ...filteredBookings.map((b) => _ReceivableRow(
                    booking: b,
                    fmtAmt: fmtAmt,
                    buckets: buckets,
                  )),
          ],
        ),
      ),
    );
  }

  String _bucketForBooking(Map<String, dynamic> booking) {
    final dateStr = booking['bookingDate']?.toString();
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final days = DateTime.now().difference(date).inDays;
      if (days <= 30) return '0–30 days';
      if (days <= 60) return '31–60 days';
      if (days <= 90) return '61–90 days';
      return '90+ days';
    } catch (_) {
      return '';
    }
  }
}

class _ReceivableRow extends StatelessWidget {
  final Map<String, dynamic> booking;
  final String Function(num) fmtAmt;
  final List<Map<String, dynamic>> buckets;

  const _ReceivableRow({
    required this.booking,
    required this.fmtAmt,
    required this.buckets,
  });

  int _ageDays() {
    final dateStr = booking['bookingDate']?.toString();
    if (dateStr == null) return 0;
    try {
      return DateTime.now().difference(DateTime.parse(dateStr)).inDays;
    } catch (_) {
      return 0;
    }
  }

  Color _ageBadgeColor(int days) {
    if (days <= 30) return const Color(0xFF6366F1);
    if (days <= 60) return const Color(0xFFF59E0B);
    if (days <= 90) return const Color(0xFFEA580C);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    final days = _ageDays();
    final color = _ageBadgeColor(days);
    final balance = (booking['balanceDue'] as num?) ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  booking['customerName']?.toString() ?? '—',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Text(
                fmtAmt(balance),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFEF4444),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                booking['invoiceNumber']?.toString() ?? '',
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(width: 8),
              if (booking['phoneNumber'] != null) ...[
                const Icon(Icons.phone_outlined,
                    size: 11, color: Color(0xFF94A3B8)),
                const SizedBox(width: 3),
                Text(
                  booking['phoneNumber'].toString(),
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${days}d ago',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
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

// ─── Items Tab ────────────────────────────────────────────────────────────────

class _ItemsTab extends StatelessWidget {
  final int view;
  final List<Map<String, dynamic>> revenueList;
  final bool revenueLoading;
  final String? revenueError;
  final int utilPeriod;
  final int utilCustomYear;
  final int utilCustomMonth;
  final List<Map<String, dynamic>> utilList;
  final bool utilLoading;
  final String? utilError;
  final String Function(num) fmtAmt;
  final String itemLabel;
  final void Function(int) onViewChanged;
  final Future<void> Function() onRevenueRefresh;
  final void Function(int) onUtilPeriodChanged;
  final void Function(int year, int month) onUtilCustomChanged;
  final Future<void> Function() onUtilLoad;

  const _ItemsTab({
    required this.view,
    required this.revenueList,
    required this.revenueLoading,
    required this.revenueError,
    required this.utilPeriod,
    required this.utilCustomYear,
    required this.utilCustomMonth,
    required this.utilList,
    required this.utilLoading,
    required this.utilError,
    required this.fmtAmt,
    required this.itemLabel,
    required this.onViewChanged,
    required this.onRevenueRefresh,
    required this.onUtilPeriodChanged,
    required this.onUtilCustomChanged,
    required this.onUtilLoad,
  });

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Toggle buttons
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: _ToggleButton(
                  label: S.reports.tabRevenue,
                  selected: view == 0,
                  onTap: () => onViewChanged(0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ToggleButton(
                  label: S.reports.utilization,
                  selected: view == 1,
                  onTap: () => onViewChanged(1),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: view == 0
              ? _buildRevenueView()
              : _buildUtilView(context),
        ),
      ],
    );
  }

  Widget _buildRevenueView() {
    if (revenueLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (revenueError != null) {
      return _ErrorRetry(message: revenueError!, onRetry: onRevenueRefresh);
    }
    if (revenueList.isEmpty) {
      return Center(
        child: Text(
          'No $itemLabel revenue data found.',
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
      );
    }

    final maxRevenue =
        (revenueList.first['totalRevenue'] as num?) ?? 1;

    return RefreshIndicator(
      onRefresh: onRevenueRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: revenueList.length,
        itemBuilder: (context, i) {
          final item = revenueList[i];
          final revenue = (item['totalRevenue'] as num?) ?? 0;
          final bookings = (item['totalBookings'] as num?) ?? 0;
          final ratio = maxRevenue > 0
              ? (revenue / maxRevenue).clamp(0.0, 1.0)
              : 0.0;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item['uniqueCode']?.toString() ?? '',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF7C3AED),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item['itemName']?.toString() ?? '',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          fmtAmt(revenue),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          '${bookings.toInt()} booking${bookings != 1 ? 's' : ''}',
                          style: const TextStyle(
                              fontSize: 10, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio.toDouble(),
                    minHeight: 6,
                    backgroundColor: const Color(0xFFF1F5F9),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF7C3AED)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildUtilView(BuildContext context) {
    return Column(
      children: [
        Container(
          color: const Color(0xFFF8FAFC),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            children: [
              Row(
                children: [
                  _PillChip(
                    label: S.reports.thisMonth,
                    selected: utilPeriod == 0,
                    onTap: () => onUtilPeriodChanged(0),
                  ),
                  const SizedBox(width: 8),
                  _PillChip(
                    label: S.reports.lastMonth,
                    selected: utilPeriod == 1,
                    onTap: () => onUtilPeriodChanged(1),
                  ),
                  const SizedBox(width: 8),
                  _PillChip(
                    label: S.reports.custom,
                    selected: utilPeriod == 2,
                    onTap: () => onUtilPeriodChanged(2),
                  ),
                ],
              ),
              if (utilPeriod == 2) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _OutlinedInput(
                        label: 'Year',
                        initialValue: utilCustomYear.toString(),
                        keyboardType: TextInputType.number,
                        onChanged: (v) {
                          final y = int.tryParse(v);
                          if (y != null && y > 2000) {
                            onUtilCustomChanged(y, utilCustomMonth);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: utilCustomMonth,
                        decoration: InputDecoration(
                          labelText: 'Month',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                        ),
                        items: List.generate(
                          12,
                          (i) => DropdownMenuItem(
                              value: i + 1, child: Text(_monthNames[i])),
                        ),
                        onChanged: (v) {
                          if (v != null) onUtilCustomChanged(utilCustomYear, v);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: onUtilLoad,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(S.reports.load,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        Expanded(child: _buildUtilList()),
      ],
    );
  }

  Widget _buildUtilList() {
    if (utilLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (utilError != null) {
      return _ErrorRetry(message: utilError!, onRetry: onUtilLoad);
    }
    if (utilList.isEmpty) {
      return Center(
        child: Text(
          'No utilization data found.',
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: utilList.length,
      itemBuilder: (context, i) {
        final item = utilList[i];
        final pct = ((item['utilizationPct'] as num?) ??
                (item['utilizationPercent'] as num?) ??
                (item['utilization'] as num?) ??
                0)
            .toDouble()
            .clamp(0.0, 100.0);
        final ratio = pct / 100.0;

        Color barColor;
        if (pct >= 75) {
          barColor = const Color(0xFF10B981);
        } else if (pct >= 40) {
          barColor = const Color(0xFFF59E0B);
        } else {
          barColor = const Color(0xFFEF4444);
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item['uniqueCode']?.toString() ?? '',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF7C3AED),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item['itemName']?.toString() ??
                          item['name']?.toString() ??
                          '',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${pct.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: barColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFF1F5F9),
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Branches Tab ─────────────────────────────────────────────────────────────

class _BranchesTab extends StatelessWidget {
  final int year;
  final int month;
  final Map<String, dynamic>? data;
  final bool loading;
  final String? error;
  final String Function(num) fmtAmt;
  final void Function(int) onYearChanged;
  final void Function(int) onMonthChanged;
  final Future<void> Function() onLoad;

  const _BranchesTab({
    required this.year,
    required this.month,
    required this.data,
    required this.loading,
    required this.error,
    required this.fmtAmt,
    required this.onYearChanged,
    required this.onMonthChanged,
    required this.onLoad,
  });

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: _OutlinedInput(
                  label: 'Year',
                  initialValue: year.toString(),
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    final y = int.tryParse(v);
                    if (y != null && y > 2000) onYearChanged(y);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: month,
                  decoration: InputDecoration(
                    labelText: 'Month',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                  items: List.generate(
                    12,
                    (i) => DropdownMenuItem(
                        value: i + 1, child: Text(_monthNames[i])),
                  ),
                  onChanged: (v) {
                    if (v != null) onMonthChanged(v);
                  },
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: onLoad,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(S.reports.load,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
                  ? _ErrorRetry(message: error!, onRetry: onLoad)
                  : data == null
                      ? Center(
                          child: Text(
                            S.reports.selectPeriodLoad,
                            style: const TextStyle(color: Color(0xFF94A3B8)),
                          ),
                        )
                      : _buildTable(),
        ),
      ],
    );
  }

  Widget _buildTable() {
    final rows = (data!['rows'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final total = data!['total'] as Map<String, dynamic>?;

    if (rows.isEmpty) {
      return const Center(
        child: Text(
          'No branch data found for this period.',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        ...rows.map((row) => _BranchRow(row: row, fmtAmt: fmtAmt)),
        if (total != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.reports.totalAllBranches,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF7C3AED),
                  ),
                ),
                const SizedBox(height: 10),
                _BranchStatsRow(row: total, fmtAmt: fmtAmt,
                    labelColor: const Color(0xFF7C3AED)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _BranchRow extends StatelessWidget {
  final Map<String, dynamic> row;
  final String Function(num) fmtAmt;

  const _BranchRow({required this.row, required this.fmtAmt});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row['branchName']?.toString() ?? '—',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          _BranchStatsRow(row: row, fmtAmt: fmtAmt),
        ],
      ),
    );
  }
}

class _BranchStatsRow extends StatelessWidget {
  final Map<String, dynamic> row;
  final String Function(num) fmtAmt;
  final Color labelColor;

  const _BranchStatsRow({
    required this.row,
    required this.fmtAmt,
    this.labelColor = const Color(0xFF64748B),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MiniStat(
          label: S.reports.bookingsStat,
          value: '${(row['totalBookings'] as num?)?.toInt() ?? 0}',
          color: labelColor,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MiniStat(
            label: S.reports.tabRevenue,
            value: fmtAmt((row['totalRevenue'] as num?) ?? 0),
            color: labelColor,
          ),
        ),
        Expanded(
          child: _MiniStat(
            label: S.reports.collected,
            value: fmtAmt((row['totalCollected'] as num?) ?? 0),
            color: const Color(0xFF10B981),
          ),
        ),
        Expanded(
          child: _MiniStat(
            label: 'Outstanding',
            value: fmtAmt((row['totalOutstanding'] as num?) ?? 0),
            color: const Color(0xFFF59E0B),
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: color,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
        ),
      ],
    );
  }
}

// ─── Shared small widgets ─────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PillChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PillChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF7C3AED) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF7C3AED) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : const Color(0xFF94A3B8),
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlinedInput extends StatefulWidget {
  final String label;
  final String initialValue;
  final TextInputType keyboardType;
  final void Function(String) onChanged;

  const _OutlinedInput({
    required this.label,
    required this.initialValue,
    required this.keyboardType,
    required this.onChanged,
  });

  @override
  State<_OutlinedInput> createState() => _OutlinedInputState();
}

class _OutlinedInputState extends State<_OutlinedInput> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      keyboardType: widget.keyboardType,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: widget.label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorRetry({required this.message, required this.onRetry});

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
              style: const TextStyle(
                  color: Color(0xFF64748B), fontSize: 14),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(S.reports.tryAgain),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'customers_provider.dart';
import '../../core/locale/locale_provider.dart';
import '../../core/locale/app_strings.dart';
import '../../core/models/customer.dart';
import '../../shared/widgets/app_error.dart';
import '../../shared/widgets/shimmer_widgets.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      ref.read(customersProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final state = ref.watch(customersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(S.nav.customers),
            if (state.total > 0)
              Text(
                '${state.total} ${S.customers.totalCustomers}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: Color(0xFF94A3B8)),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => ref.read(customersProvider.notifier).setSearch(v),
              decoration: InputDecoration(
                hintText: S.customers.searchHint,
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF94A3B8)),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          ref.read(customersProvider.notifier).setSearch('');
                        },
                      )
                    : null,
              ),
            ),
          ),
          if (state.isLoading)
            Expanded(child: ShimmerList(cardBuilder: () => const ShimmerCustomerCard()))
          else if (state.error != null)
            Expanded(
              child: AppError(
                message: state.error!,
                onRetry: () => ref.read(customersProvider.notifier).load(),
              ),
            )
          else if (state.customers.isEmpty)
            Expanded(
              child: EmptyState(
                icon: Icons.people_outline_rounded,
                title: S.customers.noCustomers,
                subtitle: state.search.isNotEmpty ? S.customers.tryDifferent : null,
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.read(customersProvider.notifier).load(),
                child: ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  itemCount: state.customers.length + (state.isLoadingMore ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == state.customers.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final c = state.customers[i];
                    return _CustomerCard(
                      customer: c,
                      onTap: () => context.push('/customers/${c.id}'),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  final Customer customer;
  final VoidCallback onTap;

  const _CustomerCard({required this.customer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            _Avatar(initials: customer.initials, isBlacklisted: customer.isBlacklisted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.name,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0F172A)),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    customer.phoneNumber,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _StatusChip(isBlacklisted: customer.isBlacklisted),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1), size: 20),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool isBlacklisted;
  const _StatusChip({required this.isBlacklisted});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isBlacklisted ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isBlacklisted ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0),
          ),
        ),
        child: Text(
          isBlacklisted ? S.customers.blacklisted : S.customers.active,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isBlacklisted ? const Color(0xFFEF4444) : const Color(0xFF10B981),
          ),
        ),
      );
}

class _Avatar extends StatelessWidget {
  final String initials;
  final bool isBlacklisted;
  const _Avatar({required this.initials, required this.isBlacklisted});

  static const _colors = [
    Color(0xFF7C3AED),
    Color(0xFF059669),
    Color(0xFFD97706),
    Color(0xFFDC2626),
    Color(0xFF7C3AED),
  ];

  @override
  Widget build(BuildContext context) {
    if (isBlacklisted) {
      return Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text('!', style: TextStyle(color: Color(0xFFEF4444), fontSize: 18, fontWeight: FontWeight.w800)),
        ),
      );
    }
    final colorIndex = initials.isNotEmpty ? initials.codeUnitAt(0) % _colors.length : 0;
    final color = _colors[colorIndex];
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

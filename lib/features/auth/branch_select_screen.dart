import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/branch/branch_provider.dart';
import '../../core/models/branch.dart';

class BranchSelectScreen extends ConsumerStatefulWidget {
  const BranchSelectScreen({super.key});

  @override
  ConsumerState<BranchSelectScreen> createState() => _BranchSelectScreenState();
}

class _BranchSelectScreenState extends ConsumerState<BranchSelectScreen> {
  Branch? _selected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(branchProvider.notifier).loadBranches();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(branchProvider);

    if (_selected == null && state.branches.isNotEmpty) {
      _selected = state.branches.first;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.store_outlined,
                      color: Color(0xFF7C3AED),
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select Branch',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Choose which branch you want to work with',
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF16A34A)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'You can change this anytime from Settings or the branch chip at the top of any screen.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF15803D)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.wifi_off_rounded,
                                  size: 40, color: Color(0xFFCBD5E1)),
                              const SizedBox(height: 12),
                              Text(state.error!,
                                  style: const TextStyle(color: Color(0xFF94A3B8))),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () =>
                                    ref.read(branchProvider.notifier).loadBranches(),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : state.branches.isEmpty
                          ? const Center(
                              child: Text(
                                'No branches found',
                                style: TextStyle(color: Color(0xFF94A3B8)),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: state.branches.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final b = state.branches[i];
                                final selected = _selected?.id == b.id;
                                return GestureDetector(
                                  onTap: () => setState(() => _selected = b),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? const Color(0xFFF5F3FF)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: selected
                                            ? const Color(0xFF7C3AED)
                                            : const Color(0xFFE2E8F0),
                                        width: selected ? 1.5 : 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: selected
                                              ? const Color(0xFF7C3AED)
                                                  .withValues(alpha: 0.1)
                                              : Colors.black
                                                  .withValues(alpha: 0.04),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: selected
                                                ? const Color(0xFF7C3AED)
                                                    .withValues(alpha: 0.12)
                                                : const Color(0xFFF1F5F9),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            Icons.store_outlined,
                                            size: 22,
                                            color: selected
                                                ? const Color(0xFF7C3AED)
                                                : const Color(0xFF94A3B8),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                b.name,
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                  color: selected
                                                      ? const Color(0xFF7C3AED)
                                                      : const Color(0xFF0F172A),
                                                ),
                                              ),
                                              if (b.address?.isNotEmpty ==
                                                  true) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  b.address!,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF94A3B8),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        if (selected)
                                          const Icon(
                                            Icons.check_circle_rounded,
                                            color: Color(0xFF7C3AED),
                                            size: 22,
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _selected == null
                      ? null
                      : () async {
                          await ref
                              .read(branchProvider.notifier)
                              .setActiveBranch(_selected!);
                          if (context.mounted) context.go('/bookings');
                        },
                  child: Text(
                    _selected != null
                        ? 'Continue with ${_selected!.name}'
                        : 'Select a branch',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/branch/branch_provider.dart';
import '../../core/auth/auth_state.dart';
import '../../core/locale/locale_provider.dart';
import '../../core/locale/app_strings.dart';

class BranchChip extends ConsumerWidget {
  const BranchChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localeProvider);
    final user = ref.watch(authProvider.select((s) => s.user));
    final branchState = ref.watch(branchProvider);

    // Auto-load branches for SHOP_ADMIN if not yet fetched
    if (user?.isShopAdmin == true &&
        !branchState.isLoading &&
        branchState.branches.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(branchProvider.notifier).loadBranches();
      });
    }

    final String branchName;
    if (user?.isShopAdmin == true) {
      branchName = branchState.activeBranch?.name ?? S.settings.switchBranch;
    } else {
      branchName = user?.branchName ?? S.settings.branches;
    }

    final tappable = user?.isShopAdmin == true;

    return GestureDetector(
      onTap: tappable ? () => showBranchSheet(context) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F3FF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFDDD6FE)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.store_outlined, size: 13, color: Color(0xFF7C3AED)),
            const SizedBox(width: 5),
            Text(
              branchName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7C3AED),
              ),
            ),
            if (tappable) ...[
              const SizedBox(width: 2),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 14, color: Color(0xFF7C3AED)),
            ],
          ],
        ),
      ),
    );
  }

  static void showBranchSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _BranchSheet(),
    );
  }
}

class _BranchSheet extends ConsumerStatefulWidget {
  const _BranchSheet();

  @override
  ConsumerState<_BranchSheet> createState() => _BranchSheetState();
}

class _BranchSheetState extends ConsumerState<_BranchSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(branchProvider).branches.isEmpty) {
        ref.read(branchProvider.notifier).loadBranches();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(branchProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.store_outlined, color: Color(0xFF7C3AED), size: 20),
                const SizedBox(width: 10),
                Text(
                  S.settings.switchBranch,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            )
          else if (state.branches.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                S.settings.noBranchesAvailable,
                style: const TextStyle(color: Color(0xFF94A3B8)),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: state.branches.length,
              itemBuilder: (context, i) {
                final b = state.branches[i];
                final active = state.activeBranch?.id == b.id;
                return ListTile(
                  onTap: () async {
                    await ref.read(branchProvider.notifier).setActiveBranch(b);
                    if (context.mounted) Navigator.pop(context);
                  },
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFF7C3AED).withValues(alpha: 0.1)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.store_outlined,
                      size: 18,
                      color: active
                          ? const Color(0xFF7C3AED)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                  title: Text(
                    b.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active
                          ? const Color(0xFF7C3AED)
                          : const Color(0xFF0F172A),
                    ),
                  ),
                  subtitle: b.address?.isNotEmpty == true
                      ? Text(
                          b.address!,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF94A3B8)),
                        )
                      : null,
                  trailing: active
                      ? const Icon(Icons.check_circle_rounded,
                          color: Color(0xFF7C3AED), size: 20)
                      : null,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                );
              },
            ),
          SizedBox(
              height: MediaQuery.of(context).padding.bottom +
                  (MediaQuery.of(context).padding.bottom > 0 ? 0 : 16)),
        ],
      ),
    );
  }
}

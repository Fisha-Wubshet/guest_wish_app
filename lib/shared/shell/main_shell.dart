import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/locale/locale_provider.dart';
import '../../core/locale/app_strings.dart';

class MainShell extends ConsumerWidget {
  final StatefulNavigationShell shell;

  const MainShell({super.key, required this.shell});

  void _onTap(int index) {
    final branchIndex = index < 2 ? index : index - 1;
    shell.goBranch(branchIndex, initialLocation: branchIndex == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localeProvider);
    return Scaffold(
      body: shell,
      floatingActionButton: _CenterFab(onPressed: () => context.push('/new-booking')),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _BottomBar(
        currentIndex: shell.currentIndex >= 2 ? shell.currentIndex + 1 : shell.currentIndex,
        onTap: _onTap,
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: Colors.white,
      elevation: 8,
      shadowColor: const Color(0x1A000000),
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildItem(context, 0, Icons.receipt_long_outlined, Icons.receipt_long, S.nav.bookings),
          _buildItem(context, 1, Icons.dashboard_outlined, Icons.dashboard, S.nav.operations),
          const SizedBox(width: 56),
          _buildItem(context, 3, Icons.people_outline, Icons.people, S.nav.customers),
          _buildItem(context, 4, Icons.settings_outlined, Icons.settings, S.nav.settings),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, int index, IconData icon, IconData activeIcon, String label) {
    final active = currentIndex == index;
    final color = active ? const Color(0xFF7C3AED) : const Color(0xFF94A3B8);
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(active ? activeIcon : icon, color: color, size: 24),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterFab extends StatelessWidget {
  final VoidCallback onPressed;
  const _CenterFab({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF9333EA), Color(0xFF7C3AED)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}

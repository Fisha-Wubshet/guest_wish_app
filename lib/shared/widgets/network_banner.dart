import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/network_status_provider.dart';
import '../../core/locale/locale_provider.dart';

/// Thin banner overlaid at the very top of the app. Red when offline,
/// green (with a Refresh action) briefly when connectivity is restored.
class NetworkBanner extends ConsumerWidget {
  final Widget child;
  const NetworkBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(networkStatusProvider);
    final showOffline    = !status.isOnline;
    final showReconnect  = status.isOnline && status.showReconnected;

    if (!showOffline && !showReconnect) return child;

    final am = appLocale == 'am';
    final isOffline = showOffline;
    final bg = isOffline ? const Color(0xFFD32F2F) : const Color(0xFF16A34A);
    final text = isOffline
        ? (am ? 'የኢንተርኔት ግንኙነት የለም' : 'No internet connection')
        : (am ? 'ግንኙነት ተመልሷል' : 'Back online');

    return Stack(
      children: [
        child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Material(
              color: Colors.transparent,
              child: Container(
                color: bg,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isOffline ? Icons.wifi_off_rounded : Icons.wifi_rounded,
                      size: 14, color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (!isOffline) ...[
                      const SizedBox(width: 10),
                      InkWell(
                        onTap: () => ref.read(networkStatusProvider.notifier).dismissReconnected(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                          ),
                          child: Text(
                            am ? 'ዝጋ' : 'Dismiss',
                            style: const TextStyle(
                              color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

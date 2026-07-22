import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';

class NetworkStatus {
  final bool isOnline;
  final bool showReconnected;   // true briefly right after going offline → online

  const NetworkStatus({this.isOnline = true, this.showReconnected = false});

  NetworkStatus copyWith({bool? isOnline, bool? showReconnected}) => NetworkStatus(
        isOnline: isOnline ?? this.isOnline,
        showReconnected: showReconnected ?? this.showReconnected,
      );
}

class NetworkStatusNotifier extends StateNotifier<NetworkStatus> {
  NetworkStatusNotifier() : super(const NetworkStatus());
  Timer? _hideTimer;

  void setOnline(bool online) {
    if (online == state.isOnline) return;
    if (online) {
      // Went from offline → online: show the "back online" banner for 6s.
      state = state.copyWith(isOnline: true, showReconnected: true);
      _hideTimer?.cancel();
      _hideTimer = Timer(const Duration(seconds: 6), () {
        if (mounted) state = state.copyWith(showReconnected: false);
      });
    } else {
      _hideTimer?.cancel();
      state = state.copyWith(isOnline: false, showReconnected: false);
    }
  }

  void dismissReconnected() {
    _hideTimer?.cancel();
    state = state.copyWith(showReconnected: false);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }
}

final networkStatusProvider = StateNotifierProvider<NetworkStatusNotifier, NetworkStatus>((ref) {
  final notifier = NetworkStatusNotifier();
  // Wire the ApiClient's network callback to this notifier.
  ref.read(apiClientProvider).setOnNetworkStatusChange(notifier.setOnline);
  return notifier;
});

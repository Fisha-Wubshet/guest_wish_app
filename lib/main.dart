import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/api/api_client.dart';
import 'core/network/network_status_provider.dart';
import 'core/router/router.dart';
import 'core/theme/app_theme.dart';
import 'shared/widgets/network_banner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  await ApiClient().init();

  runApp(const ProviderScope(child: RentDeskApp()));
}

class RentDeskApp extends ConsumerWidget {
  const RentDeskApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Materialize the network provider so the ApiClient callback is wired up
    // from the very first frame (before any request goes out).
    ref.watch(networkStatusProvider);

    return MaterialApp.router(
      title: 'GizeBit',
      theme: AppTheme.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => NetworkBanner(child: child ?? const SizedBox.shrink()),
    );
  }
}

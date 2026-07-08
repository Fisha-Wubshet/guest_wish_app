import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Global variable — updated by notifier, read by formatters so they don't need Ref
String appLocale = 'en';

final localeProvider = StateNotifierProvider<LocaleNotifier, String>(
  (ref) => LocaleNotifier(),
);

class LocaleNotifier extends StateNotifier<String> {
  LocaleNotifier() : super('en') {
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('locale') ?? 'en';
    if (mounted) {
      appLocale = saved;
      state = saved;
    }
  }

  Future<void> toggle() async {
    final next = state == 'en' ? 'am' : 'en';
    appLocale = next;
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', next);
  }

  bool get isAmharic => state == 'am';
}

import 'package:intl/intl.dart';
import '../locale/locale_provider.dart';
import 'eth_date.dart' as eth;

final _currency = NumberFormat('#,##0', 'en_US');
final _dateShort = DateFormat('MMM d, yyyy');
final _dateLong = DateFormat('EEEE, MMM d, yyyy');
final _dateApi = DateFormat('yyyy-MM-dd');
final _dateTime = DateFormat('MMM d, h:mm a');

String formatCurrency(num amount) => _currency.format(amount);

String formatDate(String? isoDate) {
  if (isoDate == null || isoDate.isEmpty) return '—';
  if (appLocale == 'am') return eth.formatEthDate(isoDate);
  try {
    final d = DateTime.parse(isoDate);
    return _dateShort.format(d);
  } catch (_) {
    return isoDate;
  }
}

String formatDateLong(String? isoDate) {
  if (isoDate == null || isoDate.isEmpty) return '—';
  if (appLocale == 'am') return eth.formatEthDate(isoDate);
  try {
    final d = DateTime.parse(isoDate);
    return _dateLong.format(d);
  } catch (_) {
    return isoDate;
  }
}

String formatDateTime(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    final d = DateTime.parse(iso);
    return _dateTime.format(d.toLocal());
  } catch (_) {
    return iso;
  }
}

String toApiDate(DateTime d) => _dateApi.format(d);

int daysBetween(String startIso, String endIso) {
  try {
    final a = DateTime.parse(startIso);
    final b = DateTime.parse(endIso);
    return b.difference(a).inDays.abs() + 1;
  } catch (_) {
    return 0;
  }
}

bool isToday(String? isoDate) {
  if (isoDate == null) return false;
  try {
    final d = DateTime.parse(isoDate);
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  } catch (_) {
    return false;
  }
}

bool isPast(String? isoDate) {
  if (isoDate == null) return false;
  try {
    final d = DateTime.parse(isoDate);
    return d.isBefore(DateTime.now().subtract(const Duration(days: 1)));
  } catch (_) {
    return false;
  }
}

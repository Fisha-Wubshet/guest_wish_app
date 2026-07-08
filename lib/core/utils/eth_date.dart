// Ethiopian–Gregorian calendar conversion.
// Algorithm: Julian Day Number bridge with Ethiopian epoch = 1723856.
// Verified: Sept 12, 2023 GC ↔ 1 Maskaram 2016 EC.

const _ethEpoch = 1723856;

const ethMonths = [
  '',
  'መስከረም', // 1
  'ጥቅምት',  // 2
  'ህዳር',   // 3
  'ታህሳስ',  // 4
  'ጥር',    // 5
  'የካቲት',  // 6
  'መጋቢት',  // 7
  'ሚያዚያ',  // 8
  'ግንቦት',  // 9
  'ሰኔ',    // 10
  'ሐምሌ',   // 11
  'ነሐሴ',   // 12
  'ጳጉሜ',   // 13
];

const _dowLabels = ['እ', 'ሰ', 'ማ', 'ረ', 'ሐ', 'አ', 'ቅ'];
List<String> get ethDowLabels => _dowLabels;

class EthDate {
  final int year;
  final int month;
  final int day;
  const EthDate(this.year, this.month, this.day);
  String get monthName => ethMonths[month];
}

// Gregorian date → Julian Day Number (proleptic Gregorian calendar)
int _gregToJDN(int y, int m, int d) {
  final a = (14 - m) ~/ 12;
  final y2 = y + 4800 - a;
  final m2 = m + 12 * a - 3;
  return d +
      (153 * m2 + 2) ~/ 5 +
      365 * y2 +
      y2 ~/ 4 -
      y2 ~/ 100 +
      y2 ~/ 400 -
      32045;
}

// Julian Day Number → Gregorian date
(int, int, int) _jdnToGreg(int jdn) {
  final a = jdn + 32044;
  final b = (4 * a + 3) ~/ 146097;
  final c = a - (146097 * b) ~/ 4;
  final d = (4 * c + 3) ~/ 1461;
  final e = c - (1461 * d) ~/ 4;
  final m = (5 * e + 2) ~/ 153;
  final day = e - (153 * m + 2) ~/ 5 + 1;
  final month = m + 3 - 12 * (m ~/ 10);
  final year = 100 * b + d - 4800 + m ~/ 10;
  return (year, month, day);
}

// ISO string (yyyy-MM-dd) → EthDate, or null on failure
EthDate? gregToEth(String? isoDate) {
  if (isoDate == null || isoDate.length < 10) return null;
  try {
    final dt = DateTime.parse(isoDate.length == 10 ? '${isoDate}T00:00:00' : isoDate);
    final jdn = _gregToJDN(dt.year, dt.month, dt.day);
    final delta = jdn - _ethEpoch;
    final r = delta % 1461;
    final n = r % 365 + 365 * (r ~/ 1460);
    final ey = 4 * (delta ~/ 1461) + r ~/ 365 - r ~/ 1460;
    final em = n ~/ 30 + 1;
    final ed = n % 30 + 1;
    return EthDate(ey, em, ed);
  } catch (_) {
    return null;
  }
}

// EthDate → ISO string (yyyy-MM-dd), or null on failure
String? ethToISO(int ey, int em, int ed) {
  try {
    final jdn = _ethEpoch + 365 * ey + ey ~/ 4 + (em - 1) * 30 + ed - 1;
    final (y, m, d) = _jdnToGreg(jdn);
    return '$y-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
  } catch (_) {
    return null;
  }
}

// How many days in this Ethiopian month (30 for months 1–12; 5 or 6 for Pagume)
int ethDaysInMonth(int ey, int em) {
  if (em < 13) return 30;
  return ey % 4 == 3 ? 6 : 5; // Ethiopian leap year: year mod 4 == 3
}

// Day-of-week offset for 1st of an Ethiopian month (0=Sun … 6=Sat)
int ethStartOffset(int ey, int em) {
  final iso = ethToISO(ey, em, 1);
  if (iso == null) return 0;
  return DateTime.parse('${iso}T00:00:00').weekday % 7; // weekday: Mon=1…Sun=7 → Sun=0
}

// Format an ISO date as Ethiopian: e.g. "መስከረም 1፣ 2016 ዓ.ም"
String formatEthDate(String? isoDate) {
  final eth = gregToEth(isoDate);
  if (eth == null) return '—';
  return '${eth.monthName} ${eth.day}፣ ${eth.year} ዓ.ም';
}

// Today's Ethiopian date
EthDate get ethToday {
  final now = DateTime.now();
  return gregToEth(
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      ) ??
      EthDate(2016, 1, 1);
}

import 'package:flutter/material.dart';
import '../../core/utils/eth_date.dart';

/// Shows a modal bottom sheet with an Ethiopian calendar picker.
/// Returns an ISO date string (yyyy-MM-dd) or null if dismissed.
Future<String?> showEthiopianDatePicker({
  required BuildContext context,
  String? initialDate,
  String? firstDate,
}) async {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EthCalendarSheet(
      initialDate: initialDate,
      firstDate: firstDate,
    ),
  );
}

class _EthCalendarSheet extends StatefulWidget {
  final String? initialDate;
  final String? firstDate;
  const _EthCalendarSheet({this.initialDate, this.firstDate});

  @override
  State<_EthCalendarSheet> createState() => _EthCalendarSheetState();
}

class _EthCalendarSheetState extends State<_EthCalendarSheet> {
  late int _viewYear;
  late int _viewMonth;
  String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialDate;
    final start = widget.initialDate != null
        ? gregToEth(widget.initialDate)
        : null;
    final today = ethToday;
    _viewYear = start?.year ?? today.year;
    _viewMonth = start?.month ?? today.month;
  }

  void _prevMonth() {
    setState(() {
      if (_viewMonth == 1) { _viewMonth = 13; _viewYear--; }
      else _viewMonth--;
    });
  }

  void _nextMonth() {
    setState(() {
      if (_viewMonth == 13) { _viewMonth = 1; _viewYear++; }
      else _viewMonth++;
    });
  }

  bool _isSelected(int day) {
    if (_selected == null) return false;
    final eth = gregToEth(_selected);
    return eth != null &&
        eth.year == _viewYear &&
        eth.month == _viewMonth &&
        eth.day == day;
  }

  bool _isToday(int day) {
    final t = ethToday;
    return t.year == _viewYear && t.month == _viewMonth && t.day == day;
  }

  bool _isBefore(int day) {
    if (widget.firstDate == null) return false;
    final first = gregToEth(widget.firstDate);
    if (first == null) return false;
    final thisDate = EthDate(_viewYear, _viewMonth, day);
    if (thisDate.year < first.year) return true;
    if (thisDate.year > first.year) return false;
    if (thisDate.month < first.month) return true;
    if (thisDate.month > first.month) return false;
    return thisDate.day < first.day;
  }

  void _selectDay(int day) {
    if (_isBefore(day)) return;
    final iso = ethToISO(_viewYear, _viewMonth, day);
    if (iso != null) Navigator.pop(context, iso);
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = ethDaysInMonth(_viewYear, _viewMonth);
    final startOffset = ethStartOffset(_viewYear, _viewMonth);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Month / year header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                color: const Color(0xFF64748B),
                onPressed: _prevMonth,
              ),
              Column(
                children: [
                  Text(
                    ethMonths[_viewMonth],
                    style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    '$_viewYear ዓ.ም',
                    style: const TextStyle(
                      fontSize: 12, color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                color: const Color(0xFF64748B),
                onPressed: _nextMonth,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Day-of-week headers
          Row(
            children: ethDowLabels.map((d) => Expanded(
              child: Center(
                child: Text(
                  d,
                  style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ),
            )).toList(),
          ),

          const Divider(height: 16),

          // Day grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: startOffset + daysInMonth,
            itemBuilder: (context, index) {
              if (index < startOffset) return const SizedBox.shrink();
              final day = index - startOffset + 1;
              final selected = _isSelected(day);
              final today = _isToday(day);
              final disabled = _isBefore(day);

              return GestureDetector(
                onTap: disabled ? null : () => _selectDay(day),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? const Color(0xFF7C3AED) : null,
                    border: today && !selected
                        ? Border.all(color: const Color(0xFF7C3AED), width: 2)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: selected || today
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: selected
                            ? Colors.white
                            : disabled
                                ? const Color(0xFFCBD5E1)
                                : today
                                    ? const Color(0xFF7C3AED)
                                    : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

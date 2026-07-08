import 'package:flutter/material.dart';
import '../../../core/locale/app_strings.dart';
import '../../../core/models/booking.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';

class BookingCard extends StatelessWidget {
  final Booking booking;
  final VoidCallback onTap;

  const BookingCard({super.key, required this.booking, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = StatusColors.forStatus(booking.status);
    final statusBg = StatusColors.backgroundForStatus(booking.status);
    final days = daysBetween(booking.startDate, booking.endDate);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.invoiceNumber,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                              color: Color(0xFF94A3B8), letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          booking.customerName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      S.status.forStatus(booking.status),
                      style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.3),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _InfoChip(
                    icon: Icons.calendar_today_outlined,
                    label: '${formatDate(booking.startDate)} → ${formatDate(booking.endDate)}',
                  ),
                  const SizedBox(width: 8),
                  _InfoChip(
                    icon: Icons.schedule_outlined,
                    label: '$days ${days != 1 ? S.bookings.allStatuses.isEmpty ? "days" : S.newBooking.rentalDaysPlural : S.newBooking.rentalDays}',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _AmountCell(label: S.bookingDetail.totalAgreed, value: formatCurrency(booking.totalAmount), color: const Color(0xFF0F172A))),
                  Expanded(child: _AmountCell(label: S.bookingDetail.totalPaid, value: formatCurrency(booking.amountPaid), color: const Color(0xFF10B981))),
                  Expanded(child: _AmountCell(
                    label: S.bookingDetail.balanceDue,
                    value: formatCurrency(booking.remainingBalance),
                    color: booking.remainingBalance > 0 ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                  )),
                ],
              ),
              if (booking.items.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Text(
                  () {
                    final counts = <String, int>{};
                    for (final i in booking.items) {
                      counts[i.item.name] = (counts[i.item.name] ?? 0) + (i.quantity > 0 ? i.quantity : 1);
                    }
                    return counts.entries.map((e) => e.value > 1 ? '${e.key} ×${e.value}' : e.key).join('  ·  ');
                  }(),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: const Color(0xFF94A3B8)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
    ],
  );
}

class _AmountCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _AmountCell({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
    ],
  );
}

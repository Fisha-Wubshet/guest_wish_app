class Booking {
  final int id;
  final String invoiceNumber;
  final String customerName;
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final String? altPhoneNumber;
  final String status;
  final String startDate;
  final String endDate;
  final String? returnDate;
  final double totalAmount;
  final double deposit;
  final double depositDeduction;
  final bool depositReturned;
  final double excessDamageCharge;
  final double amountPaid;
  final double remainingBalance;
  final String? notes;
  final int? branchId;
  final String? branchName;
  final double refundAmount;
  final List<BookingItem> items;

  const Booking({
    required this.id,
    required this.invoiceNumber,
    required this.customerName,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    this.altPhoneNumber,
    required this.status,
    required this.startDate,
    required this.endDate,
    this.returnDate,
    required this.totalAmount,
    required this.deposit,
    this.depositDeduction = 0,
    this.depositReturned = false,
    this.excessDamageCharge = 0,
    required this.amountPaid,
    required this.remainingBalance,
    this.notes,
    this.branchId,
    this.branchName,
    this.refundAmount = 0,
    required this.items,
  });

  factory Booking.fromJson(Map<String, dynamic> j) {
    final firstName = (j['firstName'] ?? j['first_name'] ?? '') as String;
    final lastName = (j['lastName'] ?? j['last_name'] ?? '') as String;
    final fullName = (j['customerName'] as String?) ??
        (j['customer_name'] as String?) ??
        '$firstName $lastName'.trim();

    final branchObj = j['branch'] as Map<String, dynamic>?;
    final branchId = branchObj?['id'] as int? ?? j['branchId'] as int? ?? j['branch_id'] as int?;
    final branchName = branchObj?['name'] as String? ??
        (j['branchName'] as String?) ??
        (j['branch_name'] as String?);

    final startDate =
        (j['booking_date'] ?? j['startDate'] ?? j['start_date'] ?? '') as String;
    final endDate =
        (j['return_date'] ?? j['endDate'] ?? j['end_date'] ?? '') as String;

    return Booking(
      id: j['id'] as int,
      invoiceNumber: (j['invoice_number'] ?? j['invoiceNumber'] ?? '') as String,
      customerName: fullName,
      firstName: firstName.isNotEmpty ? firstName : fullName.split(' ').first,
      lastName: lastName.isNotEmpty
          ? lastName
          : (fullName.contains(' ')
              ? fullName.split(' ').skip(1).join(' ')
              : ''),
      phoneNumber: (j['phone_number'] ?? j['phoneNumber'] ?? '') as String,
      altPhoneNumber: (j['alt_phone_number'] ?? j['altPhoneNumber']) as String?,
      status: (j['status'] ?? 'PENDING') as String,
      startDate: startDate,
      endDate: endDate,
      returnDate: (j['actual_return_date'] ?? j['returnDate']) as String?,
      totalAmount:
          _toDouble(j['total_agreed_price'] ?? j['totalAmount'] ?? j['total_amount']),
      deposit: _toDouble(j['security_deposit'] ?? j['deposit']),
      depositDeduction: _toDouble(j['deposit_deduction'] ?? j['depositDeduction']),
      depositReturned: (j['security_deposit_returned'] ??
          j['depositReturned'] ??
          false) as bool,
      excessDamageCharge:
          _toDouble(j['excess_damage_charge'] ?? j['excessDamageCharge']),
      amountPaid: _toDouble(
          j['total_advance_payment'] ?? j['amountPaid'] ?? j['amount_paid']),
      remainingBalance: _toDouble(
          j['balance_due'] ?? j['remainingBalance'] ?? j['remaining_balance']),
      notes: (j['notes'] ?? j['cancellation_reason']) as String?,
      branchId: branchId,
      branchName: branchName,
      refundAmount: _toDouble(j['refund_amount'] ?? j['refundAmount']),
      items: (j['items'] as List<dynamic>? ?? [])
          .map((i) => BookingItem.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  bool get isPending => status == 'PENDING';
  bool get isConfirmed => status == 'CONFIRMED';
  bool get isActive => status == 'ACTIVE' || status == 'PICKED_UP';
  bool get isCompleted => status == 'COMPLETED' || status == 'RETURNED';
  bool get isCancelled => status == 'CANCELLED';
  bool get isMaintenance => status == 'MAINTENANCE';
}

class BookingItem {
  final int id;
  final RentalItem item;
  final int quantity;
  final double pricePerDay;
  final double lineTotal;
  final bool isReturned;

  const BookingItem({
    required this.id,
    required this.item,
    required this.quantity,
    required this.pricePerDay,
    required this.lineTotal,
    this.isReturned = false,
  });

  factory BookingItem.fromJson(Map<String, dynamic> j) => BookingItem(
        id: j['id'] as int,
        item: RentalItem.fromJson(j['item'] as Map<String, dynamic>? ?? {}),
        quantity: j['quantity'] as int? ?? 1,
        pricePerDay: Booking._toDouble(j['pricePerDay'] ?? j['price_per_day']),
        lineTotal: Booking._toDouble(j['lineTotal'] ?? j['line_total']),
        isReturned: (j['is_returned'] ?? j['isReturned'] ?? false) as bool,
      );
}

class RentalItem {
  final int id;
  final String name;
  final String code;
  final String? categoryName;

  const RentalItem({
    required this.id,
    required this.name,
    required this.code,
    this.categoryName,
  });

  factory RentalItem.fromJson(Map<String, dynamic> j) => RentalItem(
        id: j['id'] as int? ?? 0,
        name: (j['name'] ?? '') as String,
        code: (j['unique_code'] ?? j['code'] ?? '') as String,
        categoryName: (j['category'] as Map<String, dynamic>?)?['name'] as String? ??
            (j['categoryName'] ?? j['category_name']) as String?,
      );
}

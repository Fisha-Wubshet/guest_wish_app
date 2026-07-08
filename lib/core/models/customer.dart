class Customer {
  final int id;
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final String? altPhoneNumber;
  final String? email;
  final int bookingCount;
  final String? lastBookingDate;
  final bool isBlacklisted;

  const Customer({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    this.altPhoneNumber,
    this.email,
    this.bookingCount = 0,
    this.lastBookingDate,
    this.isBlacklisted = false,
  });

  String get name => '$firstName $lastName'.trim();

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    final combined = '$f$l'.toUpperCase();
    return combined.isNotEmpty ? combined : '?';
  }

  factory Customer.fromJson(Map<String, dynamic> j) {
    // Handle both flat name and separate first/last name fields
    final rawName = (j['name'] as String? ?? '').trim();
    final nameParts = rawName.split(' ');
    return Customer(
      id: j['id'] as int,
      firstName: j['firstName'] ?? j['first_name'] ??
          (nameParts.isNotEmpty ? nameParts.first : ''),
      lastName: j['lastName'] ?? j['last_name'] ??
          (nameParts.length > 1 ? nameParts.sublist(1).join(' ') : ''),
      phoneNumber: j['phoneNumber'] ?? j['phone_number'] ?? '',
      altPhoneNumber: j['altPhoneNumber'] ?? j['alt_phone_number'],
      email: j['email'],
      bookingCount: j['bookingCount'] ?? j['booking_count'] ?? j['bookings_count'] ?? 0,
      lastBookingDate: j['lastBookingDate'] ?? j['last_booking_date'],
      isBlacklisted: j['isBlacklisted'] ?? j['is_blacklisted'] ?? j['blacklisted'] ?? false,
    );
  }
}

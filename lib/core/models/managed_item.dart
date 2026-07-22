class ManagedItem {
  final int id;
  final String name;
  final String uniqueCode;
  final double minPrice;
  final int quantity;
  final String? description;
  final bool hasCleaningGap;
  final int? categoryId;
  final String? categoryName;
  final String? imageUrl;

  const ManagedItem({
    required this.id,
    required this.name,
    required this.uniqueCode,
    required this.minPrice,
    required this.quantity,
    required this.hasCleaningGap,
    this.description,
    this.categoryId,
    this.categoryName,
    this.imageUrl,
  });

  factory ManagedItem.fromJson(Map<String, dynamic> j) {
    final cat = j['category'] as Map<String, dynamic>?;
    return ManagedItem(
      id: j['id'] as int,
      name: (j['name'] ?? '') as String,
      uniqueCode: (j['uniqueCode'] ?? j['unique_code'] ?? '') as String,
      minPrice: _d(j['minPrice'] ?? j['min_price']),
      quantity: (j['quantity'] as int?) ?? 1,
      description: j['description'] as String?,
      hasCleaningGap: (j['hasCleaningGap'] ?? j['has_cleaning_gap'] ?? false) as bool,
      categoryId: cat?['id'] as int?,
      categoryName: cat?['name'] as String?,
      imageUrl: j['imageUrl'] as String?,
    );
  }

  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}

class Category {
  final int id;
  final String name;

  const Category({required this.id, required this.name});

  factory Category.fromJson(Map<String, dynamic> j) =>
      Category(id: j['id'] as int, name: (j['name'] ?? '') as String);
}

class StaffUser {
  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String? phoneNumber;
  final List<String> roles;
  final String? branchName;
  final int? branchId;
  final bool banned;

  const StaffUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phoneNumber,
    required this.roles,
    this.branchName,
    this.branchId,
    this.banned = false,
  });

  String get name => '$firstName $lastName'.trim();
  String get initials {
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  bool get isManager => roles.contains('ROLE_BRANCH_MANAGER');
  bool get isShopAdmin => roles.contains('ROLE_SHOP_ADMIN');

  factory StaffUser.fromJson(Map<String, dynamic> j) {
    final branch = j['branch'] as Map<String, dynamic>?;
    final rawRoles = j['roles'];
    List<String> roles = [];
    if (rawRoles is List) {
      roles = rawRoles.map((r) {
        if (r is String) return r;
        if (r is Map) return (r['name'] ?? '') as String;
        return r.toString();
      }).toList();
    } else if (rawRoles is Set) {
      roles = rawRoles.map((r) => r.toString()).toList();
    }

    final branchId = branch?['id'] as int? ?? j['branch_id'] as int?;

    return StaffUser(
      id: j['id'] as int,
      firstName: (j['firstName'] ?? j['first_name'] ?? '') as String,
      lastName: (j['lastName'] ?? j['last_name'] ?? '') as String,
      email: (j['email'] ?? '') as String,
      phoneNumber: (j['phoneNumber'] ?? j['phone_number']) as String?,
      roles: roles,
      branchName: branch?['name'] as String?,
      branchId: branchId,
      banned: (j['banned'] ?? false) as bool,
    );
  }
}

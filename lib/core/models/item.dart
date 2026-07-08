class Item {
  final int id;
  final String name;
  final String code;
  final double pricePerDay;
  final bool available;
  final int availableUnits;
  final String? categoryName;

  const Item({
    required this.id,
    required this.name,
    required this.code,
    required this.pricePerDay,
    required this.available,
    required this.availableUnits,
    this.categoryName,
  });

  factory Item.fromJson(Map<String, dynamic> j) {
    final units = (j['availableUnits'] as int?) ?? 0;
    final statusAvailable = j['status'] == 'AVAILABLE';
    final available = (j['available'] as bool?) ?? (units > 0 || statusAvailable);
    return Item(
      id: (j['itemId'] ?? j['id']) as int,
      name: (j['itemName'] ?? j['name'] ?? '') as String,
      code: (j['unique_code'] ?? j['code'] ?? '') as String,
      pricePerDay: _toDouble(j['minPrice'] ?? j['pricePerDay'] ?? j['price_per_day']),
      available: available,
      availableUnits: units > 0 ? units : (available ? 1 : 0),
      categoryName: j['category'] is String
          ? j['category'] as String?
          : (j['category'] as Map<String, dynamic>?)?['name'] as String? ??
              j['categoryName'] as String? ??
              j['category_name'] as String?,
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}

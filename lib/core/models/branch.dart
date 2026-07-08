class Branch {
  final int id;
  final String name;
  final String? address;
  final String? phone;
  final int? shopId;

  const Branch({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    this.shopId,
  });

  factory Branch.fromJson(Map<String, dynamic> j) => Branch(
        id: j['id'] as int,
        name: (j['name'] as String?) ?? '',
        address: j['address'] as String?,
        phone: j['phone'] as String?,
        shopId: j['shop_id'] as int?,
      );
}

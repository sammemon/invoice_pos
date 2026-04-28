class UserModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final String shopName;
  final String? phone;
  final String? address;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.shopName,
    this.phone,
    this.address,
  });

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
        id: j['id'] ?? j['_id'] ?? '',
        name: j['name'] ?? '',
        email: j['email'] ?? '',
        role: j['role'] ?? 'cashier',
        shopName: j['shopName'] ?? 'My Shop',
        phone: j['phone'],
        address: j['address'],
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'email': email,
        'role': role, 'shopName': shopName,
        'phone': phone, 'address': address,
      };
}

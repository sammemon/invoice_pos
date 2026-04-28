class SupplierModel {
  final String id;
  final String? serverId;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? company;
  final double currentBalance;
  final bool isActive;

  const SupplierModel({
    required this.id,
    this.serverId,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.company,
    this.currentBalance = 0,
    this.isActive = true,
  });

  factory SupplierModel.fromJson(Map<String, dynamic> j) => SupplierModel(
        id: j['_id'] ?? j['id'] ?? '',
        serverId: j['_id'],
        name: j['name'] ?? '',
        phone: j['phone'],
        email: j['email'],
        address: j['address'],
        company: j['company'],
        currentBalance: (j['currentBalance'] ?? 0).toDouble(),
        isActive: j['isActive'] ?? true,
      );

  factory SupplierModel.fromMap(Map<String, dynamic> m) => SupplierModel(
        id: m['id'] ?? '',
        serverId: m['serverId'],
        name: m['name'] ?? '',
        phone: m['phone'],
        email: m['email'],
        address: m['address'],
        company: m['company'],
        currentBalance: (m['currentBalance'] ?? 0).toDouble(),
        isActive: (m['isActive'] ?? 1) == 1,
      );

  Map<String, dynamic> toMap() => {
        'id': id, 'serverId': serverId, 'name': name, 'phone': phone,
        'email': email, 'address': address, 'company': company,
        'currentBalance': currentBalance, 'isActive': isActive ? 1 : 0,
      };

  Map<String, dynamic> toJson() => {
        'name': name, 'phone': phone, 'email': email,
        'address': address, 'company': company,
      };
}

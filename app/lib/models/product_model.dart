class ProductModel {
  final String id;
  final String? serverId;
  final String name;
  final String? sku;
  final String? barcode;
  final String category;
  final double purchasePrice;
  final double sellingPrice;
  final int quantity;
  final int minStockLevel;
  final String unit;
  final bool isActive;

  const ProductModel({
    required this.id,
    this.serverId,
    required this.name,
    this.sku,
    this.barcode,
    this.category = 'General',
    required this.purchasePrice,
    required this.sellingPrice,
    this.quantity = 0,
    this.minStockLevel = 5,
    this.unit = 'pcs',
    this.isActive = true,
  });

  String get stockStatus {
    if (quantity == 0) return 'out_of_stock';
    if (quantity <= minStockLevel) return 'low_stock';
    return 'in_stock';
  }

  double get profit => sellingPrice - purchasePrice;
  double get profitMargin => purchasePrice > 0 ? (profit / sellingPrice) * 100 : 0;

  factory ProductModel.fromJson(Map<String, dynamic> j) => ProductModel(
        id: j['_id'] ?? j['id'] ?? '',
        serverId: j['_id'],
        name: j['name'] ?? '',
        sku: j['sku'],
        barcode: j['barcode'],
        category: j['category'] ?? 'General',
        purchasePrice: (j['purchasePrice'] ?? 0).toDouble(),
        sellingPrice: (j['sellingPrice'] ?? 0).toDouble(),
        quantity: (j['quantity'] ?? 0).toInt(),
        minStockLevel: (j['minStockLevel'] ?? 5).toInt(),
        unit: j['unit'] ?? 'pcs',
        isActive: j['isActive'] ?? true,
      );

  factory ProductModel.fromMap(Map<String, dynamic> m) => ProductModel(
        id: m['id'] ?? '',
        serverId: m['serverId'],
        name: m['name'] ?? '',
        sku: m['sku'],
        barcode: m['barcode'],
        category: m['category'] ?? 'General',
        purchasePrice: (m['purchasePrice'] ?? 0).toDouble(),
        sellingPrice: (m['sellingPrice'] ?? 0).toDouble(),
        quantity: (m['quantity'] ?? 0).toInt(),
        minStockLevel: (m['minStockLevel'] ?? 5).toInt(),
        unit: m['unit'] ?? 'pcs',
        isActive: (m['isActive'] ?? 1) == 1,
      );

  Map<String, dynamic> toMap() => {
        'id': id, 'serverId': serverId, 'name': name, 'sku': sku,
        'barcode': barcode, 'category': category,
        'purchasePrice': purchasePrice, 'sellingPrice': sellingPrice,
        'quantity': quantity, 'minStockLevel': minStockLevel,
        'unit': unit, 'isActive': isActive ? 1 : 0,
      };

  Map<String, dynamic> toJson() => {
        'name': name, 'sku': sku, 'barcode': barcode, 'category': category,
        'purchasePrice': purchasePrice, 'sellingPrice': sellingPrice,
        'quantity': quantity, 'minStockLevel': minStockLevel, 'unit': unit,
      };

  ProductModel copyWith({int? quantity, double? sellingPrice, double? purchasePrice}) => ProductModel(
        id: id, serverId: serverId, name: name, sku: sku, barcode: barcode,
        category: category,
        purchasePrice: purchasePrice ?? this.purchasePrice,
        sellingPrice: sellingPrice ?? this.sellingPrice,
        quantity: quantity ?? this.quantity,
        minStockLevel: minStockLevel, unit: unit, isActive: isActive,
      );
}

class SaleItemModel {
  final String id;
  final String productId;
  final String productName;
  final int quantity;
  final double purchasePrice;
  final double sellingPrice;
  final double discount;
  final double total;

  const SaleItemModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.purchasePrice,
    required this.sellingPrice,
    this.discount = 0,
    required this.total,
  });

  factory SaleItemModel.fromJson(Map<String, dynamic> j) => SaleItemModel(
        id: j['_id'] ?? j['id'] ?? '',
        productId: j['product'] is Map ? j['product']['_id'] : (j['product'] ?? j['productId'] ?? ''),
        productName: j['productName'] ?? '',
        quantity: (j['quantity'] ?? 1).toInt(),
        purchasePrice: (j['purchasePrice'] ?? 0).toDouble(),
        sellingPrice: (j['sellingPrice'] ?? 0).toDouble(),
        discount: (j['discount'] ?? 0).toDouble(),
        total: (j['total'] ?? 0).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'productId': productId, 'productName': productName,
        'quantity': quantity, 'purchasePrice': purchasePrice,
        'sellingPrice': sellingPrice, 'discount': discount, 'total': total,
      };
}

class SaleModel {
  final String id;
  final String? serverId;
  final String invoiceNumber;
  final String? customerId;
  final String? customerName;
  final List<SaleItemModel> items;
  final double subTotal;
  final double discountAmount;
  final double taxAmount;
  final double grandTotal;
  final double paidAmount;
  final double dueAmount;
  final String paymentMethod;
  final String paymentStatus;
  final String? notes;
  final DateTime saleDate;
  final bool isSynced;
  final String? syncId;

  const SaleModel({
    required this.id,
    this.serverId,
    required this.invoiceNumber,
    this.customerId,
    this.customerName,
    required this.items,
    required this.subTotal,
    this.discountAmount = 0,
    this.taxAmount = 0,
    required this.grandTotal,
    this.paidAmount = 0,
    this.dueAmount = 0,
    this.paymentMethod = 'cash',
    this.paymentStatus = 'paid',
    this.notes,
    required this.saleDate,
    this.isSynced = false,
    this.syncId,
  });

  factory SaleModel.fromJson(Map<String, dynamic> j) => SaleModel(
        id: j['_id'] ?? j['id'] ?? '',
        serverId: j['_id'],
        invoiceNumber: j['invoiceNumber'] ?? '',
        customerId: j['customer'] is Map ? j['customer']['_id'] : j['customer'],
        customerName: j['customerName'] ?? (j['customer'] is Map ? j['customer']['name'] : null),
        items: (j['items'] as List? ?? []).map((i) => SaleItemModel.fromJson(i)).toList(),
        subTotal: (j['subTotal'] ?? 0).toDouble(),
        discountAmount: (j['discountAmount'] ?? 0).toDouble(),
        taxAmount: (j['taxAmount'] ?? 0).toDouble(),
        grandTotal: (j['grandTotal'] ?? 0).toDouble(),
        paidAmount: (j['paidAmount'] ?? 0).toDouble(),
        dueAmount: (j['dueAmount'] ?? 0).toDouble(),
        paymentMethod: j['paymentMethod'] ?? 'cash',
        paymentStatus: j['paymentStatus'] ?? 'paid',
        notes: j['notes'],
        saleDate: j['saleDate'] != null ? DateTime.parse(j['saleDate']) : DateTime.now(),
        isSynced: true,
      );
}

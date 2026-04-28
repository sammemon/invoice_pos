import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../core/network/api_client.dart';
import '../core/database/local_db.dart';
import '../core/utils/helpers.dart';
import '../models/sale_model.dart';
import '../models/product_model.dart';

// ─── Cart Item ────────────────────────────────────────────
class CartItem {
  final ProductModel product;
  int quantity;
  double sellingPrice;
  double discount;

  CartItem({required this.product, this.quantity = 1, required this.sellingPrice, this.discount = 0});

  double get total => sellingPrice * quantity - discount;
}

// ─── POS State ────────────────────────────────────────────
class PosState {
  final List<CartItem> cart;
  final double discountAmount;
  final double taxAmount;
  final String paymentMethod;
  final String? customerId;
  final String? customerName;

  const PosState({
    this.cart = const [],
    this.discountAmount = 0,
    this.taxAmount = 0,
    this.paymentMethod = 'cash',
    this.customerId,
    this.customerName,
  });

  double get subTotal => cart.fold(0, (s, i) => s + i.total);
  double get grandTotal => subTotal - discountAmount + taxAmount;

  PosState copyWith({List<CartItem>? cart, double? discountAmount, double? taxAmount,
      String? paymentMethod, String? customerId, String? customerName}) =>
      PosState(
        cart: cart ?? this.cart,
        discountAmount: discountAmount ?? this.discountAmount,
        taxAmount: taxAmount ?? this.taxAmount,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        customerId: customerId, customerName: customerName,
      );
}

class PosNotifier extends StateNotifier<PosState> {
  PosNotifier() : super(const PosState());

  void addToCart(ProductModel product) {
    final existing = state.cart.indexWhere((i) => i.product.id == product.id);
    if (existing >= 0) {
      final updated = List<CartItem>.from(state.cart);
      if (updated[existing].quantity < product.quantity) {
        updated[existing].quantity++;
        state = state.copyWith(cart: updated);
      }
    } else if (product.quantity > 0) {
      state = state.copyWith(cart: [...state.cart,
        CartItem(product: product, sellingPrice: product.sellingPrice)]);
    }
  }

  void removeFromCart(String productId) =>
      state = state.copyWith(cart: state.cart.where((i) => i.product.id != productId).toList());

  void updateQuantity(String productId, int qty) {
    if (qty <= 0) { removeFromCart(productId); return; }
    final updated = List<CartItem>.from(state.cart);
    final idx = updated.indexWhere((i) => i.product.id == productId);
    if (idx >= 0) {
      final max = updated[idx].product.quantity;
      updated[idx].quantity = qty > max ? max : qty;
      state = state.copyWith(cart: updated);
    }
  }

  void updatePrice(String productId, double price) {
    final updated = List<CartItem>.from(state.cart);
    final idx = updated.indexWhere((i) => i.product.id == productId);
    if (idx >= 0) { updated[idx].sellingPrice = price; state = state.copyWith(cart: updated); }
  }

  void setDiscount(double d) => state = state.copyWith(discountAmount: d);
  void setTax(double t) => state = state.copyWith(taxAmount: t);
  void setPaymentMethod(String m) => state = state.copyWith(paymentMethod: m);
  void setCustomer(String? id, String? name) => state = state.copyWith(customerId: id, customerName: name);
  void clearCart() => state = const PosState();
}

// ─── Sale History ─────────────────────────────────────────
class SaleState {
  final List<SaleModel> sales;
  final bool isLoading;
  final String? error;

  const SaleState({this.sales = const [], this.isLoading = false, this.error});
  SaleState copyWith({List<SaleModel>? sales, bool? isLoading, String? error}) =>
      SaleState(sales: sales ?? this.sales, isLoading: isLoading ?? this.isLoading, error: error);
}

class SaleNotifier extends StateNotifier<SaleState> {
  SaleNotifier() : super(const SaleState());

  Future<void> fetch({String? startDate, String? endDate}) async {
    state = state.copyWith(isLoading: true);
    try {
      final params = <String, String>{};
      if (startDate != null) params['startDate'] = startDate;
      if (endDate != null) params['endDate'] = endDate;
      final res = await ApiClient.instance.get('/sales', params: params);
      final list = (res.data['data'] as List).map((j) => SaleModel.fromJson(j)).toList();
      state = state.copyWith(sales: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<SaleModel?> createSale(PosState pos, double paidAmount) async {
    final syncId = Helpers.generateId();
    final invoiceNumber = Helpers.generateInvoiceNumber();
    final saleData = {
      'items': pos.cart.map((i) => {
        'productId': i.product.id, 'quantity': i.quantity,
        'sellingPrice': i.sellingPrice, 'discount': i.discount,
      }).toList(),
      'customerId': pos.customerId,
      'paidAmount': paidAmount,
      'paymentMethod': pos.paymentMethod,
      'discountAmount': pos.discountAmount,
      'taxAmount': pos.taxAmount,
      'syncId': syncId,
    };

    // Save locally first
    final db = await LocalDb.db;
    await db.insert('sales', {
      'id': syncId, 'invoiceNumber': invoiceNumber,
      'customerId': pos.customerId, 'customerName': pos.customerName,
      'subTotal': pos.subTotal, 'discountAmount': pos.discountAmount,
      'taxAmount': pos.taxAmount, 'grandTotal': pos.grandTotal,
      'paidAmount': paidAmount, 'dueAmount': (pos.grandTotal - paidAmount).clamp(0, double.infinity),
      'paymentMethod': pos.paymentMethod,
      'paymentStatus': paidAmount >= pos.grandTotal ? 'paid' : paidAmount > 0 ? 'partial' : 'unpaid',
      'saleDate': DateTime.now().toIso8601String(), 'isSynced': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // Deduct stock locally
    for (final item in pos.cart) {
      await db.rawUpdate('UPDATE products SET quantity = quantity - ? WHERE id = ?',
          [item.quantity, item.product.id]);
      await db.insert('sale_items', {
        'id': '${syncId}_${item.product.id}', 'saleId': syncId,
        'productId': item.product.id, 'productName': item.product.name,
        'quantity': item.quantity, 'purchasePrice': item.product.purchasePrice,
        'sellingPrice': item.sellingPrice, 'discount': item.discount,
        'total': item.total,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    try {
      final res = await ApiClient.instance.post('/sales', data: saleData);
      final sale = SaleModel.fromJson(res.data['data']);
      await db.update('sales', {'isSynced': 1, 'serverId': sale.serverId}, where: 'id = ?', whereArgs: [syncId]);
      return sale;
    } catch (_) {
      // Queued offline — will sync later
      return null;
    }
  }
}

final posProvider = StateNotifierProvider<PosNotifier, PosState>((_) => PosNotifier());
final saleProvider = StateNotifierProvider<SaleNotifier, SaleState>((_) => SaleNotifier());

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../core/network/api_client.dart';
import '../core/database/local_db.dart';
import '../core/utils/helpers.dart';
import '../models/product_model.dart';

class ProductState {
  final List<ProductModel> products;
  final bool isLoading;
  final String? error;
  final String searchQuery;
  final String? selectedCategory;

  const ProductState({
    this.products = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.selectedCategory,
  });

  List<ProductModel> get filtered {
    var list = products;
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      list = list.where((p) =>
          p.name.toLowerCase().contains(q) ||
          (p.barcode?.contains(q) ?? false) ||
          (p.sku?.toLowerCase().contains(q) ?? false)).toList();
    }
    if (selectedCategory != null) {
      list = list.where((p) => p.category == selectedCategory).toList();
    }
    return list;
  }

  List<ProductModel> get lowStock =>
      products.where((p) => p.quantity <= p.minStockLevel && p.isActive).toList();

  ProductState copyWith({List<ProductModel>? products, bool? isLoading, String? error,
      String? searchQuery, String? selectedCategory}) =>
      ProductState(
        products: products ?? this.products,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        searchQuery: searchQuery ?? this.searchQuery,
        selectedCategory: selectedCategory,
      );
}

class ProductNotifier extends StateNotifier<ProductState> {
  ProductNotifier() : super(const ProductState()) { loadLocal(); }

  Future<void> loadLocal() async {
    final db = await LocalDb.db;
    final rows = await db.query('products', where: 'isActive = 1', orderBy: 'name ASC');
    state = state.copyWith(products: rows.map(ProductModel.fromMap).toList());
  }

  Future<void> fetchFromServer() async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await ApiClient.instance.get('/products', params: {'limit': '500'});
      final list = (res.data['data'] as List).map((j) => ProductModel.fromJson(j)).toList();
      final db = await LocalDb.db;
      final batch = db.batch();
      for (final p in list) {
        batch.insert('products', p.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
      state = state.copyWith(products: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<ProductModel?> saveProduct(Map<String, dynamic> data, {String? id}) async {
    try {
      final res = id != null
          ? await ApiClient.instance.put('/products/$id', data: data)
          : await ApiClient.instance.post('/products', data: data);
      final product = ProductModel.fromJson(res.data['data']);
      final db = await LocalDb.db;
      await db.insert('products', product.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      await loadLocal();
      return product;
    } catch (e) {
      // Save locally if offline
      final product = ProductModel(
        id: id ?? Helpers.generateId(),
        name: data['name'] ?? '',
        purchasePrice: (data['purchasePrice'] ?? 0).toDouble(),
        sellingPrice: (data['sellingPrice'] ?? 0).toDouble(),
        quantity: data['quantity'] ?? 0,
        category: data['category'] ?? 'General',
        barcode: data['barcode'],
        sku: data['sku'],
        minStockLevel: data['minStockLevel'] ?? 5,
        unit: data['unit'] ?? 'pcs',
      );
      final db = await LocalDb.db;
      await db.insert('products', product.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      await loadLocal();
      return product;
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      await ApiClient.instance.delete('/products/$id');
    } catch (_) {}
    final db = await LocalDb.db;
    await db.update('products', {'isActive': 0}, where: 'id = ?', whereArgs: [id]);
    await loadLocal();
  }

  void search(String q) => state = state.copyWith(searchQuery: q);
  void filterCategory(String? cat) => state = state.copyWith(selectedCategory: cat);

  ProductModel? findByBarcode(String barcode) =>
      state.products.where((p) => p.barcode == barcode).firstOrNull;
}

final productProvider = StateNotifierProvider<ProductNotifier, ProductState>((_) => ProductNotifier());

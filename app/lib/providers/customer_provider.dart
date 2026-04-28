import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../core/network/api_client.dart';
import '../core/database/local_db.dart';
import '../core/utils/helpers.dart';
import '../models/customer_model.dart';

class CustomerState {
  final List<CustomerModel> customers;
  final bool isLoading;
  final String? error;

  const CustomerState({this.customers = const [], this.isLoading = false, this.error});

  List<CustomerModel> get withBalance =>
      customers.where((c) => c.currentBalance > 0).toList();

  CustomerState copyWith({List<CustomerModel>? customers, bool? isLoading, String? error}) =>
      CustomerState(customers: customers ?? this.customers,
                    isLoading: isLoading ?? this.isLoading, error: error);
}

class CustomerNotifier extends StateNotifier<CustomerState> {
  CustomerNotifier() : super(const CustomerState()) { loadLocal(); }

  Future<void> loadLocal() async {
    final db = await LocalDb.db;
    final rows = await db.query('customers', where: 'isActive = 1', orderBy: 'name ASC');
    state = state.copyWith(customers: rows.map(CustomerModel.fromMap).toList());
  }

  Future<void> fetchFromServer() async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await ApiClient.instance.get('/customers', params: {'limit': '500'});
      final list = (res.data['data'] as List).map((j) => CustomerModel.fromJson(j)).toList();
      final db = await LocalDb.db;
      final batch = db.batch();
      for (final c in list) {
        batch.insert('customers', c.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
      state = state.copyWith(customers: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<CustomerModel?> saveCustomer(Map<String, dynamic> data, {String? id}) async {
    try {
      final res = id != null
          ? await ApiClient.instance.put('/customers/$id', data: data)
          : await ApiClient.instance.post('/customers', data: data);
      final customer = CustomerModel.fromJson(res.data['data']);
      final db = await LocalDb.db;
      await db.insert('customers', customer.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      await loadLocal();
      return customer;
    } catch (_) {
      final customer = CustomerModel(id: id ?? Helpers.generateId(), name: data['name'] ?? '',
          phone: data['phone'], email: data['email'], address: data['address']);
      final db = await LocalDb.db;
      await db.insert('customers', customer.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      await loadLocal();
      return customer;
    }
  }

  Future<void> deleteCustomer(String id) async {
    try { await ApiClient.instance.delete('/customers/$id'); } catch (_) {}
    final db = await LocalDb.db;
    await db.update('customers', {'isActive': 0}, where: 'id = ?', whereArgs: [id]);
    await loadLocal();
  }
}

final customerProvider = StateNotifierProvider<CustomerNotifier, CustomerState>((_) => CustomerNotifier());

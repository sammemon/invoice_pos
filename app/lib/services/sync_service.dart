import '../core/database/local_db.dart';
import '../core/network/api_client.dart';

class SyncService {
  static Future<int> pendingCount() async {
    final db = await LocalDb.db;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as c FROM sales WHERE isSynced = 0');
    final salesCount = (result.first['c'] as int? ?? 0);
    final expResult = await db.rawQuery(
        'SELECT COUNT(*) as c FROM expenses WHERE isSynced = 0');
    final expCount = (expResult.first['c'] as int? ?? 0);
    return salesCount + expCount;
  }

  static Future<void> syncAll() async {
    await _syncSales();
    await _syncExpenses();
    await _syncPurchases();
  }

  static Future<void> _syncSales() async {
    final db = await LocalDb.db;
    final pending = await db.query('sales', where: 'isSynced = 0');
    for (final row in pending) {
      try {
        final items = await db.query('sale_items',
            where: 'saleId = ?', whereArgs: [row['id']]);
        final payload = {
          ...row,
          'syncId': row['id'],
          'items': items.map((i) => {
            'productId': i['productId'],
            'productName': i['productName'],
            'quantity': i['quantity'],
            'sellingPrice': i['sellingPrice'],
            'discount': i['discount'],
          }).toList(),
        };
        final res = await ApiClient.instance.post('/sales', data: payload);
        final serverId = res.data['data']?['_id'];
        await db.update('sales', {'isSynced': 1, 'serverId': serverId},
            where: 'id = ?', whereArgs: [row['id']]);
      } catch (_) {
        // Will retry next sync
      }
    }
  }

  static Future<void> _syncExpenses() async {
    final db = await LocalDb.db;
    final pending = await db.query('expenses', where: 'isSynced = 0');
    for (final row in pending) {
      try {
        final res = await ApiClient.instance.post('/expenses', data: {
          ...row, 'syncId': row['id'],
        });
        final serverId = res.data['data']?['_id'];
        await db.update('expenses', {'isSynced': 1, 'serverId': serverId},
            where: 'id = ?', whereArgs: [row['id']]);
      } catch (_) {}
    }
  }

  static Future<void> _syncPurchases() async {
    final db = await LocalDb.db;
    final pending = await db.query('purchases', where: 'isSynced = 0');
    for (final row in pending) {
      try {
        final items = await db.query('purchase_items',
            where: 'purchaseId = ?', whereArgs: [row['id']]);
        await ApiClient.instance.post('/purchases', data: {
          ...row, 'syncId': row['id'],
          'items': items.map((i) => {
            'productId': i['productId'],
            'quantity': i['quantity'],
            'costPrice': i['costPrice'],
          }).toList(),
        });
        await db.update('purchases', {'isSynced': 1},
            where: 'id = ?', whereArgs: [row['id']]);
      } catch (_) {}
    }
  }
}

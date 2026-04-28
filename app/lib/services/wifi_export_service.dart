import 'dart:convert';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import '../core/database/local_db.dart';
import '../core/utils/helpers.dart';

class WifiExportService {
  static dynamic _server;
  static const int _port = 8080;

  static Future<String> start() async {
    final router = Router();

    router.get('/', (_) => Response.ok(
      _htmlPage(), headers: {'Content-Type': 'text/html'}));

    router.get('/api/sales', (_) async {
      final db = await LocalDb.db;
      final rows = await db.query('sales', orderBy: 'saleDate DESC', limit: 1000);
      return Response.ok(jsonEncode(rows), headers: {'Content-Type': 'application/json'});
    });

    router.get('/api/products', (_) async {
      final db = await LocalDb.db;
      final rows = await db.query('products', where: 'isActive = 1');
      return Response.ok(jsonEncode(rows), headers: {'Content-Type': 'application/json'});
    });

    router.get('/api/customers', (_) async {
      final db = await LocalDb.db;
      final rows = await db.query('customers', where: 'isActive = 1');
      return Response.ok(jsonEncode(rows), headers: {'Content-Type': 'application/json'});
    });

    router.get('/export/sales.csv', (_) async {
      final db = await LocalDb.db;
      final rows = await db.query('sales', orderBy: 'saleDate DESC', limit: 1000);
      final csv = _toCsv(['invoiceNumber','customerName','grandTotal','paidAmount','paymentStatus','saleDate'], rows);
      return Response.ok(csv, headers: {
        'Content-Type': 'text/csv',
        'Content-Disposition': 'attachment; filename="sales_${Helpers.formatDateOnly(DateTime.now())}.csv"',
      });
    });

    router.get('/export/products.csv', (_) async {
      final db = await LocalDb.db;
      final rows = await db.query('products', where: 'isActive = 1');
      final csv = _toCsv(['name','category','purchasePrice','sellingPrice','quantity','unit','barcode'], rows);
      return Response.ok(csv, headers: {
        'Content-Type': 'text/csv',
        'Content-Disposition': 'attachment; filename="products.csv"',
      });
    });

    final handler = const Pipeline().addMiddleware(logRequests()).addHandler(router.call);
    _server = await io.serve(handler, '0.0.0.0', _port);

    final ip = await NetworkInfo().getWifiIP() ?? 'localhost';
    return 'http://$ip:$_port';
  }

  static void stop() {
    _server?.close(force: true);
    _server = null;
  }

  static String _toCsv(List<String> headers, List<Map<String, dynamic>> rows) {
    final buf = StringBuffer();
    buf.writeln(headers.join(','));
    for (final row in rows) {
      buf.writeln(headers.map((h) {
        final v = row[h]?.toString() ?? '';
        return v.contains(',') ? '"$v"' : v;
      }).join(','));
    }
    return buf.toString();
  }

  static String _htmlPage() => '''
<!DOCTYPE html><html><head><title>Invoice POS Export</title>
<style>body{font-family:sans-serif;max-width:600px;margin:40px auto;padding:20px}
h1{color:#1565C0}a.btn{display:inline-block;margin:8px;padding:12px 24px;background:#1565C0;color:#fff;text-decoration:none;border-radius:8px}</style></head>
<body><h1>&#128197; Invoice & POS Export</h1>
<p>Download your data files:</p>
<a class="btn" href="/export/sales.csv">&#128202; Sales CSV</a>
<a class="btn" href="/export/products.csv">&#128230; Products CSV</a>
<br/><br/><p style="color:#666;font-size:12px">Generated: ${DateTime.now()}</p>
</body></html>''';
}

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class LocalDb {
  static Database? _db;

  static Future<Database> get db async => _db ??= await _init();

  static Future<Database> _init() async {
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final path = join(await getDatabasesPath(), 'invoice_pos.db');
    return openDatabase(path, version: 1, onCreate: _onCreate);
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY, serverId TEXT, name TEXT NOT NULL, sku TEXT, barcode TEXT,
        category TEXT DEFAULT 'General', purchasePrice REAL NOT NULL, sellingPrice REAL NOT NULL,
        quantity INTEGER DEFAULT 0, minStockLevel INTEGER DEFAULT 5, unit TEXT DEFAULT 'pcs',
        isActive INTEGER DEFAULT 1, updatedAt TEXT, syncedAt TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE sales (
        id TEXT PRIMARY KEY, serverId TEXT, invoiceNumber TEXT, customerId TEXT,
        customerName TEXT, subTotal REAL, discountAmount REAL DEFAULT 0,
        taxAmount REAL DEFAULT 0, grandTotal REAL, paidAmount REAL DEFAULT 0,
        dueAmount REAL DEFAULT 0, paymentMethod TEXT DEFAULT 'cash',
        paymentStatus TEXT DEFAULT 'paid', notes TEXT,
        saleDate TEXT, syncedAt TEXT, isSynced INTEGER DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE sale_items (
        id TEXT PRIMARY KEY, saleId TEXT, productId TEXT, productName TEXT,
        quantity INTEGER, purchasePrice REAL, sellingPrice REAL,
        discount REAL DEFAULT 0, total REAL,
        FOREIGN KEY (saleId) REFERENCES sales(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY, serverId TEXT, name TEXT NOT NULL, phone TEXT,
        email TEXT, address TEXT, currentBalance REAL DEFAULT 0,
        isActive INTEGER DEFAULT 1, syncedAt TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE suppliers (
        id TEXT PRIMARY KEY, serverId TEXT, name TEXT NOT NULL, phone TEXT,
        email TEXT, company TEXT, currentBalance REAL DEFAULT 0,
        isActive INTEGER DEFAULT 1, syncedAt TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE purchases (
        id TEXT PRIMARY KEY, serverId TEXT, purchaseNumber TEXT,
        supplierId TEXT, supplierName TEXT, totalAmount REAL,
        paidAmount REAL DEFAULT 0, dueAmount REAL DEFAULT 0,
        paymentStatus TEXT DEFAULT 'paid', notes TEXT,
        purchaseDate TEXT, isSynced INTEGER DEFAULT 0, syncedAt TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE purchase_items (
        id TEXT PRIMARY KEY, purchaseId TEXT, productId TEXT, productName TEXT,
        quantity INTEGER, costPrice REAL, total REAL,
        FOREIGN KEY (purchaseId) REFERENCES purchases(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY, serverId TEXT, title TEXT, category TEXT,
        amount REAL, description TEXT, expenseDate TEXT,
        paymentMethod TEXT DEFAULT 'cash', isSynced INTEGER DEFAULT 0, syncedAt TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE sync_queue (
        id TEXT PRIMARY KEY, type TEXT, action TEXT,
        payload TEXT, createdAt TEXT, attempts INTEGER DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX idx_sales_date ON sales(saleDate)');
    await db.execute('CREATE INDEX idx_products_barcode ON products(barcode)');
  }
}

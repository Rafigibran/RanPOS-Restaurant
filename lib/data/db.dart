import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

const uuidGen = Uuid();
const backupSchemaVersion = 1;

/// Local SQLite database, the single source of truth for MVP operations.
/// All order writes go through a transaction in the repository.
class RanDb {
  static Database? _db;

  static Future<Database> instance() async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, 'ranpos.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE business_profile(id TEXT PRIMARY KEY, name TEXT NOT NULL, currency_code TEXT NOT NULL, currency_symbol TEXT NOT NULL, tax_percent INTEGER NOT NULL, tax_inclusive INTEGER NOT NULL, address TEXT, phone TEXT, updated_at TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE menu_categories(id TEXT PRIMARY KEY, name TEXT NOT NULL, sort_order INTEGER NOT NULL, is_active INTEGER NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE menu_items(id TEXT PRIMARY KEY, category_id TEXT, name TEXT NOT NULL, description TEXT, price_minor INTEGER NOT NULL, sku TEXT, is_active INTEGER NOT NULL, stock_tracking INTEGER NOT NULL, stock_quantity INTEGER NOT NULL, low_stock_threshold INTEGER NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE customers(id TEXT PRIMARY KEY, name TEXT NOT NULL, phone TEXT, email TEXT, address TEXT, notes TEXT, created_at TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE floors(id TEXT PRIMARY KEY, name TEXT NOT NULL, sort_order INTEGER NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE restaurant_tables(id TEXT PRIMARY KEY, floor_id TEXT, label TEXT NOT NULL, capacity INTEGER NOT NULL, is_active INTEGER NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE orders(id TEXT PRIMARY KEY, display_number TEXT NOT NULL UNIQUE, order_type TEXT NOT NULL, customer_id TEXT, table_id TEXT, guest_count INTEGER NOT NULL, order_status TEXT NOT NULL, payment_status TEXT NOT NULL, notes TEXT, subtotal_minor INTEGER NOT NULL, tax_minor INTEGER NOT NULL, total_minor INTEGER NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, cancel_reason TEXT)',
        );
        await db.execute(
          'CREATE TABLE order_items(id TEXT PRIMARY KEY, order_id TEXT NOT NULL, menu_item_id TEXT, item_name TEXT NOT NULL, price_minor INTEGER NOT NULL, quantity INTEGER NOT NULL, line_discount_minor INTEGER NOT NULL, notes TEXT)',
        );
        await db.execute(
          'CREATE TABLE payments(id TEXT PRIMARY KEY, order_id TEXT NOT NULL, method TEXT NOT NULL, amount_minor INTEGER NOT NULL, status TEXT NOT NULL, reference TEXT, paid_at TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE stock_movements(id TEXT PRIMARY KEY, menu_item_id TEXT NOT NULL, delta INTEGER NOT NULL, reason TEXT NOT NULL, order_id TEXT, created_at TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE in_app_notifications(id TEXT PRIMARY KEY, type TEXT NOT NULL, title TEXT NOT NULL, message TEXT NOT NULL, related_id TEXT, read_at TEXT, created_at TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE app_settings(key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE backup_metadata(id TEXT PRIMARY KEY, provider TEXT NOT NULL, remote_path TEXT, created_at TEXT NOT NULL, size_bytes INTEGER NOT NULL, schema_version INTEGER NOT NULL, status TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE INDEX idx_orders_status ON orders(order_status)',
        );
        await db.execute(
          'CREATE INDEX idx_orders_created ON orders(created_at)',
        );
        await db.execute(
          'CREATE INDEX idx_items_order ON order_items(order_id)',
        );
      },
    );
    return _db!;
  }

  static Future<void> closeForTest() async {
    await _db?.close();
    _db = null;
  }
}

String nowIso() => DateTime.now().toUtc().toIso8601String();
String newId() => uuidGen.v4();

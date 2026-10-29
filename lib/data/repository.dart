import 'package:sqflite/sqflite.dart';
import '../core/money.dart';
import 'db.dart';
import 'seed.dart';

/// Repository over SQLite. UI never touches the database directly.
/// Order creation, payment and cancellation are atomic: order + items +
/// stock movements + notification are written in one transaction.
class Repository {
  Future<Database> get _db async => RanDb.instance();

  Future<Map<String, dynamic>?> business() async {
    final db = await _db;
    final rows = await db.query('business_profile', limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> saveBusiness(Map<String, dynamic> b) async {
    final db = await _db;
    final row = {
      'id': 'main',
      'name': b['name'],
      'currency_code': b['currency_code'],
      'currency_symbol': b['currency_symbol'],
      'tax_percent': b['tax_percent'],
      'tax_inclusive': (b['tax_inclusive'] == true) ? 1 : 0,
      'address': b['address'] ?? '',
      'phone': b['phone'] ?? '',
      'updated_at': nowIso(),
    };
    await db.insert(
      'business_profile',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> ensureSeeded(bool loadSample) async {
    final db = await _db;
    final cats = await db.query('menu_categories', limit: 1);
    if (cats.isNotEmpty) return;
    if (!loadSample) {
      await db.insert('menu_categories', {
        'id': newId(),
        'name': 'Main Course',
        'sort_order': 0,
        'is_active': 1,
      });
      await db.insert('floors', {
        'id': newId(),
        'name': '1st Floor',
        'sort_order': 0,
      });
      return;
    }
    await seedSampleData(db);
  }

  Future<void> clearAllData() async {
    final db = await _db;
    for (final t in [
      'menu_items',
      'menu_categories',
      'customers',
      'restaurant_tables',
      'floors',
      'orders',
      'order_items',
      'payments',
      'stock_movements',
      'in_app_notifications',
      'backup_metadata',
    ]) {
      await db.delete(t);
    }
  }

  // ---- reads ----
  Future<List<Map<String, dynamic>>> categories() async =>
      (await _db).query('menu_categories', orderBy: 'sort_order');
  Future<List<Map<String, dynamic>>> menuItems() async =>
      (await _db).query('menu_items', orderBy: 'name');
  Future<List<Map<String, dynamic>>> customers() async =>
      (await _db).query('customers', orderBy: 'name');
  Future<List<Map<String, dynamic>>> floors() async =>
      (await _db).query('floors', orderBy: 'sort_order');
  Future<List<Map<String, dynamic>>> tables() async =>
      (await _db).query('restaurant_tables', orderBy: 'label');
  Future<List<Map<String, dynamic>>> orders() async =>
      (await _db).query('orders', orderBy: 'created_at DESC');
  Future<List<Map<String, dynamic>>> orderItems(String orderId) async =>
      (await _db).query(
        'order_items',
        where: 'order_id = ?',
        whereArgs: [orderId],
      );
  Future<List<Map<String, dynamic>>> paymentsFor(String orderId) async =>
      (await _db).query(
        'payments',
        where: 'order_id = ?',
        whereArgs: [orderId],
      );
  Future<List<Map<String, dynamic>>> notifications() async =>
      (await _db).query('in_app_notifications', orderBy: 'created_at DESC');
  Future<List<Map<String, dynamic>>> stockMovements() async => (await _db)
      .query('stock_movements', orderBy: 'created_at DESC', limit: 100);
  Future<Map<String, dynamic>?> orderById(String id) async {
    final db = await _db;
    final rows = await db.query('orders', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<Set<String>> occupiedTableIds() async {
    final db = await _db;
    final rows = await db.query(
      'orders',
      columns: ['table_id'],
      where: "table_id IS NOT NULL AND order_status IN ('in_progress','ready')",
    );
    return rows.map((r) => r['table_id'] as String).toSet();
  }

  Future<void> markNotificationsRead() async {
    final db = await _db;
    await db.update('in_app_notifications', {
      'read_at': nowIso(),
    }, where: 'read_at IS NULL');
  }

  Future<void> notify(
    String type,
    String title,
    String message, [
    String? relatedId,
  ]) async {
    final db = await _db;
    await db.insert('in_app_notifications', {
      'id': newId(),
      'type': type,
      'title': title,
      'message': message,
      'related_id': relatedId,
      'read_at': null,
      'created_at': nowIso(),
    });
  }

  // ---- menu / customers / tables CRUD ----
  Future<void> upsertMenuItem(Map<String, dynamic> item) async {
    final db = await _db;
    await db.insert(
      'menu_items',
      item,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> archiveMenuItem(String id) async {
    final db = await _db;
    await db.update(
      'menu_items',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> upsertCustomer(Map<String, dynamic> c) async {
    final db = await _db;
    await db.insert(
      'customers',
      c,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertTable(Map<String, dynamic> t) async {
    final db = await _db;
    await db.insert(
      'restaurant_tables',
      t,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> adjustStock(
    String itemId,
    int delta,
    String reason,
    String? orderId,
  ) async {
    final db = await _db;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'menu_items',
        where: 'id = ?',
        whereArgs: [itemId],
      );
      if (rows.isEmpty) return;
      final current = rows.first['stock_quantity'] as int;
      final next = current + delta;
      if (next < 0) throw Exception('Stock would go below zero');
      await txn.update(
        'menu_items',
        {'stock_quantity': next},
        where: 'id = ?',
        whereArgs: [itemId],
      );
      await txn.insert('stock_movements', {
        'id': newId(),
        'menu_item_id': itemId,
        'delta': delta,
        'reason': reason,
        'order_id': orderId,
        'created_at': nowIso(),
      });
    });
  }

  // ---- orders ----
  Future<String> createOrder({
    required String type,
    String? customerId,
    String? tableId,
    required int guests,
    required List<Map<String, dynamic>> cart, // menu item maps + qty
    required int taxPercent,
    required bool taxInclusive,
  }) async {
    final db = await _db;
    if (cart.isEmpty) throw Exception('Order needs at least one item');
    if (type == 'dine_in' && tableId != null) {
      final occupied = await occupiedTableIds();
      if (occupied.contains(tableId)) {
        throw Exception('Table is already used by an active order');
      }
    }
    // Validate stock before writing anything.
    for (final line in cart) {
      final tracking = line['stock_tracking'] == 1;
      if (tracking) {
        final qty = line['qty'] as int;
        final stock = line['stock_quantity'] as int;
        final active = line['is_active'] == 1;
        if (!active) throw Exception('Inactive item in cart');
        if (stock < qty) throw Exception('Not enough stock');
      }
    }
    final lines = cart
        .map(
          (l) => (
            price: l['price_minor'] as int,
            qty: l['qty'] as int,
            discount: 0,
          ),
        )
        .toList();
    final totals = calcTotals(
      lines: lines,
      taxPercent: taxPercent,
      taxInclusive: taxInclusive,
    );
    final orderId = newId();
    final count =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM orders'),
        ) ??
        0;
    final display = orderDisplayNumber(DateTime.now(), count + 1);
    await db.transaction((txn) async {
      await txn.insert('orders', {
        'id': orderId,
        'display_number': display,
        'order_type': type,
        'customer_id': customerId,
        'table_id': tableId,
        'guest_count': guests,
        'order_status': 'in_progress',
        'payment_status': 'unpaid',
        'notes': null,
        'subtotal_minor': totals.subtotal,
        'tax_minor': totals.tax,
        'total_minor': totals.total,
        'created_at': nowIso(),
        'updated_at': nowIso(),
        'cancel_reason': null,
      });
      for (final line in cart) {
        await txn.insert('order_items', {
          'id': newId(),
          'order_id': orderId,
          'menu_item_id': line['id'],
          'item_name': line['name'],
          'price_minor': line['price_minor'],
          'quantity': line['qty'],
          'line_discount_minor': 0,
          'notes': line['note'] ?? '',
        });
        if (line['stock_tracking'] == 1) {
          await txn.update(
            'menu_items',
            {
              'stock_quantity':
                  (line['stock_quantity'] as int) - (line['qty'] as int),
            },
            where: 'id = ?',
            whereArgs: [line['id']],
          );
          await txn.insert('stock_movements', {
            'id': newId(),
            'menu_item_id': line['id'],
            'delta': -(line['qty'] as int),
            'reason': 'order_confirmed',
            'order_id': orderId,
            'created_at': nowIso(),
          });
        }
      }
      await txn.insert('in_app_notifications', {
        'id': newId(),
        'type': 'order_created',
        'title': 'New order $display',
        'message': 'Order created and sent to preparation.',
        'related_id': orderId,
        'read_at': null,
        'created_at': nowIso(),
      });
    });
    return orderId;
  }

  Future<void> addItemToOrder(
    String orderId,
    Map<String, dynamic> item,
    int qty,
  ) async {
    final db = await _db;
    final order = await orderById(orderId);
    if (order == null) return;
    if (order['order_status'] == 'completed' ||
        order['order_status'] == 'cancelled') {
      throw Exception('Order can no longer be changed');
    }
    await db.transaction((txn) async {
      await txn.insert('order_items', {
        'id': newId(),
        'order_id': orderId,
        'menu_item_id': item['id'],
        'item_name': item['name'],
        'price_minor': item['price_minor'],
        'quantity': qty,
        'line_discount_minor': 0,
        'notes': '',
      });
      if (item['stock_tracking'] == 1) {
        final stock = item['stock_quantity'] as int;
        if (stock < qty) throw Exception('Not enough stock');
        await txn.update(
          'menu_items',
          {'stock_quantity': stock - qty},
          where: 'id = ?',
          whereArgs: [item['id']],
        );
        await txn.insert('stock_movements', {
          'id': newId(),
          'menu_item_id': item['id'],
          'delta': -qty,
          'reason': 'order_item_added',
          'order_id': orderId,
          'created_at': nowIso(),
        });
      }
      await _recalcTotals(txn, orderId);
    });
  }

  Future<void> _recalcTotals(Transaction txn, String orderId) async {
    final orderRows = await txn.query(
      'orders',
      where: 'id = ?',
      whereArgs: [orderId],
    );
    if (orderRows.isEmpty) return;
    final biz = await txn.query('business_profile', limit: 1);
    final taxPercent = biz.isEmpty ? 5 : biz.first['tax_percent'] as int;
    final taxInclusive =
        biz.isNotEmpty && (biz.first['tax_inclusive'] as int) == 1;
    final items = await txn.query(
      'order_items',
      where: 'order_id = ?',
      whereArgs: [orderId],
    );
    final lines = items
        .map(
          (i) => (
            price: i['price_minor'] as int,
            qty: i['quantity'] as int,
            discount: i['line_discount_minor'] as int,
          ),
        )
        .toList();
    final t = calcTotals(
      lines: lines,
      taxPercent: taxPercent,
      taxInclusive: taxInclusive,
    );
    await txn.update(
      'orders',
      {
        'subtotal_minor': t.subtotal,
        'tax_minor': t.tax,
        'total_minor': t.total,
        'updated_at': nowIso(),
      },
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  Future<void> updateOrderStatus(
    String orderId,
    String status, {
    String? reason,
  }) async {
    final db = await _db;
    final order = await orderById(orderId);
    if (order == null) return;
    await db.transaction((txn) async {
      await txn.update(
        'orders',
        {
          'order_status': status,
          'updated_at': nowIso(),
          if (reason != null) 'cancel_reason': reason,
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );
      if (status == 'ready') {
        await txn.insert('in_app_notifications', {
          'id': newId(),
          'type': 'order_ready',
          'title': 'Order ready',
          'message': '${order['display_number']} is ready to serve.',
          'related_id': orderId,
          'read_at': null,
          'created_at': nowIso(),
        });
      }
      if (status == 'cancelled') {
        // Return stock for this order.
        final items = await txn.query(
          'order_items',
          where: 'order_id = ?',
          whereArgs: [orderId],
        );
        for (final it in items) {
          final menuId = it['menu_item_id'] as String?;
          if (menuId == null) continue;
          final menu = await txn.query(
            'menu_items',
            where: 'id = ?',
            whereArgs: [menuId],
          );
          if (menu.isEmpty) continue;
          if (menu.first['stock_tracking'] != 1) continue;
          final stock = menu.first['stock_quantity'] as int;
          await txn.update(
            'menu_items',
            {'stock_quantity': stock + (it['quantity'] as int)},
            where: 'id = ?',
            whereArgs: [menuId],
          );
          await txn.insert('stock_movements', {
            'id': newId(),
            'menu_item_id': menuId,
            'delta': it['quantity'] as int,
            'reason': 'order_cancelled',
            'order_id': orderId,
            'created_at': nowIso(),
          });
        }
      }
    });
  }

  Future<void> recordPayment(
    String orderId,
    String method,
    int amountMinor,
  ) async {
    final db = await _db;
    final order = await orderById(orderId);
    if (order == null) throw Exception('Order not found');
    await db.transaction((txn) async {
      await txn.insert('payments', {
        'id': newId(),
        'order_id': orderId,
        'method': method,
        'amount_minor': amountMinor,
        'status': 'confirmed',
        'reference': null,
        'paid_at': nowIso(),
      });
      final paidRows = await txn.rawQuery(
        "SELECT COALESCE(SUM(amount_minor),0) AS s FROM payments WHERE order_id = ? AND status='confirmed'",
        [orderId],
      );
      final paid = (paidRows.first['s'] as int?) ?? 0;
      final total = order['total_minor'] as int;
      await txn.update(
        'orders',
        {
          'payment_status': paid >= total ? 'paid' : 'partially_paid',
          'updated_at': nowIso(),
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );
      await txn.insert('in_app_notifications', {
        'id': newId(),
        'type': 'payment_completed',
        'title': 'Payment completed',
        'message': 'Payment recorded for ${order['display_number']}.',
        'related_id': orderId,
        'read_at': null,
        'created_at': nowIso(),
      });
    });
  }

  // ---- reports ----
  Future<Map<String, dynamic>> report({DateTime? from, DateTime? to}) async {
    final db = await _db;
    final fromIso = from?.toUtc().toIso8601String();
    final toIso = to?.toUtc().toIso8601String();
    var where = "p.status='confirmed'";
    final args = <Object?>[];
    if (fromIso != null) {
      where += ' AND p.paid_at >= ?';
      args.add(fromIso);
    }
    if (toIso != null) {
      where += ' AND p.paid_at <= ?';
      args.add(toIso);
    }
    final rev = await db.rawQuery(
      'SELECT COALESCE(SUM(p.amount_minor),0) AS revenue, COUNT(DISTINCT p.order_id) AS orders FROM payments p WHERE $where',
      args,
    );
    final byMethod = await db.rawQuery(
      'SELECT p.method AS method, COALESCE(SUM(p.amount_minor),0) AS total FROM payments p WHERE $where GROUP BY p.method',
      args,
    );
    final top = await db.rawQuery('''
      SELECT oi.item_name AS name, SUM(oi.quantity) AS qty,
             SUM(oi.price_minor * oi.quantity) AS value
      FROM order_items oi JOIN orders o ON o.id = oi.order_id
      JOIN payments p ON p.order_id = o.id AND p.status='confirmed'
      GROUP BY oi.item_name ORDER BY qty DESC LIMIT 5
    ''');
    return {
      'revenue': rev.first['revenue'] as int? ?? 0,
      'orders': rev.first['orders'] as int? ?? 0,
      'byMethod': byMethod,
      'top': top,
    };
  }

  // ---- backup snapshot ----
  Future<Map<String, dynamic>> buildBackup() async {
    final db = await _db;
    final data = <String, dynamic>{};
    for (final t in [
      'business_profile',
      'menu_categories',
      'menu_items',
      'customers',
      'floors',
      'restaurant_tables',
      'orders',
      'order_items',
      'payments',
      'stock_movements',
      'in_app_notifications',
      'app_settings',
    ]) {
      data[t] = await db.query(t);
    }
    return {
      'format': 'ranpos-backup',
      'backup_schema_version': backupSchemaVersion,
      'app_version': '1.0.0',
      'created_at': nowIso(),
      'data': data,
    };
  }

  Future<void> restoreBackup(Map<String, dynamic> backup) async {
    if (!validateBackup(backup)) throw Exception('Invalid backup file');
    final data = backup['data'] as Map<String, dynamic>;
    final db = await _db;
    await db.transaction((txn) async {
      for (final t in [
        'in_app_notifications',
        'stock_movements',
        'payments',
        'order_items',
        'orders',
        'restaurant_tables',
        'floors',
        'customers',
        'menu_items',
        'menu_categories',
        'business_profile',
        'app_settings',
      ]) {
        await txn.delete(t);
      }
      for (final entry in data.entries) {
        final rows = entry.value as List;
        for (final row in rows) {
          await txn.insert(
            entry.key,
            Map<String, Object?>.from(row as Map),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }
}

bool validateBackup(Map<String, dynamic> backup) {
  if (backup['format'] != 'ranpos-backup') return false;
  final v = backup['backup_schema_version'];
  if (v is! int || v > backupSchemaVersion) return false;
  final data = backup['data'];
  if (data is! Map) return false;
  return data.containsKey('orders') && data.containsKey('menu_items');
}

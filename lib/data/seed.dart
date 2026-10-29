import 'package:sqflite/sqflite.dart';
import 'db.dart';

/// Own demo content only. No brand, restaurant name, dish name or person
/// from the reference screenshots is copied here.
Future<void> seedSampleData(Database db) async {
  final now = nowIso();
  final catMain = newId();
  final catBreak = newId();
  final catFast = newId();
  final catDrink = newId();
  await db.insert('menu_categories', {
    'id': catMain,
    'name': 'Main Course',
    'sort_order': 0,
    'is_active': 1,
  });
  await db.insert('menu_categories', {
    'id': catBreak,
    'name': 'Breakfast',
    'sort_order': 1,
    'is_active': 1,
  });
  await db.insert('menu_categories', {
    'id': catFast,
    'name': 'Fast Food',
    'sort_order': 2,
    'is_active': 1,
  });
  await db.insert('menu_categories', {
    'id': catDrink,
    'name': 'Drinks',
    'sort_order': 3,
    'is_active': 1,
  });

  Future<String> item(String cat, String name, int price, int stock) async {
    final id = newId();
    await db.insert('menu_items', {
      'id': id,
      'category_id': cat,
      'name': name,
      'description': '',
      'price_minor': price,
      'sku': null,
      'is_active': 1,
      'stock_tracking': 1,
      'stock_quantity': stock,
      'low_stock_threshold': 5,
      'created_at': now,
      'updated_at': now,
    });
    return id;
  }

  final carbonara = await item(catMain, 'Creamy Carbonara', 1699, 20);
  final linguine = await item(catMain, 'Seafood Linguine', 1999, 12);
  final pappardelle = await item(catMain, 'Truffle Pappardelle', 1999, 8);
  final gnocchi = await item(catMain, 'Potato Gnocchi', 1199, 0);
  await item(catBreak, 'Morning Omelette', 899, 15);
  await item(catFast, 'Crispy Chicken Burger', 1099, 25);
  await item(catDrink, 'Iced Lemon Tea', 499, 40);

  Future<String> customer(String name, String email, String address) async {
    final id = newId();
    await db.insert('customers', {
      'id': id,
      'name': name,
      'phone': '',
      'email': email,
      'address': address,
      'notes': '',
      'created_at': now,
    });
    return id;
  }

  final ayu = await customer(
    'Ayu Lestari',
    'ayu@example.com',
    'Jl. Merdeka 12, Mataram',
  );
  final budi = await customer(
    'Budi Santoso',
    'budi@example.com',
    'Jl. Raya 45, Lombok',
  );
  final clara = await customer(
    'Clara Wijaya',
    'clara@example.com',
    'Jl. Pantai 8, Senggigi',
  );
  final dimas = await customer(
    'Dimas Pratama',
    'dimas@example.com',
    'Jl. Udayana 3, Mataram',
  );
  await customer(
    'Ella Maharani',
    'ella@example.com',
    'Jl. Cendana 21, Mataram',
  );
  await customer('Fajar Nugraha', 'fajar@example.com', 'Jl. Dahlia 7, Lombok');

  final floor1 = newId();
  final floor2 = newId();
  final floor3 = newId();
  await db.insert('floors', {
    'id': floor1,
    'name': '1st Floor',
    'sort_order': 0,
  });
  await db.insert('floors', {
    'id': floor2,
    'name': '2nd Floor',
    'sort_order': 1,
  });
  await db.insert('floors', {
    'id': floor3,
    'name': '3rd Floor',
    'sort_order': 2,
  });

  Future<String> table(String floor, String label, int cap) async {
    final id = newId();
    await db.insert('restaurant_tables', {
      'id': id,
      'floor_id': floor,
      'label': label,
      'capacity': cap,
      'is_active': 1,
    });
    return id;
  }

  final a6 = await table(floor1, 'A6', 4);
  final a7 = await table(floor1, 'A7', 2);
  for (var i = 1; i <= 8; i++) {
    if (i == 6 || i == 7) continue;
    await table(floor1, 'A$i', 4);
  }
  for (var i = 1; i <= 6; i++) {
    await table(floor2, 'B$i', 4);
  }
  for (var i = 1; i <= 4; i++) {
    await table(floor3, 'C$i', 6);
  }

  // A few seeded orders so dashboard, filters and reports are meaningful.
  Future<void> order(
    String display,
    String status,
    String pay,
    String? cust,
    String? tbl,
    List<(String, String, int, int)> lines,
  ) async {
    final id = newId();
    var sub = 0;
    for (final l in lines) {
      sub += l.$3 * l.$4;
    }
    final tax = (sub * 5 + 50) ~/ 100;
    await db.insert('orders', {
      'id': id,
      'display_number': display,
      'order_type': tbl == null ? 'takeaway' : 'dine_in',
      'customer_id': cust,
      'table_id': tbl,
      'guest_count': 2,
      'order_status': status,
      'payment_status': pay,
      'notes': null,
      'subtotal_minor': sub,
      'tax_minor': tax,
      'total_minor': sub + tax,
      'created_at': now,
      'updated_at': now,
      'cancel_reason': null,
    });
    for (final l in lines) {
      await db.insert('order_items', {
        'id': newId(),
        'order_id': id,
        'menu_item_id': l.$1,
        'item_name': l.$2,
        'price_minor': l.$3,
        'quantity': l.$4,
        'line_discount_minor': 0,
        'notes': '',
      });
    }
    if (pay == 'paid') {
      await db.insert('payments', {
        'id': newId(),
        'order_id': id,
        'method': 'cash',
        'amount_minor': sub + tax,
        'status': 'confirmed',
        'reference': null,
        'paid_at': now,
      });
    }
  }

  await order('RAN-20261029-0001', 'in_progress', 'unpaid', ayu, a6, [
    (carbonara, 'Creamy Carbonara', 1699, 1),
  ]);
  await order('RAN-20261029-0002', 'ready', 'unpaid', budi, a7, [
    (linguine, 'Seafood Linguine', 1999, 1),
  ]);
  await order('RAN-20261029-0003', 'completed', 'paid', clara, null, [
    (carbonara, 'Creamy Carbonara', 1699, 1),
    (pappardelle, 'Truffle Pappardelle', 1999, 1),
    (gnocchi, 'Potato Gnocchi', 1199, 1),
  ]);
  await order('RAN-20261029-0004', 'in_progress', 'unpaid', dimas, null, [
    (pappardelle, 'Truffle Pappardelle', 1999, 2),
  ]);
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n.dart';
import '../../core/money.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'order_detail.dart';

class CreateOrderPage extends ConsumerStatefulWidget {
  final String lang;
  const CreateOrderPage({super.key, required this.lang});
  @override
  ConsumerState<CreateOrderPage> createState() => _CreateOrderPageState();
}

class _CreateOrderPageState extends ConsumerState<CreateOrderPage> {
  String _type = 'dine_in';
  String? _customerId;
  String? _tableId;
  int _guests = 2;
  final Map<String, Map<String, dynamic>> _cart = {};
  bool _busy = false;
  String tr(String k) => L.t(widget.lang, k);

  @override
  Widget build(BuildContext context) {
    ref.watch(refreshProvider);
    final repo = ref.watch(repoProvider);
    final biz = ref.watch(businessProvider).value;
    final code = biz?['currency_code'] as String? ?? 'USD';
    final symbol = biz?['currency_symbol'] as String? ?? '\$';
    final tax = biz?['tax_percent'] as int? ?? 5;
    final taxInclusive = (biz?['tax_inclusive'] as int? ?? 0) == 1;
    final totals = calcTotals(
      lines: _cart.values
          .map(
            (e) => (
              price: e['price_minor'] as int,
              qty: e['qty'] as int,
              discount: 0,
            ),
          )
          .toList(),
      taxPercent: tax,
      taxInclusive: taxInclusive,
    );
    return Scaffold(
      appBar: AppBar(title: Text(tr('createNewOrder'))),
      body: FutureBuilder(
        future: Future.wait([
          repo.customers(),
          repo.tables(),
          repo.floors(),
          repo.menuItems(),
          repo.occupiedTableIds(),
        ]),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final customers = snap.data![0] as List<Map<String, dynamic>>;
          final tables = snap.data![1] as List<Map<String, dynamic>>;
          final floors = snap.data![2] as List<Map<String, dynamic>>;
          final menu = snap.data![3] as List<Map<String, dynamic>>;
          final occupied = snap.data![4] as Set<String>;
          final availableTables = tables
              .where((t) => t['is_active'] == 1)
              .where((t) => !occupied.contains(t['id']))
              .toList();
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _typeBtn(tr('dineIn'), 'dine_in')),
                      Expanded(child: _typeBtn(tr('takeaway'), 'takeaway')),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  tr('customerName'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  key: ValueKey(_customerId),
                  initialValue: _customerId,
                  decoration: const InputDecoration(),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(tr('walkIn')),
                    ),
                    for (final c in customers)
                      DropdownMenuItem<String?>(
                        value: c['id'] as String,
                        child: Text(c['name'] as String),
                      ),
                  ],
                  onChanged: (v) => setState(() => _customerId = v),
                ),
                const SizedBox(height: 16),
                Text(
                  tr('guest'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                RanCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$_guests ${tr('guest')}'),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _guests > 1
                                ? () => setState(() => _guests--)
                                : null,
                            icon: const Icon(Icons.remove_circle),
                          ),
                          IconButton(
                            onPressed: () => setState(() => _guests++),
                            icon: const Icon(
                              Icons.add_circle,
                              color: RanTheme.accent,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_type == 'dine_in') ...[
                  const SizedBox(height: 16),
                  Text(
                    tr('selectTable'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final t in availableTables)
                        ChoiceChip(
                          label: Text(t['label'] as String),
                          selected: _tableId == t['id'],
                          selectedColor: RanTheme.accent,
                          labelStyle: TextStyle(
                            color: _tableId == t['id']
                                ? Colors.white
                                : RanTheme.ink,
                          ),
                          onSelected: (_) =>
                              setState(() => _tableId = t['id'] as String),
                        ),
                      if (availableTables.isEmpty)
                        Text(
                          tr('empty'),
                          style: const TextStyle(color: RanTheme.muted),
                        ),
                    ],
                  ),
                  if (floors.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        floors.map((f) => f['name']).join(' · '),
                        style: const TextStyle(
                          color: RanTheme.muted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      tr('chooseMenu'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    Text('${_cart.length} ${tr('items')}'),
                  ],
                ),
                const SizedBox(height: 12),
                ...menu.where((i) => i['is_active'] == 1).map((it) {
                  final inCart = _cart[it['id']];
                  final qty = inCart?['qty'] as int? ?? 0;
                  final out =
                      it['stock_tracking'] == 1 &&
                      (it['stock_quantity'] as int) <= 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: RanCard(
                      child: Row(
                        children: [
                          DishThumb(name: it['name'] as String),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  it['name'] as String,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                MoneyText(
                                  it['price_minor'] as int,
                                  code: code,
                                  symbol: symbol,
                                ),
                                if (out)
                                  Text(
                                    tr('outOfStock'),
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (qty == 0)
                            IconButton(
                              onPressed: out
                                  ? null
                                  : () => setState(
                                      () => _cart[it['id'] as String] = {
                                        ...it,
                                        'qty': 1,
                                      },
                                    ),
                              icon: const Icon(
                                Icons.add_circle,
                                color: RanTheme.accent,
                                size: 32,
                              ),
                            )
                          else
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () => setState(() {
                                    if (qty <= 1) {
                                      _cart.remove(it['id']);
                                    } else {
                                      _cart[it['id'] as String]!['qty'] =
                                          qty - 1;
                                    }
                                  }),
                                  icon: const Icon(Icons.remove_circle),
                                ),
                                Text(
                                  '$qty',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => setState(
                                    () => _cart[it['id'] as String]!['qty'] =
                                        qty + 1,
                                  ),
                                  icon: const Icon(
                                    Icons.add_circle,
                                    color: RanTheme.accent,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                RanCard(
                  child: Column(
                    children: [
                      _sumRow(
                        tr('subtotal'),
                        formatMoney(totals.subtotal, code, symbol),
                      ),
                      _sumRow(tr('tax'), formatMoney(totals.tax, code, symbol)),
                      const Divider(),
                      _sumRow(
                        tr('total'),
                        formatMoney(totals.total, code, symbol),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _busy || _cart.isEmpty
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            try {
                              final id = await repo.createOrder(
                                type: _type,
                                customerId: _customerId,
                                tableId: _type == 'dine_in' ? _tableId : null,
                                guests: _guests,
                                cart: _cart.values.toList(),
                                taxPercent: tax,
                                taxInclusive: taxInclusive,
                              );
                              ref.read(refreshProvider.notifier).state++;
                              if (!context.mounted) return;
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => OrderDetailPage(
                                    lang: widget.lang,
                                    orderId: id,
                                  ),
                                ),
                              );
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(SnackBar(content: Text('$e')));
                              }
                              setState(() => _busy = false);
                            }
                          },
                    child: Text(tr('createOrder')),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _typeBtn(String label, String value) {
    final sel = _type == value;
    return InkWell(
      onTap: () => setState(() => _type = value),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: sel ? RanTheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: sel ? Colors.white : RanTheme.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _sumRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), Text(value)],
      ),
    );
  }
}

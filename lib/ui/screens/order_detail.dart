import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n.dart';
import '../../core/money.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'menu_picker.dart';

class OrderDetailPage extends ConsumerStatefulWidget {
  final String lang;
  final String orderId;
  const OrderDetailPage({super.key, required this.lang, required this.orderId});
  @override
  ConsumerState<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends ConsumerState<OrderDetailPage> {
  String tr(String k) => L.t(widget.lang, k);

  Future<void> _pay(
    Map<String, dynamic> order,
    String code,
    String symbol,
  ) async {
    var method = 'cash';
    final amountCtrl = TextEditingController(
      text: ((order['total_minor'] as int) / (isZeroDecimal(code) ? 1 : 100))
          .toString(),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('confirmPay')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${tr('total')}: ${formatMoney(order['total_minor'] as int, code, symbol)}',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: method,
              items: [
                DropdownMenuItem(value: 'cash', child: Text(tr('cash'))),
                DropdownMenuItem(value: 'card', child: Text(tr('card'))),
              ],
              onChanged: (v) => method = v ?? 'cash',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(labelText: tr('amountPaid')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('payBills')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final parsed = double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0;
    final minor = isZeroDecimal(code) ? parsed.round() : (parsed * 100).round();
    try {
      await ref.read(repoProvider).recordPayment(widget.orderId, method, minor);
      if (!mounted) return;
      final change = calcChange(
        paid: minor,
        total: order['total_minor'] as int,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            change > 0
                ? '${tr('change')}: ${formatMoney(change, code, symbol)}'
                : tr('paid'),
          ),
        ),
      );
      ref.read(refreshProvider.notifier).state++;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(refreshProvider);
    final repo = ref.watch(repoProvider);
    final biz = ref.watch(businessProvider).value;
    final code = biz?['currency_code'] as String? ?? 'USD';
    final symbol = biz?['currency_symbol'] as String? ?? '\$';
    return Scaffold(
      appBar: AppBar(title: Text(tr('detailOrder'))),
      body: FutureBuilder(
        future: Future.wait([
          repo.orderById(widget.orderId),
          repo.orderItems(widget.orderId),
          repo.customers(),
          repo.tables(),
          repo.paymentsFor(widget.orderId),
        ]),
        builder: (context, snap) {
          if (!snap.hasData || snap.data![0] == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final order = snap.data![0] as Map<String, dynamic>;
          final items = snap.data![1] as List<Map<String, dynamic>>;
          final customers = snap.data![2] as List<Map<String, dynamic>>;
          final tables = snap.data![3] as List<Map<String, dynamic>>;
          final payments = snap.data![4] as List<Map<String, dynamic>>;
          final cust = customers
              .where((c) => c['id'] == order['customer_id'])
              .toList();
          final table = tables
              .where((t) => t['id'] == order['table_id'])
              .toList();
          final paid = payments.fold<int>(
            0,
            (s, p) => s + (p['amount_minor'] as int),
          );
          final remaining = (order['total_minor'] as int) - paid;
          final editable =
              order['order_status'] != 'completed' &&
              order['order_status'] != 'cancelled';
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RanCard(
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE8E0),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            table.isEmpty
                                ? 'T'
                                : table.first['label'] as String,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: RanTheme.accent,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order['display_number'] as String,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '${(order['order_type'] as String) == 'dine_in' ? tr('dineIn') : tr('takeaway')} · ${order['guest_count']} ${tr('guest')}',
                              style: const TextStyle(
                                color: RanTheme.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusChip(
                        label: order['payment_status'] == 'paid'
                            ? tr('paid')
                            : tr('unpaid'),
                        color: order['payment_status'] == 'paid'
                            ? RanTheme.green
                            : RanTheme.amber,
                        icon: Icons.payment,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  tr('customerInfo'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                RanCard(
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: RanTheme.accent,
                        child: Text(
                          initials(
                            cust.isEmpty
                                ? tr('walkIn')
                                : cust.first['name'] as String,
                          ),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          cust.isEmpty
                              ? tr('walkIn')
                              : cust.first['name'] as String,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  tr('transactionDetails'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                RanCard(
                  child: Column(
                    children: [
                      for (final it in items)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  it['item_name'] as String,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text('x${it['quantity']}  '),
                              MoneyText(
                                (it['price_minor'] as int) *
                                    (it['quantity'] as int),
                                code: code,
                                symbol: symbol,
                              ),
                            ],
                          ),
                        ),
                      const Divider(),
                      _row(
                        tr('items'),
                        '${items.fold<int>(0, (s, i) => s + (i['quantity'] as int))}',
                      ),
                      _row(
                        tr('subtotal'),
                        formatMoney(
                          order['subtotal_minor'] as int,
                          code,
                          symbol,
                        ),
                      ),
                      _row(
                        tr('tax'),
                        formatMoney(order['tax_minor'] as int, code, symbol),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            tr('total'),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          MoneyText(
                            order['total_minor'] as int,
                            code: code,
                            symbol: symbol,
                          ),
                        ],
                      ),
                      if (remaining > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(tr('unpaid')),
                              MoneyText(remaining, code: code, symbol: symbol),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (editable)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showMenuPicker(
                          context,
                          lang: widget.lang,
                        );
                        if (picked != null) {
                          try {
                            await repo.addItemToOrder(
                              widget.orderId,
                              picked.$1,
                              picked.$2,
                            );
                            ref.read(refreshProvider.notifier).state++;
                            setState(() {});
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text('$e')));
                            }
                          }
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: Text('+ ${tr('addItem')}'),
                    ),
                  ),
                const SizedBox(height: 12),
                if (editable && order['order_status'] == 'in_progress')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await repo.updateOrderStatus(widget.orderId, 'ready');
                        ref.read(refreshProvider.notifier).state++;
                        setState(() {});
                      },
                      child: Text(tr('markReady')),
                    ),
                  ),
                if (editable && order['order_status'] == 'ready')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await repo.updateOrderStatus(
                          widget.orderId,
                          'completed',
                        );
                        ref.read(refreshProvider.notifier).state++;
                        setState(() {});
                      },
                      child: Text(tr('markCompleted')),
                    ),
                  ),
                const SizedBox(height: 12),
                if (order['payment_status'] != 'paid' &&
                    order['order_status'] != 'cancelled')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _pay(order, code, symbol),
                      icon: const Icon(Icons.payment),
                      label: Text(tr('payBills')),
                    ),
                  ),
                const SizedBox(height: 12),
                if (editable)
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () async {
                        await repo.updateOrderStatus(
                          widget.orderId,
                          'cancelled',
                          reason: 'cancelled_by_staff',
                        );
                        ref.read(refreshProvider.notifier).state++;
                        setState(() {});
                      },
                      child: Text(
                        tr('cancelled'),
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), Text(value)],
      ),
    );
  }
}

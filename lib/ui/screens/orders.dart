import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'order_detail.dart';

class OrdersPage extends ConsumerStatefulWidget {
  final String lang;
  const OrdersPage({super.key, required this.lang});
  @override
  ConsumerState<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends ConsumerState<OrdersPage> {
  String _filter = 'all';
  String _query = '';
  String tr(String k) => L.t(widget.lang, k);

  bool _matches(Map<String, dynamic> o) {
    if (_filter == 'in_progress' && o['order_status'] != 'in_progress') {
      return false;
    }
    if (_filter == 'ready' && o['order_status'] != 'ready') return false;
    if (_filter == 'waiting' &&
        !((o['payment_status'] == 'unpaid' ||
                o['payment_status'] == 'partially_paid') &&
            o['order_status'] != 'cancelled')) {
      return false;
    }
    if (_filter == 'completed' && o['order_status'] != 'completed') {
      return false;
    }
    if (_filter == 'cancelled' && o['order_status'] != 'cancelled') {
      return false;
    }
    if (_query.isNotEmpty &&
        !(o['display_number'] as String).toLowerCase().contains(
          _query.toLowerCase(),
        )) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(refreshProvider);
    final repo = ref.watch(repoProvider);
    final biz = ref.watch(businessProvider).value;
    final code = biz?['currency_code'] as String? ?? 'USD';
    final symbol = biz?['currency_symbol'] as String? ?? '\$';
    final filters = [
      ('all', tr('orders')),
      ('in_progress', tr('inProgress')),
      ('ready', tr('ready')),
      ('waiting', tr('waitingPayment')),
      ('completed', tr('completed')),
      ('cancelled', tr('cancelled')),
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: tr('searchOrder'),
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final f = filters[i];
              final sel = _filter == f.$1;
              return ChoiceChip(
                label: Text(f.$2),
                selected: sel,
                selectedColor: RanTheme.accent,
                labelStyle: TextStyle(color: sel ? Colors.white : RanTheme.ink),
                onSelected: (_) => setState(() => _filter = f.$1),
              );
            },
          ),
        ),
        Expanded(
          child: FutureBuilder(
            future: repo.orders(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final list = snap.data!.where(_matches).toList();
              if (list.isEmpty) {
                return EmptyState(
                  title: tr('empty'),
                  hint: tr('emptyOrdersHint'),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final o = list[i];
                  return RanCard(
                    onTap: () => Navigator.of(context)
                        .push(
                          MaterialPageRoute(
                            builder: (_) => OrderDetailPage(
                              lang: widget.lang,
                              orderId: o['id'] as String,
                            ),
                          ),
                        )
                        .then(
                          (_) => ref.read(refreshProvider.notifier).state++,
                        ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE8E0),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              (o['display_number'] as String).split('-').last,
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
                                o['display_number'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                (o['order_type'] as String) == 'dine_in'
                                    ? tr('dineIn')
                                    : tr('takeaway'),
                                style: const TextStyle(
                                  color: RanTheme.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            MoneyText(
                              o['total_minor'] as int,
                              code: code,
                              symbol: symbol,
                            ),
                            const SizedBox(height: 4),
                            StatusChip(
                              label: o['order_status'] == 'in_progress'
                                  ? tr('inProgress')
                                  : o['order_status'] == 'ready'
                                  ? tr('ready')
                                  : o['order_status'] == 'completed'
                                  ? tr('completed')
                                  : tr('cancelled'),
                              color: orderStatusColor(
                                o['order_status'] as String,
                              ),
                              icon: orderStatusIcon(
                                o['order_status'] as String,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

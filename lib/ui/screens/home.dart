import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'notifications.dart';
import 'order_detail.dart';

class HomePage extends ConsumerWidget {
  final String lang;
  final void Function(int) goTab;
  final VoidCallback openCreate;
  const HomePage({
    super.key,
    required this.lang,
    required this.goTab,
    required this.openCreate,
  });
  String tr(String k) => L.t(lang, k);

  String greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return tr('greetingMorning');
    if (h < 18) return tr('greetingAfternoon');
    return tr('greetingEvening');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final bizAsync = ref.watch(businessProvider);
    return bizAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (biz) {
        final code = biz?['currency_code'] as String? ?? 'USD';
        final symbol = biz?['currency_symbol'] as String? ?? '\$';
        final name = biz?['name'] as String? ?? 'RanPOS';
        return FutureBuilder(
          future: Future.wait([repo.orders(), repo.menuItems(), repo.report()]),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final orders = snap.data![0] as List<Map<String, dynamic>>;
            final items = snap.data![1] as List<Map<String, dynamic>>;
            final report = snap.data![2] as Map<String, dynamic>;
            final inProgress = orders
                .where((o) => o['order_status'] == 'in_progress')
                .length;
            final waiting = orders
                .where(
                  (o) =>
                      (o['payment_status'] == 'unpaid' ||
                          o['payment_status'] == 'partially_paid') &&
                      o['order_status'] != 'cancelled',
                )
                .length;
            final outStock = items
                .where(
                  (i) =>
                      i['stock_tracking'] == 1 &&
                      (i['stock_quantity'] as int) <= 0,
                )
                .toList();
            final lowStock = items
                .where(
                  (i) =>
                      i['stock_tracking'] == 1 &&
                      (i['stock_quantity'] as int) > 0 &&
                      (i['stock_quantity'] as int) <=
                          (i['low_stock_threshold'] as int),
                )
                .toList();
            final popular = items
                .where((i) => i['is_active'] == 1)
                .take(5)
                .toList();
            final revenue = report['revenue'] as int? ?? 0;
            final cardW = (MediaQuery.of(context).size.width * 0.38).clamp(
              132.0,
              160.0,
            );
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: RanTheme.accent,
                          borderRadius: BorderRadius.circular(23),
                        ),
                        child: const Icon(
                          Icons.store,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '${greeting()}, Admin',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: RanTheme.muted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => NotificationsPage(lang: lang),
                          ),
                        ),
                        icon: const Icon(Icons.notifications_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    tr('totalEarnings'),
                    style: const TextStyle(color: RanTheme.muted),
                  ),
                  const SizedBox(height: 4),
                  // Shrinks on narrow screens so long amounts never overflow.
                  FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: MoneyText(
                      revenue,
                      code: code,
                      symbol: symbol,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr('savedOnDevice'),
                    style: const TextStyle(color: RanTheme.green, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: RanCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.soup_kitchen,
                                    size: 16,
                                    color: RanTheme.amber,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      tr('inProgress'),
                                      style: const TextStyle(fontSize: 12),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$inProgress',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: RanCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.hourglass_bottom,
                                    size: 16,
                                    color: RanTheme.blue,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      tr('waitingPayment'),
                                      style: const TextStyle(fontSize: 12),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$waiting',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        tr('popularDishes'),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextButton(
                        onPressed: () => goTab(3),
                        child: Text(tr('viewAll')),
                      ),
                    ],
                  ),
                  if (popular.isEmpty)
                    EmptyState(title: tr('popularDishes'), hint: tr('empty'))
                  else
                    SizedBox(
                      height: 152,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: popular.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, i) {
                          final it = popular[i];
                          return SizedBox(
                            width: cardW,
                            child: RanCard(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  DishThumb(name: it['name'] as String),
                                  const Spacer(),
                                  Text(
                                    it['name'] as String,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  FittedBox(
                                    alignment: Alignment.centerLeft,
                                    fit: BoxFit.scaleDown,
                                    child: MoneyText(
                                      it['price_minor'] as int,
                                      code: code,
                                      symbol: symbol,
                                      style: const TextStyle(
                                        color: RanTheme.accent,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    tr('outOfStock'),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (outStock.isEmpty && lowStock.isEmpty)
                    RanCard(
                      child: Text(
                        tr('empty'),
                        style: const TextStyle(color: RanTheme.muted),
                      ),
                    )
                  else ...[
                    for (final it in [...outStock, ...lowStock])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: RanCard(
                          child: Row(
                            children: [
                              DishThumb(name: it['name'] as String, size: 48),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  it['name'] as String,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              StatusChip(
                                label: (it['stock_quantity'] as int) <= 0
                                    ? tr('outOfStock')
                                    : tr('lowStock'),
                                color: (it['stock_quantity'] as int) <= 0
                                    ? Colors.red
                                    : RanTheme.amber,
                                icon: Icons.inventory_2_outlined,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    tr('recentTransactions'),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (orders.isEmpty)
                    EmptyState(title: tr('empty'), hint: tr('emptyOrdersHint'))
                  else
                    ...orders
                        .take(5)
                        .map(
                          (o) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: RanCard(
                              onTap: () => Navigator.of(context)
                                  .push(
                                    MaterialPageRoute(
                                      builder: (_) => OrderDetailPage(
                                        lang: lang,
                                        orderId: o['id'] as String,
                                      ),
                                    ),
                                  )
                                  .then(
                                    (_) => ref
                                        .read(refreshProvider.notifier)
                                        .state++,
                                  ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          o['display_number'] as String,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          (o['order_type'] as String) ==
                                                  'dine_in'
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
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 140,
                                        ),
                                        child: FittedBox(
                                          alignment: Alignment.centerRight,
                                          fit: BoxFit.scaleDown,
                                          child: MoneyText(
                                            o['total_minor'] as int,
                                            code: code,
                                            symbol: symbol,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      OrderStatusChips(lang: lang, order: o),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: openCreate,
                      child: Text(tr('createOrder')),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

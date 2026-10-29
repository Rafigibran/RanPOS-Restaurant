import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/l10n.dart';
import '../../core/money.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets.dart';

class ReportsPage extends ConsumerStatefulWidget {
  final String lang;
  const ReportsPage({super.key, required this.lang});
  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  String _period = 'today';
  String tr(String k) => L.t(widget.lang, k);
  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider);
    final biz = ref.watch(businessProvider).value;
    final code = biz?['currency_code'] as String? ?? 'USD';
    final symbol = biz?['currency_symbol'] as String? ?? '\$';
    final now = DateTime.now();
    DateTime? from;
    if (_period == 'today') from = DateTime(now.year, now.month, now.day);
    if (_period == 'week') from = now.subtract(const Duration(days: 7));
    if (_period == 'month') from = DateTime(now.year, now.month, 1);
    return Scaffold(
      appBar: AppBar(title: Text(tr('reports'))),
      body: FutureBuilder(
        future: repo.report(from: from),
        builder: (context, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          final r = snap.data!;
          final revenue = r['revenue'] as int;
          final count = r['orders'] as int;
          final avg = count == 0 ? 0 : revenue ~/ count;
          final byMethod = r['byMethod'] as List<Map<String, dynamic>>;
          final top = r['top'] as List<Map<String, dynamic>>;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    for (final p in ['today', 'week', 'month', 'all'])
                      ChoiceChip(
                        label: Text(p),
                        selected: _period == p,
                        selectedColor: RanTheme.accent,
                        labelStyle: TextStyle(
                          color: _period == p ? Colors.white : RanTheme.ink,
                        ),
                        onSelected: (_) => setState(() => _period = p),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                RanCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('totalEarnings'),
                        style: const TextStyle(color: RanTheme.muted),
                      ),
                      MoneyText(
                        revenue,
                        code: code,
                        symbol: symbol,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('${tr('orders')}: $count'),
                      Text('Average: ${formatMoney(avg, code, symbol)}'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  tr('popularDishes'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 8),
                for (final t in top)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: RanCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              t['name'] as String,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text('x${t['qty']}'),
                          const SizedBox(width: 12),
                          MoneyText(
                            t['value'] as int,
                            code: code,
                            symbol: symbol,
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                for (final m in byMethod)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: RanCard(
                      child: Row(
                        children: [
                          Expanded(child: Text(m['method'] as String)),
                          MoneyText(
                            m['total'] as int,
                            code: code,
                            symbol: symbol,
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final csv = StringBuffer(
                        'order_id,method,amount_minor\n',
                      );
                      // Report export is intentionally limited to the
                      // aggregated method totals in MVP; full transaction
                      // export reuses the same file location.
                      for (final m in byMethod) {
                        csv.writeln('${m['method']},${m['total']}');
                      }
                      final dir = await getApplicationDocumentsDirectory();
                      final file = File('${dir.path}/ranpos-report.csv');
                      await file.writeAsString(csv.toString());
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('CSV: ${file.path}')),
                        );
                      }
                    },
                    icon: const Icon(Icons.download),
                    label: Text(tr('exportCsv')),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Revenue counts paid payments only. Cancelled orders are excluded.',
                  style: TextStyle(color: RanTheme.muted, fontSize: 12),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

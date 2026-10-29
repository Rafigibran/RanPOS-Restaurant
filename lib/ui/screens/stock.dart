import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets.dart';

class StockPage extends ConsumerWidget {
  final String lang;
  const StockPage({super.key, required this.lang});
  String tr(String k) => L.t(lang, k);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(refreshProvider);
    final repo = ref.watch(repoProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr('stock'))),
      body: FutureBuilder(
        future: Future.wait([repo.menuItems(), repo.stockMovements()]),
        builder: (context, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          final items = snap.data![0] as List<Map<String, dynamic>>;
          final moves = snap.data![1] as List<Map<String, dynamic>>;
          final itemById = {for (final i in items) i['id']: i['name']};
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final it in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: RanCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            it['name'] as String,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            await repo.adjustStock(
                              it['id'] as String,
                              -1,
                              'manual_adjust',
                              null,
                            );
                            ref.read(refreshProvider.notifier).state++;
                          },
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text(
                          '${it['stock_quantity']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            await repo.adjustStock(
                              it['id'] as String,
                              1,
                              'manual_adjust',
                              null,
                            );
                            ref.read(refreshProvider.notifier).state++;
                          },
                          icon: const Icon(
                            Icons.add_circle,
                            color: RanTheme.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              const Divider(),
              for (final m in moves.take(30))
                ListTile(
                  title: Text(itemById[m['menu_item_id']]?.toString() ?? ''),
                  subtitle: Text(m['reason'] as String),
                  trailing: Text(
                    (m['delta'] as int) >= 0
                        ? '+${m['delta']}'
                        : '${m['delta']}',
                    style: TextStyle(
                      color: (m['delta'] as int) >= 0
                          ? RanTheme.green
                          : Colors.red,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

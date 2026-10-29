import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n.dart';
import '../../data/db.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets.dart';

class MenuPage extends ConsumerStatefulWidget {
  final String lang;
  const MenuPage({super.key, required this.lang});
  @override
  ConsumerState<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends ConsumerState<MenuPage> {
  String _query = '';
  String? _cat;
  String tr(String k) => L.t(widget.lang, k);

  Future<void> _edit([Map<String, dynamic>? existing]) async {
    final name = TextEditingController(
      text: existing?['name'] as String? ?? '',
    );
    final price = TextEditingController(
      text: existing == null
          ? ''
          : ((existing['price_minor'] as int) / 100).toString(),
    );
    final stock = TextEditingController(
      text: existing == null
          ? '10'
          : (existing['stock_quantity'] as int).toString(),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? tr('add') : tr('edit')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: InputDecoration(labelText: tr('menu')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Price'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: stock,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: tr('stock')),
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
            child: Text(tr('save')),
          ),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    final biz = await ref.read(repoProvider).business();
    final code = biz?['currency_code'] as String? ?? 'USD';
    final parsed = double.tryParse(price.text.replaceAll(',', '.')) ?? 0;
    final minor = code == 'IDR' ? parsed.round() : (parsed * 100).round();
    await ref.read(repoProvider).upsertMenuItem({
      'id': existing?['id'] ?? newId(),
      'category_id': existing?['category_id'],
      'name': name.text.trim(),
      'description': existing?['description'] ?? '',
      'price_minor': minor,
      'sku': existing?['sku'],
      'is_active': 1,
      'stock_tracking': 1,
      'stock_quantity': int.tryParse(stock.text) ?? 10,
      'low_stock_threshold': existing?['low_stock_threshold'] ?? 5,
      'created_at': existing?['created_at'] ?? nowIso(),
      'updated_at': nowIso(),
    });
    ref.read(refreshProvider.notifier).state++;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(refreshProvider);
    final repo = ref.watch(repoProvider);
    final biz = ref.watch(businessProvider).value;
    final code = biz?['currency_code'] as String? ?? 'USD';
    final symbol = biz?['currency_symbol'] as String? ?? '\$';
    return Scaffold(
      appBar: AppBar(title: Text(tr('chooseMenu'))),
      floatingActionButton: FloatingActionButton(
        backgroundColor: RanTheme.accent,
        onPressed: () => _edit(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: tr('searchMenu'),
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          FutureBuilder(
            future: repo.categories(),
            builder: (context, snap) {
              if (!snap.hasData) return const SizedBox.shrink();
              final cats = snap.data!;
              return SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(tr('allMenu')),
                        selected: _cat == null,
                        selectedColor: RanTheme.accent,
                        labelStyle: TextStyle(
                          color: _cat == null ? Colors.white : RanTheme.ink,
                        ),
                        onSelected: (_) => setState(() => _cat = null),
                      ),
                    ),
                    for (final c in cats)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(c['name'] as String),
                          selected: _cat == c['id'],
                          selectedColor: RanTheme.accent,
                          labelStyle: TextStyle(
                            color: _cat == c['id']
                                ? Colors.white
                                : RanTheme.ink,
                          ),
                          onSelected: (_) =>
                              setState(() => _cat = c['id'] as String),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder(
              future: repo.menuItems(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snap.data!
                    .where((i) => i['is_active'] == 1)
                    .where((i) => _cat == null || i['category_id'] == _cat)
                    .where(
                      (i) =>
                          _query.isEmpty ||
                          (i['name'] as String).toLowerCase().contains(
                            _query.toLowerCase(),
                          ),
                    )
                    .toList();
                if (list.isEmpty) {
                  return EmptyState(title: tr('empty'), hint: '');
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final it = list[i];
                    final out =
                        it['stock_tracking'] == 1 &&
                        (it['stock_quantity'] as int) <= 0;
                    return RanCard(
                      onTap: () => _edit(it),
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
                                  style: const TextStyle(
                                    color: RanTheme.accent,
                                  ),
                                ),
                                Text(
                                  out
                                      ? tr('outOfStock')
                                      : '${tr('stock')}: ${it['stock_quantity']}',
                                  style: TextStyle(
                                    color: out ? Colors.red : RanTheme.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () async {
                              await repo.archiveMenuItem(it['id'] as String);
                              ref.read(refreshProvider.notifier).state++;
                              setState(() {});
                            },
                            icon: const Icon(Icons.archive_outlined),
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
      ),
    );
  }
}

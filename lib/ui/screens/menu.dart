import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n.dart';
import '../../core/money.dart';
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

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _minorToDisplay(int minor, bool zero) => zero
      ? minor.toString()
      : (minor / 100).toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');

  Future<void> _addCategory() async {
    final nameCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('addCategory')),
        content: TextField(
          controller: nameCtrl,
          decoration: InputDecoration(labelText: tr('categoryName')),
          autofocus: true,
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
    if (ok != true || nameCtrl.text.trim().isEmpty) return;
    final repo = ref.read(repoProvider);
    final cats = await repo.categories();
    await repo.upsertCategory({
      'id': newId(),
      'name': nameCtrl.text.trim(),
      'sort_order': cats.length,
      'is_active': 1,
    });
    ref.read(refreshProvider.notifier).state++;
    setState(() {});
  }

  Future<void> _deleteCategory(Map<String, dynamic> cat) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(cat['name'] as String),
        content: Text(tr('deleteCategoryConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(repoProvider).deleteCategory(cat['id'] as String);
      if (_cat == cat['id']) _cat = null;
      ref.read(refreshProvider.notifier).state++;
      setState(() {});
    } catch (_) {
      _snack(tr('categoryInUse'));
    }
  }

  Future<void> _edit([Map<String, dynamic>? existing]) async {
    final repo = ref.read(repoProvider);
    final biz = await repo.business();
    final code = biz?['currency_code'] as String? ?? 'USD';
    final zero = isZeroDecimal(code);
    final nameCtrl = TextEditingController(
      text: existing?['name'] as String? ?? '',
    );
    final priceCtrl = TextEditingController(
      text: existing == null
          ? ''
          : _minorToDisplay(existing['price_minor'] as int, zero),
    );
    final stockCtrl = TextEditingController(
      text: existing == null
          ? '10'
          : (existing['stock_quantity'] as int).toString(),
    );
    var categoryId = existing?['category_id'] as String?;
    var trackStock = (existing?['stock_tracking'] as int? ?? 1) == 1;
    final cats = await repo.categories();
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(existing == null ? tr('add') : tr('edit')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(labelText: tr('itemName')),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: '${tr('price')} ($code)',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: categoryId,
                  decoration: InputDecoration(labelText: tr('category')),
                  items: [
                    DropdownMenuItem<String?>(value: null, child: Text('-')),
                    for (final c in cats)
                      DropdownMenuItem<String?>(
                        value: c['id'] as String,
                        child: Text(c['name'] as String),
                      ),
                  ],
                  onChanged: (v) => setDlg(() => categoryId = v),
                ),
                SwitchListTile(
                  value: trackStock,
                  contentPadding: EdgeInsets.zero,
                  title: Text(tr('trackStock')),
                  onChanged: (v) => setDlg(() => trackStock = v),
                ),
                if (trackStock)
                  TextField(
                    controller: stockCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: tr('stock')),
                  ),
              ],
            ),
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
      ),
    );
    if (ok != true || nameCtrl.text.trim().isEmpty) return;
    final parsed = double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0;
    final minor = zero ? parsed.round() : (parsed * 100).round();
    await repo.upsertMenuItem({
      'id': existing?['id'] ?? newId(),
      'category_id': categoryId,
      'name': nameCtrl.text.trim(),
      'description': existing?['description'] ?? '',
      'price_minor': minor,
      'sku': existing?['sku'],
      'is_active': 1,
      'stock_tracking': trackStock ? 1 : 0,
      'stock_quantity': trackStock ? (int.tryParse(stockCtrl.text) ?? 0) : 0,
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
                        child: GestureDetector(
                          onLongPress: () => _deleteCategory(c),
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
                      ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        avatar: const Icon(Icons.add, size: 16),
                        label: Text(tr('addCategory')),
                        onPressed: _addCategory,
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

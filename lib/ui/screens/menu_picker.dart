import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets.dart';

/// Returns (menu item map, qty) or null.
Future<(Map<String, dynamic>, int)?> showMenuPicker(
  BuildContext context, {
  required String lang,
}) async {
  return showModalBottomSheet<(Map<String, dynamic>, int)>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _MenuPickerSheet(lang: lang),
  );
}

class _MenuPickerSheet extends ConsumerStatefulWidget {
  final String lang;
  const _MenuPickerSheet({required this.lang});
  @override
  ConsumerState<_MenuPickerSheet> createState() => _MenuPickerSheetState();
}

class _MenuPickerSheetState extends ConsumerState<_MenuPickerSheet> {
  String _query = '';
  String tr(String k) => L.t(widget.lang, k);
  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider);
    final biz = ref.watch(businessProvider).value;
    final code = biz?['currency_code'] as String? ?? 'USD';
    final symbol = biz?['currency_symbol'] as String? ?? '\$';
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
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
              Expanded(
                child: FutureBuilder(
                  future: repo.menuItems(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final list = snap.data!
                        .where((i) => i['is_active'] == 1)
                        .where(
                          (i) =>
                              _query.isEmpty ||
                              (i['name'] as String).toLowerCase().contains(
                                _query.toLowerCase(),
                              ),
                        )
                        .toList();
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
                              IconButton(
                                onPressed: out
                                    ? null
                                    : () => Navigator.pop(context, (it, 1)),
                                icon: const Icon(
                                  Icons.add_circle,
                                  color: RanTheme.accent,
                                  size: 32,
                                ),
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
        ),
      ),
    );
  }
}

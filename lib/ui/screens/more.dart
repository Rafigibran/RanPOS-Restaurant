import 'package:flutter/material.dart';
import '../../core/l10n.dart';
import '../theme.dart';
import '../widgets.dart';
import 'customers.dart';
import 'menu.dart';
import 'reports.dart';
import 'settings.dart';
import 'stock.dart';

class MorePage extends StatelessWidget {
  final String lang;
  const MorePage({super.key, required this.lang});
  String tr(String k) => L.t(lang, k);
  @override
  Widget build(BuildContext context) {
    final tiles = [
      (Icons.restaurant_menu, tr('menu'), () => MenuPage(lang: lang)),
      (Icons.people, tr('customers'), () => CustomersPage(lang: lang)),
      (Icons.inventory_2, tr('stock'), () => StockPage(lang: lang)),
      (Icons.bar_chart, tr('reports'), () => ReportsPage(lang: lang)),
      (Icons.settings, tr('settings'), () => SettingsPage(lang: lang)),
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: tiles.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final t = tiles[i];
        return RanCard(
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => t.$3())),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE8E0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(t.$1, color: RanTheme.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  t.$2,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const Icon(Icons.chevron_right, color: RanTheme.muted),
            ],
          ),
        );
      },
    );
  }
}

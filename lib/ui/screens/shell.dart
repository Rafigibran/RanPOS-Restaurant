import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import 'create_order.dart';
import 'home.dart';
import 'more.dart';
import 'orders.dart';
import 'tables.dart';

class ShellPage extends ConsumerStatefulWidget {
  const ShellPage({super.key});
  @override
  ConsumerState<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends ConsumerState<ShellPage> {
  int _tab = 0;

  void _openCreate(String lang) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => CreateOrderPage(lang: lang)))
        .then((_) => ref.read(refreshProvider.notifier).state++);
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    // Resolve with device locale at build time via platform locale.
    final resolved = L.resolve(
      View.of(context).platformDispatcher.locale.toLanguageTag(),
      lang,
    );
    final pages = [
      HomePage(
        lang: resolved,
        goTab: (i) => setState(() => _tab = i),
        openCreate: () => _openCreate(resolved),
      ),
      OrdersPage(lang: resolved),
      TablesPage(lang: resolved),
      MorePage(lang: resolved),
    ];
    final titles = [
      L.t(resolved, 'home'),
      L.t(resolved, 'orders'),
      L.t(resolved, 'tables'),
      L.t(resolved, 'more'),
    ];
    return Scaffold(
      appBar: _tab == 0 ? null : AppBar(title: Text(titles[_tab])),
      body: _tab == 0 ? SafeArea(child: pages[_tab]) : pages[_tab],
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _nav(Icons.home_outlined, L.t(resolved, 'home'), 0),
            _nav(Icons.receipt_long_outlined, L.t(resolved, 'orders'), 1),
            const SizedBox(width: 56),
            _nav(Icons.table_restaurant_outlined, L.t(resolved, 'tables'), 2),
            _nav(Icons.grid_view_outlined, L.t(resolved, 'more'), 3),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: RanTheme.accent,
        shape: const CircleBorder(),
        onPressed: () => _openCreate(resolved),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _nav(IconData icon, String label, int index) {
    final sel = _tab == index;
    return InkWell(
      onTap: () => setState(() => _tab = index),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: sel ? RanTheme.accent : RanTheme.muted),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: sel ? RanTheme.accent : RanTheme.muted,
                fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

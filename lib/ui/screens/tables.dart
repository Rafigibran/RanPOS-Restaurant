import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets.dart';

class TablesPage extends ConsumerStatefulWidget {
  final String lang;
  const TablesPage({super.key, required this.lang});
  @override
  ConsumerState<TablesPage> createState() => _TablesPageState();
}

class _TablesPageState extends ConsumerState<TablesPage> {
  String? _floorId;
  String tr(String k) => L.t(widget.lang, k);
  @override
  Widget build(BuildContext context) {
    ref.watch(refreshProvider);
    final repo = ref.watch(repoProvider);
    return FutureBuilder(
      future: Future.wait([
        repo.floors(),
        repo.tables(),
        repo.occupiedTableIds(),
      ]),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final floors = snap.data![0] as List<Map<String, dynamic>>;
        final tables = snap.data![1] as List<Map<String, dynamic>>;
        final occupied = snap.data![2] as Set<String>;
        final floor =
            _floorId ?? (floors.isEmpty ? null : floors.first['id'] as String);
        final shown = tables.where((t) => t['floor_id'] == floor).toList();
        return Column(
          children: [
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (final f in floors)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f['name'] as String),
                        selected: floor == f['id'],
                        selectedColor: RanTheme.accent,
                        labelStyle: TextStyle(
                          color: floor == f['id'] ? Colors.white : RanTheme.ink,
                        ),
                        onSelected: (_) =>
                            setState(() => _floorId = f['id'] as String),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: RanCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _legend(RanTheme.blue, tr('available')),
                    _legend(RanTheme.accent, tr('occupied')),
                    _legend(RanTheme.amber, tr('reserved')),
                  ],
                ),
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.95,
                ),
                itemCount: shown.length,
                itemBuilder: (context, i) {
                  final t = shown[i];
                  final occ = occupied.contains(t['id']);
                  return RanCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.table_restaurant,
                          color: occ ? RanTheme.accent : RanTheme.blue,
                          size: 30,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t['label'] as String,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          occ ? tr('occupied') : tr('available'),
                          style: TextStyle(
                            fontSize: 11,
                            color: occ ? RanTheme.accent : RanTheme.blue,
                          ),
                        ),
                        Text(
                          '${t['capacity']} ${tr('guest')}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: RanTheme.muted,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _legend(Color c, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

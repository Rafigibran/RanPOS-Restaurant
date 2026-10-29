import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n.dart';
import '../../data/db.dart';
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

  void _refresh() => ref.read(refreshProvider.notifier).state++;

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _floorDialog({Map<String, dynamic>? floor}) async {
    final nameCtrl = TextEditingController(
      text: floor?['name'] as String? ?? '',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('addFloor')),
        content: TextField(
          controller: nameCtrl,
          decoration: InputDecoration(labelText: tr('floorName')),
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
    if (ok != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;
    try {
      await ref.read(repoProvider).upsertFloor({
        'id': floor?['id'] ?? newId(),
        'name': name,
        'sort_order': floor?['sort_order'] ?? DateTime.now().millisecond,
      });
      _refresh();
      setState(() {});
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _deleteFloor(Map<String, dynamic> floor) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(floor['name'] as String),
        content: Text(tr('deleteFloorConfirm')),
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
      await ref.read(repoProvider).deleteFloor(floor['id'] as String);
      if (_floorId == floor['id']) _floorId = null;
      _refresh();
      setState(() {});
    } catch (e) {
      _snack(tr('floorHasTables'));
    }
  }

  Future<void> _tableDialog({
    Map<String, dynamic>? table,
    required List<Map<String, dynamic>> floors,
    String? defaultFloorId,
  }) async {
    final labelCtrl = TextEditingController(
      text: table?['label'] as String? ?? '',
    );
    final capCtrl = TextEditingController(
      text: (table?['capacity'] as int? ?? 4).toString(),
    );
    var floorId =
        table?['floor_id'] as String? ??
        defaultFloorId ??
        (floors.isEmpty ? null : floors.first['id'] as String);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(table == null ? tr('addTable') : tr('editTable')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelCtrl,
                decoration: InputDecoration(labelText: tr('tableLabel')),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: capCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: tr('capacity')),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey(floorId),
                initialValue: floorId,
                decoration: InputDecoration(labelText: tr('chooseFloor')),
                items: [
                  for (final f in floors)
                    DropdownMenuItem(
                      value: f['id'] as String,
                      child: Text(f['name'] as String),
                    ),
                ],
                onChanged: (v) => setDlg(() => floorId = v),
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
      ),
    );
    if (ok != true || floorId == null) return;
    final label = labelCtrl.text.trim();
    if (label.isEmpty) return;
    try {
      await ref.read(repoProvider).upsertTable({
        'id': table?['id'] ?? newId(),
        'label': label,
        'capacity': int.tryParse(capCtrl.text) ?? 4,
        'floor_id': floorId,
        'is_active': 1,
      });
      _refresh();
      setState(() {});
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _tableOptions(
    Map<String, dynamic> table,
    List<Map<String, dynamic>> floors,
    bool occupied,
  ) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(table['label'] as String),
        content: Text('${table['capacity']} ${tr('guest')}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'edit'),
            child: Text(tr('edit')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'delete'),
            child: Text(
              tr('delete'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('cancel')),
          ),
        ],
      ),
    );
    if (choice == 'edit') {
      await _tableDialog(table: table, floors: floors);
    } else if (choice == 'delete') {
      if (occupied) {
        _snack(tr('tableOccupied'));
        return;
      }
      try {
        await ref.read(repoProvider).deleteTable(table['id'] as String);
        _refresh();
        setState(() {});
      } catch (e) {
        _snack('$e');
      }
    }
  }

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
        final floorIds = floors.map((f) => f['id'] as String).toSet();
        final floor = (_floorId != null && floorIds.contains(_floorId))
            ? _floorId
            : (floors.isEmpty ? null : floors.first['id'] as String);
        final shown = tables.where((t) => t['floor_id'] == floor).toList();
        return Column(
          children: [
            const SizedBox(height: 12),
            if (floors.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: EmptyState(
                  title: tr('noTables'),
                  hint: tr('noTablesHint'),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    for (final f in floors)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onLongPress: () => _deleteFloor(f),
                          child: ChoiceChip(
                            label: Text(f['name'] as String),
                            selected: floor == f['id'],
                            selectedColor: RanTheme.accent,
                            labelStyle: TextStyle(
                              color: floor == f['id']
                                  ? Colors.white
                                  : RanTheme.ink,
                            ),
                            onSelected: (_) =>
                                setState(() => _floorId = f['id'] as String),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _floorDialog(),
                      icon: const Icon(Icons.layers_outlined, size: 18),
                      label: Text(tr('addFloor')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: floors.isEmpty
                          ? null
                          : () => _tableDialog(
                              floors: floors,
                              defaultFloorId: floor,
                            ),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(tr('addTable')),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: RanCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
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
            const SizedBox(height: 12),
            Expanded(
              child: shown.isEmpty
                  ? EmptyState(title: tr('noTables'), hint: tr('noTablesHint'))
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final w = constraints.maxWidth;
                        final count = w < 380 ? 3 : (w < 640 ? 4 : 6);
                        return GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: count,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.95,
                              ),
                          itemCount: shown.length,
                          itemBuilder: (context, i) {
                            final t = shown[i];
                            final occ = occupied.contains(t['id']);
                            return RanCard(
                              onTap: () => _tableOptions(t, floors, occ),
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.table_restaurant,
                                    color: occ
                                        ? RanTheme.accent
                                        : RanTheme.blue,
                                    size: 30,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    t['label'] as String,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    occ ? tr('occupied') : tr('available'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: occ
                                          ? RanTheme.accent
                                          : RanTheme.blue,
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
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}

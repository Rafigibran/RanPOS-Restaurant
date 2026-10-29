import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n.dart';
import '../../data/db.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets.dart';

class CustomersPage extends ConsumerStatefulWidget {
  final String lang;
  const CustomersPage({super.key, required this.lang});
  @override
  ConsumerState<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends ConsumerState<CustomersPage> {
  String _query = '';
  String tr(String k) => L.t(widget.lang, k);

  Future<void> _edit([Map<String, dynamic>? existing]) async {
    final name = TextEditingController(
      text: existing?['name'] as String? ?? '',
    );
    final email = TextEditingController(
      text: existing?['email'] as String? ?? '',
    );
    final address = TextEditingController(
      text: existing?['address'] as String? ?? '',
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
              decoration: InputDecoration(labelText: tr('customerName')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: email,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: address,
              decoration: const InputDecoration(labelText: 'Address'),
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
    await ref.read(repoProvider).upsertCustomer({
      'id': existing?['id'] ?? newId(),
      'name': name.text.trim(),
      'phone': existing?['phone'] ?? '',
      'email': email.text.trim(),
      'address': address.text.trim(),
      'notes': existing?['notes'] ?? '',
      'created_at': existing?['created_at'] ?? nowIso(),
    });
    ref.read(refreshProvider.notifier).state++;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(refreshProvider);
    final repo = ref.watch(repoProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr('selectCustomer'))),
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
                hintText: tr('searchOrder'),
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: FutureBuilder(
              future: repo.customers(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snap.data!
                    .where(
                      (c) =>
                          _query.isEmpty ||
                          (c['name'] as String).toLowerCase().contains(
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
                    final c = list[i];
                    return RanCard(
                      onTap: () => _edit(c),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: const Color(0xFFFFE8E0),
                            child: Text(
                              initials(c['name'] as String),
                              style: const TextStyle(
                                color: RanTheme.accent,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c['name'] as String,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if ((c['email'] as String).isNotEmpty)
                                  Text(
                                    c['email'] as String,
                                    style: const TextStyle(
                                      color: RanTheme.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                if ((c['address'] as String).isNotEmpty)
                                  Text(
                                    c['address'] as String,
                                    style: const TextStyle(
                                      color: RanTheme.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: RanTheme.muted,
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

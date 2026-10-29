import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets.dart';

class NotificationsPage extends ConsumerWidget {
  final String lang;
  const NotificationsPage({super.key, required this.lang});
  String tr(String k) => L.t(lang, k);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(refreshProvider);
    final repo = ref.watch(repoProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('notifications')),
        actions: [
          TextButton(
            onPressed: () async {
              await repo.markNotificationsRead();
              ref.read(refreshProvider.notifier).state++;
            },
            child: Text(tr('markAllRead')),
          ),
        ],
      ),
      body: FutureBuilder(
        future: repo.notifications(),
        builder: (context, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          if (list.isEmpty) return EmptyState(title: tr('empty'), hint: '');
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final n = list[i];
              final unread = n['read_at'] == null;
              return RanCard(
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE8E0),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.notifications,
                        color: RanTheme.accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            n['title'] as String,
                            style: TextStyle(
                              fontWeight: unread
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                          Text(
                            n['message'] as String,
                            style: const TextStyle(
                              color: RanTheme.muted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (unread)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: RanTheme.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

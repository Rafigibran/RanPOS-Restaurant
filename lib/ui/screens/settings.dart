import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/l10n.dart';
import '../../core/money.dart';
import '../../data/supabase_backup.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets.dart';

class SettingsPage extends ConsumerStatefulWidget {
  final String lang;
  const SettingsPage({super.key, required this.lang});
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  String _status = '';
  String? _currencySel;
  String tr(String k) => L.t(widget.lang, k);

  Future<void> _localBackup() async {
    final repo = ref.read(repoProvider);
    final backup = await repo.buildBackup();
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/ranpos-backup.json');
    await file.writeAsString(jsonEncode(backup));
    setState(() => _status = 'Local backup: ${file.path}');
  }

  Future<void> _localRestore() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/ranpos-backup.json');
    if (!await file.exists()) {
      setState(() => _status = 'No local backup file found.');
      return;
    }
    if (!mounted) {
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('restore')),
        content: const Text('Restore will replace local data. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('restore')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final data =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      await ref.read(repoProvider).restoreBackup(data);
      ref.read(refreshProvider.notifier).state++;
      setState(() => _status = 'Restore succeeded.');
    } catch (e) {
      setState(() => _status = 'Restore failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bizAsync = ref.watch(businessProvider);
    final langChoice = ref.watch(languageProvider);
    final biz = bizAsync.value;
    final nameCtrl = TextEditingController(text: biz?['name'] as String? ?? '');
    final taxCtrl = TextEditingController(
      text: (biz?['tax_percent'] as int? ?? 5).toString(),
    );
    return Scaffold(
      appBar: AppBar(title: Text(tr('settings'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('business'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(labelText: tr('businessName')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: taxCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: tr('taxRate')),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('cur_${biz?['currency_code']}'),
              initialValue:
                  _currencySel ?? (biz?['currency_code'] as String? ?? 'USD'),
              decoration: InputDecoration(labelText: tr('currency')),
              items: [
                for (final e in currencySymbols.entries)
                  DropdownMenuItem(
                    value: e.key,
                    child: Text('${e.key} (${e.value})'),
                  ),
              ],
              onChanged: (v) => setState(() => _currencySel = v),
            ),
            const SizedBox(height: 6),
            Text(
              tr('currencyNote'),
              style: const TextStyle(color: RanTheme.muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final code =
                      _currencySel ??
                      (biz?['currency_code'] as String? ?? 'USD');
                  await ref.read(repoProvider).saveBusiness({
                    'name': nameCtrl.text.trim(),
                    'currency_code': code,
                    'currency_symbol': currencySymbols[code] ?? code,
                    'tax_percent': parseIntInput(taxCtrl.text),
                    'tax_inclusive': false,
                    'address': biz?['address'] ?? '',
                    'phone': biz?['phone'] ?? '',
                  });
                  setState(() => _currencySel = null);
                  ref.read(refreshProvider.notifier).state++;
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(tr('save'))));
                  }
                },
                child: Text(tr('save')),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              tr('language'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: ValueKey(langChoice),
              initialValue: langChoice,
              items: [
                DropdownMenuItem(
                  value: 'system',
                  child: Text(tr('systemDefault')),
                ),
                const DropdownMenuItem(
                  value: 'id',
                  child: Text('Bahasa Indonesia'),
                ),
                const DropdownMenuItem(value: 'en', child: Text('English')),
                const DropdownMenuItem(value: 'ja', child: Text('日本語')),
                const DropdownMenuItem(value: 'zh', child: Text('简体中文')),
                const DropdownMenuItem(value: 'es', child: Text('Español')),
                const DropdownMenuItem(value: 'ar', child: Text('العربية')),
              ],
              onChanged: (v) async {
                if (v == null) return;
                ref.read(languageProvider.notifier).state = v;
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('ranpos_language', v);
              },
            ),
            const SizedBox(height: 24),
            Text(
              tr('dataBackup'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            const SizedBox(height: 8),
            Text(
              tr('savedOnDevice'),
              style: const TextStyle(color: RanTheme.green),
            ),
            Text(
              tr('notBackedUp'),
              style: const TextStyle(color: RanTheme.muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _localBackup,
                    child: Text(tr('backupNow')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _localRestore,
                    child: Text(tr('restore')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Supabase (your own project, optional)',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            const SizedBox(height: 8),
            const Text(
              'Use a publishable/anon key only. Never enter a secret/service-role key in this app. Backup is not realtime sync.',
              style: TextStyle(color: RanTheme.muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            _SupabaseForm(onStatus: (s) => setState(() => _status = s)),
            if (_status.isNotEmpty) ...[
              const SizedBox(height: 12),
              RanCard(child: Text(_status)),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(tr('clearData')),
                      content: Text(tr('clearDataConfirm')),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(tr('cancel')),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(tr('delete')),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await ref.read(repoProvider).clearAllData();
                    ref.read(refreshProvider.notifier).state++;
                  }
                },
                child: Text(tr('clearData')),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'RanPOS 1.0.0 · com.rafdevplay.ranpos · Offline-first. Supabase setup guide: docs/supabase-setup.md',
              style: TextStyle(color: RanTheme.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupabaseForm extends ConsumerStatefulWidget {
  final void Function(String) onStatus;
  const _SupabaseForm({required this.onStatus});
  @override
  ConsumerState<_SupabaseForm> createState() => _SupabaseFormState();
}

class _SupabaseFormState extends ConsumerState<_SupabaseForm> {
  final _url = TextEditingController();
  final _key = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    SupabaseBackup.connection().then((c) {
      if (mounted) {
        setState(() {
          _url.text = c.$1 ?? '';
          _key.text = c.$2 ?? '';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _url,
          decoration: const InputDecoration(labelText: 'Project URL'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _key,
          decoration: const InputDecoration(
            labelText: 'Publishable / Anon Key',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _email,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pass,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Password'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        try {
                          if (SupabaseBackup.looksLikeSecretKey(_key.text)) {
                            throw Exception(
                              'Secret/service-role keys are refused.',
                            );
                          }
                          await SupabaseBackup.saveConnection(
                            _url.text,
                            _key.text,
                          );
                          final ok = await SupabaseBackup.testConnection(
                            _url.text,
                            _key.text,
                          );
                          widget.onStatus(
                            ok
                                ? 'Connection OK'
                                : 'Connection test returned a non-OK status.',
                          );
                        } catch (e) {
                          widget.onStatus('Connection failed: $e');
                        }
                        setState(() => _busy = false);
                      },
                child: const Text('Test Connection'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        try {
                          await SupabaseBackup.saveConnection(
                            _url.text,
                            _key.text,
                          );
                          await SupabaseBackup.signIn(
                            _url.text,
                            _key.text,
                            _email.text,
                            _pass.text,
                          );
                          widget.onStatus('Signed in to Supabase.');
                        } catch (e) {
                          widget.onStatus('Sign-in failed: $e');
                        }
                        setState(() => _busy = false);
                      },
                child: const Text('Save and Sign In'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        try {
                          final backup = await ref
                              .read(repoProvider)
                              .buildBackup();
                          final path = await SupabaseBackup.uploadBackup(
                            backup,
                          );
                          widget.onStatus('Cloud backup uploaded: $path');
                        } catch (e) {
                          widget.onStatus('Cloud backup failed: $e');
                        }
                        setState(() => _busy = false);
                      },
                child: const Text('Back Up Now (cloud)'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextButton(
                onPressed: () async {
                  await SupabaseBackup.disconnect();
                  widget.onStatus('Disconnected from Supabase.');
                },
                child: const Text('Disconnect'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

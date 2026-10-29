import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/l10n.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import 'shell.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  final String lang;
  const OnboardingPage({super.key, required this.lang});
  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _name = TextEditingController(text: 'RanPOS Restaurant');
  String _currency = 'USD';
  String _symbol = '\$';
  int _tax = 5;
  bool _sample = true;
  bool _busy = false;

  String tr(String k) => L.t(widget.lang, k);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: RanTheme.accent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                tr('welcome'),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr('offlineNote'),
                style: const TextStyle(color: RanTheme.muted, fontSize: 15),
              ),
              const SizedBox(height: 28),
              Text(
                tr('businessName'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TextField(controller: _name),
              const SizedBox(height: 16),
              Text(
                tr('currency'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _currency,
                decoration: const InputDecoration(),
                items: const [
                  DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                  DropdownMenuItem(value: 'IDR', child: Text('IDR (Rp)')),
                  DropdownMenuItem(value: 'EUR', child: Text('EUR (€)')),
                  DropdownMenuItem(value: 'JPY', child: Text('JPY (¥)')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _currency = v;
                    _symbol = {
                      'USD': '\$',
                      'IDR': 'Rp',
                      'EUR': '€',
                      'JPY': '¥',
                    }[v]!;
                  });
                },
              ),
              const SizedBox(height: 16),
              Text(
                tr('taxRate'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: '5'),
                onChanged: (v) => _tax = int.tryParse(v) ?? 5,
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: _sample,
                contentPadding: EdgeInsets.zero,
                title: Text(tr('sampleData')),
                onChanged: (v) => setState(() => _sample = v ?? true),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          final repo = ref.read(repoProvider);
                          await repo.saveBusiness({
                            'name': _name.text.trim().isEmpty
                                ? 'RanPOS Restaurant'
                                : _name.text.trim(),
                            'currency_code': _currency,
                            'currency_symbol': _symbol,
                            'tax_percent': _tax,
                            'tax_inclusive': false,
                            'address': '',
                            'phone': '',
                          });
                          await repo.ensureSeeded(_sample);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('ranpos_setup_done', true);
                          ref.read(refreshProvider.notifier).state++;
                          if (!mounted) return;
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const ShellPage(),
                            ),
                          );
                        },
                  child: Text(_busy ? '...' : tr('getStarted')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

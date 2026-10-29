import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/l10n.dart';
import 'state/app_state.dart';
import 'ui/screens/onboarding.dart';
import 'ui/screens/shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final setupDone = prefs.getBool('ranpos_setup_done') ?? false;
  final savedLang = prefs.getString('ranpos_language') ?? 'system';
  runApp(
    ProviderScope(
      overrides: [languageProvider.overrideWith((_) => savedLang)],
      child: RanPosApp(setupDone: setupDone),
    ),
  );
}

class RanPosApp extends ConsumerWidget {
  final bool setupDone;
  const RanPosApp({super.key, required this.setupDone});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final langChoice = ref.watch(languageProvider);
    return MaterialApp(
      title: 'RanPOS',
      debugShowCheckedModeBanner: false,
      theme: RanTheme.light(),
      supportedLocales: const [
        Locale('id'),
        Locale('en'),
        Locale('ja'),
        Locale('zh'),
        Locale('es'),
        Locale('ar'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      locale: langChoice == 'system' ? null : Locale(langChoice),
      localeResolutionCallback: (device, supported) {
        if (langChoice != 'system') return Locale(langChoice);
        final resolved = L.resolve(device?.toLanguageTag(), 'system');
        return Locale(resolved);
      },
      home: Builder(
        builder: (ctx) {
          final device = Localizations.localeOf(ctx).toLanguageTag();
          final resolved = L.resolve(device, langChoice);
          return setupDone ? const ShellPage() : OnboardingPage(lang: resolved);
        },
      ),
    );
  }
}

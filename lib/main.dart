import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'distant.dart';
import 'ecrans/connexion.dart';
import 'ecrans/coque.dart';
import 'ecrans/espace_chauffeur.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Distant? distant;
  if (Config.serveur) {
    await Supabase.initialize(url: Config.url, publishableKey: Config.cle);
    distant = Distant(Supabase.instance.client);
  }
  final store = SperoStore(distant: distant);
  await store.charger();
  runApp(ChangeNotifierProvider.value(value: store, child: const SperoApp()));
}

class SperoApp extends StatelessWidget {
  const SperoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final role = context.select<SperoStore, Role?>((s) => s.role);
    return MaterialApp(
      title: 'Spero',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Column(
        children: [
          const BandeauErreur(),
          Expanded(child: child!),
        ],
      ),
      home: switch (role) {
        null => const Connexion(),
        Role.chauffeur => const EspaceChauffeur(),
        _ => const Coque(),
      },
    );
  }
}

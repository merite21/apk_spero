import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spero/ecrans/alertes.dart';
import 'package:spero/ecrans/depenses.dart';
import 'package:spero/ecrans/espace_chauffeur.dart';
import 'package:spero/ecrans/flotte.dart';
import 'package:spero/ecrans/inscription.dart';
import 'package:spero/ecrans/fiche_chauffeur.dart';
import 'package:spero/ecrans/fiche_tricycle.dart';
import 'package:spero/ecrans/formulaires.dart';
import 'package:spero/ecrans/parametres.dart';
import 'package:spero/main.dart';
import 'package:spero/models.dart';
import 'package:spero/store.dart';

Future<SperoStore> _store(Role r) async {
  SharedPreferences.setMockInitialValues({});
  final s = SperoStore();
  await s.charger();
  if (r == Role.chauffeur) {
    expect(s.connecterChauffeur('01 97 00 00 05', '1234'), isNull);
  } else {
    s.connecter(r);
  }
  return s;
}

Future<void> _ouvrir(WidgetTester t, SperoStore s, Widget w) async {
  await t.pumpWidget(
    ChangeNotifierProvider.value(
      value: s,
      child: MaterialApp(home: w),
    ),
  );
  await t.pump(const Duration(milliseconds: 300));
}

void main() {
  for (final taille in [const Size(390, 844), const Size(1280, 800)]) {
    for (final role in Role.values) {
      testWidgets('écrans ${role.name} ${taille.width.toInt()}px', (t) async {
        t.view.physicalSize = taille;
        t.view.devicePixelRatio = 1;
        final s = await t.runAsync(() => _store(role));
        await t.pumpWidget(ChangeNotifierProvider.value(value: s!, child: const SperoApp()));
        await t.pump(const Duration(milliseconds: 300));
        expect(find.textContaining('Bonjour'), findsOneWidget);
        if (role == Role.chauffeur) {
          expect(find.text('Dépôt du jour'), findsOneWidget);
          for (final onglet in ['Mes dépôts', 'Contrat', 'Profil', 'Accueil']) {
            await t.tap(find.text(onglet).last);
            await t.pump(const Duration(milliseconds: 300));
          }
          await _ouvrir(t, s, EcranDepot(s.moi!));
          await _ouvrir(t, s, const Inscription());
          s.dispose();
          await t.pumpWidget(const SizedBox());
          t.view.reset();
          return;
        }
        for (final onglet in ['Carte', 'Dépôts', 'Flotte', if (role == Role.admin) 'Rapports']) {
          await t.tap(find.text(onglet).last);
          await t.pump(const Duration(milliseconds: 300));
        }
        await _ouvrir(t, s, const EcranAlertes());
        await _ouvrir(t, s, const EcranDepenses());
        await _ouvrir(t, s, const NouveauVersement(chauffeurId: 'CH-3'));
        await _ouvrir(t, s, const NouvelleDepense());
        await _ouvrir(t, s, const NouvelIncident());
        await _ouvrir(t, s, const NouvelleInspection(tricycleId: 'TC-01'));
        await _ouvrir(t, s, const FormulaireChauffeur(chauffeurId: 'CH-1'));
        await _ouvrir(t, s, const FormulaireTricycle());
        await _ouvrir(t, s, const FicheChauffeur(chauffeurId: 'CH-4'));
        await _ouvrir(t, s, const FicheChauffeur(chauffeurId: 'CH-10'));
        await _ouvrir(t, s, const EcranInscriptions());
        await _ouvrir(t, s, const FicheTricycle(tricycleId: 'TC-04'));
        await t.drag(find.byType(ListView).first, const Offset(0, -2000));
        await t.pump();
        await _ouvrir(t, s, const EcranParametres());
        await _ouvrir(t, s, const EcranJournal());
        final alertes = s.alertesOuvertes();
        // ignore: avoid_print
        print('${role.name}: ${alertes.length} alertes → ${alertes.map((a) => a.titre).join(' | ')}');
        s.dispose();
        await t.pumpWidget(const SizedBox());
        t.view.reset();
      });
    }
  }
}

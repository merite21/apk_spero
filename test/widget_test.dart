import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spero/models.dart';
import 'package:spero/store.dart';
import 'package:spero/theme.dart';

Chauffeur _chauffeur(DateTime debut) => Chauffeur(
  id: 'CH-T',
  nom: 'Test Chauffeur',
  telephone: '',
  pieceIdentite: '',
  garant: '',
  telephoneGarant: '',
  tricycleId: 'TC-01',
  montantJournalier: 5000,
  caution: 0,
  debutContrat: debut,
);

void main() {
  // Mercredi 11 novembre 2026, 15 h
  final maintenant = DateTime(2026, 11, 11, 15);

  test('à jour quand tout est payé, y compris aujourd\'hui', () {
    final store = SperoStore();
    final c = _chauffeur(DateTime(2026, 11, 9)); // lundi
    store.chauffeurs = [c];
    store.versements = [
      Versement(id: '1', chauffeurId: c.id, montant: 15000, mode: ModePaiement.especes, date: maintenant, saisiPar: 'test'),
    ];
    final s = store.situation(c, maintenant: maintenant);
    expect(s.arrieres, 0);
    expect(s.payeAujourdhui, true);
    expect(s.libelle, 'Payé');
  });

  test('deux jours d\'impayés = critique', () {
    final store = SperoStore();
    final c = _chauffeur(DateTime(2026, 11, 9));
    store.chauffeurs = [c];
    final s = store.situation(c, maintenant: maintenant);
    expect(s.arrieres, 10000);
    expect(s.joursRetard, 2);
    expect(s.niveau, Niveau.critique);
  });

  test('le dimanche de repos n\'est pas dû', () {
    final store = SperoStore();
    final c = _chauffeur(DateTime(2026, 11, 7)); // samedi
    store.chauffeurs = [c];
    // samedi + lundi + mardi = 3 jours dus avant aujourd'hui (dimanche exclu)
    final s = store.situation(c, maintenant: maintenant);
    expect(s.arrieres, 15000);
  });

  test('annulation : le versement annulé ne compte plus', () async {
    final store = SperoStore();
    final c = _chauffeur(DateTime(2026, 11, 11));
    store.chauffeurs = [c];
    final v = Versement(id: '1', chauffeurId: c.id, montant: 5000, mode: ModePaiement.especes, date: maintenant, saisiPar: 'test');
    store.versements = [
      v,
      Versement(id: '2', chauffeurId: c.id, montant: -5000, mode: ModePaiement.especes, date: maintenant, saisiPar: 'test', annuleId: '1'),
    ];
    expect(store.estAnnule(v), true);
    expect(store.situation(c, maintenant: maintenant).resteAujourdhui, 5000);
  });

  test('format FCFA', () {
    expect(fcfa(1450000), '1 450 000 FCFA');
    expect(fcfa(-5000), '-5 000 FCFA');
  });

  test('dépôt partiel : il manque la différence pour le jour', () {
    final store = SperoStore();
    final c = _chauffeur(DateTime(2026, 11, 11))..montantJournalier = 10000;
    store.chauffeurs = [c];
    store.versements = [
      Versement(id: '1', chauffeurId: c.id, montant: 5000, mode: ModePaiement.mtnMomo, date: DateTime(2026, 11, 11, 9), saisiPar: 'test'),
    ];
    final s = store.situation(c, maintenant: maintenant);
    expect(s.deposeAujourdhui, 5000);
    expect(s.manqueAujourdhui, 5000);
    expect(s.libelle, 'Manque 5 000');
  });

  test('un dépôt rembourse d\'abord les jours les plus anciens', () {
    final store = SperoStore();
    final c = _chauffeur(DateTime(2026, 11, 9))..montantJournalier = 10000; // lundi
    store.chauffeurs = [c];
    store.versements = [
      // lundi : 6 000 seulement ; mercredi : 24 000
      Versement(id: '1', chauffeurId: c.id, montant: 6000, mode: ModePaiement.mtnMomo, date: DateTime(2026, 11, 9, 18), saisiPar: 'test'),
      Versement(id: '2', chauffeurId: c.id, montant: 24000, mode: ModePaiement.mtnMomo, date: DateTime(2026, 11, 11, 10), saisiPar: 'test'),
    ];
    final jours = store.journalDepots(c, maintenant: maintenant);
    expect(jours.map((j) => j.manque).toList(), [0, 0, 0]); // lundi, mardi, mercredi couverts
    expect(store.situation(c, maintenant: maintenant).arrieres, 0);
  });

  test('compte chauffeur : inscription puis connexion par téléphone', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SperoStore();
    await store.inscrire(
      prenom: 'Ange',
      nom: 'Test',
      telephone: '+229 01 90 12 34 56',
      cip: '123',
      photoCip: 'x',
      photoVisage: 'y',
      motDePasse: 'secret1',
    );
    final c = store.moi!;
    expect(c.enAttente, true);
    expect(store.chauffeursActifs.contains(c), false);
    store.deconnecter();
    expect(store.connecterChauffeur('0190123456', 'mauvais'), isNotNull);
    expect(store.connecterChauffeur('01 90 12 34 56', 'secret1'), isNull);
    expect(store.identifiantPris('+229 0190123456', null), true);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:spero/distant.dart';
import 'package:spero/models.dart';

void main() {
  test('conversion modèle ↔ base : noms de colonnes et dates', () {
    final v = Versement(
      id: 'V1',
      chauffeurId: 'abc',
      montant: 10000,
      mode: ModePaiement.mtnMomo,
      date: DateTime(2026, 11, 11, 8, 30),
      saisiPar: 'Chauffeur (application)',
      statut: StatutVersement.aConfirmer,
    );
    final ligne = Distant.versBase(v.toJson());
    expect(ligne['chauffeur_id'], 'abc');
    expect(ligne['saisi_par'], 'Chauffeur (application)');
    expect((ligne['date'] as String).endsWith('Z'), true); // envoyée en UTC
    final retour = Versement.fromJson(Distant.depuisBase(ligne));
    expect(retour.date, v.date); // relue en heure locale
    expect(retour.statut, StatutVersement.aConfirmer);
    expect(retour.chauffeurId, 'abc');
  });

  test('le mot de passe local ne part jamais vers le serveur', () {
    final c = Chauffeur(
      id: 'x',
      nom: 'A B',
      telephone: '',
      pieceIdentite: '',
      motDePasse: 'empreinte',
      garant: '',
      telephoneGarant: '',
      tricycleId: null,
      montantJournalier: 10000,
      caution: 0,
      debutContrat: DateTime(2026, 11, 1),
    );
    final ligne = Distant.versBase(c.toJson());
    expect(ligne.containsKey('mot_de_passe'), false);
    expect(ligne['montant_journalier'], 10000);
    expect(ligne['photo_cip'], null);
  });

  test('adresse technique depuis un numéro', () {
    expect(Distant.emailTechnique('+229 01 97 00 00 01'), '2290197000001@tel.spero.app');
  });
}

import 'package:latlong2/latlong.dart';

import 'theme.dart';

enum Role { admin, gestionnaire, chauffeur }

enum ModePaiement { especes, mtnMomo, moovMoney }

extension ModePaiementLibelle on ModePaiement {
  String get libelle => switch (this) {
    ModePaiement.especes => 'Espèces',
    ModePaiement.mtnMomo => 'MTN MoMo',
    ModePaiement.moovMoney => 'Moov Money',
  };
}

enum CategorieDepense { reparation, vidange, pneus, pieces, carburant, autre }

extension CategorieDepenseLibelle on CategorieDepense {
  String get libelle => switch (this) {
    CategorieDepense.reparation => 'Réparation',
    CategorieDepense.vidange => 'Vidange',
    CategorieDepense.pneus => 'Pneus',
    CategorieDepense.pieces => 'Pièces',
    CategorieDepense.carburant => 'Carburant',
    CategorieDepense.autre => 'Autre',
  };
}

class Tricycle {
  final String id; // ex. TC-01
  final String immatriculation;
  final String imeiTraceur;
  final int coutAchat;
  final DateTime dateAchat;
  double kilometrage;
  int kmDerniereVidange;

  Tricycle({
    required this.id,
    required this.immatriculation,
    required this.imeiTraceur,
    required this.coutAchat,
    required this.dateAchat,
    required this.kilometrage,
    required this.kmDerniereVidange,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'immatriculation': immatriculation,
    'imeiTraceur': imeiTraceur,
    'coutAchat': coutAchat,
    'dateAchat': dateAchat.toIso8601String(),
    'kilometrage': kilometrage,
    'kmDerniereVidange': kmDerniereVidange,
  };

  factory Tricycle.fromJson(Map<String, dynamic> j) => Tricycle(
    id: j['id'],
    immatriculation: j['immatriculation'],
    imeiTraceur: j['imeiTraceur'],
    coutAchat: j['coutAchat'],
    dateAchat: DateTime.parse(j['dateAchat']),
    kilometrage: (j['kilometrage'] as num).toDouble(),
    kmDerniereVidange: j['kmDerniereVidange'],
  );
}

/// Un chauffeur et son contrat de location.
enum StatutInscription { enAttente, valide, refuse }

/// Un chauffeur : son compte (inscription faite par lui-même dans l'application)
/// et son contrat (rempli par le propriétaire à la validation).
class Chauffeur {
  final String id;
  String nom; // prénom + nom
  String telephone;
  String? email;
  String pieceIdentite; // numéro CIP
  String? ifu;
  String? photoCip; // image en base64
  String? photoVisage; // selfie en base64
  String motDePasse; // empreinte, jamais le mot de passe en clair
  StatutInscription statut;
  DateTime dateInscription;
  DateTime? dateValidation;
  String? motifRefus;
  DateTime? contratAccepteLe;
  String? signature;

  String garant;
  String telephoneGarant;
  String? tricycleId;
  int montantJournalier;
  int salaireMensuel;
  int caution;
  DateTime debutContrat;
  bool reposDimanche;
  int heureDebut; // horaires autorisés
  int heureFin;
  ModePaiement modeHabituel;
  bool actif;

  Chauffeur({
    required this.id,
    required this.nom,
    required this.telephone,
    this.email,
    required this.pieceIdentite,
    this.ifu,
    this.photoCip,
    this.photoVisage,
    this.motDePasse = '',
    this.statut = StatutInscription.valide,
    DateTime? dateInscription,
    this.dateValidation,
    this.motifRefus,
    this.contratAccepteLe,
    this.signature,
    required this.garant,
    required this.telephoneGarant,
    required this.tricycleId,
    required this.montantJournalier,
    this.salaireMensuel = 0,
    required this.caution,
    required this.debutContrat,
    this.reposDimanche = true,
    this.heureDebut = 6,
    this.heureFin = 22,
    this.modeHabituel = ModePaiement.mtnMomo,
    this.actif = true,
  }) : dateInscription = dateInscription ?? debutContrat;

  String get prenomNom {
    final p = nom.split(' ');
    return p.length > 1 ? '${p.first} ${p[1][0]}.' : nom;
  }

  String get prenom => nom.split(' ').first;

  bool get enAttente => statut == StatutInscription.enAttente;
  bool get contratAccepte => contratAccepteLe != null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'nom': nom,
    'telephone': telephone,
    'email': email,
    'pieceIdentite': pieceIdentite,
    'ifu': ifu,
    'photoCip': photoCip,
    'photoVisage': photoVisage,
    'motDePasse': motDePasse,
    'statut': statut.index,
    'dateInscription': dateInscription.toIso8601String(),
    'dateValidation': dateValidation?.toIso8601String(),
    'motifRefus': motifRefus,
    'contratAccepteLe': contratAccepteLe?.toIso8601String(),
    'signature': signature,
    'garant': garant,
    'telephoneGarant': telephoneGarant,
    'tricycleId': tricycleId,
    'montantJournalier': montantJournalier,
    'salaireMensuel': salaireMensuel,
    'caution': caution,
    'debutContrat': debutContrat.toIso8601String(),
    'reposDimanche': reposDimanche,
    'heureDebut': heureDebut,
    'heureFin': heureFin,
    'modeHabituel': modeHabituel.index,
    'actif': actif,
  };

  static DateTime? _date(dynamic v) => v == null ? null : DateTime.parse(v);

  factory Chauffeur.fromJson(Map<String, dynamic> j) => Chauffeur(
    id: j['id'],
    nom: j['nom'],
    telephone: j['telephone'],
    email: j['email'],
    pieceIdentite: j['pieceIdentite'],
    ifu: j['ifu'],
    photoCip: j['photoCip'],
    photoVisage: j['photoVisage'],
    motDePasse: j['motDePasse'] ?? '',
    statut: StatutInscription.values[j['statut'] ?? 1],
    dateInscription: _date(j['dateInscription']),
    dateValidation: _date(j['dateValidation']),
    motifRefus: j['motifRefus'],
    contratAccepteLe: _date(j['contratAccepteLe']),
    signature: j['signature'],
    garant: j['garant'],
    telephoneGarant: j['telephoneGarant'],
    tricycleId: j['tricycleId'],
    montantJournalier: j['montantJournalier'],
    salaireMensuel: j['salaireMensuel'] ?? 0,
    caution: j['caution'],
    debutContrat: DateTime.parse(j['debutContrat']),
    reposDimanche: j['reposDimanche'],
    heureDebut: j['heureDebut'],
    heureFin: j['heureFin'],
    modeHabituel: ModePaiement.values[j['modeHabituel']],
    actif: j['actif'],
  );
}

enum ModeSalaire { mtnMomo, moovMoney, virement, especes }

extension ModeSalaireLibelle on ModeSalaire {
  String get libelle => switch (this) {
    ModeSalaire.mtnMomo => 'MTN MoMo',
    ModeSalaire.moovMoney => 'Moov Money',
    ModeSalaire.virement => 'Virement bancaire',
    ModeSalaire.especes => 'Espèces',
  };
}

/// Salaire payé par le propriétaire à un chauffeur.
class PaiementSalaire {
  final String id;
  final String chauffeurId;
  final int montant;
  final ModeSalaire mode;
  final String periode; // ex. « nov. 2026 »
  final DateTime date;

  PaiementSalaire({
    required this.id,
    required this.chauffeurId,
    required this.montant,
    required this.mode,
    required this.periode,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'chauffeurId': chauffeurId,
    'montant': montant,
    'mode': mode.index,
    'periode': periode,
    'date': date.toIso8601String(),
  };

  factory PaiementSalaire.fromJson(Map<String, dynamic> j) => PaiementSalaire(
    id: j['id'],
    chauffeurId: j['chauffeurId'],
    montant: j['montant'],
    mode: ModeSalaire.values[j['mode']],
    periode: j['periode'],
    date: DateTime.parse(j['date']),
  );
}

/// Un jour travaillé et ce qui a été déposé pour lui.
/// Les dépôts couvrent d'abord les jours les plus anciens.
class JourDepot {
  final DateTime jour;
  final int du;
  final int deposeCeJour; // somme des dépôts faits ce jour-là
  final int couvert; // part du dû couverte (dépôts répartis du plus ancien au plus récent)

  JourDepot(this.jour, this.du, this.deposeCeJour, this.couvert);

  int get manque => du - couvert;
  bool get complet => manque <= 0;
  bool get partiel => couvert > 0 && manque > 0;
}

/// Un versement. Jamais modifié ni supprimé : une correction crée
/// une ligne d'annulation (montant négatif) liée au versement d'origine.
enum StatutVersement { confirme, aConfirmer, rejete }

class Versement {
  final String id;
  final String chauffeurId;
  final int montant;
  final ModePaiement mode;
  final DateTime date;
  final String saisiPar;
  final String? annuleId; // si c'est une annulation, id du versement annulé
  String? motif;

  /// Un dépôt fait par le chauffeur dans l'application reste « à confirmer »
  /// tant que le propriétaire ou le gestionnaire n'a pas vu l'argent arriver
  /// (ou, plus tard, tant que Mobile Money ne l'a pas confirmé).
  StatutVersement statut;

  bool get compte => statut == StatutVersement.confirme;

  Versement({
    required this.id,
    required this.chauffeurId,
    required this.montant,
    required this.mode,
    required this.date,
    required this.saisiPar,
    this.annuleId,
    this.motif,
    this.statut = StatutVersement.confirme,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'chauffeurId': chauffeurId,
    'montant': montant,
    'mode': mode.index,
    'date': date.toIso8601String(),
    'saisiPar': saisiPar,
    'annuleId': annuleId,
    'motif': motif,
    'statut': statut.index,
  };

  factory Versement.fromJson(Map<String, dynamic> j) => Versement(
    id: j['id'],
    chauffeurId: j['chauffeurId'],
    montant: j['montant'],
    mode: ModePaiement.values[j['mode']],
    date: DateTime.parse(j['date']),
    saisiPar: j['saisiPar'],
    annuleId: j['annuleId'],
    motif: j['motif'],
    statut: StatutVersement.values[j['statut'] ?? 0],
  );
}

enum StatutDepense { enAttente, validee, refusee }

class Depense {
  final String id;
  final String tricycleId;
  final CategorieDepense categorie;
  final int montant;
  final String description;
  final DateTime date;
  final String saisiPar;
  final bool avecRecu;
  StatutDepense statut;

  Depense({
    required this.id,
    required this.tricycleId,
    required this.categorie,
    required this.montant,
    required this.description,
    required this.date,
    required this.saisiPar,
    required this.avecRecu,
    required this.statut,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'tricycleId': tricycleId,
    'categorie': categorie.index,
    'montant': montant,
    'description': description,
    'date': date.toIso8601String(),
    'saisiPar': saisiPar,
    'avecRecu': avecRecu,
    'statut': statut.index,
  };

  factory Depense.fromJson(Map<String, dynamic> j) => Depense(
    id: j['id'],
    tricycleId: j['tricycleId'],
    categorie: CategorieDepense.values[j['categorie']],
    montant: j['montant'],
    description: j['description'],
    date: DateTime.parse(j['date']),
    saisiPar: j['saisiPar'],
    avecRecu: j['avecRecu'],
    statut: StatutDepense.values[j['statut']],
  );
}

class Incident {
  final String id;
  final String tricycleId;
  final String type;
  final String description;
  final DateTime date;
  final String saisiPar;
  bool resolu;

  Incident({
    required this.id,
    required this.tricycleId,
    required this.type,
    required this.description,
    required this.date,
    required this.saisiPar,
    this.resolu = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'tricycleId': tricycleId,
    'type': type,
    'description': description,
    'date': date.toIso8601String(),
    'saisiPar': saisiPar,
    'resolu': resolu,
  };

  factory Incident.fromJson(Map<String, dynamic> j) => Incident(
    id: j['id'],
    tricycleId: j['tricycleId'],
    type: j['type'],
    description: j['description'],
    date: DateTime.parse(j['date']),
    saisiPar: j['saisiPar'],
    resolu: j['resolu'],
  );
}

class Inspection {
  final String id;
  final String tricycleId;
  final DateTime date;
  final String saisiPar;
  final Map<String, bool> points; // point de contrôle -> conforme
  final String numeroMoteur;
  final String commentaire;

  Inspection({
    required this.id,
    required this.tricycleId,
    required this.date,
    required this.saisiPar,
    required this.points,
    required this.numeroMoteur,
    required this.commentaire,
  });

  bool get conforme => points.values.every((v) => v);

  Map<String, dynamic> toJson() => {
    'id': id,
    'tricycleId': tricycleId,
    'date': date.toIso8601String(),
    'saisiPar': saisiPar,
    'points': points,
    'numeroMoteur': numeroMoteur,
    'commentaire': commentaire,
  };

  factory Inspection.fromJson(Map<String, dynamic> j) => Inspection(
    id: j['id'],
    tricycleId: j['tricycleId'],
    date: DateTime.parse(j['date']),
    saisiPar: j['saisiPar'],
    points: Map<String, bool>.from(j['points']),
    numeroMoteur: j['numeroMoteur'],
    commentaire: j['commentaire'],
  );
}

/// Ligne du journal d'activité (visible par l'administrateur).
class Activite {
  final DateTime date;
  final String auteur;
  final String action;

  Activite(this.date, this.auteur, this.action);

  Map<String, dynamic> toJson() => {'date': date.toIso8601String(), 'auteur': auteur, 'action': action};
  factory Activite.fromJson(Map<String, dynamic> j) => Activite(DateTime.parse(j['date']), j['auteur'], j['action']);
}

/// Position remontée par le traceur GPS.
class PointGps {
  final LatLng position;
  final DateTime date;
  final double vitesse; // km/h
  final bool moteur;

  PointGps(this.position, this.date, this.vitesse, this.moteur);
}

/// État en direct d'un tricycle (venant du traceur).
class EtatTraceur {
  LatLng position;
  double vitesse;
  bool moteur;
  bool alimentation; // false = traceur débranché
  DateTime dernierSignal;
  double cap; // direction en radians, pour la simulation

  EtatTraceur({
    required this.position,
    required this.vitesse,
    required this.moteur,
    required this.alimentation,
    required this.dernierSignal,
    required this.cap,
  });
}

class Alerte {
  final String id; // stable : type + cible + jour
  final Niveau niveau;
  final String titre;
  final String detail;
  final DateTime date;
  final String? tricycleId;
  final String? chauffeurId;
  final String pour; // 'admin', 'gestionnaire', 'tous'

  Alerte({
    required this.id,
    required this.niveau,
    required this.titre,
    required this.detail,
    required this.date,
    this.tricycleId,
    this.chauffeurId,
    this.pour = 'tous',
  });
}

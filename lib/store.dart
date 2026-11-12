import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'distant.dart';

import 'models.dart';
import 'theme.dart';

/// Situation financière d'un chauffeur à un instant donné.
class Situation {
  final int totalDu;
  final int totalPaye;
  final int arrieres; // dû jusqu'à hier et non payé
  final int resteAujourdhui; // reste à payer, aujourd'hui compris
  final int avance;
  final int joursRetard;
  final bool payeAujourdhui;
  final int duAujourdhui;
  final int deposeAujourdhui; // déposé aujourd'hui (tous jours confondus)
  final int manqueAujourdhui; // ce qui manque pour le jour même
  final int enAttenteConfirmation; // dépôts faits dans l'application, pas encore confirmés
  final Niveau niveau;
  final String libelle;

  Situation({
    required this.duAujourdhui,
    required this.deposeAujourdhui,
    required this.manqueAujourdhui,
    this.enAttenteConfirmation = 0,
    required this.totalDu,
    required this.totalPaye,
    required this.arrieres,
    required this.resteAujourdhui,
    required this.avance,
    required this.joursRetard,
    required this.payeAujourdhui,
    required this.niveau,
    required this.libelle,
  });
}

class Parametres {
  int heureLimite; // heure limite du versement journalier
  int seuilDepense; // au-dessus : validation admin
  double facteurKm; // km du jour > facteur x moyenne => alerte
  double rayonZoneKm;
  int minutesSansSignal;
  int kmVidange;

  Parametres({
    this.heureLimite = 20,
    this.seuilDepense = 25000,
    this.facteurKm = 1.5,
    this.rayonZoneKm = 8,
    this.minutesSansSignal = 30,
    this.kmVidange = 3000,
  });

  Map<String, dynamic> toJson() => {
    'heureLimite': heureLimite,
    'seuilDepense': seuilDepense,
    'facteurKm': facteurKm,
    'rayonZoneKm': rayonZoneKm,
    'minutesSansSignal': minutesSansSignal,
    'kmVidange': kmVidange,
  };

  factory Parametres.fromJson(Map<String, dynamic> j) => Parametres(
    heureLimite: j['heureLimite'],
    seuilDepense: j['seuilDepense'],
    facteurKm: (j['facteurKm'] as num).toDouble(),
    rayonZoneKm: (j['rayonZoneKm'] as num).toDouble(),
    minutesSansSignal: j['minutesSansSignal'],
    kmVidange: j['kmVidange'],
  );
}

/// Stockage local de l'application.
///
/// Toutes les données passent par cette classe : quand le serveur (Supabase)
/// sera branché, seules les méthodes de chargement et d'enregistrement
/// changeront, les écrans resteront les mêmes.
class SperoStore extends ChangeNotifier {
  static const _cle = 'spero_donnees_v2';
  static final centreZone = const LatLng(6.3720, 2.4200); // Cotonou
  static final _distance = const Distance();

  /// Serveur Supabase, ou null en mode démonstration (données sur l'appareil).
  final Distant? distant;
  SperoStore({this.distant});
  bool get surServeur => distant != null;

  /// Dernier problème de synchronisation, affiché en bandeau.
  String? erreur;
  bool chargement = false;
  final List<Activite> _journalAEnvoyer = [];
  Timer? _rechargement;

  Role? role;
  String? chauffeurConnecteId;

  /// Le chauffeur connecté (espace chauffeur).
  Chauffeur? get moi => chauffeur(chauffeurConnecteId);

  void connecter(Role r) {
    role = r;
    notifyListeners();
  }

  void deconnecter() {
    role = null;
    chauffeurConnecteId = null;
    if (distant != null) {
      distant!.arreterEcoute();
      distant!.seDeconnecter();
      _viderDonnees();
    }
    notifyListeners();
  }

  void effacerErreur() {
    erreur = null;
    notifyListeners();
  }

  /// Connexion avec téléphone ou e-mail et mot de passe.
  /// En démonstration, seuls les chauffeurs se connectent ainsi.
  /// Renvoie un message d'erreur, ou null si la connexion a réussi.
  Future<String?> seConnecter(String identifiant, String motDePasse) async {
    if (distant == null) return connecterChauffeur(identifiant, motDePasse);
    try {
      final email = identifiant.contains('@')
          ? (await distant!.emailDeConnexion(identifiant) ?? identifiant.trim())
          : await distant!.emailDeConnexion(identifiant);
      if (email == null) return 'Aucun compte avec ce numéro.';
      await distant!.seConnecter(email, motDePasse);
      await _ouvrirSession();
      return null;
    } catch (e) {
      final m = e.toString();
      if (m.contains('Invalid login')) return 'Téléphone, e-mail ou mot de passe incorrect.';
      return 'Connexion impossible. Vérifiez votre connexion internet.';
    }
  }

  Future<void> _ouvrirSession() async {
    final r = await distant!.monRole();
    role = switch (r) {
      'proprietaire' => Role.admin,
      'gestionnaire' => Role.gestionnaire,
      _ => Role.chauffeur,
    };
    chauffeurConnecteId = role == Role.chauffeur ? distant!.uid : null;
    await chargerDistant();
    distant!.ecouter(() {
      _rechargement?.cancel();
      _rechargement = Timer(const Duration(milliseconds: 600), chargerDistant);
    });
  }

  void _viderDonnees() {
    tricycles = [];
    chauffeurs = [];
    versements = [];
    depenses = [];
    incidents = [];
    inspections = [];
    journal = [];
    salaires = [];
    alertesTraitees = {};
    moteursBloques = {};
    traceurs.clear();
    historique.clear();
  }

  /// Recharge toutes les données visibles par le compte connecté.
  Future<void> chargerDistant() async {
    final d = distant!;
    try {
      final r = await Future.wait([
        d.lire('tricycles'),
        d.lire('chauffeurs'),
        d.lire('versements'),
        d.lire('depenses'),
        d.lire('incidents'),
        d.lire('inspections'),
        d.lire('journal', ordre: 'date'),
        d.lire('salaires'),
        d.lire('alertes_traitees'),
        d.lire('moteurs_bloques'),
        d.lire('parametres'),
      ]);
      tricycles = r[0].map(Tricycle.fromJson).toList()..sort((a, b) => a.id.compareTo(b.id));
      chauffeurs = r[1].map(Chauffeur.fromJson).toList();
      versements = r[2].map(Versement.fromJson).toList();
      depenses = r[3].map(Depense.fromJson).toList();
      incidents = r[4].map(Incident.fromJson).toList();
      inspections = r[5].map((j) => Inspection.fromJson({...j, 'points': Map<String, dynamic>.from(j['points'] as Map)})).toList();
      journal = r[6].map(Activite.fromJson).toList();
      salaires = r[7].map(PaiementSalaire.fromJson).toList();
      alertesTraitees = {for (final j in r[8]) j['id'] as String: j['commentaire'] as String};
      moteursBloques = {for (final j in r[9]) j['tricycleId'] as String};
      if (r[10].isNotEmpty) parametres = Parametres.fromJson(r[10].first);
      for (final t in tricycles) {
        if (!traceurs.containsKey(t.id)) _creerTraceur(t.id, centreZone, enRoute: false);
      }
      _timer ??= Timer.periodic(const Duration(seconds: 3), (_) => _tick());
      erreur = null;
    } catch (e) {
      erreur = 'Impossible de charger les données. Vérifiez votre connexion internet.';
    }
    notifyListeners();
  }

  String get auteur => switch (role) {
    Role.admin => 'Administrateur',
    Role.gestionnaire => 'Gestionnaire',
    Role.chauffeur => 'Chauffeur ${moi?.nom ?? ''}'.trim(),
    null => 'Système',
  };

  static String empreinte(String motDePasse) => sha256.convert(utf8.encode('spero:$motDePasse')).toString();
  static String _chiffres(String s) => s.replaceAll(RegExp(r'\D'), '');

  Chauffeur? trouverCompte(String identifiant) {
    final id = identifiant.trim().toLowerCase();
    if (id.isEmpty) return null;
    if (id.contains('@')) return chauffeurs.where((c) => c.email?.toLowerCase() == id).firstOrNull;
    final n = _chiffres(id);
    if (n.length < 8) return null;
    return chauffeurs.where((c) => _chiffres(c.telephone).endsWith(n) || n.endsWith(_chiffres(c.telephone))).firstOrNull;
  }

  /// Renvoie un message d'erreur, ou null si la connexion a réussi.
  String? connecterChauffeur(String identifiant, String motDePasse) {
    final c = trouverCompte(identifiant);
    if (c == null || c.motDePasse != empreinte(motDePasse)) {
      return 'Téléphone, e-mail ou mot de passe incorrect.';
    }
    chauffeurConnecteId = c.id;
    role = Role.chauffeur;
    notifyListeners();
    return null;
  }

  List<Tricycle> tricycles = [];
  List<Chauffeur> chauffeurs = [];
  List<Versement> versements = [];
  List<Depense> depenses = [];
  List<Incident> incidents = [];
  List<Inspection> inspections = [];
  List<Activite> journal = [];
  List<PaiementSalaire> salaires = [];
  Map<String, String> alertesTraitees = {}; // id alerte -> commentaire
  Set<String> moteursBloques = {};
  Parametres parametres = Parametres();

  // Données GPS (simulées tant que les traceurs ne sont pas posés)
  final Map<String, EtatTraceur> traceurs = {};
  final Map<String, List<PointGps>> historique = {};
  final Map<String, double> moyenneKm = {};
  final Map<String, int> nuitsHorsHoraires7j = {};
  Timer? _timer;
  final _rnd = Random(7);
  int _compteur = 0;

  // ---------- Chargement / enregistrement ----------

  Future<void> charger() async {
    if (distant != null) {
      if (distant!.session != null) {
        try {
          await _ouvrirSession();
        } catch (_) {
          erreur = 'Impossible de joindre le serveur. Vérifiez votre connexion internet.';
        }
      }
      notifyListeners();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final brut = prefs.getString(_cle);
    if (brut == null) {
      _donneesDemo();
      await enregistrer();
    } else {
      final j = jsonDecode(brut) as Map<String, dynamic>;
      tricycles = (j['tricycles'] as List).map((e) => Tricycle.fromJson(e)).toList();
      chauffeurs = (j['chauffeurs'] as List).map((e) => Chauffeur.fromJson(e)).toList();
      versements = (j['versements'] as List).map((e) => Versement.fromJson(e)).toList();
      depenses = (j['depenses'] as List).map((e) => Depense.fromJson(e)).toList();
      incidents = (j['incidents'] as List).map((e) => Incident.fromJson(e)).toList();
      inspections = (j['inspections'] as List).map((e) => Inspection.fromJson(e)).toList();
      journal = (j['journal'] as List).map((e) => Activite.fromJson(e)).toList();
      salaires = ((j['salaires'] ?? []) as List).map((e) => PaiementSalaire.fromJson(e)).toList();
      alertesTraitees = Map<String, String>.from(j['alertesTraitees']);
      moteursBloques = Set<String>.from(j['moteursBloques']);
      parametres = Parametres.fromJson(j['parametres']);
    }
    _demarrerGps();
    notifyListeners();
  }

  Future<void> enregistrer() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cle,
      jsonEncode({
        'tricycles': tricycles.map((e) => e.toJson()).toList(),
        'chauffeurs': chauffeurs.map((e) => e.toJson()).toList(),
        'versements': versements.map((e) => e.toJson()).toList(),
        'depenses': depenses.map((e) => e.toJson()).toList(),
        'incidents': incidents.map((e) => e.toJson()).toList(),
        'inspections': inspections.map((e) => e.toJson()).toList(),
        'journal': journal.map((e) => e.toJson()).toList(),
        'salaires': salaires.map((e) => e.toJson()).toList(),
        'alertesTraitees': alertesTraitees,
        'moteursBloques': moteursBloques.toList(),
        'parametres': parametres.toJson(),
      }),
    );
  }

  Future<void> reinitialiserDemo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cle);
    _timer?.cancel();
    traceurs.clear();
    historique.clear();
    versements = [];
    depenses = [];
    salaires = [];
    await charger();
  }

  void _noter(String action) {
    final a = Activite(DateTime.now(), auteur, action);
    journal.insert(0, a);
    if (distant != null) _journalAEnvoyer.add(a);
  }

  /// Enregistre : sur l'appareil en démonstration, sur le serveur sinon.
  Future<void> _sauver([List<Operation> ops = const []]) async {
    notifyListeners();
    if (distant == null) {
      await enregistrer();
      return;
    }
    final journalOps = [for (final a in _journalAEnvoyer) Ajout('journal', a.toJson())];
    _journalAEnvoyer.clear();
    try {
      for (final op in [...ops, ...journalOps]) {
        await distant!.executer(op);
      }
    } catch (e) {
      erreur = 'L\'enregistrement a échoué : ${_messageErreur(e)}';
      await chargerDistant();
      throw Exception(erreur);
    }
  }

  static String _messageErreur(Object e) {
    final m = e.toString();
    if (m.contains('row-level security') || m.contains('42501')) return 'vous n\'avez pas le droit de faire cette action.';
    if (m.contains('SocketException') || m.contains('Failed host lookup') || m.contains('ClientException')) {
      return 'pas de connexion internet.';
    }
    return m.length > 140 ? '${m.substring(0, 140)}…' : m;
  }

  // ---------- Accès ----------

  Tricycle? tricycle(String? id) => tricycles.where((t) => t.id == id).firstOrNull;
  Chauffeur? chauffeur(String? id) => chauffeurs.where((c) => c.id == id).firstOrNull;
  Chauffeur? chauffeurDe(String tricycleId) =>
      chauffeurs.where((c) => c.actif && c.statut == StatutInscription.valide && c.tricycleId == tricycleId).firstOrNull;
  List<Chauffeur> get chauffeursActifs => chauffeurs.where((c) => c.actif && c.statut == StatutInscription.valide).toList();
  List<Chauffeur> get inscriptionsEnAttente => chauffeurs.where((c) => c.enAttente).toList();

  // ---------- Calculs financiers ----------

  static DateTime jour(DateTime d) => DateTime(d.year, d.month, d.day);

  bool estJourTravaille(Chauffeur c, DateTime d) => !(c.reposDimanche && d.weekday == DateTime.sunday);

  int joursTravailles(Chauffeur c, DateTime debut, DateTime fin) {
    var n = 0;
    for (var d = jour(debut); !d.isAfter(jour(fin)); d = d.add(const Duration(days: 1))) {
      if (estJourTravaille(c, d)) n++;
    }
    return n;
  }

  Iterable<Versement> versementsDe(String chauffeurId) => versements.where((v) => v.chauffeurId == chauffeurId);

  /// Versements pris en compte dans les calculs (confirmés).
  Iterable<Versement> versementsComptesDe(String chauffeurId) => versements.where((v) => v.chauffeurId == chauffeurId && v.compte);
  Iterable<Versement> get versementsComptes => versements.where((v) => v.compte);
  List<Versement> get depotsAConfirmer => versements.where((v) => v.statut == StatutVersement.aConfirmer).toList();

  bool estAnnule(Versement v) => versements.any((x) => x.annuleId == v.id);

  /// Détail jour par jour : ce qui était dû, ce qui a été déposé, ce qui manque.
  /// Les dépôts couvrent d'abord les jours les plus anciens.
  List<JourDepot> journalDepots(Chauffeur c, {DateTime? maintenant}) {
    if (c.statut != StatutInscription.valide) return [];
    final now = maintenant ?? DateTime.now();
    final aujourdhui = jour(now);
    final parJour = <DateTime, int>{};
    var reste = 0;
    for (final v in versementsComptesDe(c.id)) {
      if (v.date.isAfter(now)) continue;
      reste += v.montant;
      parJour[jour(v.date)] = (parJour[jour(v.date)] ?? 0) + v.montant;
    }
    final res = <JourDepot>[];
    for (var d = jour(c.debutContrat); !d.isAfter(aujourdhui); d = d.add(const Duration(days: 1))) {
      if (!estJourTravaille(c, d)) continue;
      final couvert = min(c.montantJournalier, max(0, reste));
      reste -= couvert;
      res.add(JourDepot(d, c.montantJournalier, parJour[d] ?? 0, couvert));
    }
    return res;
  }

  Situation situation(Chauffeur c, {DateTime? maintenant}) {
    final now = maintenant ?? DateTime.now();
    final aujourdhui = jour(now);
    final jours = journalDepots(c, maintenant: now);
    final passes = jours.where((j) => j.jour.isBefore(aujourdhui));
    final duJ = jours.where((j) => j.jour == aujourdhui).firstOrNull;
    final paye = versementsComptesDe(c.id).where((v) => !v.date.isAfter(now)).fold<int>(0, (s, v) => s + v.montant);
    final enAttente = versementsDe(c.id).where((v) => v.statut == StatutVersement.aConfirmer).fold<int>(0, (s, v) => s + v.montant);
    final deposeJour = versementsComptesDe(c.id)
        .where((v) => jour(v.date) == aujourdhui && !v.date.isAfter(now))
        .fold<int>(0, (s, v) => s + v.montant);
    final totalDu = jours.fold<int>(0, (s, j) => s + j.du);
    final arrieres = passes.fold<int>(0, (s, j) => s + j.manque);
    final joursRetard = passes.where((j) => j.manque > 0).length;
    final manqueJour = duJ?.manque ?? 0;
    final reste = max(0, totalDu - paye);
    final avance = max(0, paye - totalDu);
    final apresLimite = now.hour >= parametres.heureLimite;

    Niveau niveau;
    String libelle;
    if (joursRetard >= 2) {
      niveau = Niveau.critique;
      libelle = 'Retard $joursRetard j';
    } else if (joursRetard == 1) {
      niveau = Niveau.attention;
      libelle = 'Retard 1 j';
    } else if (manqueJour > 0 && deposeJour > 0) {
      niveau = apresLimite ? Niveau.attention : Niveau.ok;
      libelle = 'Manque ${nombre(manqueJour)}';
    } else if (manqueJour > 0 && apresLimite) {
      niveau = Niveau.attention;
      libelle = 'Dépôt non fait';
    } else if (manqueJour > 0) {
      niveau = Niveau.ok;
      libelle = 'À déposer';
    } else {
      niveau = Niveau.ok;
      libelle = duJ == null ? 'Repos' : 'Payé';
    }
    return Situation(
      totalDu: totalDu,
      totalPaye: paye,
      arrieres: arrieres,
      resteAujourdhui: reste,
      avance: avance,
      joursRetard: joursRetard,
      payeAujourdhui: reste == 0,
      duAujourdhui: duJ?.du ?? 0,
      deposeAujourdhui: deposeJour,
      manqueAujourdhui: manqueJour,
      enAttenteConfirmation: enAttente,
      niveau: niveau,
      libelle: libelle,
    );
  }

  Iterable<PaiementSalaire> salairesDe(String chauffeurId) => salaires.where((x) => x.chauffeurId == chauffeurId);

  int salairesEntre(DateTime debut, DateTime fin) =>
      salaires.where((x) => !x.date.isBefore(debut) && x.date.isBefore(fin)).fold(0, (s, x) => s + x.montant);

  int encaisseLe(DateTime d) => versementsComptes.where((v) => jour(v.date) == jour(d)).fold(0, (s, v) => s + v.montant);

  int depensesLe(DateTime d) =>
      depenses.where((x) => jour(x.date) == jour(d) && x.statut != StatutDepense.refusee).fold(0, (s, x) => s + x.montant);

  int encaisseEntre(DateTime debut, DateTime fin) =>
      versementsComptes.where((v) => !v.date.isBefore(debut) && v.date.isBefore(fin)).fold(0, (s, v) => s + v.montant);

  int depensesEntre(DateTime debut, DateTime fin, {String? tricycleId}) => depenses
      .where(
        (x) =>
            !x.date.isBefore(debut) &&
            x.date.isBefore(fin) &&
            x.statut != StatutDepense.refusee &&
            (tricycleId == null || x.tricycleId == tricycleId),
      )
      .fold(0, (s, x) => s + x.montant);

  /// Recettes encaissées pour un tricycle (via les chauffeurs qui l'ont loué).
  int recettesTricycle(String tricycleId, {DateTime? depuis}) {
    final ids = chauffeurs.where((c) => c.tricycleId == tricycleId).map((c) => c.id).toSet();
    return versementsComptes
        .where((v) => ids.contains(v.chauffeurId) && (depuis == null || !v.date.isBefore(depuis)))
        .fold(0, (s, v) => s + v.montant);
  }

  int get arrieresTotaux => chauffeursActifs.fold(0, (s, c) => s + situation(c).arrieres);

  // ---------- Actions (gestionnaire / admin) ----------

  String _id(String p) => '$p-${DateTime.now().microsecondsSinceEpoch}';

  Future<Versement> enregistrerVersement(Chauffeur c, int montant, ModePaiement mode) async {
    final v = Versement(id: _id('V'), chauffeurId: c.id, montant: montant, mode: mode, date: DateTime.now(), saisiPar: auteur);
    versements.add(v);
    _noter('Dépôt de ${fcfa(montant)} (${mode.libelle}) enregistré pour ${c.nom}');
    await _sauver([Ajout('versements', v.toJson())]);
    return v;
  }

  /// Le propriétaire ou le gestionnaire confirme avoir reçu l'argent.
  Future<void> confirmerVersement(Versement v) async {
    v.statut = StatutVersement.confirme;
    _noter('Dépôt de ${fcfa(v.montant)} de ${chauffeur(v.chauffeurId)?.nom} confirmé');
    await _sauver([
      MiseAJour('versements', v.id, {'statut': v.statut.index}),
    ]);
  }

  /// L'argent n'est jamais arrivé : le dépôt est rejeté et ne compte pas.
  Future<void> rejeterVersement(Versement v, String motif) async {
    v
      ..statut = StatutVersement.rejete
      ..motif = motif;
    _noter('Dépôt de ${fcfa(v.montant)} de ${chauffeur(v.chauffeurId)?.nom} rejeté : $motif');
    await _sauver([
      MiseAJour('versements', v.id, {'statut': v.statut.index, 'motif': motif}),
    ]);
  }

  /// Vérifie qu'aucun compte n'utilise déjà ce téléphone ou cet e-mail.
  Future<bool> identifiantDejaPris(String telephone, String? email) async {
    if (distant == null) return identifiantPris(telephone, email);
    try {
      if (await distant!.emailDeConnexion(telephone) != null) return true;
      if (email != null && email.trim().isNotEmpty && await distant!.emailDeConnexion(email) != null) return true;
    } catch (_) {}
    return false;
  }

  bool identifiantPris(String telephone, String? email) {
    final n = _chiffres(telephone);
    return chauffeurs.any(
      (c) =>
          (n.length >= 8 && _chiffres(c.telephone).endsWith(n.substring(n.length - 8))) ||
          (email != null && email.isNotEmpty && c.email?.toLowerCase() == email.toLowerCase()),
    );
  }

  /// Inscription faite par le chauffeur lui-même, depuis l'application.
  Future<Chauffeur> inscrire({
    required String prenom,
    required String nom,
    required String telephone,
    String? email,
    required String cip,
    String? ifu,
    required String photoCip,
    required String photoVisage,
    required String motDePasse,
  }) async {
    if (distant != null) {
      final nomComplet = '${prenom.trim()} ${nom.trim()}';
      await distant!.creerCompte(
        email: Distant.emailTechnique(telephone),
        motDePasse: motDePasse,
        nom: nomComplet,
        telephone: telephone.trim(),
      );
      final cheminCip = await distant!.envoyerPhoto('cip.jpg', base64Decode(photoCip));
      final cheminVisage = await distant!.envoyerPhoto('visage.jpg', base64Decode(photoVisage));
      await distant!.rpc('completer_inscription', {
        'p_nom': nomComplet,
        'p_telephone': telephone.trim(),
        'p_email': email?.trim() ?? '',
        'p_cip': cip.trim(),
        'p_ifu': ifu?.trim() ?? '',
        'p_photo_cip': cheminCip,
        'p_photo_visage': cheminVisage,
      });
      await _ouvrirSession();
      return moi!;
    }
    final now = DateTime.now();
    final c = Chauffeur(
      id: _id('CH'),
      nom: '${prenom.trim()} ${nom.trim()}',
      telephone: telephone.trim(),
      email: (email == null || email.trim().isEmpty) ? null : email.trim(),
      pieceIdentite: cip.trim(),
      ifu: (ifu == null || ifu.trim().isEmpty) ? null : ifu.trim(),
      photoCip: photoCip,
      photoVisage: photoVisage,
      motDePasse: empreinte(motDePasse),
      statut: StatutInscription.enAttente,
      dateInscription: now,
      garant: '',
      telephoneGarant: '',
      tricycleId: null,
      montantJournalier: 10000,
      salaireMensuel: 75000,
      caution: 50000,
      debutContrat: jour(now),
      actif: false,
    );
    chauffeurs.add(c);
    chauffeurConnecteId = c.id;
    role = Role.chauffeur;
    _noter('Nouvelle inscription : ${c.nom} (${c.telephone})');
    await _sauver();
    return c;
  }

  Future<void> validerInscription(
    Chauffeur c, {
    required String tricycleId,
    required DateTime debut,
    required int montantJournalier,
    required int salaireMensuel,
    required int caution,
    required String garant,
    required String telephoneGarant,
  }) async {
    final ops = <Operation>[];
    for (final autre in chauffeurs) {
      if (autre.id != c.id && autre.tricycleId == tricycleId) {
        autre.tricycleId = null;
        ops.add(MiseAJour('chauffeurs', autre.id, {'tricycleId': null}));
      }
    }
    c
      ..statut = StatutInscription.valide
      ..actif = true
      ..dateValidation = DateTime.now()
      ..tricycleId = tricycleId
      ..debutContrat = jour(debut)
      ..montantJournalier = montantJournalier
      ..salaireMensuel = salaireMensuel
      ..caution = caution
      ..garant = garant
      ..telephoneGarant = telephoneGarant
      ..contratAccepteLe = null
      ..signature = null;
    _noter('Inscription de ${c.nom} validée : $tricycleId, début le ${DateFormatSimple.date(debut)}');
    await _sauver([...ops, MiseAJour('chauffeurs', c.id, c.toJson())]);
  }

  Future<void> refuserInscription(Chauffeur c, String motif) async {
    c
      ..statut = StatutInscription.refuse
      ..actif = false
      ..motifRefus = motif;
    _noter('Inscription de ${c.nom} refusée : $motif');
    await _sauver([
      MiseAJour('chauffeurs', c.id, {'statut': c.statut.index, 'actif': false, 'motifRefus': motif}),
    ]);
  }

  Future<void> accepterContrat(Chauffeur c, String signature) async {
    if (distant != null) {
      await distant!.rpc('accepter_contrat', {'p_signature': signature});
      await chargerDistant();
      return;
    }
    c
      ..contratAccepteLe = DateTime.now()
      ..signature = signature;
    _noter('Contrat accepté par ${c.nom}');
    await _sauver();
  }

  /// Dépôt fait par le chauffeur depuis l'application, vers le compte du propriétaire.
  Future<Versement> deposer(Chauffeur c, int montant, ModePaiement mode) async {
    final v = Versement(
      id: _id('V'),
      chauffeurId: c.id,
      montant: montant,
      mode: mode,
      date: DateTime.now(),
      saisiPar: 'Chauffeur (application)',
      statut: StatutVersement.aConfirmer,
    );
    versements.add(v);
    _noter('Dépôt de ${fcfa(montant)} par ${c.nom} (${mode.libelle}), à confirmer');
    await _sauver([Ajout('versements', v.toJson())]);
    return v;
  }

  Future<void> payerSalaire(Chauffeur c, int montant, ModeSalaire mode, String periode) async {
    final p = PaiementSalaire(id: _id('S'), chauffeurId: c.id, montant: montant, mode: mode, periode: periode, date: DateTime.now());
    salaires.add(p);
    _noter('Salaire de ${fcfa(montant)} payé à ${c.nom} ($periode, ${mode.libelle})');
    await _sauver([Ajout('salaires', p.toJson())]);
  }

  /// Notifications affichées dans l'espace du chauffeur.
  List<Alerte> notificationsChauffeur(Chauffeur c) {
    final now = DateTime.now();
    final res = <Alerte>[];
    if (c.statut == StatutInscription.enAttente) {
      res.add(
        Alerte(
          id: 'n-attente',
          niveau: Niveau.ok,
          titre: 'Inscription en cours de vérification',
          detail: 'Le propriétaire va vérifier votre dossier et vous attribuer un tricycle.',
          date: c.dateInscription,
        ),
      );
      return res;
    }
    if (c.statut == StatutInscription.refuse) {
      res.add(Alerte(id: 'n-refus', niveau: Niveau.critique, titre: 'Inscription refusée', detail: c.motifRefus ?? '', date: now));
      return res;
    }
    if (!c.contratAccepte) {
      res.add(
        Alerte(
          id: 'n-contrat',
          niveau: Niveau.critique,
          titre: 'Contrat à lire et accepter',
          detail: 'Ouvrez l\'onglet Contrat pour en prendre connaissance.',
          date: c.dateValidation ?? now,
        ),
      );
    }
    final s = situation(c);
    if (s.arrieres > 0) {
      res.add(
        Alerte(
          id: 'n-arrieres',
          niveau: Niveau.critique,
          titre: 'Arriérés : ${fcfa(s.arrieres)}',
          detail: 'Dépôts incomplets ou manquants sur ${s.joursRetard} jour(s). Régularisez au plus vite.',
          date: now,
        ),
      );
    }
    if (s.manqueAujourdhui > 0) {
      final apres = now.hour >= parametres.heureLimite;
      if (s.deposeAujourdhui > 0) {
        res.add(
          Alerte(
            id: 'n-partiel',
            niveau: Niveau.attention,
            titre: 'Dépôt incomplet : il manque ${fcfa(s.manqueAujourdhui)}',
            detail: 'Vous avez déposé ${fcfa(s.deposeAujourdhui)} aujourd\'hui sur ${fcfa(s.duAujourdhui)}.',
            date: now,
          ),
        );
      } else {
        res.add(
          Alerte(
            id: 'n-jour',
            niveau: apres ? Niveau.critique : Niveau.ok,
            titre: apres ? 'Dépôt du jour non fait' : 'Dépôt du jour : ${fcfa(s.manqueAujourdhui)}',
            detail: apres ? 'L\'heure limite de ${parametres.heureLimite} h est passée.' : 'À déposer avant ${parametres.heureLimite} h.',
            date: now,
          ),
        );
      }
    }
    for (final v in versementsDe(
      c.id,
    ).where((v) => v.statut == StatutVersement.rejete && v.date.isAfter(now.subtract(const Duration(days: 7))))) {
      res.add(
        Alerte(
          id: 'n-rejet-${v.id}',
          niveau: Niveau.critique,
          titre: 'Dépôt de ${fcfa(v.montant)} rejeté',
          detail: 'Le propriétaire n\'a pas reçu l\'argent : ${v.motif ?? ''}',
          date: v.date,
        ),
      );
    }
    if (c.tricycleId != null && moteursBloques.contains(c.tricycleId)) {
      res.add(
        Alerte(
          id: 'n-moteur',
          niveau: Niveau.critique,
          titre: 'Moteur bloqué par le propriétaire',
          detail: 'Contactez le propriétaire pour régulariser votre situation.',
          date: now,
        ),
      );
    }
    for (final p in salairesDe(c.id).where((p) => p.date.isAfter(now.subtract(const Duration(days: 40))))) {
      res.add(
        Alerte(
          id: 'n-sal-${p.id}',
          niveau: Niveau.ok,
          titre: 'Salaire reçu : ${fcfa(p.montant)}',
          detail: '${p.periode} · ${p.mode.libelle}',
          date: p.date,
        ),
      );
    }
    if (c.dateValidation != null && now.difference(c.dateValidation!).inDays < 7) {
      res.add(
        Alerte(
          id: 'n-valide',
          niveau: Niveau.ok,
          titre: 'Compte validé',
          detail: 'Tricycle ${c.tricycleId ?? '-'} attribué. Début du contrat le ${DateFormatSimple.date(c.debutContrat)}.',
          date: c.dateValidation!,
        ),
      );
    }
    return res;
  }

  Future<void> annulerVersement(Versement v, String motif) async {
    if (role != Role.admin || estAnnule(v) || v.annuleId != null || !v.compte) return;
    final a = Versement(
      id: _id('A'),
      chauffeurId: v.chauffeurId,
      montant: -v.montant,
      mode: v.mode,
      date: DateTime.now(),
      saisiPar: auteur,
      annuleId: v.id,
      motif: motif,
    );
    versements.add(a);
    _noter('Annulation du versement de ${fcfa(v.montant)} de ${chauffeur(v.chauffeurId)?.nom} : $motif');
    await _sauver([Ajout('versements', a.toJson())]);
  }

  Future<void> ajouterDepense({
    required String tricycleId,
    required CategorieDepense categorie,
    required int montant,
    required String description,
    required bool avecRecu,
  }) async {
    final aValider = montant > parametres.seuilDepense || !avecRecu;
    final ops = <Operation>[];
    final d = Depense(
      id: _id('D'),
      tricycleId: tricycleId,
      categorie: categorie,
      montant: montant,
      description: description,
      date: DateTime.now(),
      saisiPar: auteur,
      avecRecu: avecRecu,
      statut: aValider && role != Role.admin ? StatutDepense.enAttente : StatutDepense.validee,
    );
    depenses.add(d);
    ops.add(Ajout('depenses', d.toJson()));
    if (categorie == CategorieDepense.vidange) {
      final t = tricycle(tricycleId);
      if (t != null) {
        t.kmDerniereVidange = t.kilometrage.round();
        ops.add(MiseAJour('tricycles', t.id, {'kmDerniereVidange': t.kmDerniereVidange, 'kilometrage': t.kilometrage}));
      }
    }
    _noter('Dépense ${categorie.libelle} de ${fcfa(montant)} sur $tricycleId');
    await _sauver(ops);
  }

  Future<void> deciderDepense(Depense d, bool valider) async {
    d.statut = valider ? StatutDepense.validee : StatutDepense.refusee;
    _noter('Dépense de ${fcfa(d.montant)} sur ${d.tricycleId} ${valider ? 'validée' : 'refusée'}');
    await _sauver([
      MiseAJour('depenses', d.id, {'statut': d.statut.index}),
    ]);
  }

  Future<void> declarerIncident(String tricycleId, String type, String description) async {
    final i = Incident(id: _id('I'), tricycleId: tricycleId, type: type, description: description, date: DateTime.now(), saisiPar: auteur);
    incidents.add(i);
    _noter('Incident « $type » déclaré sur $tricycleId');
    await _sauver([Ajout('incidents', i.toJson())]);
  }

  Future<void> resoudreIncident(Incident i) async {
    i.resolu = true;
    _noter('Incident « ${i.type} » sur ${i.tricycleId} résolu');
    await _sauver([
      MiseAJour('incidents', i.id, {'resolu': true}),
    ]);
  }

  Future<void> ajouterInspection(String tricycleId, Map<String, bool> points, String numeroMoteur, String commentaire) async {
    final ins = Inspection(
      id: _id('C'),
      tricycleId: tricycleId,
      date: DateTime.now(),
      saisiPar: auteur,
      points: points,
      numeroMoteur: numeroMoteur,
      commentaire: commentaire,
    );
    inspections.add(ins);
    _noter('Inspection de $tricycleId');
    await _sauver([Ajout('inspections', ins.toJson())]);
  }

  Future<void> enregistrerChauffeur(Chauffeur c, {bool nouveau = false}) async {
    if (nouveau) chauffeurs.add(c);
    final ops = <Operation>[];
    // un tricycle ne peut être loué qu'à un seul chauffeur actif
    for (final autre in chauffeurs) {
      if (autre.id != c.id && autre.actif && autre.tricycleId != null && autre.tricycleId == c.tricycleId) {
        autre.tricycleId = null;
        ops.add(MiseAJour('chauffeurs', autre.id, {'tricycleId': null}));
      }
    }
    ops.add(nouveau ? Ajout('chauffeurs', c.toJson()) : MiseAJour('chauffeurs', c.id, c.toJson()));
    _noter(nouveau ? 'Nouveau contrat : ${c.nom}' : 'Contrat modifié : ${c.nom}');
    await _sauver(ops);
  }

  Future<void> enregistrerTricycle(Tricycle t, {bool nouveau = false}) async {
    if (nouveau) {
      tricycles.add(t);
      _creerTraceur(t.id, centreZone, enRoute: false);
    }
    _noter(nouveau ? 'Nouveau tricycle : ${t.id}' : 'Tricycle modifié : ${t.id}');
    await _sauver([nouveau ? Ajout('tricycles', t.toJson()) : MiseAJour('tricycles', t.id, t.toJson())]);
  }

  Future<void> traiterAlerte(Alerte a, String commentaire) async {
    alertesTraitees[a.id] = commentaire;
    _noter('Alerte traitée « ${a.titre} » : $commentaire');
    await _sauver([
      Ajout('alertes_traitees', {'id': a.id, 'commentaire': commentaire}),
    ]);
  }

  Future<void> basculerMoteur(String tricycleId) async {
    final bloque = moteursBloques.contains(tricycleId);
    Operation op;
    if (bloque) {
      moteursBloques.remove(tricycleId);
      op = Suppression('moteurs_bloques', 'tricycle_id', tricycleId);
      _noter('Moteur de $tricycleId réactivé à distance');
    } else {
      final e = traceurs[tricycleId];
      if (e != null && e.vitesse > 0) return; // sécurité : uniquement à l'arrêt
      moteursBloques.add(tricycleId);
      op = Ajout('moteurs_bloques', {'tricycleId': tricycleId});
      _noter('Moteur de $tricycleId coupé à distance');
    }
    await _sauver([op]);
  }

  Future<void> sauverParametres() async {
    _noter('Paramètres modifiés');
    await _sauver([MiseAJour('parametres', '1', parametres.toJson())]);
  }

  // ---------- Règles d'alerte ----------

  bool horsZone(LatLng p) => _distance.as(LengthUnit.Kilometer, centreZone, p) > parametres.rayonZoneKm;

  double kmEntre(String tricycleId, DateTime debut, DateTime fin) {
    final pts = (historique[tricycleId] ?? []).where((p) => !p.date.isBefore(debut) && p.date.isBefore(fin)).toList();
    var km = 0.0;
    for (var i = 1; i < pts.length; i++) {
      km += _distance.as(LengthUnit.Meter, pts[i - 1].position, pts[i].position) / 1000;
    }
    return km;
  }

  double kmAujourdhui(String id) => kmEntre(id, jour(DateTime.now()), DateTime.now().add(const Duration(minutes: 1)));
  double kmHier(String id) {
    final a = jour(DateTime.now());
    return kmEntre(id, a.subtract(const Duration(days: 1)), a);
  }

  bool estHorsHoraires(Chauffeur c, DateTime d) => d.hour < c.heureDebut || d.hour >= c.heureFin;

  /// Points roulés hors des horaires du contrat sur les dernières 24 h.
  List<PointGps> pointsHorsHoraires(String tricycleId) {
    final c = chauffeurDe(tricycleId);
    if (c == null) return [];
    final depuis = DateTime.now().subtract(const Duration(hours: 24));
    return (historique[tricycleId] ?? []).where((p) => p.moteur && p.date.isAfter(depuis) && estHorsHoraires(c, p.date)).toList();
  }

  bool traceurCoupe(String tricycleId) {
    final e = traceurs[tricycleId];
    if (e == null) return false;
    return !e.alimentation || DateTime.now().difference(e.dernierSignal).inMinutes > parametres.minutesSansSignal;
  }

  List<Alerte> get toutesAlertes {
    final now = DateTime.now();
    final cleJour = '${now.year}${now.month}${now.day}';
    final res = <Alerte>[];
    final h = DateFormatSimple.heure;

    for (final c in chauffeursActifs) {
      final s = situation(c);
      if (s.joursRetard >= 2) {
        res.add(
          Alerte(
            id: 'impaye-${c.id}-$cleJour',
            niveau: Niveau.critique,
            titre: 'Retard ${s.joursRetard} jours · ${c.prenomNom}',
            detail: '${fcfa(s.arrieres)} d\'arriérés sur ${c.tricycleId ?? 'aucun tricycle'}',
            date: now,
            chauffeurId: c.id,
            tricycleId: c.tricycleId,
          ),
        );
      } else if (s.joursRetard == 1) {
        res.add(
          Alerte(
            id: 'retard-${c.id}-$cleJour',
            niveau: Niveau.attention,
            titre: 'Retard de paiement · ${c.prenomNom}',
            detail: 'Il manque ${fcfa(s.arrieres)} sur les jours précédents',
            date: now,
            chauffeurId: c.id,
            tricycleId: c.tricycleId,
          ),
        );
      }
      if (s.manqueAujourdhui > 0 && now.hour >= parametres.heureLimite) {
        res.add(
          Alerte(
            id: 'limite-${c.id}-$cleJour',
            niveau: Niveau.attention,
            titre: '${s.deposeAujourdhui > 0 ? 'Dépôt incomplet' : 'Dépôt du jour non fait'} · ${c.prenomNom}',
            detail: 'Déposé ${fcfa(s.deposeAujourdhui)} sur ${fcfa(s.duAujourdhui)} : il manque ${fcfa(s.manqueAujourdhui)}',
            date: now,
            chauffeurId: c.id,
            tricycleId: c.tricycleId,
          ),
        );
      }
      if (nuitsHorsHoraires7j[c.tricycleId] != null && nuitsHorsHoraires7j[c.tricycleId]! >= 3) {
        res.add(
          Alerte(
            id: 'souslocation-${c.id}-$cleJour',
            niveau: Niveau.attention,
            titre: 'Sous-location probable · ${c.tricycleId}',
            detail: 'Roule hors horaires ${nuitsHorsHoraires7j[c.tricycleId]} nuits sur les 7 derniers jours',
            date: now,
            chauffeurId: c.id,
            tricycleId: c.tricycleId,
            pour: 'admin',
          ),
        );
      }
    }

    for (final v in depotsAConfirmer) {
      final c = chauffeur(v.chauffeurId);
      res.add(
        Alerte(
          id: 'confirmer-${v.id}',
          niveau: Niveau.attention,
          titre: 'Dépôt à confirmer · ${c?.prenomNom ?? ''}',
          detail: '${fcfa(v.montant)} via ${v.mode.libelle}, ${DateFormatSimple.relative(v.date).toLowerCase()} : vérifiez la réception',
          date: v.date,
          chauffeurId: v.chauffeurId,
        ),
      );
    }

    for (final c in inscriptionsEnAttente) {
      res.add(
        Alerte(
          id: 'inscription-${c.id}',
          niveau: Niveau.attention,
          titre: 'Nouvelle inscription · ${c.nom}',
          detail: 'Inscrit ${DateFormatSimple.relative(c.dateInscription).toLowerCase()} · dossier à vérifier, tricycle à attribuer',
          date: c.dateInscription,
          chauffeurId: c.id,
          pour: 'admin',
        ),
      );
    }
    for (final c in chauffeursActifs.where((c) => !c.contratAccepte)) {
      res.add(
        Alerte(
          id: 'contrat-${c.id}',
          niveau: Niveau.attention,
          titre: 'Contrat non accepté · ${c.prenomNom}',
          detail: 'Le chauffeur n\'a pas encore lu et accepté son contrat',
          date: c.dateValidation ?? now,
          chauffeurId: c.id,
          tricycleId: c.tricycleId,
          pour: 'admin',
        ),
      );
    }

    for (final t in tricycles) {
      final e = traceurs[t.id];
      if (e == null) continue;
      if (traceurCoupe(t.id)) {
        res.add(
          Alerte(
            id: 'traceur-${t.id}-$cleJour',
            niveau: Niveau.critique,
            titre: 'Traceur débranché · ${t.id}',
            detail: 'Signal perdu depuis ${h(e.dernierSignal)}',
            date: e.dernierSignal,
            tricycleId: t.id,
          ),
        );
      }
      if (horsZone(e.position) && !traceurCoupe(t.id)) {
        res.add(
          Alerte(
            id: 'zone-${t.id}-$cleJour',
            niveau: Niveau.critique,
            titre: 'Sortie de zone · ${t.id}',
            detail:
                'À ${_distance.as(LengthUnit.Kilometer, centreZone, e.position).toStringAsFixed(1)} km du centre (limite ${parametres.rayonZoneKm.toStringAsFixed(0)} km)',
            date: now,
            tricycleId: t.id,
          ),
        );
      }
      final nuit = pointsHorsHoraires(t.id);
      if (nuit.isNotEmpty) {
        res.add(
          Alerte(
            id: 'nuit-${t.id}-$cleJour',
            niveau: Niveau.attention,
            titre: 'Circulation hors horaires · ${t.id}',
            detail: 'A roulé entre ${h(nuit.first.date)} et ${h(nuit.last.date)}',
            date: nuit.last.date,
            tricycleId: t.id,
            pour: 'admin',
          ),
        );
      }
      final kmH = kmHier(t.id);
      final moy = moyenneKm[t.id] ?? 0;
      if (moy > 0 && kmH > moy * parametres.facteurKm) {
        res.add(
          Alerte(
            id: 'km-${t.id}-$cleJour',
            niveau: Niveau.attention,
            titre: 'Kilométrage anormal · ${t.id}',
            detail: '${kmH.round()} km hier, moyenne ${moy.round()} km',
            date: now,
            tricycleId: t.id,
            pour: 'admin',
          ),
        );
      }
      final c = chauffeurDe(t.id);
      final rouleAujourdhui = (historique[t.id] ?? []).any((p) => p.moteur && !p.date.isBefore(jour(now)));
      if (c != null && estJourTravaille(c, now) && now.hour >= 10 && !rouleAujourdhui && !traceurCoupe(t.id)) {
        res.add(
          Alerte(
            id: 'immobile-${t.id}-$cleJour',
            niveau: Niveau.attention,
            titre: 'Tricycle immobile · ${t.id}',
            detail: 'Aucun déplacement aujourd\'hui alors que c\'est un jour de travail',
            date: now,
            tricycleId: t.id,
          ),
        );
      }
      final depuisVidange = t.kilometrage - t.kmDerniereVidange;
      if (depuisVidange > parametres.kmVidange - 300) {
        final restant = (parametres.kmVidange - depuisVidange).round();
        res.add(
          Alerte(
            id: 'vidange-${t.id}-${t.kmDerniereVidange}',
            niveau: Niveau.ok,
            titre: 'Vidange à prévoir · ${t.id}',
            detail: restant > 0 ? 'Dans $restant km' : 'Dépassée de ${-restant} km',
            date: now,
            tricycleId: t.id,
            pour: 'gestionnaire',
          ),
        );
      }
    }

    for (final d in depenses.where((d) => d.statut == StatutDepense.enAttente)) {
      res.add(
        Alerte(
          id: 'depense-${d.id}',
          niveau: Niveau.attention,
          titre: 'Dépense à valider · ${d.tricycleId}',
          detail: '${d.categorie.libelle} ${fcfa(d.montant)}${d.avecRecu ? '' : ' · sans reçu'}',
          date: d.date,
          tricycleId: d.tricycleId,
          pour: 'admin',
        ),
      );
    }

    final hier = now.subtract(const Duration(days: 2));
    for (final v in versements.where((v) => v.date.isAfter(hier) && v.montant > 0 && v.annuleId == null)) {
      final c = chauffeur(v.chauffeurId);
      if (c == null) continue;
      final tard = v.date.hour >= 22 || v.date.hour < 5;
      final especesInhabituel = v.mode == ModePaiement.especes && c.modeHabituel != ModePaiement.especes;
      if (tard || especesInhabituel) {
        res.add(
          Alerte(
            id: 'saisie-${v.id}',
            niveau: Niveau.attention,
            titre: 'Saisie à vérifier · ${c.prenomNom}',
            detail: tard
                ? 'Versement de ${fcfa(v.montant)} saisi à ${h(v.date)}'
                : 'Payé en espèces (${fcfa(v.montant)}) alors qu\'il paie d\'habitude par ${c.modeHabituel.libelle}',
            date: v.date,
            chauffeurId: c.id,
            pour: 'admin',
          ),
        );
      }
    }

    for (final i in incidents.where((i) => !i.resolu)) {
      res.add(
        Alerte(
          id: 'incident-${i.id}',
          niveau: Niveau.attention,
          titre: '${i.type} · ${i.tricycleId}',
          detail: i.description,
          date: i.date,
          tricycleId: i.tricycleId,
        ),
      );
    }

    res.sort((a, b) {
      final n = b.niveau.index.compareTo(a.niveau.index);
      return n != 0 ? n : b.date.compareTo(a.date);
    });
    return res;
  }

  List<Alerte> alertesOuvertes() {
    final cible = role == Role.admin ? 'admin' : 'gestionnaire';
    return toutesAlertes
        .where((a) => !alertesTraitees.containsKey(a.id) && (a.pour == 'tous' || a.pour == cible || role == Role.admin))
        .toList();
  }

  // ---------- GPS ----------

  void _creerTraceur(String id, LatLng p, {bool enRoute = true}) {
    traceurs[id] = EtatTraceur(
      position: p,
      vitesse: enRoute ? 20 + _rnd.nextDouble() * 15 : 0,
      moteur: enRoute,
      alimentation: true,
      dernierSignal: DateTime.now(),
      cap: _rnd.nextDouble() * 2 * pi,
    );
    historique[id] = [];
    moyenneKm[id] = 0;
  }

  LatLng _pas(LatLng p, double cap, double km) {
    final dLat = km / 111.0 * cos(cap);
    final dLng = km / (111.0 * cos(p.latitude * pi / 180)) * sin(cap);
    return LatLng(p.latitude + dLat, p.longitude + dLng);
  }

  /// Génère deux jours d'historique de trajets simulés.
  void _genererHistorique() {
    final now = DateTime.now();
    final aujourdhui = jour(now);
    final r = Random(11);
    final profils = <String, double>{'TC-02': 1.35}; // km par pas de 5 min
    for (final t in tricycles) {
      final id = t.id;
      final c = chauffeurDe(id);
      final pts = <PointGps>[];
      var pos = _pas(centreZone, r.nextDouble() * 2 * pi, r.nextDouble() * 4);
      var cap = r.nextDouble() * 2 * pi;
      final pasKm = profils[id] ?? 0.45 + r.nextDouble() * 0.15;

      void rouler(DateTime debut, DateTime fin, {double pas = 0.5, bool sortir = false}) {
        for (var d = debut; d.isBefore(fin); d = d.add(const Duration(minutes: 5))) {
          cap += (r.nextDouble() - 0.5) * 1.2;
          final dist = _distance.as(LengthUnit.Kilometer, centreZone, pos);
          if (!sortir && dist > parametres.rayonZoneKm - 1.5) {
            // revenir vers le centre
            cap = atan2(centreZone.longitude - pos.longitude, centreZone.latitude - pos.latitude);
          }
          if (sortir && dist < parametres.rayonZoneKm + 3) {
            cap = -0.75 + (r.nextDouble() - 0.5) * 0.4; // vers le nord-ouest (Abomey-Calavi)
          } else if (sortir && dist > parametres.rayonZoneKm + 5) {
            cap = atan2(centreZone.longitude - pos.longitude, centreZone.latitude - pos.latitude);
          }
          final arret = r.nextDouble() < 0.18;
          if (!arret) pos = _pas(pos, cap, pas * (0.6 + r.nextDouble() * 0.8));
          pts.add(PointGps(pos, d, arret ? 0 : 15 + r.nextDouble() * 25, true));
        }
      }

      if (c != null && id != 'TC-09') {
        // hier
        final hier = aujourdhui.subtract(const Duration(days: 1));
        rouler(hier.add(const Duration(hours: 6, minutes: 30)), hier.add(const Duration(hours: 21)), pas: pasKm);
        if (id == 'TC-04') {
          // circulation de nuit, hors zone
          rouler(hier.add(const Duration(hours: 23)), aujourdhui.add(const Duration(hours: 1, minutes: 30)), pas: 0.9, sortir: true);
        }
        // aujourd'hui
        final debutJour = aujourdhui.add(const Duration(hours: 6, minutes: 30));
        if (id != 'TC-07' && now.isAfter(debutJour)) {
          rouler(debutJour, now, pas: pasKm, sortir: id == 'TC-04');
        }
        if (id == 'TC-07') {
          final coupure = now.subtract(const Duration(hours: 2, minutes: 10));
          if (coupure.isAfter(debutJour)) rouler(debutJour, coupure, pas: pasKm);
        }
      }
      historique[id] = pts;
      moyenneKm[id] = id == 'TC-02' ? 96 : 0;
      final e = EtatTraceur(
        position: pts.isNotEmpty ? pts.last.position : pos,
        vitesse: pts.isNotEmpty ? pts.last.vitesse : 0,
        moteur: pts.isNotEmpty && pts.last.date.isAfter(now.subtract(const Duration(minutes: 10))),
        alimentation: id != 'TC-07',
        dernierSignal: id == 'TC-07' ? now.subtract(const Duration(hours: 2, minutes: 10)) : now,
        cap: cap,
      );
      if (!e.moteur) e.vitesse = 0;
      traceurs[id] = e;
    }
    for (final t in tricycles) {
      if ((moyenneKm[t.id] ?? 0) == 0) moyenneKm[t.id] = max(60, kmHier(t.id) * (0.9 + r.nextDouble() * 0.2));
    }
    nuitsHorsHoraires7j['TC-04'] = 3;
  }

  void _demarrerGps() {
    _genererHistorique();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _tick());
  }

  void _tick() {
    final now = DateTime.now();
    _compteur++;
    for (final entry in traceurs.entries) {
      final id = entry.key;
      final e = entry.value;
      if (!e.alimentation) continue;
      e.dernierSignal = now;
      if (!e.moteur || moteursBloques.contains(id)) {
        e.vitesse = 0;
        continue;
      }
      e.cap += (_rnd.nextDouble() - 0.5) * 0.6;
      final dist = _distance.as(LengthUnit.Kilometer, centreZone, e.position);
      if ((id != 'TC-04' && dist > parametres.rayonZoneKm - 1) || dist > parametres.rayonZoneKm + 5) {
        e.cap = atan2(centreZone.longitude - e.position.longitude, centreZone.latitude - e.position.latitude);
      }
      e.vitesse = (15 + _rnd.nextDouble() * 25);
      // accéléré x4 pour que le déplacement se voie sur la carte
      final km = e.vitesse / 3600 * 3 * 4;
      e.position = _pas(e.position, e.cap, km);
      final t = tricycle(id);
      if (t != null) t.kilometrage += km;
      if (_compteur % 5 == 0) {
        historique[id]?.add(PointGps(e.position, now, e.vitesse, true));
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ---------- Données de démonstration ----------

  void _donneesDemo() {
    final now = DateTime.now();
    final aujourdhui = jour(now);
    final debut = aujourdhui.subtract(const Duration(days: 45));
    final r = Random(42);

    tricycles = List.generate(10, (i) {
      final n = (i + 1).toString().padLeft(2, '0');
      final km = 4200 + r.nextInt(3500).toDouble();
      return Tricycle(
        id: 'TC-$n',
        immatriculation: 'AB ${4100 + i * 37} RB',
        imeiTraceur: '86${(4000000000000 + r.nextInt(999999999)).toString()}',
        coutAchat: 1450000,
        dateAchat: debut.subtract(const Duration(days: 10)),
        kilometrage: km,
        kmDerniereVidange: (km - (i == 4 ? 2850 : 400 + r.nextInt(1800))).round(),
      );
    });

    final noms = [
      ['Koffi Agossou', ModePaiement.mtnMomo],
      ['Sèna Dossou', ModePaiement.mtnMomo],
      ['Rachidi Bello', ModePaiement.moovMoney],
      ['Codjo Hounsou', ModePaiement.especes],
      ['Yao Mensah', ModePaiement.mtnMomo],
      ['Brice Kpadonou', ModePaiement.moovMoney],
      ['Ismaël Adjovi', ModePaiement.mtnMomo],
      ['Fiacre Gbaguidi', ModePaiement.especes],
      ['Romaric Zinsou', ModePaiement.mtnMomo],
    ];
    chauffeurs = List.generate(noms.length, (i) {
      return Chauffeur(
        id: 'CH-${i + 1}',
        nom: noms[i][0] as String,
        telephone: '+229 01 97 00 00 ${(i + 1).toString().padLeft(2, '0')}',
        email: i == 0 ? 'koffi.agossou@exemple.bj' : null,
        pieceIdentite: '${1000000 + r.nextInt(8999999)}',
        ifu: i.isEven ? '32019${1000000 + r.nextInt(8999999)}' : null,
        motDePasse: empreinte('1234'),
        dateInscription: debut.subtract(const Duration(days: 2)),
        dateValidation: debut.subtract(const Duration(days: 1)),
        contratAccepteLe: debut.subtract(const Duration(hours: 20)),
        signature: noms[i][0] as String,
        garant: [
          'Paul Agossou',
          'Mme Dossou',
          'Alassane Bello',
          'Jean Hounsou',
          'Akim Mensah',
          'Félix Kpadonou',
          'Rose Adjovi',
          'Marc Gbaguidi',
          'Eric Zinsou',
        ][i],
        telephoneGarant: '+229 01 6${r.nextInt(9)} ${10 + r.nextInt(89)} ${10 + r.nextInt(89)} ${10 + r.nextInt(89)}',
        tricycleId: 'TC-${(i + 1).toString().padLeft(2, '0')}',
        montantJournalier: 10000,
        salaireMensuel: 75000,
        caution: 50000,
        debutContrat: debut,
        modeHabituel: noms[i][1] as ModePaiement,
      );
    });

    // Versements : profils de comportement
    // CH-3 : un jour de retard ; CH-4 : deux jours d'impayés ; CH-6 : paie souvent en retard
    var k = 0;
    for (final c in chauffeurs) {
      for (var d = jour(c.debutContrat); d.isBefore(aujourdhui); d = d.add(const Duration(days: 1))) {
        if (!estJourTravaille(c, d)) continue;
        final joursAvant = aujourdhui.difference(d).inDays;
        if (c.id == 'CH-4' && joursAvant <= 2) continue;
        if (c.id == 'CH-3' && joursAvant == 1) continue;
        if (c.id == 'CH-6' && r.nextDouble() < 0.15 && joursAvant > 3) {
          // paie le lendemain, en double
          continue;
        }
        var montant = c.montantJournalier;
        if (c.id == 'CH-6' && k % 7 == 0) montant *= 2;
        final heure = 17 + r.nextInt(3);
        versements.add(
          Versement(
            id: 'V-${k++}',
            chauffeurId: c.id,
            montant: montant,
            mode: c.modeHabituel,
            date: d.add(Duration(hours: heure, minutes: r.nextInt(59))),
            saisiPar: c.modeHabituel == ModePaiement.especes ? 'Gestionnaire' : 'Chauffeur (application)',
          ),
        );
      }
      // équilibrer CH-6 pour qu'il soit à jour à hier
      if (c.id == 'CH-6') {
        final s = situation(c, maintenant: aujourdhui.add(const Duration(seconds: 1)));
        if (s.arrieres > 0) {
          versements.add(
            Versement(
              id: 'V-${k++}',
              chauffeurId: c.id,
              montant: s.arrieres,
              mode: c.modeHabituel,
              date: aujourdhui.subtract(const Duration(hours: 5)),
              saisiPar: 'Chauffeur (application)',
            ),
          );
        }
      }
    }
    // quelques versements déjà reçus aujourd'hui
    if (now.hour >= 8) {
      for (final id in ['CH-1', 'CH-2', 'CH-5']) {
        final c = chauffeur(id)!;
        if (!estJourTravaille(c, now)) continue;
        versements.add(
          Versement(
            id: 'V-${k++}',
            chauffeurId: id,
            montant: id == 'CH-5' ? 5000 : 10000, // CH-5 : dépôt incomplet
            mode: c.modeHabituel,
            date: aujourdhui.add(Duration(hours: min(now.hour, 8), minutes: 10 + r.nextInt(40))),
            saisiPar: 'Chauffeur (application)',
          ),
        );
      }
    }
    // un dépôt fait dans l'application, pas encore confirmé
    if (now.hour >= 9 && estJourTravaille(chauffeur('CH-7')!, now)) {
      versements.add(
        Versement(
          id: 'V-${k++}',
          chauffeurId: 'CH-7',
          montant: 10000,
          mode: ModePaiement.mtnMomo,
          date: aujourdhui.add(const Duration(hours: 8, minutes: 47)),
          saisiPar: 'Chauffeur (application)',
          statut: StatutVersement.aConfirmer,
        ),
      );
    }
    // saisie suspecte : espèces pour quelqu'un qui paie par MoMo, saisi tard hier
    versements.add(
      Versement(
        id: 'V-${k++}',
        chauffeurId: 'CH-9',
        montant: 10000,
        mode: ModePaiement.especes,
        date: aujourdhui.subtract(const Duration(hours: 1, minutes: 20)),
        saisiPar: 'Gestionnaire',
      ),
    );
    // retirer le paiement MoMo normal d'hier de CH-9 pour garder le solde juste
    final hier = aujourdhui.subtract(const Duration(days: 1));
    versements.removeWhere((v) => v.chauffeurId == 'CH-9' && jour(v.date) == hier && v.mode == ModePaiement.mtnMomo);

    // CH-8 : dépôt incomplet hier (6 000 sur 10 000)
    final hierCh8 = versements.where((v) => v.chauffeurId == 'CH-8' && jour(v.date) == hier).toList();
    if (hierCh8.isNotEmpty) {
      versements.removeWhere((v) => hierCh8.contains(v));
      final v0 = hierCh8.first;
      versements.add(Versement(id: v0.id, chauffeurId: 'CH-8', montant: 6000, mode: v0.mode, date: v0.date, saisiPar: v0.saisiPar));
    }

    // Salaires du mois dernier
    final moisDernier = DateTime(now.year, now.month - 1);
    salaires = [
      for (final c in chauffeurs)
        PaiementSalaire(
          id: 'S-${c.id}',
          chauffeurId: c.id,
          montant: c.salaireMensuel,
          mode: c.id == 'CH-4' ? ModeSalaire.especes : ModeSalaire.mtnMomo,
          periode: DateFormatSimple.moisAnnee(moisDernier),
          date: DateTime(now.year, now.month, 1, 10),
        ),
    ];

    // Une inscription en attente de validation
    chauffeurs.add(
      Chauffeur(
        id: 'CH-10',
        nom: 'Gildas Hounkpè',
        telephone: '+229 01 96 44 21 08',
        email: 'gildas.hounkpe@exemple.bj',
        pieceIdentite: '4471902',
        motDePasse: empreinte('1234'),
        statut: StatutInscription.enAttente,
        dateInscription: now.subtract(const Duration(hours: 2)),
        garant: '',
        telephoneGarant: '',
        tricycleId: null,
        montantJournalier: 10000,
        salaireMensuel: 75000,
        caution: 50000,
        debutContrat: aujourdhui,
        actif: false,
      ),
    );

    // Dépenses
    final cats = CategorieDepense.values;
    for (var i = 0; i < 26; i++) {
      final t = tricycles[r.nextInt(tricycles.length)];
      final cat = cats[r.nextInt(5)];
      final montant = switch (cat) {
        CategorieDepense.vidange => 6500,
        CategorieDepense.pneus => 18000,
        CategorieDepense.reparation => 8000 + r.nextInt(15) * 1000,
        CategorieDepense.pieces => 3000 + r.nextInt(10) * 1000,
        _ => 5000,
      };
      depenses.add(
        Depense(
          id: 'D-$i',
          tricycleId: t.id,
          categorie: cat,
          montant: montant,
          description: switch (cat) {
            CategorieDepense.vidange => 'Vidange moteur + filtre',
            CategorieDepense.pneus => 'Pneu arrière',
            CategorieDepense.reparation => 'Réparation embrayage',
            CategorieDepense.pieces => 'Plaquettes de frein',
            _ => 'Divers',
          },
          date: aujourdhui.subtract(Duration(days: 1 + r.nextInt(40), hours: -10)),
          saisiPar: 'Gestionnaire',
          avecRecu: true,
          statut: StatutDepense.validee,
        ),
      );
    }
    depenses.add(
      Depense(
        id: 'D-att1',
        tricycleId: 'TC-09',
        categorie: CategorieDepense.reparation,
        montant: 42000,
        description: 'Remplacement boîte de vitesses',
        date: aujourdhui.add(const Duration(hours: 9)),
        saisiPar: 'Gestionnaire',
        avecRecu: true,
        statut: StatutDepense.enAttente,
      ),
    );
    depenses.add(
      Depense(
        id: 'D-att2',
        tricycleId: 'TC-04',
        categorie: CategorieDepense.pieces,
        montant: 12000,
        description: 'Rétroviseur + clignotant',
        date: aujourdhui.subtract(const Duration(hours: 6)),
        saisiPar: 'Gestionnaire',
        avecRecu: false,
        statut: StatutDepense.enAttente,
      ),
    );

    incidents = [
      Incident(
        id: 'I-1',
        tricycleId: 'TC-09',
        type: 'Panne',
        description: 'Boîte de vitesses cassée, tricycle au garage à Akpakpa',
        date: aujourdhui.subtract(const Duration(hours: 14)),
        saisiPar: 'Gestionnaire',
      ),
    ];

    inspections = [
      for (final t in tricycles.take(6))
        Inspection(
          id: 'C-${t.id}',
          tricycleId: t.id,
          date: aujourdhui.subtract(Duration(days: 3 + r.nextInt(10))),
          saisiPar: 'Gestionnaire',
          points: {for (final p in pointsInspection) p: !(t.id == 'TC-04' && p == 'Rétroviseurs')},
          numeroMoteur: 'MT${100000 + r.nextInt(899999)}',
          commentaire: t.id == 'TC-04' ? 'Rétroviseur gauche cassé' : 'RAS',
        ),
    ];

    journal = [Activite(now, 'Système', 'Données de démonstration créées')];
    alertesTraitees = {};
    moteursBloques = {};
    parametres = Parametres();
  }
}

const pointsInspection = [
  'Freins',
  'Pneus',
  'Feux et clignotants',
  'Rétroviseurs',
  'Niveau d\'huile',
  'Carrosserie',
  'Traceur GPS en place',
];

String fcfa(int montant) {
  final s = montant.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return '${montant < 0 ? '-' : ''}$b FCFA';
}

String nombre(int n) => fcfa(n).replaceAll(' FCFA', '');

class DateFormatSimple {
  static String heure(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  static const _mois = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
  static const _jours = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];
  static String date(DateTime d) => '${d.day} ${_mois[d.month - 1]}';
  static String dateLongue(DateTime d) => '${_jours[d.weekday - 1]} ${d.day} ${_mois[d.month - 1]} ${d.year}';
  static String moisAnnee(DateTime d) => '${_mois[d.month - 1]} ${d.year}';
  static String relative(DateTime d) {
    final now = DateTime.now();
    final a = SperoStore.jour(now);
    final j = SperoStore.jour(d);
    if (j == a) return 'Aujourd\'hui ${heure(d)}';
    if (j == a.subtract(const Duration(days: 1))) return 'Hier ${heure(d)}';
    return '${date(d)} ${heure(d)}';
  }
}

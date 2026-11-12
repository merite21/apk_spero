import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'alertes.dart';
import 'depenses.dart';
import 'fiche_chauffeur.dart';
import 'flotte.dart';
import 'formulaires.dart';
import 'parametres.dart';

class Accueil extends StatelessWidget {
  final void Function(int) allerA;
  const Accueil({super.key, required this.allerA});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SperoStore>();
    final admin = store.role == Role.admin;
    final now = DateTime.now();
    final actifs = store.chauffeursActifs;
    final attendu = actifs.where((c) => store.estJourTravaille(c, now)).fold<int>(0, (s, c) => s + c.montantJournalier);
    final encaisse = store.encaisseLe(now);
    final alertes = store.alertesOuvertes();
    final critiques = alertes.where((a) => a.niveau == Niveau.critique).length;
    final aJour = actifs.where((c) => store.situation(c).joursRetard == 0).length;
    final enRoute = store.traceurs.values.where((e) => e.moteur && e.vitesse > 0).length;
    final debutMois = DateTime(now.year, now.month);
    final resultatMois =
        store.encaisseEntre(debutMois, now.add(const Duration(days: 1))) -
        store.depensesEntre(debutMois, now.add(const Duration(days: 1))) -
        store.salairesEntre(debutMois, now.add(const Duration(days: 1)));
    final inscriptions = store.inscriptionsEnAttente.length;
    final aEncaisser = actifs.where((c) => !store.situation(c).payeAujourdhui).toList()
      ..sort((a, b) => store.situation(b).arrieres.compareTo(store.situation(a).arrieres));
    final depensesAttente = store.depenses.where((d) => d.statut == StatutDepense.enAttente).length;

    void ouvrir(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));

    final actions = admin
        ? [
            TuileAction(
              icone: Icons.notifications_active_rounded,
              libelle: 'Alertes',
              couleur: SperoColors.rouge,
              fond: SperoColors.rougeClair,
              onTap: () => ouvrir(const EcranAlertes()),
            ),
            TuileAction(
              icone: Icons.receipt_long_rounded,
              libelle: depensesAttente > 0 ? 'À valider ($depensesAttente)' : 'Dépenses',
              couleur: SperoColors.jaune,
              fond: SperoColors.jauneClair,
              onTap: () => ouvrir(const EcranDepenses()),
            ),
            TuileAction(
              icone: Icons.map_rounded,
              libelle: 'Carte',
              couleur: SperoColors.vert,
              fond: SperoColors.vertClair,
              onTap: () => allerA(1),
            ),
            TuileAction(
              icone: Icons.bar_chart_rounded,
              libelle: 'Rapports',
              couleur: SperoColors.vert,
              fond: SperoColors.vertClair,
              onTap: () => allerA(4),
            ),
            TuileAction(
              icone: Icons.how_to_reg_rounded,
              libelle: inscriptions > 0 ? 'Inscriptions ($inscriptions)' : 'Inscriptions',
              couleur: SperoColors.rouge,
              fond: SperoColors.rougeClair,
              onTap: () => ouvrir(const EcranInscriptions()),
            ),
            TuileAction(
              icone: Icons.history_rounded,
              libelle: 'Journal',
              couleur: SperoColors.jaune,
              fond: SperoColors.jauneClair,
              onTap: () => ouvrir(const EcranJournal()),
            ),
            TuileAction(
              icone: Icons.tune_rounded,
              libelle: 'Paramètres',
              couleur: SperoColors.vert,
              fond: SperoColors.vertClair,
              onTap: () => ouvrir(const EcranParametres()),
            ),
            TuileAction(
              icone: Icons.payments_rounded,
              libelle: 'Versements',
              couleur: SperoColors.vert,
              fond: SperoColors.vertClair,
              onTap: () => allerA(2),
            ),
          ]
        : [
            TuileAction(
              icone: Icons.payments_rounded,
              libelle: 'Dépôt espèces',
              couleur: SperoColors.vert,
              fond: SperoColors.vertClair,
              onTap: () => ouvrir(const NouveauVersement()),
            ),
            TuileAction(
              icone: Icons.receipt_long_rounded,
              libelle: 'Dépense',
              couleur: SperoColors.jaune,
              fond: SperoColors.jauneClair,
              onTap: () => ouvrir(const NouvelleDepense()),
            ),
            TuileAction(
              icone: Icons.car_crash_rounded,
              libelle: 'Incident',
              couleur: SperoColors.rouge,
              fond: SperoColors.rougeClair,
              onTap: () => ouvrir(const NouvelIncident()),
            ),
            TuileAction(
              icone: Icons.fact_check_rounded,
              libelle: 'Inspection',
              couleur: SperoColors.vert,
              fond: SperoColors.vertClair,
              onTap: () => ouvrir(const NouvelleInspection()),
            ),
            TuileAction(
              icone: Icons.notifications_active_rounded,
              libelle: 'Alertes',
              couleur: SperoColors.rouge,
              fond: SperoColors.rougeClair,
              onTap: () => ouvrir(const EcranAlertes()),
            ),
            TuileAction(
              icone: Icons.map_rounded,
              libelle: 'Carte',
              couleur: SperoColors.vert,
              fond: SperoColors.vertClair,
              onTap: () => allerA(1),
            ),
            TuileAction(
              icone: Icons.list_alt_rounded,
              libelle: 'Dépenses',
              couleur: SperoColors.jaune,
              fond: SperoColors.jauneClair,
              onTap: () => ouvrir(const EcranDepenses()),
            ),
            TuileAction(
              icone: Icons.electric_rickshaw_rounded,
              libelle: 'Flotte',
              couleur: SperoColors.vert,
              fond: SperoColors.vertClair,
              onTap: () => allerA(3),
            ),
          ];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _EnTete(
              titre: admin ? 'Bonjour, Propriétaire' : 'Bonjour, Gestionnaire',
              critiques: critiques,
              encaisse: encaisse,
              attendu: attendu,
              onAlertes: () => ouvrir(const EcranAlertes()),
            ),
          ),
          SliverToBoxAdapter(
            child: Largeur(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 18),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                        child: Grille(enfants: actions, colonnes: 4, colonnesLarge: 8, ecart: 4),
                      ),
                    ),
                    const TitreSection('En ce moment'),
                    Grille(
                      enfants: [
                        Indicateur(
                          valeur: '$enRoute / ${store.tricycles.length}',
                          libelle: 'Tricycles en route',
                          icone: Icons.route_rounded,
                        ),
                        Indicateur(
                          valeur: '$aJour / ${actifs.length}',
                          libelle: 'Chauffeurs à jour',
                          icone: Icons.verified_rounded,
                          couleur: aJour == actifs.length ? SperoColors.vert : const Color(0xFFC9A400),
                        ),
                        Indicateur(
                          valeur: nombre(store.arrieresTotaux),
                          libelle: 'Arriérés (FCFA)',
                          icone: Icons.hourglass_bottom_rounded,
                          couleur: store.arrieresTotaux > 0 ? SperoColors.rouge : SperoColors.vert,
                        ),
                        if (admin)
                          Indicateur(valeur: nombre(resultatMois), libelle: 'Résultat du mois (FCFA)', icone: Icons.trending_up_rounded)
                        else
                          Indicateur(
                            valeur: '${alertes.length}',
                            libelle: 'Alertes ouvertes',
                            icone: Icons.notifications_rounded,
                            couleur: SperoColors.rouge,
                          ),
                      ],
                    ),
                    TitreSection(
                      'Alertes',
                      action: TextButton(onPressed: () => ouvrir(const EcranAlertes()), child: Text('Tout voir (${alertes.length})')),
                    ),
                    if (alertes.isEmpty) const Card(child: Vide(Icons.check_circle_outline, 'Aucune alerte. Tout est en ordre.')),
                    for (final a in alertes.take(3))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: CarteAlerte(a, onTap: () => ouvrirAlerte(context, a)),
                      ),
                    TitreSection(
                      'Dépôts du jour à recevoir',
                      action: admin
                          ? null
                          : TextButton(onPressed: () => ouvrir(const NouveauVersement()), child: const Text('Dépôt espèces')),
                    ),
                    if (aEncaisser.isEmpty) const Card(child: Vide(Icons.celebration_outlined, 'Tous les dépôts du jour sont reçus.')),
                    if (aEncaisser.isNotEmpty)
                      Card(
                        child: Column(
                          children: [
                            for (final c in aEncaisser)
                              ListTile(
                                leading: Initiales(c.nom, couleur: store.situation(c).niveau.couleur),
                                title: Text(c.nom, style: const TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: Text(
                                  '${c.tricycleId ?? 'Sans tricycle'} · déposé ${nombre(store.situation(c).deposeAujourdhui)} sur ${nombre(store.situation(c).duAujourdhui)} · il manque ${fcfa(store.situation(c).resteAujourdhui)}',
                                ),
                                trailing: Pastille.situation(store.situation(c)),
                                onTap: () => ouvrir(FicheChauffeur(chauffeurId: c.id)),
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnTete extends StatelessWidget {
  final String titre;
  final int critiques;
  final int encaisse;
  final int attendu;
  final VoidCallback onAlertes;
  const _EnTete({required this.titre, required this.critiques, required this.encaisse, required this.attendu, required this.onAlertes});

  @override
  Widget build(BuildContext context) {
    final store = context.read<SperoStore>();
    final ratio = attendu == 0 ? 1.0 : (encaisse / attendu).clamp(0.0, 1.0);
    return Container(
      decoration: const BoxDecoration(
        color: SperoColors.vert,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Largeur(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(DateFormatSimple.dateLongue(DateTime.now()), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text(
                            titre,
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onAlertes,
                      icon: Badge(
                        isLabelVisible: critiques > 0,
                        label: Text('$critiques'),
                        backgroundColor: SperoColors.rouge,
                        child: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 28),
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      onSelected: (v) {
                        if (v == 'quitter') store.deconnecter();
                        if (v == 'parametres') {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const EcranParametres()));
                        }
                      },
                      itemBuilder: (_) => [
                        if (store.role == Role.admin) const PopupMenuItem(value: 'parametres', child: Text('Paramètres')),
                        const PopupMenuItem(value: 'quitter', child: Text('Se déconnecter')),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(18)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Encaissé aujourd\'hui', style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 4),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.end,
                        children: [
                          Text(
                            fcfa(encaisse),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Text('sur ${nombre(attendu)}', style: const TextStyle(color: Colors.white70)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 8,
                          color: SperoColors.jaune,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
